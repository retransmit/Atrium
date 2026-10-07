import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'adguard_home_access_edit.dart';
import 'adguard_home_api.dart';
import 'adguard_home_errors.dart';
import 'adguard_home_rules.dart';
import 'adguard_home_session.dart';
import 'models/adguard_home_access.dart';
import 'models/adguard_home_filtering.dart';
import 'models/adguard_home_stats.dart';
import 'models/adguard_home_status.dart';

/// How often the status is read: often enough that a pause someone else
/// set, or one that ran out, shows up promptly.
const Duration adguardHomeStatusInterval = Duration(seconds: 10);

/// How often the statistics are read.
const Duration adguardHomeStatsInterval = Duration(seconds: 30);

/// How often the filter lists are read. Their rule counts only move when
/// the server refreshes a list.
const Duration adguardHomeFilteringInterval = Duration(minutes: 5);

/// The session of an instance: the queue its requests leave through and the
/// latch a refused sign-in closes.
///
/// Deliberately not auto-disposed. The latch has to outlive whichever screen
/// or widget was watching when the sign-in was refused, or the next one to
/// open would send the wrong password again. Editing the instance makes a
/// new [Instance], and so a new session.
final adguardHomeSessionProvider = Provider.family<AdguardHomeSession, Instance>(
  (Ref ref, Instance instance) => AdguardHomeSession(),
);

/// How many times the user has asked to try the sign-in again.
///
/// The polled reads are told through an invalidation. What is not a
/// provider of that kind, the query log, listens to this instead, so that a
/// try that works from one tab is seen on the other.
final adguardHomeSignInRetriesProvider =
    StateProvider.family<int, Instance>((Ref ref, Instance _) => 0);

/// Whether [instance] has a username or password to sign in with.
///
/// Without either, nothing is sent that AdGuard Home counts as a wrong try.
/// A 401 then means the server wants a sign-in, not that one was wrong.
bool adguardHomeHasCredentials(Instance instance) => switch (instance.auth) {
      InstanceAuthUserPass(:final String username, :final String password) =>
        username.isNotEmpty || password.isNotEmpty,
      _ => false,
    };

/// The API client of an instance.
final adguardHomeApiProvider =
    FutureProvider.family<AdguardHomeApi, Instance>((
  Ref ref,
  Instance instance,
) async {
  final Dio dio = await ref.watch(instanceDioProvider(instance).future);
  return AdguardHomeApi(dio, ref.watch(adguardHomeSessionProvider(instance)));
});

/// Whether the server is running and filtering, re-read every
/// [adguardHomeStatusInterval].
///
/// The polling keeps its timer after a refused sign-in, but the session
/// answers those runs without sending anything.
final adguardHomeStatusProvider =
    FutureProvider.autoDispose.family<AdguardHomeStatus, Instance>(
  (Ref ref, Instance instance) => ref.polled(
    adguardHomeStatusInterval,
    () async =>
        (await ref.watch(adguardHomeApiProvider(instance).future)).getStatus(),
  ),
);

/// The statistics, re-read every [adguardHomeStatsInterval].
final adguardHomeStatsProvider =
    FutureProvider.autoDispose.family<AdguardHomeStats, Instance>(
  (Ref ref, Instance instance) => ref.polled(
    adguardHomeStatsInterval,
    () async =>
        (await ref.watch(adguardHomeApiProvider(instance).future)).getStats(),
  ),
);

/// The filter lists and custom rules, re-read every
/// [adguardHomeFilteringInterval].
final adguardHomeFilteringProvider =
    FutureProvider.autoDispose.family<AdguardHomeFiltering, Instance>(
  (Ref ref, Instance instance) => ref.polled(
    adguardHomeFilteringInterval,
    () async => (await ref.watch(adguardHomeApiProvider(instance).future))
        .getFiltering(),
  ),
);

/// How far back the statistics go. Read once: it changes only when someone
/// changes the setting.
final adguardHomeStatsPeriodProvider =
    FutureProvider.autoDispose.family<Duration, Instance>((
  Ref ref,
  Instance instance,
) async {
  final AdguardHomeApi api =
      await ref.watch(adguardHomeApiProvider(instance).future);
  return api.getStatsPeriod();
});

/// One of the lengths protection can be paused for.
class AdguardHomePause {
  const AdguardHomePause(this.label, this.length);

  final String label;
  final Duration length;
}

/// The pauses AdGuard Home's own page offers, in its order.
///
/// "Until tomorrow" is the flat 24 hours the web UI sends for it, not the
/// time left until midnight.
const List<AdguardHomePause> adguardHomePauses = <AdguardHomePause>[
  AdguardHomePause('30 seconds', Duration(seconds: 30)),
  AdguardHomePause('1 minute', Duration(minutes: 1)),
  AdguardHomePause('10 minutes', Duration(minutes: 10)),
  AdguardHomePause('1 hour', Duration(hours: 1)),
  AdguardHomePause('Until tomorrow', Duration(hours: 24)),
];

/// The changes the Home tab and the dashboard widget can make.
final adguardHomeActionsProvider =
    Provider.family<AdguardHomeActions, Instance>(AdguardHomeActions.new);

class AdguardHomeActions {
  AdguardHomeActions(this._ref, this._instance);

  final Ref _ref;
  final Instance _instance;

  Future<AdguardHomeApi> get _api =>
      _ref.read(adguardHomeApiProvider(_instance).future);

  /// Turns protection on or off, or pauses it for [pause], then reads the
  /// status again.
  Future<void> setProtection({required bool enabled, Duration? pause}) async {
    await (await _api).setProtection(enabled: enabled, pause: pause);
    _ref.invalidate(adguardHomeStatusProvider(_instance));
  }

  /// Lets one more request out after a refused sign-in, and reads
  /// everything again behind it.
  void retrySignIn() {
    _ref.read(adguardHomeSessionProvider(_instance)).retry();
    _ref.read(adguardHomeSignInRetriesProvider(_instance).notifier).state++;
    refresh();
  }

  /// Reads everything again.
  void refresh() {
    _ref.invalidate(adguardHomeStatusProvider(_instance));
    _ref.invalidate(adguardHomeStatsProvider(_instance));
    _ref.invalidate(adguardHomeFilteringProvider(_instance));
    _ref.invalidate(adguardHomeStatsPeriodProvider(_instance));
  }

  /// Blocks or unblocks [domain] through the custom rules, the way the web
  /// UI does (see [adguardHomeBlockingEdit]).
  ///
  /// The rules are read fresh first: the list may have been edited
  /// elsewhere since it was last shown, and the write replaces all of it.
  ///
  /// With a [clientAddress] the rule is for that client only. It names the
  /// client the way the server knows it, so the named clients are read
  /// first.
  Future<AdguardHomeRuleEdit> toggleBlocking(
    String domain, {
    required bool block,
    String? clientAddress,
  }) async {
    final AdguardHomeApi api = await _api;
    final String? client = clientAddress == null
        ? null
        : adguardHomeBlockingClientName(
            await api.getPersistentClients(),
            clientAddress,
          );
    final AdguardHomeFiltering filtering = await api.getFiltering();
    final AdguardHomeRuleEdit edit = adguardHomeBlockingEdit(
      filtering.userRules,
      domain,
      block: block,
      client: client,
    );
    if (edit.change != AdguardHomeRuleChange.alreadyThere) {
      await api.setUserRules(edit.rules);
      _ref.invalidate(adguardHomeFilteringProvider(_instance));
    }
    return edit;
  }

  /// Who may use the server, read now. For the question that is asked
  /// before a client is shut out.
  Future<AdguardHomeAccessList> readAccessList() async =>
      (await _api).getAccessList();

  /// Shuts the client at [address] out, or lets it back in when it is
  /// [disallowed] now, the way the web UI does (see
  /// [adguardHomeClientAccessEdit]).
  ///
  /// The lists are read fresh first, as the write replaces all three. A
  /// client that turns out to be the last allowed one is left alone and
  /// [AdguardHomeLastAllowedClient] is thrown, whatever was confirmed
  /// against an older reading. So is one that is only let in by an entry
  /// covering more than itself, with [AdguardHomeAllowedByWiderEntry]: the
  /// write would change nothing.
  Future<void> setClientAccess({
    required String address,
    required bool disallowed,
    required String disallowedRule,
  }) async {
    final AdguardHomeApi api = await _api;
    final AdguardHomeAccessList list = await api.getAccessList();
    if (adguardHomeIsLastAllowedClient(list, address, disallowed: disallowed)) {
      throw const AdguardHomeLastAllowedClient();
    }
    if (adguardHomeIsAllowedByWiderEntry(
      list,
      address,
      disallowed: disallowed,
    )) {
      throw const AdguardHomeAllowedByWiderEntry();
    }
    await api.setAccessList(
      adguardHomeClientAccessEdit(
        list,
        address: address,
        disallowed: disallowed,
        disallowedRule: disallowedRule,
      ),
    );
  }

  /// Throws the whole query log away.
  Future<void> clearQueryLog() async => (await _api).clearQueryLog();
}
