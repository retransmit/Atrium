import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'models/sonarr_blocklist_item.dart';
import 'models/sonarr_episode.dart';
import 'models/sonarr_history_item.dart';
import 'models/sonarr_queue_item.dart';
import 'models/sonarr_series.dart';
import 'sonarr_api.dart';

/// How often the series library refreshes.
const Duration sonarrLibraryPollInterval = Duration(seconds: 60);

/// A [SonarrApi] bound to a specific instance.
final sonarrApiProvider = FutureProvider.family<SonarrApi, Instance>((
  Ref ref,
  Instance instance,
) async {
  final dio = await ref.watch(instanceDioProvider(instance).future);
  final String? apiKey = switch (instance.auth) {
    InstanceAuthApiKey(:final String apiKey) => apiKey,
    _ => null,
  };
  return SonarrApi(dio, apiKey: apiKey);
});

/// All series for an instance, sorted by title. Polls slowly while watched.
final sonarrSeriesProvider =
    FutureProvider.autoDispose.family<List<SonarrSeries>, Instance>((
  Ref ref,
  Instance instance,
) async {
  ref.pollEvery(sonarrLibraryPollInterval);
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  final List<SonarrSeries> series = await api.getSeries();
  series.sort(
    (SonarrSeries a, SonarrSeries b) =>
        a.title.toLowerCase().compareTo(b.title.toLowerCase()),
  );
  return series;
});

/// One series by id. Refreshed on demand.
final sonarrSeriesByIdProvider =
    FutureProvider.autoDispose.family<SonarrSeries, (Instance, int)>((
  Ref ref,
  (Instance, int) key,
) async {
  final (Instance instance, int id) = key;
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getSeriesById(id);
});

/// Active layout view mode for the series tab (grid or list).
enum SonarrViewMode { grid, list }

/// Persistent view mode preference for Sonarr series.
final sonarrViewModeProvider = StateProvider.family<SonarrViewMode, Instance>(
  (ref, instance) => SonarrViewMode.grid,
);

/// Search query string for Sonarr series.
final sonarrSearchQueryProvider =
    StateProvider.family<String, Instance>((ref, instance) => '');

/// Tracks if search is active (focused or has text) in Sonarr series tab.
final sonarrSearchActiveProvider = StateProvider.family<bool, Instance>(
  (ref, instance) => false,
);

/// Dynamic filtered series provider based on active search query.
final sonarrFilteredSeriesProvider = Provider.autoDispose
    .family<AsyncValue<List<SonarrSeries>>, Instance>((ref, instance) {
  final String query = ref.watch(sonarrSearchQueryProvider(instance));
  final AsyncValue<List<SonarrSeries>> seriesAsync =
      ref.watch(sonarrSeriesProvider(instance));

  return seriesAsync.whenData((List<SonarrSeries> list) {
    if (query.isEmpty) {
      return list;
    }
    final String lowercaseQuery = query.toLowerCase();
    return list
        .where(
          (SonarrSeries s) => s.title.toLowerCase().contains(lowercaseQuery),
        )
        .toList();
  });
});

/// Manages visibility of the Sonarr bottom navigation bar.
final sonarrBottomNavVisibleProvider =
    StateProvider.family<bool, Instance>((ref, instance) => true);

/// Trigger value to scroll the series list to top when the active tab is tapped again.
final sonarrSeriesScrollToTopProvider =
    StateProvider.family<int, Instance>((ref, instance) => 0);

/// All episodes for a given series.
final sonarrEpisodesProvider =
    FutureProvider.autoDispose.family<List<SonarrEpisode>, (Instance, int)>((
  Ref ref,
  (Instance, int) key,
) async {
  final (Instance instance, int seriesId) = key;
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getEpisodes(seriesId);
});

/// All releases for an episode (interactive search).
final sonarrReleasesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, (Instance, int)>((
  Ref ref,
  (Instance, int) key,
) async {
  final (Instance instance, int episodeId) = key;
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getReleases(episodeId: episodeId);
});

/// All releases for a season (interactive search).
final sonarrSeasonReleasesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, (Instance, int, int)>((
  Ref ref,
  (Instance, int, int) key,
) async {
  final (Instance instance, int seriesId, int seasonNumber) = key;
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getReleases(seriesId: seriesId, seasonNumber: seasonNumber);
});

/// Rename preview files for a series.
final sonarrRenamePreviewProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, (Instance, int)>((
  Ref ref,
  (Instance, int) key,
) async {
  final (Instance instance, int seriesId) = key;
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getRenamePreview(seriesId);
});

/// All quality profiles for an instance.
final sonarrQualityProfilesProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getQualityProfiles();
});

/// Schema for quality profiles (used when creating a new one).
final sonarrQualityProfileSchemaProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getQualityProfileSchema();
});

/// All tags for an instance.
final sonarrTagsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getTags();
});

/// Search results for online lookup.
final sonarrLookupSeriesProvider =
    FutureProvider.autoDispose.family<List<SonarrSeries>, (Instance, String)>((
  Ref ref,
  (Instance, String) key,
) async {
  final (Instance instance, String term) = key;
  if (term.trim().isEmpty) return const <SonarrSeries>[];
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.lookupSeries(term);
});

/// All root folders for an instance.
final sonarrRootFoldersProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getRootFolders();
});

/// Polling interval for active download queue.
const Duration sonarrQueuePollInterval = Duration(seconds: 10);

/// Active downloads queue provider. Polls every 10 seconds.
final sonarrQueueProvider =
    FutureProvider.autoDispose.family<List<SonarrQueueItem>, Instance>((
  Ref ref,
  Instance instance,
) async {
  ref.pollEvery(sonarrQueuePollInterval);
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getQueue();
});

/// Event history provider. Fetches top 150 items.
final sonarrHistoryProvider =
    FutureProvider.autoDispose.family<List<SonarrHistoryItem>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getHistory(pageSize: 150);
});

/// Blocklist items provider. Fetches top 150 items.
final sonarrBlocklistProvider =
    FutureProvider.autoDispose.family<List<SonarrBlocklistItem>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getBlocklist(pageSize: 150);
});

/// Search query for the Activity tab.
final sonarrActivitySearchQueryProvider =
    StateProvider.family<String, Instance>((ref, instance) => '');

/// Grouping toggle for the Activity tab (true = Grouped by Series, false = Plain List).
final sonarrActivityGroupedProvider =
    StateProvider.family<bool, Instance>((ref, instance) => true);

/// Wanted tab missing episodes provider. Polls every 30 seconds.
final sonarrWantedMissingProvider =
    FutureProvider.autoDispose.family<List<SonarrEpisode>, Instance>((
  Ref ref,
  Instance instance,
) async {
  ref.pollEvery(const Duration(seconds: 30));
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getWantedMissing();
});

/// Wanted tab cutoff unmet episodes provider. Polls every 30 seconds.
final sonarrWantedCutoffProvider =
    FutureProvider.autoDispose.family<List<SonarrEpisode>, Instance>((
  Ref ref,
  Instance instance,
) async {
  ref.pollEvery(const Duration(seconds: 30));
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getWantedCutoff();
});

/// The calendar entries for an instance for a given month.
final sonarrCalendarProvider = FutureProvider.autoDispose
    .family<List<SonarrEpisode>, (Instance, DateTime)>((
  Ref ref,
  (Instance, DateTime) key,
) async {
  final (Instance instance, DateTime month) = key;
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);

  // Calculate local month boundaries
  final DateTime start = DateTime(month.year, month.month);
  final DateTime end = DateTime(month.year, month.month + 1)
      .subtract(const Duration(seconds: 1));

  final List<SonarrEpisode> episodes = await api.getCalendar(
    start: start,
    end: end,
  );

  return episodes;
});

/// Search query for the Wanted tab.
final sonarrWantedSearchQueryProvider =
    StateProvider.family<String, Instance>((ref, instance) => '');

/// Filtered missing episodes provider based on Wanted search query.
final sonarrWantedFilteredMissingProvider = Provider.autoDispose
    .family<AsyncValue<List<SonarrEpisode>>, Instance>((ref, instance) {
  final String query = ref.watch(sonarrWantedSearchQueryProvider(instance));
  final AsyncValue<List<SonarrEpisode>> missingAsync =
      ref.watch(sonarrWantedMissingProvider(instance));

  return missingAsync.whenData((List<SonarrEpisode> list) {
    if (query.isEmpty) {
      return list;
    }
    final String lowercaseQuery = query.toLowerCase();
    return list
        .where(
          (SonarrEpisode ep) =>
              ep.title.toLowerCase().contains(lowercaseQuery) ||
              (ep.series?.title.toLowerCase().contains(lowercaseQuery) ??
                  false),
        )
        .toList();
  });
});

/// Filtered cutoff unmet episodes provider based on Wanted search query.
final sonarrWantedFilteredCutoffProvider = Provider.autoDispose
    .family<AsyncValue<List<SonarrEpisode>>, Instance>((ref, instance) {
  final String query = ref.watch(sonarrWantedSearchQueryProvider(instance));
  final AsyncValue<List<SonarrEpisode>> cutoffAsync =
      ref.watch(sonarrWantedCutoffProvider(instance));

  return cutoffAsync.whenData((List<SonarrEpisode> list) {
    if (query.isEmpty) {
      return list;
    }
    final String lowercaseQuery = query.toLowerCase();
    return list
        .where(
          (SonarrEpisode ep) =>
              ep.title.toLowerCase().contains(lowercaseQuery) ||
              (ep.series?.title.toLowerCase().contains(lowercaseQuery) ??
                  false),
        )
        .toList();
  });
});

/// Grouping toggle for the Wanted tab (true = Grouped by Series, false = Plain List).
final sonarrWantedGroupedProvider =
    StateProvider.family<bool, Instance>((ref, instance) => true);

/// Selected path for Sonarr Manual Import scan.
final sonarrManualImportPathProvider =
    StateProvider.family<String, Instance>((ref, instance) => '');

/// Selected import mode for Sonarr Manual Import ('Move' or 'Copy').
final sonarrManualImportModeProvider =
    StateProvider.family<String, Instance>((ref, instance) => 'Move');

/// Filter existing files flag for Sonarr Manual Import.
final sonarrManualImportFilterProvider =
    StateProvider.family<bool, Instance>((ref, instance) => true);

/// Naming configuration provider.
final sonarrNamingConfigProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getNamingConfig();
});

/// Media Management configuration provider.
final sonarrMediaManagementConfigProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getMediaManagementConfig();
});

/// Host/General configuration provider.
final sonarrHostConfigProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getHostConfig();
});

/// UI configuration provider.
final sonarrUiConfigProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getUiConfig();
});

/// Quality definitions provider.
final sonarrQualityDefinitionsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getQualityDefinitions();
});

/// Indexers configuration provider.
final sonarrIndexersProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getIndexers();
});

/// Download Clients configuration provider.
final sonarrDownloadClientsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getDownloadClients();
});

/// Download Client Config provider.
final sonarrDownloadClientConfigProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getDownloadClientConfig();
});

/// Indexer schemas provider.
final sonarrIndexerSchemaProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getIndexerSchema();
});

/// Import lists provider.
final sonarrImportListsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getImportLists();
});

/// Import list config provider.
final sonarrImportListConfigProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getImportListConfig();
});

/// Indexer config provider.
final sonarrIndexerConfigProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getIndexerConfig();
});

/// Import list schemas provider.
final sonarrImportListSchemaProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getImportListSchema();
});

/// Download client schemas provider.
final sonarrDownloadClientSchemaProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getDownloadClientSchema();
});

/// Remote path mappings provider.
final sonarrRemotePathMappingsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getRemotePathMappings();
});

/// Notifications provider.
final sonarrNotificationsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getNotifications();
});

/// Notification schemas provider.
final sonarrNotificationSchemaProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getNotificationSchema();
});

/// Metadata configurations provider.
final sonarrMetadataConfigsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getMetadataConfigs();
});

/// Metadata schemas provider.
final sonarrMetadataSchemaProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getMetadataSchema();
});

/// Delay profiles provider.
final sonarrDelayProfilesProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getDelayProfiles();
});

/// Release profiles provider.
final sonarrReleaseProfilesProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getReleaseProfiles();
});

/// Custom formats provider.
final sonarrCustomFormatsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getCustomFormats();
});

/// Custom format schemas provider.
final sonarrCustomFormatSchemaProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getCustomFormatSchema();
});

// ==========================================
// System providers
// ==========================================

/// System status (version, OS, uptime, etc.).
final sonarrSystemStatusProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getSystemStatus();
});

/// Health check warnings/errors.
final sonarrHealthProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getHealth();
});

/// Disk space for all root paths.
final sonarrDiskSpaceProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getDiskSpace();
});

/// Scheduled tasks list.
final sonarrTasksProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getTasks();
});

/// Available software updates.
final sonarrUpdatesProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getUpdates();
});

/// Paginated logs. Key is (instance, page, pageSize, level).
final sonarrLogsProvider = FutureProvider.autoDispose.family<
    Map<String, dynamic>, (Instance, {int page, int pageSize, String? level})>((
  Ref ref,
  (Instance, {int page, int pageSize, String? level}) key,
) async {
  final (Instance instance, :int page, :int pageSize, :String? level) = key;
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getLogs(page: page, pageSize: pageSize, level: level);
});

/// Log files list.
final sonarrLogFilesProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getLogFiles();
});

/// Backups list.
final sonarrBackupsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getBackups();
});

/// Track selection state for Series
final sonarrSeriesSelectionProvider = StateProvider.autoDispose
    .family<Set<int>, Instance>((ref, instance) => <int>{});

/// Track selection state for Queue
final sonarrQueueSelectionProvider = StateProvider.autoDispose
    .family<Set<int>, Instance>((ref, instance) => <int>{});

/// Track selection state for Blocklist
final sonarrBlocklistSelectionProvider = StateProvider.autoDispose
    .family<Set<int>, Instance>((ref, instance) => <int>{});

/// Track selection state for the Wanted tab episodes.
final sonarrWantedSelectionProvider = StateProvider.autoDispose
    .family<Set<int>, Instance>((ref, instance) => <int>{});

/// Parse a title / release name
final sonarrParseResultProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, (Instance, String)>((
  Ref ref,
  (Instance, String) key,
) async {
  final (Instance instance, String title) = key;
  if (title.trim().isEmpty) return null;
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.parseTitle(title);
});
