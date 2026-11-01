import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'adguard_home_access_edit.dart';
import 'adguard_home_api.dart';
import 'adguard_home_client_edit.dart';
import 'adguard_home_clients_view.dart';
import 'adguard_home_errors.dart';
import 'adguard_home_filter_rules.dart';
import 'adguard_home_query_log.dart';
import 'adguard_home_rules.dart';
import 'adguard_home_session.dart';
import 'models/adguard_home_access.dart';
import 'models/adguard_home_clients.dart';
import 'models/adguard_home_filtering.dart';
import 'models/adguard_home_filters.dart';
import 'models/adguard_home_services.dart';
import 'models/adguard_home_settings.dart';
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

/// The clients as the Clients tab lists them: those with settings and those
/// the server has merely seen, each with its queries.
///
/// Three requests, one after the other: the clients, the statistics for
/// their top clients, and whose each of those is. Read once, and again
/// when asked: a list of clients does not need a timer.
final adguardHomeClientsProvider =
    FutureProvider.autoDispose.family<AdguardHomeClientsView, Instance>(
  (Ref ref, Instance instance) async {
    // A try that works from another tab has to be seen here too.
    ref.watch(adguardHomeSignInRetriesProvider(instance));
    final AdguardHomeApi api =
        await ref.watch(adguardHomeApiProvider(instance).future);
    final AdguardHomeClientList list = await api.getClients();
    final AdguardHomeStats stats = await api.getStats();
    return AdguardHomeClientsView.build(
      list: list,
      topClients: stats.topClients,
      found: await adguardHomeFindClients(
        api,
        <String>[for (final AdguardHomeCount top in stats.topClients) top.name],
      ),
    );
  },
  // Riverpod would ask again by itself, ten times over. After a refused
  // sign-in nothing would be sent, but a server that is down would be asked
  // three things at a time for nothing.
  retry: (int _, Object __) => null,
);

/// Whose each of [ids] is, as far as the server says.
///
/// A server from before v0.107.56 cannot say: it has no such address and
/// turns the request down, in its own words or, behind a proxy, with the
/// proxy's page for a missing one. Either reads as nothing found, and the
/// caller matches the ids itself. Any other failure is the caller's to
/// show.
Future<Map<String, AdguardHomeFoundClient>> adguardHomeFindClients(
  AdguardHomeApi api,
  List<String> ids,
) async {
  try {
    return await api.searchClients(ids);
  } on AdguardHomeRequestRefused {
    return const <String, AdguardHomeFoundClient>{};
  } on NetworkNotFoundException {
    return const <String, AdguardHomeFoundClient>{};
  }
}

/// Every service the server can block, with names and icons.
///
/// A few hundred kilobytes that only a server update changes, so once read
/// it is kept for the session. A read that failed is not kept.
final adguardHomeServicesProvider =
    FutureProvider.autoDispose.family<AdguardHomeServiceCatalogue, Instance>(
  (Ref ref, Instance instance) async {
    final AdguardHomeApi api =
        await ref.watch(adguardHomeApiProvider(instance).future);
    final AdguardHomeServiceCatalogue catalogue =
        await api.getBlockedServices();
    if (ref.mounted) ref.keepAlive();
    return catalogue;
  },
  retry: (int _, Object __) => null,
);

/// The server's own safe search, which a new client starts from.
final adguardHomeSafeSearchProvider =
    FutureProvider.autoDispose.family<AdguardHomeSafeSearch, Instance>(
  (Ref ref, Instance instance) async {
    final AdguardHomeApi api =
        await ref.watch(adguardHomeApiProvider(instance).future);
    return api.getSafeSearch();
  },
  retry: (int _, Object __) => null,
);

/// The DNS rewrites. Read when a screen asks, not on a timer.
final adguardHomeRewritesProvider =
    FutureProvider.autoDispose.family<List<AdguardHomeRewrite>, Instance>(
  (Ref ref, Instance instance) async {
    ref.watch(adguardHomeSignInRetriesProvider(instance));
    final AdguardHomeApi api =
        await ref.watch(adguardHomeApiProvider(instance).future);
    return api.getRewrites();
  },
  retry: (int _, Object __) => null,
);

/// Whether rewrites apply at all.
final adguardHomeRewritesEnabledProvider =
    FutureProvider.autoDispose.family<bool, Instance>(
  (Ref ref, Instance instance) async {
    ref.watch(adguardHomeSignInRetriesProvider(instance));
    final AdguardHomeApi api =
        await ref.watch(adguardHomeApiProvider(instance).future);
    return api.getRewritesEnabled();
  },
  retry: (int _, Object __) => null,
);

/// The services the server blocks for everyone, and its pause schedule.
final adguardHomeGlobalServicesProvider =
    FutureProvider.autoDispose.family<AdguardHomeGlobalServices, Instance>(
  (Ref ref, Instance instance) async {
    ref.watch(adguardHomeSignInRetriesProvider(instance));
    final AdguardHomeApi api =
        await ref.watch(adguardHomeApiProvider(instance).future);
    return api.getGlobalServices();
  },
  retry: (int _, Object __) => null,
);

/// The protection switches of the General settings, beside filtering on
/// or off, which comes with the lists.
class AdguardHomeGeneralSettings {
  const AdguardHomeGeneralSettings({
    required this.safeBrowsing,
    required this.parental,
    required this.safeSearch,
  });

  final bool safeBrowsing;
  final bool parental;
  final AdguardHomeSafeSearch safeSearch;
}

/// Safe browsing, parental control and safe search: three reads.
final adguardHomeGeneralSettingsProvider =
    FutureProvider.autoDispose.family<AdguardHomeGeneralSettings, Instance>(
  (Ref ref, Instance instance) async {
    ref.watch(adguardHomeSignInRetriesProvider(instance));
    final AdguardHomeApi api =
        await ref.watch(adguardHomeApiProvider(instance).future);
    final bool safeBrowsing = await api.getSafeBrowsing();
    final bool parental = await api.getParental();
    final AdguardHomeSafeSearch safeSearch = await api.getSafeSearch();
    return AdguardHomeGeneralSettings(
      safeBrowsing: safeBrowsing,
      parental: parental,
      safeSearch: safeSearch,
    );
  },
  retry: (int _, Object __) => null,
);

/// How long the query log keeps queries, and which it leaves out.
final adguardHomeQueryLogRetentionProvider =
    FutureProvider.autoDispose.family<AdguardHomeRetention, Instance>(
  (Ref ref, Instance instance) async {
    ref.watch(adguardHomeSignInRetriesProvider(instance));
    final AdguardHomeApi api =
        await ref.watch(adguardHomeApiProvider(instance).future);
    return api.getQueryLogRetention();
  },
  retry: (int _, Object __) => null,
);

/// How long the statistics keep what they count, and what they leave out.
final adguardHomeStatsRetentionProvider =
    FutureProvider.autoDispose.family<AdguardHomeRetention, Instance>(
  (Ref ref, Instance instance) async {
    ref.watch(adguardHomeSignInRetriesProvider(instance));
    final AdguardHomeApi api =
        await ref.watch(adguardHomeApiProvider(instance).future);
    return api.getStatsRetention();
  },
  retry: (int _, Object __) => null,
);

/// The server's DNS settings, for the Upstreams, Server and Cache screens.
final adguardHomeDnsConfigProvider =
    FutureProvider.autoDispose.family<AdguardHomeDnsConfig, Instance>(
  (Ref ref, Instance instance) async {
    ref.watch(adguardHomeSignInRetriesProvider(instance));
    final AdguardHomeApi api =
        await ref.watch(adguardHomeApiProvider(instance).future);
    return api.getDnsConfig();
  },
  retry: (int _, Object __) => null,
);

/// Who may use the server, and which names it refuses outright.
final adguardHomeAccessListProvider =
    FutureProvider.autoDispose.family<AdguardHomeAccessList, Instance>(
  (Ref ref, Instance instance) async {
    ref.watch(adguardHomeSignInRetriesProvider(instance));
    final AdguardHomeApi api =
        await ref.watch(adguardHomeApiProvider(instance).future);
    return api.getAccessList();
  },
  retry: (int _, Object __) => null,
);

/// Whether encryption is set up.
final adguardHomeTlsStatusProvider =
    FutureProvider.autoDispose.family<AdguardHomeTlsStatus, Instance>(
  (Ref ref, Instance instance) async {
    ref.watch(adguardHomeSignInRetriesProvider(instance));
    final AdguardHomeApi api =
        await ref.watch(adguardHomeApiProvider(instance).future);
    return api.getTlsStatus();
  },
  retry: (int _, Object __) => null,
);

/// The server's DHCP.
final adguardHomeDhcpStatusProvider =
    FutureProvider.autoDispose.family<AdguardHomeDhcpStatus, Instance>(
  (Ref ref, Instance instance) async {
    ref.watch(adguardHomeSignInRetriesProvider(instance));
    final AdguardHomeApi api =
        await ref.watch(adguardHomeApiProvider(instance).future);
    return api.getDhcpStatus();
  },
  retry: (int _, Object __) => null,
);

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

  /// Adds the client in [after], or with an [originalName] changes the
  /// client of that name to it. [before] is what the form started with.
  ///
  /// A client that is there is read again first, and only what the form
  /// changed is written over that (see [adguardHomeClientWrite]): the
  /// server resets whatever a write leaves out, and the form may have been
  /// open for a while. One that is no longer there under its name is not
  /// written, and [AdguardHomeClientGone] is thrown.
  ///
  /// The list is read again behind it whether it worked or not: a refusal
  /// often means the list on screen is no longer the server's.
  Future<void> saveClient({
    required AdguardHomeClientDraft before,
    required AdguardHomeClientDraft after,
    String? originalName,
  }) async {
    try {
      final AdguardHomeApi api = await _api;
      if (originalName == null) {
        await api.addClient(adguardHomeNewClient(after));
        return;
      }
      AdguardHomeClient? current;
      for (final AdguardHomeClient client
          in (await api.getClients()).persistent) {
        if (client.name == originalName) current = client;
      }
      if (current == null) throw AdguardHomeClientGone(originalName);
      await api.updateClient(
        originalName,
        adguardHomeClientWrite(
          current: current.json,
          before: before,
          after: after,
        ),
      );
    } finally {
      _ref.invalidate(adguardHomeClientsProvider(_instance));
    }
  }

  /// Removes the settings of the client called [name], and reads the list
  /// again.
  Future<void> deleteClient(String name) async {
    try {
      await (await _api).deleteClient(name);
    } finally {
      _ref.invalidate(adguardHomeClientsProvider(_instance));
    }
  }

  /// Who is behind [address]: the persistent client it belongs to, what the
  /// server knows of it as a runtime client, or neither. [queries] is passed
  /// through for the caller that knows them.
  Future<AdguardHomeClientLookup> findClient(
    String address, {
    int? queries,
  }) async {
    final AdguardHomeApi api = await _api;
    final AdguardHomeClientList list = await api.getClients();
    final Map<String, AdguardHomeFoundClient> found =
        await adguardHomeFindClients(api, <String>[address]);
    return AdguardHomeClientLookup.of(
      address: address,
      list: list,
      found: found[address],
      queries: queries,
    );
  }

  /// The lists, the custom rules and the figures on Home all come from the
  /// one filtering read.
  void _filteringChanged() =>
      _ref.invalidate(adguardHomeFilteringProvider(_instance));

  /// The list of the kind [allowlist] says at [url], as the server has it
  /// now. The server takes a list whole, so what a write does not change
  /// goes back as it is now, not as the screen last read it.
  Future<AdguardHomeFilterList> _freshList(
    AdguardHomeApi api,
    String url, {
    required bool allowlist,
  }) async {
    final AdguardHomeFiltering now = await api.getFiltering();
    for (final AdguardHomeFilterList list
        in allowlist ? now.allowlists : now.blocklists) {
      if (list.url == url) return list;
    }
    throw const AdguardHomeEntryGone('list');
  }

  /// Switches [list] on or off. Its name and address go back as the server
  /// has them.
  Future<void> setListEnabled(
    AdguardHomeFilterList list, {
    required bool allowlist,
    required bool enabled,
  }) async {
    try {
      final AdguardHomeApi api = await _api;
      final AdguardHomeFilterList now =
          await _freshList(api, list.url, allowlist: allowlist);
      await api.updateFilterList(
        url: now.url,
        allowlist: allowlist,
        name: now.name,
        newUrl: now.url,
        enabled: enabled,
      );
    } finally {
      _filteringChanged();
    }
  }

  /// Adds a list called [name] at [url], or with an [original] changes that
  /// one, which keeps its switch as the server has it.
  Future<void> saveList({
    required bool allowlist,
    required String name,
    required String url,
    AdguardHomeFilterList? original,
  }) async {
    try {
      final AdguardHomeApi api = await _api;
      if (original == null) {
        await _addList(api, name: name, url: url, allowlist: allowlist);
      } else {
        final AdguardHomeFilterList now =
            await _freshList(api, original.url, allowlist: allowlist);
        await api.updateFilterList(
          url: now.url,
          allowlist: allowlist,
          name: name,
          newUrl: url,
          enabled: now.enabled,
        );
      }
    } finally {
      _filteringChanged();
    }
  }

  /// The server answers an add only once it has fetched the list. When the
  /// answer is not waited for that long it may still have got there, and
  /// then saying it failed would have the user add it twice.
  Future<void> _addList(
    AdguardHomeApi api, {
    required String name,
    required String url,
    required bool allowlist,
  }) async {
    try {
      await api.addFilterList(name: name, url: url, allowlist: allowlist);
    } on NetworkTimeoutException {
      final AdguardHomeFiltering now = await api.getFiltering();
      final bool there = (allowlist ? now.allowlists : now.blocklists)
          .any((AdguardHomeFilterList list) => list.url == url);
      if (!there) rethrow;
    }
  }

  Future<void> removeList(
    AdguardHomeFilterList list, {
    required bool allowlist,
  }) async {
    try {
      await (await _api).removeFilterList(url: list.url, allowlist: allowlist);
    } finally {
      _filteringChanged();
    }
  }

  /// Fetches the lists of one kind again. The answer is how many changed.
  Future<int> refreshLists({required bool allowlist}) async {
    try {
      return await (await _api).refreshFilterLists(allowlist: allowlist);
    } finally {
      _filteringChanged();
    }
  }

  /// Sets how often the lists are fetched again. Whether filtering is on
  /// goes with it, read fresh: the server resets what the write leaves out.
  Future<void> setUpdateInterval(int hours) async {
    try {
      final AdguardHomeApi api = await _api;
      final AdguardHomeFiltering now = await api.getFiltering();
      await api.setFilteringConfig(enabled: now.enabled, intervalHours: hours);
    } finally {
      _filteringChanged();
    }
  }

  /// Replaces the custom rules with [after].
  ///
  /// The rules are read again first. When they are no longer [before], what
  /// the editor was opened with, someone changed them meanwhile, and
  /// [AdguardHomeRulesChanged] is thrown with the server's rules unless the
  /// user said to [overwrite].
  Future<void> saveRules({
    required List<String> before,
    required List<String> after,
    bool overwrite = false,
  }) async {
    try {
      final AdguardHomeApi api = await _api;
      final List<String> now = (await api.getFiltering()).userRules;
      if (!overwrite && !_sameList(now, before)) {
        throw AdguardHomeRulesChanged(now);
      }
      await api.setUserRules(after);
    } finally {
      _filteringChanged();
    }
  }

  /// Points the custom rules written for the client called [from] at its
  /// new name [to]. The answer is how many rules changed; none, and nothing
  /// is written.
  Future<int> renameClientInRules(String from, String to) async {
    final AdguardHomeApi api = await _api;
    final List<String> rules = (await api.getFiltering()).userRules;
    final int count = adguardHomeRulesNamingClient(rules, from);
    if (count == 0) return 0;
    try {
      await api.setUserRules(adguardHomeRenameClientInRules(rules, from, to));
    } finally {
      _filteringChanged();
    }
    return count;
  }

  /// What the server would do with [name].
  Future<AdguardHomeHostCheck> checkHost(String name, {String? client}) async =>
      (await _api).checkHost(name, client: client);

  /// Blocks [ids] for everyone. The pause schedule is read fresh and goes
  /// back as it is.
  Future<void> setGlobalServiceIds(List<String> ids) async {
    try {
      final AdguardHomeApi api = await _api;
      final AdguardHomeGlobalServices now = await api.getGlobalServices();
      await api.setGlobalServices(now.copyWith(ids: ids));
    } finally {
      _ref.invalidate(adguardHomeGlobalServicesProvider(_instance));
    }
  }

  /// Sets when blocking of the server's services pauses. The services are
  /// read fresh and go back as they are.
  Future<void> setGlobalSchedule(AdguardHomeSchedule schedule) async {
    try {
      final AdguardHomeApi api = await _api;
      final AdguardHomeGlobalServices now = await api.getGlobalServices();
      await api.setGlobalServices(now.copyWith(schedule: schedule));
    } finally {
      _ref.invalidate(adguardHomeGlobalServicesProvider(_instance));
    }
  }

  /// Adds [rewrite], or with an [original] changes that one into it. An
  /// edit keeps the rewrite's switch as the server has it.
  Future<void> saveRewrite({
    required AdguardHomeRewrite rewrite,
    AdguardHomeRewrite? original,
  }) async {
    if (original == null) {
      try {
        await (await _api).addRewrite(rewrite);
      } finally {
        _ref.invalidate(adguardHomeRewritesProvider(_instance));
      }
      return;
    }
    await _changeRewrite(
      original,
      (AdguardHomeRewrite now) => AdguardHomeRewrite(
        domain: rewrite.domain,
        answer: rewrite.answer,
        enabled: now.enabled,
        switchable: now.switchable,
      ),
    );
  }

  Future<void> setRewriteEnabled(
    AdguardHomeRewrite rewrite, {
    required bool enabled,
  }) =>
      _changeRewrite(
        rewrite,
        (AdguardHomeRewrite now) => now.copyWith(enabled: enabled),
      );

  /// Changes [original] into what [change] makes of it as the server has it
  /// now. The server finds the rewrite to change by its domain and answer
  /// alone and takes the first that matches, so a rewrite it holds more
  /// than once is left alone rather than changed at random.
  Future<void> _changeRewrite(
    AdguardHomeRewrite original,
    AdguardHomeRewrite Function(AdguardHomeRewrite now) change,
  ) async {
    try {
      final AdguardHomeApi api = await _api;
      final List<AdguardHomeRewrite> copies = (await api.getRewrites())
          .where((AdguardHomeRewrite r) => r.sameTarget(original))
          .toList();
      if (copies.isEmpty) throw const AdguardHomeEntryGone('rewrite');
      if (copies.length > 1) {
        throw AdguardHomeRewriteRepeated(original.domain, copies.length);
      }
      await api.updateRewrite(copies.single, change(copies.single));
    } finally {
      _ref.invalidate(adguardHomeRewritesProvider(_instance));
    }
  }

  /// Removes [rewrite]. The server removes every copy of it, as its domain
  /// and answer go.
  Future<void> deleteRewrite(AdguardHomeRewrite rewrite) async {
    try {
      await (await _api).deleteRewrite(rewrite);
    } finally {
      _ref.invalidate(adguardHomeRewritesProvider(_instance));
    }
  }

  /// Turns all rewrites on or off.
  Future<void> setRewritesEnabled({required bool enabled}) async {
    try {
      await (await _api).setRewritesEnabled(enabled: enabled);
    } finally {
      _ref.invalidate(adguardHomeRewritesEnabledProvider(_instance));
    }
  }

  /// Turns filtering by the lists and rules on or off. How often the lists
  /// are fetched goes with it, read fresh: the server resets what the write
  /// leaves out.
  Future<void> setFilteringEnabled({required bool enabled}) async {
    try {
      final AdguardHomeApi api = await _api;
      final AdguardHomeFiltering now = await api.getFiltering();
      await api.setFilteringConfig(
        enabled: enabled,
        intervalHours: now.intervalHours,
      );
    } finally {
      _filteringChanged();
    }
  }

  Future<void> setSafeBrowsing({required bool enabled}) async {
    try {
      await (await _api).setSafeBrowsing(enabled: enabled);
    } finally {
      _ref.invalidate(adguardHomeGeneralSettingsProvider(_instance));
    }
  }

  Future<void> setParental({required bool enabled}) async {
    try {
      await (await _api).setParental(enabled: enabled);
    } finally {
      _ref.invalidate(adguardHomeGeneralSettingsProvider(_instance));
    }
  }

  /// Turns safe search, or one engine of it, on or off. The server takes
  /// it whole, so it is read fresh and only what [before] and [after]
  /// differ in is changed.
  Future<void> setSafeSearch({
    required AdguardHomeSafeSearch before,
    required AdguardHomeSafeSearch after,
  }) async {
    try {
      final AdguardHomeApi api = await _api;
      final AdguardHomeSafeSearch now = await api.getSafeSearch();
      await api.setSafeSearch(
        AdguardHomeSafeSearch.fromJson(<String, dynamic>{
          ...now.toJson(),
          ...adguardHomeChangedSettings(before.toJson(), after.toJson()),
        }),
      );
    } finally {
      _ref
        ..invalidate(adguardHomeGeneralSettingsProvider(_instance))
        ..invalidate(adguardHomeSafeSearchProvider(_instance));
    }
  }

  /// Saves the query log's settings: read fresh, with what [before] and
  /// [after] differ in put on top.
  Future<void> saveQueryLogRetention({
    required AdguardHomeRetention before,
    required AdguardHomeRetention after,
  }) async {
    try {
      final AdguardHomeApi api = await _api;
      final AdguardHomeRetention now = await api.getQueryLogRetention();
      await api.setQueryLogRetention(
        AdguardHomeRetention.fromJson(_overlay(now, before, after)),
      );
    } finally {
      _ref
        ..invalidate(adguardHomeQueryLogRetentionProvider(_instance))
        ..invalidate(adguardHomeQueryLogConfigProvider(_instance));
    }
  }

  /// Saves the statistics' settings, as [saveQueryLogRetention].
  Future<void> saveStatsRetention({
    required AdguardHomeRetention before,
    required AdguardHomeRetention after,
  }) async {
    try {
      final AdguardHomeApi api = await _api;
      final AdguardHomeRetention now = await api.getStatsRetention();
      await api.setStatsRetention(
        AdguardHomeRetention.fromJson(_overlay(now, before, after)),
      );
    } finally {
      _ref
        ..invalidate(adguardHomeStatsRetentionProvider(_instance))
        ..invalidate(adguardHomeStatsPeriodProvider(_instance))
        ..invalidate(adguardHomeStatsProvider(_instance));
    }
  }

  static Map<String, dynamic> _overlay(
    AdguardHomeRetention now,
    AdguardHomeRetention before,
    AdguardHomeRetention after,
  ) =>
      <String, dynamic>{
        ...now.toJson(),
        ...adguardHomeChangedSettings(before.toJson(), after.toJson()),
      };

  /// Empties the statistics.
  Future<void> resetStats() async {
    try {
      await (await _api).resetStats();
    } finally {
      _ref.invalidate(adguardHomeStatsProvider(_instance));
    }
  }

  /// Saves DNS settings: only those [after] has otherwise than [before]
  /// are sent, with the rest of any group the server takes only together
  /// (see [adguardHomeDnsChanges]), and the server keeps the others.
  /// Nothing changed, nothing is sent.
  Future<void> saveDnsSettings({
    required Map<String, dynamic> before,
    required Map<String, dynamic> after,
  }) async {
    final Map<String, dynamic> changes = adguardHomeDnsChanges(before, after);
    if (changes.isEmpty) return;
    try {
      await (await _api).setDnsConfig(changes);
    } finally {
      _ref.invalidate(adguardHomeDnsConfigProvider(_instance));
    }
  }

  /// Whether each server answers, for the lists as typed.
  Future<List<AdguardHomeUpstreamResult>> testUpstreams({
    required List<String> upstreams,
    required List<String> bootstrap,
    required List<String> fallback,
    required List<String> privateUpstreams,
  }) async =>
      (await _api).testUpstreams(
        upstreams: upstreams,
        bootstrap: bootstrap,
        fallback: fallback,
        privateUpstreams: privateUpstreams,
      );

  Future<void> clearDnsCache() async => (await _api).clearDnsCache();

  /// Saves the access lists: read fresh, with only the lists [before] and
  /// [after] differ in replaced, as the write replaces all three.
  Future<void> saveAccessList({
    required AdguardHomeAccessList before,
    required AdguardHomeAccessList after,
  }) async {
    try {
      final AdguardHomeApi api = await _api;
      final AdguardHomeAccessList now = await api.getAccessList();
      await api.setAccessList(
        AdguardHomeAccessList.fromJson(<String, dynamic>{
          ...now.toJson(),
          ...adguardHomeChangedSettings(before.toJson(), after.toJson()),
        }),
      );
    } finally {
      _ref.invalidate(adguardHomeAccessListProvider(_instance));
    }
  }

  /// Whether a newer AdGuard Home is out. With [recheck] the server asks
  /// for it now.
  Future<AdguardHomeVersionCheck> checkVersion({bool recheck = false}) async =>
      (await _api).checkVersion(recheck: recheck);
}

bool _sameList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
