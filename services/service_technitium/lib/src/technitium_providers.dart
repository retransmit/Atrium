import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'models/technitium_blocked_zone.dart';
import 'models/technitium_query_log.dart';
import 'models/technitium_settings.dart';
import 'models/technitium_stats.dart';
import 'models/technitium_status.dart';
import 'technitium_api.dart';
import 'technitium_session.dart';

/// Preset timed pauses for protection.
class TechnitiumPause {
  const TechnitiumPause(this.label, this.duration);
  final String label;
  final Duration duration;
}

const List<TechnitiumPause> technitiumPauses = <TechnitiumPause>[
  TechnitiumPause('1 minute', Duration(minutes: 1)),
  TechnitiumPause('5 minutes', Duration(minutes: 5)),
  TechnitiumPause('10 minutes', Duration(minutes: 10)),
  TechnitiumPause('1 hour', Duration(hours: 1)),
];

/// The session manager for a Technitium instance.
final technitiumSessionProvider = Provider.family<TechnitiumSession, Instance>(
  (Ref ref, Instance instance) => TechnitiumSession(),
);

/// The API client for an instance.
final technitiumApiProvider = FutureProvider.family<TechnitiumApi, Instance>((
  Ref ref,
  Instance instance,
) async {
  final Dio dio = await ref.watch(instanceDioProvider(instance).future);
  final TechnitiumSession session =
      ref.watch(technitiumSessionProvider(instance));
  return TechnitiumApi(dio, session);
});

/// Current dashboard time window for statistics (e.g. `LastHour`, `LastDay`, `LastWeek`, `LastMonth`).
final technitiumStatsPeriodProvider =
    StateProvider.family<String, Instance>((Ref ref, Instance _) => 'LastDay');

/// Server status, combining `/api/status` with settings blocking status.
final technitiumStatusProvider =
    FutureProvider.family<TechnitiumStatus, Instance>((
  Ref ref,
  Instance instance,
) async {
  final TechnitiumApi api =
      await ref.watch(technitiumApiProvider(instance).future);
  final DateTime readAt = DateTime.now();
  final TechnitiumStatus status = await api.getStatus();
  final TechnitiumSettings settings = await api.getSettings();
  return TechnitiumStatus(
    version: status.version.isNotEmpty ? status.version : '13.0.0',
    dnsServerDomain: settings.dnsServerDomain.isNotEmpty
        ? settings.dnsServerDomain
        : status.dnsServerDomain,
    isBlockingEnabled: settings.enableBlocking,
    pausedUntil: settings.temporaryDisableBlockingTill,
    readAt: readAt,
    uptimeSeconds: status.uptimeSeconds,
    serverIp: status.serverIp,
  );
});

/// Fixed 24-hour statistics for the Atrium dashboard widget.
final technitiumDashboardStatsProvider =
    FutureProvider.family<TechnitiumStats, Instance>((
  Ref ref,
  Instance instance,
) async {
  final TechnitiumApi api =
      await ref.watch(technitiumApiProvider(instance).future);
  return api.getStats(type: 'LastDay');
});

/// Server statistics for the active period.
final technitiumStatsProvider =
    FutureProvider.family<TechnitiumStats, Instance>((
  Ref ref,
  Instance instance,
) async {
  final TechnitiumApi api =
      await ref.watch(technitiumApiProvider(instance).future);
  final String period = ref.watch(technitiumStatsPeriodProvider(instance));
  return api.getStats(type: period);
});

/// Server settings (blocking settings, upstream forwarders, cache configs).
final technitiumSettingsProvider =
    FutureProvider.family<TechnitiumSettings, Instance>((
  Ref ref,
  Instance instance,
) async {
  final TechnitiumApi api =
      await ref.watch(technitiumApiProvider(instance).future);
  return api.getSettings();
});

/// Manually configured blocked zones.
final technitiumBlockedZonesProvider =
    FutureProvider.family<List<TechnitiumBlockedZone>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final TechnitiumApi api =
      await ref.watch(technitiumApiProvider(instance).future);
  return api.listBlockedZones();
});

/// Current response-type filter for the query log.
final technitiumQueryLogFilterProvider =
    StateProvider.family<String, Instance>((Ref ref, Instance _) => 'All');

/// Current search term for the query log.
final technitiumQueryLogSearchProvider =
    StateProvider.family<String, Instance>((Ref ref, Instance _) => '');

/// Current page number for query log pagination.
final technitiumQueryLogPageProvider =
    StateProvider.family<int, Instance>((Ref ref, Instance _) => 1);

/// Query log page stream.
final technitiumQueryLogProvider =
    FutureProvider.family<TechnitiumQueryLogPage, Instance>((
  Ref ref,
  Instance instance,
) async {
  final TechnitiumApi api =
      await ref.watch(technitiumApiProvider(instance).future);
  final String filter = ref.watch(technitiumQueryLogFilterProvider(instance));
  final String search = ref.watch(technitiumQueryLogSearchProvider(instance));
  final int page = ref.watch(technitiumQueryLogPageProvider(instance));

  return api.getQueryLogs(
    pageNumber: page,
    filter: filter,
    domain: search.isNotEmpty ? search : null,
  );
});

/// Actions coordinator for mutations (pause, resume, flush, block domain).
class TechnitiumActions {
  const TechnitiumActions(this._ref, this._instance);

  final Ref _ref;
  final Instance _instance;

  Future<TechnitiumApi> _api() =>
      _ref.read(technitiumApiProvider(_instance).future);

  /// Pauses, disables, or resumes DNS ad blocking.
  Future<void> setProtection({required bool enabled, Duration? pause}) async {
    final TechnitiumApi api = await _api();
    try {
      if (pause != null && pause > Duration.zero) {
        final int minutes = (pause.inSeconds / 60).ceil().clamp(1, 1440);
        await api.temporaryDisableBlocking(minutes: minutes);
      } else if (enabled) {
        // Clear any pause and enable
        await api.temporaryDisableBlocking(minutes: 0);
        await api.setBlocking(enabled: true);
      } else {
        // Clear any pending temporary-disable timer before disabling
        // indefinitely so it does not auto-resume later.
        await api.temporaryDisableBlocking(minutes: 0);
        await api.setBlocking(enabled: false);
      }
    } finally {
      _ref.invalidate(technitiumStatusProvider(_instance));
      _ref.invalidate(technitiumSettingsProvider(_instance));
      _ref.invalidate(technitiumStatsProvider(_instance));
      _ref.invalidate(technitiumDashboardStatsProvider(_instance));
    }
  }

  /// Flushes DNS server cache.
  Future<void> flushDnsCache() async {
    final TechnitiumApi api = await _api();
    await api.flushDnsCache();
    _ref.invalidate(technitiumStatsProvider(_instance));
    _ref.invalidate(technitiumStatusProvider(_instance));
  }

  /// Forces an update of block lists.
  Future<void> forceUpdateBlockLists() async {
    final TechnitiumApi api = await _api();
    await api.forceUpdateBlockLists();
    _ref.invalidate(technitiumSettingsProvider(_instance));
  }

  /// Adds a domain to blocked zones.
  Future<void> addBlockedZone(String domain) async {
    final TechnitiumApi api = await _api();
    await api.addBlockedZone(domain);
    _ref.invalidate(technitiumBlockedZonesProvider(_instance));
    _ref.invalidate(technitiumSettingsProvider(_instance));
  }

  /// Removes a domain from blocked zones.
  Future<void> deleteBlockedZone(String domain) async {
    final TechnitiumApi api = await _api();
    await api.deleteBlockedZone(domain);
    _ref.invalidate(technitiumBlockedZonesProvider(_instance));
    _ref.invalidate(technitiumSettingsProvider(_instance));
  }

  /// Refreshes all active instance providers.
  void refresh() {
    _ref.invalidate(technitiumStatusProvider(_instance));
    _ref.invalidate(technitiumStatsProvider(_instance));
    _ref.invalidate(technitiumDashboardStatsProvider(_instance));
    _ref.invalidate(technitiumSettingsProvider(_instance));
    _ref.invalidate(technitiumBlockedZonesProvider(_instance));
    _ref.invalidate(technitiumQueryLogProvider(_instance));
  }
}

final technitiumActionsProvider = Provider.family<TechnitiumActions, Instance>(
  TechnitiumActions.new,
);
