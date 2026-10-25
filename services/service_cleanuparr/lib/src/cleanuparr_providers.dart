import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'cleanuparr_api.dart';
import 'models/cleanuparr_event.dart';
import 'models/cleanuparr_job.dart';
import 'models/cleanuparr_stats.dart';
import 'models/cleanuparr_status.dart';
import 'models/cleanuparr_strike.dart';

/// Active bottom navbar tab index for [instance] (0: Overview, 1: Strikes, 2: Events).
final cleanuparrTabProvider =
    StateProvider.autoDispose.family<int, Instance>((ref, instance) => 0);

/// Provides a [CleanuparrApi] configured with the instance's resolved base URL and API key.
final cleanuparrApiProvider =
    FutureProvider.autoDispose.family<CleanuparrApi, Instance>((
  Ref ref,
  Instance instance,
) async {
  final Dio dio = await ref.watch(instanceDioProvider(instance).future);
  return CleanuparrApi(dio);
},
  retry: (int _, Object __) => null,
);

/// Fetches system information, uptime, memory, and Arr/client connections.
final cleanuparrStatusProvider =
    FutureProvider.autoDispose.family<CleanuparrStatus, Instance>((
  Ref ref,
  Instance instance,
) async {
  final CleanuparrApi api =
      await ref.watch(cleanuparrApiProvider(instance).future);
  return api.getStatus();
},
  retry: (int _, Object __) => null,
);

/// Selected timeframe in hours for the Overview metrics (e.g. 24, 168, 720).
final cleanuparrTimeframeHoursProvider =
    StateProvider.autoDispose.family<int, Instance>((ref, instance) => 168);

/// Fetches aggregated operational metrics for the selected timeframe.
final cleanuparrStatsProvider =
    FutureProvider.autoDispose.family<CleanuparrStats, Instance>((
  Ref ref,
  Instance instance,
) async {
  final CleanuparrApi api =
      await ref.watch(cleanuparrApiProvider(instance).future);
  final int hours = ref.watch(cleanuparrTimeframeHoursProvider(instance));
  return api.getStats(hours: hours);
},
  retry: (int _, Object __) => null,
);

/// Fetches registered background jobs and their execution states.
final cleanuparrJobsProvider =
    FutureProvider.autoDispose.family<List<CleanuparrJob>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final CleanuparrApi api =
      await ref.watch(cleanuparrApiProvider(instance).future);
  return api.getJobs();
},
  retry: (int _, Object __) => null,
);

/// Search query string for filtering the active strikes list.
final cleanuparrStrikesSearchProvider =
    StateProvider.autoDispose.family<String, Instance>((ref, instance) => '');

/// Fetches download items currently holding active strikes.
final cleanuparrStrikesProvider =
    FutureProvider.autoDispose.family<List<CleanuparrStrikeItem>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final CleanuparrApi api =
      await ref.watch(cleanuparrApiProvider(instance).future);
  final String search = ref.watch(cleanuparrStrikesSearchProvider(instance));
  return api.getStrikes(search: search.isNotEmpty ? search : null);
},
  retry: (int _, Object __) => null,
);

/// Returns the number of download items with active strikes, from
/// `getActiveStrikesCount()`, which leaves out items Cleanuparr already
/// removed (`isRemoved == true`). It ignores the Strikes-tab search text.
final cleanuparrActiveStrikesCountProvider =
    Provider.autoDispose.family<int, Instance>((Ref ref, Instance instance) {
  final countAsync = ref.watch(cleanuparrStrikesCountProvider(instance));
  return countAsync.maybeWhen(data: (int total) => total, orElse: () => 0);
});

/// Fetches the number of download items holding strikes that Cleanuparr has
/// not removed yet, unaffected by the Strikes tab's search.
final cleanuparrStrikesCountProvider =
    FutureProvider.autoDispose.family<int, Instance>((Ref ref, Instance instance) async {
  final CleanuparrApi api =
      await ref.watch(cleanuparrApiProvider(instance).future);
  return api.getActiveStrikesCount();
},
  retry: (int _, Object __) => null,
);

/// Search query string for filtering audit events.
final cleanuparrEventsSearchProvider =
    StateProvider.autoDispose.family<String, Instance>((ref, instance) => '');

/// Active category filter for audit events (null = All, 'malware', 'strikes', 'deletions', 'cleaned').
final cleanuparrEventsFilterProvider =
    StateProvider.autoDispose.family<String?, Instance>((ref, instance) => null);

/// Fetches audit log events filtered by active search query and category filter.
///
/// Text search is answered server-side by the backend LIKE query. Category
/// filtering is client-side because the backend accepts only a single scalar
/// EventType while categories span several. When a category is active, pages
/// beyond the first are fetched (cap: 3 x 500 entries) so matches deeper in the
/// history are not missed just because they fell off the first page.
final cleanuparrEventsProvider =
    FutureProvider.autoDispose.family<List<CleanuparrEvent>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final CleanuparrApi api =
      await ref.watch(cleanuparrApiProvider(instance).future);
  final String search = ref.watch(cleanuparrEventsSearchProvider(instance));
  final String? filter = ref.watch(cleanuparrEventsFilterProvider(instance));

  // 'Cleaned' maps to a single exact enum member, so forward it server-side
  // and let the database do the work across all records.
  final String serverEventType =
      (filter != null && const <String>['cleaned', 'clean'].contains(filter.toLowerCase()))
          ? 'DownloadCleaned'
          : '';

  // Backend Pagination.MaxPageSize is 500.
  const int filteredPageSize = 500;
  // Hard cap on pages walked for a client-side category filter (3 requests).
  const int maxFilteredPages = 3;

  final int pageSize =
      (filter == null || filter.isEmpty) ? 50 : filteredPageSize;

  final CleanuparrEventPage firstPage = await api.getEventsPage(
    search: search.isNotEmpty ? search : null,
    eventType: serverEventType.isNotEmpty ? serverEventType : null,
    pageSize: pageSize,
  );

  if (filter == null || filter.isEmpty) {
    return firstPage.items;
  }

  final List<CleanuparrEvent> all = List<CleanuparrEvent>.of(firstPage.items);
  final int pageCap = firstPage.totalPages < maxFilteredPages
      ? firstPage.totalPages
      : maxFilteredPages;
  for (int pageNum = 2; pageNum <= pageCap; pageNum++) {
    final CleanuparrEventPage nextPage = await api.getEventsPage(
      search: search.isNotEmpty ? search : null,
      eventType: serverEventType.isNotEmpty ? serverEventType : null,
      page: pageNum,
      pageSize: pageSize,
    );
    all.addAll(nextPage.items);
  }

  final String f = filter.toLowerCase();
  switch (f) {
    case 'strikes':
    case 'strike':
      return all.where((CleanuparrEvent e) => e.isStrike).toList();
    case 'malware':
      return all.where((CleanuparrEvent e) => e.isMalware).toList();
    case 'deletions':
    case 'deletion':
    case 'delet':
      return all.where((CleanuparrEvent e) => e.isDeletion).toList();
    case 'cleaned':
    case 'clean':
      return all;
    default:
      return all
          .where((CleanuparrEvent e) => e.eventType.toLowerCase() == f)
          .toList();
  }
},
  retry: (int _, Object __) => null,
);
