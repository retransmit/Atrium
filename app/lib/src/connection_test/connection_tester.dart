import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:service_adguard_home/service_adguard_home.dart';
import 'package:service_beszel/service_beszel.dart';
import 'package:service_emby/service_emby.dart';
import 'package:service_jellyfin/service_jellyfin.dart';
import 'package:service_plex/service_plex.dart';
import 'package:service_qbittorrent/service_qbittorrent.dart';

import 'connection_test_result.dart';

/// Tests one URL of a not-yet-saved [Instance] and reports whether it is
/// reachable and whether its credentials are valid.
///
/// The URL under test is chosen by forcing [UrlMode]: `forceLocal` tests the
/// LAN URL, `forceExternal` tests the WAN URL. The form calls this once per
/// filled-in URL.
///
/// Key and token services (the *arr family, Seerr, Tautulli, SABnzbd, Glances,
/// Speedtest) are verified by [HealthProbe], whose authed endpoints already
/// return 401/403 on a bad key. The session services log in for real, since
/// that is the only way to check their credentials: Jellyfin and Emby each
/// expose `login()`, and Plex is verified against its token-gated
/// `getLibraries()`. qBittorrent logs in for cookie auth, but an API key is
/// stateless (Authorization: Bearer) and cannot use the login endpoint, so it
/// is verified against an authed endpoint instead. Beszel logs in through
/// PocketBase's auth-with-password: its `api/health` endpoint is public (a
/// lightweight probe would pass with any password), so it must attempt the real
/// login, where a rejected email or password comes back as HTTP 400.
///
/// AdGuard Home is asked once, signed. Its health probe carries no password,
/// because AdGuard Home locks an address out after a few wrong ones, so the
/// probe proves nothing about the credentials.
class ConnectionTester {
  ConnectionTester(this._ref, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final Ref _ref;

  /// The clock. Tests hand in their own.
  final DateTime Function() _now;

  /// How long a refused AdGuard Home sign-in is remembered.
  static const Duration _adguardHomeRefusalMemory = Duration(seconds: 30);

  /// The AdGuard Home candidate whose sign-in was last refused, and when.
  ///
  /// The form tests the local address and then the external one. AdGuard
  /// Home counts every wrong password towards a lockout, so the second
  /// address must not send what the first was just refused with. Anything
  /// changed on the form makes a different candidate, and that is tried.
  Instance? _adguardHomeRefused;
  DateTime? _adguardHomeRefusedAt;

  Future<ConnectionTestResult> test({
    required Instance candidate,
    required UrlMode url,
  }) async {
    final Instance forced = candidate.copyWith(urlMode: url);
    switch (forced.kind) {
      case ServiceKind.qbittorrent:
        return _verify(() async {
          final QbittorrentClient client =
              await _ref.read(qbittorrentClientProvider(forced).future);
          // qBit 5.2+ API keys are stateless (Authorization: Bearer) and cannot
          // use the cookie login endpoint, so an empty-credential login() would
          // always report the key as rejected. Verify it against an authed
          // endpoint instead; a bad key 403s there just the same.
          if (forced.auth is InstanceAuthApiKey) {
            await client.getTransferInfo();
          } else {
            await client.login();
          }
        });
      case ServiceKind.jellyfin:
        return _verify(() async {
          final JellyfinClient client =
              await _ref.read(jellyfinClientProvider(forced).future);
          await client.login();
        });
      case ServiceKind.emby:
        return _verify(() async {
          final EmbyClient client =
              await _ref.read(embyClientProvider(forced).future);
          await client.login();
        });
      case ServiceKind.plex:
        return _verify(() async {
          final PlexApi api = await _ref.read(plexApiProvider(forced).future);
          await api.getLibraries();
        });
      case ServiceKind.beszel:
        return _verify(() async {
          // `api/health` is public, so a probe can't tell a good password from a
          // bad one; log in against PocketBase for real and let a rejection (a
          // 400 from auth-with-password) surface as an auth failure.
          final Dio dio = await _ref.read(dioFactoryProvider).create(forced);
          try {
            await verifyBeszelConnection(dio, forced.auth);
          } finally {
            dio.close(force: true);
          }
        });
      case ServiceKind.adguardHome:
        return _testAdguardHome(candidate, forced);
      default:
        final HealthProbe probe =
            HealthProbe(dioFactory: _ref.read(dioFactoryProvider));
        // Only whether the URL and credentials work. A problem the service
        // reports about itself, such as a stopped Gluetun VPN, is not a
        // failed connection and would otherwise read as a rejected key.
        return connectionResultFromHealth(
          await probe.check(forced, connectionOnly: true),
        );
    }
  }

  /// One signed request, unless this exact [candidate] was refused a moment
  /// ago. [forced] is the candidate pinned to the address under test.
  Future<ConnectionTestResult> _testAdguardHome(
    Instance candidate,
    Instance forced,
  ) async {
    final DateTime? refusedAt = _adguardHomeRefusedAt;
    if (candidate == _adguardHomeRefused &&
        refusedAt != null &&
        _now().difference(refusedAt) < _adguardHomeRefusalMemory) {
      return const ConnectionTestResult(
        ConnectionOutcome.authFailed,
        'Not tried, because this sign-in was refused a moment ago',
      );
    }
    Dio? dio;
    try {
      dio = await _ref.read(dioFactoryProvider).create(forced);
      await AdguardHomeApi(dio, AdguardHomeSession()).getStatus();
      return const ConnectionTestResult(
        ConnectionOutcome.connected,
        'Connected',
      );
    } on AdguardHomeSignInRefused {
      _adguardHomeRefused = candidate;
      _adguardHomeRefusedAt = _now();
      return const ConnectionTestResult(
        ConnectionOutcome.authFailed,
        'Sign-in refused. By default AdGuard Home blocks an address for 15 '
        'minutes after five wrong tries',
      );
    } on Object catch (error) {
      if (error is AdguardHomeUnexpectedAnswer ||
          error is AdguardHomeRequestRefused ||
          error is NetworkNotFoundException) {
        // Something answered, but not AdGuard Home's API: another server, a
        // proxy's sign-in page, or a wrong base path.
        return const ConnectionTestResult(
          ConnectionOutcome.authFailed,
          'Reachable, but AdGuard Home did not answer at this address',
        );
      }
      return connectionResultFromError(error);
    } finally {
      dio?.close(force: true);
    }
  }

  Future<ConnectionTestResult> _verify(Future<void> Function() action) async {
    try {
      await action();
      return const ConnectionTestResult(
        ConnectionOutcome.connected,
        'Connected',
      );
    } on Object catch (error) {
      return connectionResultFromError(error);
    }
  }
}

final Provider<ConnectionTester> connectionTesterProvider =
    Provider<ConnectionTester>((Ref ref) => ConnectionTester(ref));
