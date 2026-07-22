import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connection_test_result.dart';

/// Tests one URL of a not-yet-saved [Instance] and reports whether it is
/// reachable and whether its credentials are valid.
///
/// The URL under test is chosen by forcing [UrlMode]: `forceLocal` tests the
/// LAN URL, `forceExternal` tests the WAN URL. The form calls this once per
/// filled-in URL.
///
/// Key and token services (the *arr family, Seerr, Tautulli, SABnzbd, Plex,
/// Glances, Speedtest) are verified by [HealthProbe], whose authed endpoints
/// already return 401/403 on a bad key. The session services (qBittorrent,
/// Jellyfin, Emby) get their own branches in later tasks, since a real login
/// is the only way to check their credentials.
class ConnectionTester {
  ConnectionTester(this._ref);

  final Ref _ref;

  Future<ConnectionTestResult> test({
    required Instance candidate,
    required UrlMode url,
  }) async {
    final Instance forced = candidate.copyWith(urlMode: url);
    final HealthProbe probe =
        HealthProbe(dioFactory: _ref.read(dioFactoryProvider));
    final Health health = await probe.check(forced);
    return connectionResultFromHealth(health);
  }
}

final Provider<ConnectionTester> connectionTesterProvider =
    Provider<ConnectionTester>((Ref ref) => ConnectionTester(ref));
