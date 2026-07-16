import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'models/radarr_blocklist_item.dart';
import 'models/radarr_history_item.dart';
import 'models/radarr_movie.dart';
import 'models/radarr_queue_item.dart';
import 'radarr_api.dart';

/// How often the movie library refreshes.
const Duration radarrLibraryPollInterval = Duration(seconds: 60);

/// A [RadarrApi] bound to a specific instance.
final radarrApiProvider = FutureProvider.family<RadarrApi, Instance>((
  Ref ref,
  Instance instance,
) async {
  final dio = await ref.watch(instanceDioProvider(instance).future);
  final String? apiKey = switch (instance.auth) {
    InstanceAuthApiKey(:final String apiKey) => apiKey,
    _ => null,
  };
  return RadarrApi(dio, apiKey: apiKey);
});

/// All movies for an instance, sorted by title. Polls slowly while watched.
final radarrMoviesProvider =
    FutureProvider.autoDispose.family<List<RadarrMovie>, Instance>((
  Ref ref,
  Instance instance,
) async {
  ref.pollEvery(radarrLibraryPollInterval);
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  final List<RadarrMovie> movies = await api.getMovies();
  movies.sort(
    (RadarrMovie a, RadarrMovie b) =>
        a.title.toLowerCase().compareTo(b.title.toLowerCase()),
  );
  return movies;
});

/// One movie by id. Refreshed on demand.
final radarrMovieByIdProvider =
    FutureProvider.autoDispose.family<RadarrMovie, (Instance, int)>((
  Ref ref,
  (Instance, int) key,
) async {
  final (Instance instance, int id) = key;
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getMovieById(id);
});

/// Active layout view mode for the movies tab (grid or list).
enum RadarrViewMode { grid, list }

/// Sorting fields supported by the Radarr Movies tab.
enum RadarrMovieSortField {
  monitoredStatus,
  title,
  year,
  added,
  sizeOnDisk,
}

/// Filter settings supported by the Radarr Movies tab.
enum RadarrMovieFilter {
  all,
  monitoredOnly,
  unmonitoredOnly,
  downloaded,
  missing,
}

/// Persistent view mode preference for Radarr movies.
final radarrViewModeProvider = StateProvider.family<RadarrViewMode, Instance>(
  (ref, instance) => RadarrViewMode.grid,
);

/// Sort field preference for Radarr movies.
final radarrMovieSortFieldProvider =
    StateProvider.family<RadarrMovieSortField, Instance>(
  (ref, instance) => RadarrMovieSortField.title,
);

/// Sort direction preference for Radarr movies.
final radarrMovieSortAscendingProvider = StateProvider.family<bool, Instance>(
  (ref, instance) => true,
);

/// Active filter setting for Radarr movies.
final radarrMovieFilterProvider =
    StateProvider.family<RadarrMovieFilter, Instance>(
  (ref, instance) => RadarrMovieFilter.all,
);

/// Search query string for Radarr movies.
final radarrSearchQueryProvider =
    StateProvider.family<String, Instance>((ref, instance) => '');

/// Tracks if search is active (focused or has text) in Radarr movies tab.
final radarrSearchActiveProvider = StateProvider.family<bool, Instance>(
  (ref, instance) => false,
);

/// Dynamic filtered movies provider based on active search query, filters, and sorts.
final radarrFilteredMoviesProvider = Provider.autoDispose
    .family<AsyncValue<List<RadarrMovie>>, Instance>((ref, instance) {
  final String query = ref.watch(radarrSearchQueryProvider(instance));
  final AsyncValue<List<RadarrMovie>> moviesAsync =
      ref.watch(radarrMoviesProvider(instance));

  final RadarrMovieSortField sortField =
      ref.watch(radarrMovieSortFieldProvider(instance));
  final bool sortAscending =
      ref.watch(radarrMovieSortAscendingProvider(instance));
  final RadarrMovieFilter filter =
      ref.watch(radarrMovieFilterProvider(instance));

  return moviesAsync.whenData((List<RadarrMovie> list) {
    Iterable<RadarrMovie> filtered = list;

    // 1. Filter by search query
    if (query.isNotEmpty) {
      final String lowercaseQuery = query.toLowerCase();
      filtered = filtered.where(
        (RadarrMovie m) => m.title.toLowerCase().contains(lowercaseQuery),
      );
    }

    // 2. Filter by active filter setting
    switch (filter) {
      case RadarrMovieFilter.all:
        break;
      case RadarrMovieFilter.monitoredOnly:
        filtered = filtered.where((RadarrMovie m) => m.monitored);
        break;
      case RadarrMovieFilter.unmonitoredOnly:
        filtered = filtered.where((RadarrMovie m) => !m.monitored);
        break;
      case RadarrMovieFilter.downloaded:
        filtered = filtered.where((RadarrMovie m) => m.hasFile);
        break;
      case RadarrMovieFilter.missing:
        filtered = filtered.where((RadarrMovie m) => !m.hasFile);
        break;
    }

    // 3. Sort
    final List<RadarrMovie> result = filtered.toList();
    result.sort((RadarrMovie a, RadarrMovie b) {
      int compare = 0;
      switch (sortField) {
        case RadarrMovieSortField.monitoredStatus:
          if (a.monitored != b.monitored) {
            compare = a.monitored ? -1 : 1;
          } else {
            final String titleA = a.sortTitle ?? a.title;
            final String titleB = b.sortTitle ?? b.title;
            compare = titleA.toLowerCase().compareTo(titleB.toLowerCase());
          }
          break;
        case RadarrMovieSortField.title:
          final String titleA = a.sortTitle ?? a.title;
          final String titleB = b.sortTitle ?? b.title;
          compare = titleA.toLowerCase().compareTo(titleB.toLowerCase());
          break;
        case RadarrMovieSortField.year:
          final int yearA = a.year ?? 0;
          final int yearB = b.year ?? 0;
          compare = yearA.compareTo(yearB);
          break;
        case RadarrMovieSortField.added:
          final String addedA = a.added ?? '';
          final String addedB = b.added ?? '';
          compare = addedA.compareTo(addedB);
          break;
        case RadarrMovieSortField.sizeOnDisk:
          compare = a.sizeOnDisk.compareTo(b.sizeOnDisk);
          break;
      }

      return sortAscending ? compare : -compare;
    });

    return result;
  });
});

/// Manages visibility of the Radarr bottom navigation bar.
final radarrBottomNavVisibleProvider =
    StateProvider.family<bool, Instance>((ref, instance) => true);

/// Trigger value to scroll the movies list to top when the active tab is tapped again.
final radarrMoviesScrollToTopProvider =
    StateProvider.family<int, Instance>((ref, instance) => 0);

/// All releases for a movie (interactive search).
final radarrReleasesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, (Instance, int)>((
  Ref ref,
  (Instance, int) key,
) async {
  final (Instance instance, int movieId) = key;
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getReleases(movieId: movieId);
});

/// Rename preview files for a movie.
final radarrRenamePreviewProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, (Instance, int)>((
  Ref ref,
  (Instance, int) key,
) async {
  final (Instance instance, int movieId) = key;
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getRenamePreview(movieId);
});

/// All quality profiles for an instance.
final radarrQualityProfilesProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getQualityProfiles();
});

/// Schema for quality profiles (used when creating a new one).
final radarrQualityProfileSchemaProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getQualityProfileSchema();
});

/// All tags for an instance.
final radarrTagsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getTags();
});

/// Search results for online lookup.
final radarrLookupMovieProvider =
    FutureProvider.autoDispose.family<List<RadarrMovie>, (Instance, String)>((
  Ref ref,
  (Instance, String) key,
) async {
  final (Instance instance, String term) = key;
  if (term.trim().isEmpty) return const <RadarrMovie>[];
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.lookupMovie(term);
});

/// All root folders for an instance.
final radarrRootFoldersProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getRootFolders();
});

/// Polling interval for active download queue.
const Duration radarrQueuePollInterval = Duration(seconds: 10);

/// Active downloads queue provider. Polls every 10 seconds.
final radarrQueueProvider =
    FutureProvider.autoDispose.family<List<RadarrQueueItem>, Instance>((
  Ref ref,
  Instance instance,
) async {
  ref.pollEvery(radarrQueuePollInterval);
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getQueue();
});

/// Event history provider. Fetches top 150 items.
final radarrHistoryProvider =
    FutureProvider.autoDispose.family<List<RadarrHistoryItem>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getHistory(pageSize: 150);
});

/// Blocklist items provider. Fetches top 150 items.
final radarrBlocklistProvider =
    FutureProvider.autoDispose.family<List<RadarrBlocklistItem>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getBlocklist(pageSize: 150);
});

/// Search query for the Activity tab.
final radarrActivitySearchQueryProvider =
    StateProvider.family<String, Instance>((ref, instance) => '');

/// Grouping toggle for the Activity tab (true = Grouped by Movie, false = Plain List).
final radarrActivityGroupedProvider =
    StateProvider.family<bool, Instance>((ref, instance) => true);

/// Wanted tab missing movies provider. Polls every 30 seconds.
final radarrWantedMissingProvider =
    FutureProvider.autoDispose.family<RadarrWantedPage, Instance>((
  Ref ref,
  Instance instance,
) async {
  ref.pollEvery(const Duration(seconds: 30));
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getWantedMissing();
});

/// Wanted tab cutoff unmet movies provider. Polls every 30 seconds.
final radarrWantedCutoffProvider =
    FutureProvider.autoDispose.family<RadarrWantedPage, Instance>((
  Ref ref,
  Instance instance,
) async {
  ref.pollEvery(const Duration(seconds: 30));
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getWantedCutoff();
});

/// The calendar entries for an instance for a given month.
final radarrCalendarProvider =
    FutureProvider.autoDispose.family<List<RadarrMovie>, (Instance, DateTime)>((
  Ref ref,
  (Instance, DateTime) key,
) async {
  final (Instance instance, DateTime month) = key;
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);

  // Calculate local month boundaries
  final DateTime start = DateTime(month.year, month.month);
  final DateTime end = DateTime(month.year, month.month + 1)
      .subtract(const Duration(seconds: 1));

  return api.getCalendar(start: start, end: end);
});

/// Search query for the Wanted tab.
final radarrWantedSearchQueryProvider =
    StateProvider.family<String, Instance>((ref, instance) => '');

/// Filtered missing movies provider based on Wanted search query.
final radarrWantedFilteredMissingProvider = Provider.autoDispose
    .family<AsyncValue<List<RadarrMovie>>, Instance>((ref, instance) {
  final String query = ref.watch(radarrWantedSearchQueryProvider(instance));
  final AsyncValue<RadarrWantedPage> missingAsync =
      ref.watch(radarrWantedMissingProvider(instance));

  return missingAsync.whenData((RadarrWantedPage page) {
    if (query.isEmpty) {
      return page.records;
    }
    final String lowercaseQuery = query.toLowerCase();
    return page.records
        .where(
          (RadarrMovie m) => m.title.toLowerCase().contains(lowercaseQuery),
        )
        .toList();
  });
});

/// Filtered cutoff unmet movies provider based on Wanted search query.
final radarrWantedFilteredCutoffProvider = Provider.autoDispose
    .family<AsyncValue<List<RadarrMovie>>, Instance>((ref, instance) {
  final String query = ref.watch(radarrWantedSearchQueryProvider(instance));
  final AsyncValue<RadarrWantedPage> cutoffAsync =
      ref.watch(radarrWantedCutoffProvider(instance));

  return cutoffAsync.whenData((RadarrWantedPage page) {
    if (query.isEmpty) {
      return page.records;
    }
    final String lowercaseQuery = query.toLowerCase();
    return page.records
        .where(
          (RadarrMovie m) => m.title.toLowerCase().contains(lowercaseQuery),
        )
        .toList();
  });
});

/// Grouping toggle for the Wanted tab (true = Grouped by Movie, false = Plain List).
final radarrWantedGroupedProvider =
    StateProvider.family<bool, Instance>((ref, instance) => true);

/// Selected path for Radarr Manual Import scan.
final radarrManualImportPathProvider =
    StateProvider.family<String, Instance>((ref, instance) => '');

/// Selected import mode for Radarr Manual Import ('Move' or 'Copy').
final radarrManualImportModeProvider =
    StateProvider.family<String, Instance>((ref, instance) => 'Move');

/// Filter existing files flag for Radarr Manual Import.
final radarrManualImportFilterProvider =
    StateProvider.family<bool, Instance>((ref, instance) => true);

/// Naming configuration provider.
final radarrNamingConfigProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getNamingConfig();
});

/// Media Management configuration provider.
final radarrMediaManagementConfigProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getMediaManagementConfig();
});

/// Host/General configuration provider.
final radarrHostConfigProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getHostConfig();
});

/// UI configuration provider.
final radarrUiConfigProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getUiConfig();
});

/// Quality definitions provider.
final radarrQualityDefinitionsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getQualityDefinitions();
});

/// Indexers configuration provider.
final radarrIndexersProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getIndexers();
});

/// Download Clients configuration provider.
final radarrDownloadClientsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getDownloadClients();
});

/// Download Client Config provider.
final radarrDownloadClientConfigProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getDownloadClientConfig();
});

/// Indexer schemas provider.
final radarrIndexerSchemaProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getIndexerSchema();
});

/// Import lists provider.
final radarrImportListsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getImportLists();
});

/// Import list config provider.
final radarrImportListConfigProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getImportListConfig();
});

/// Indexer config provider.
final radarrIndexerConfigProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getIndexerConfig();
});

/// Import list schemas provider.
final radarrImportListSchemaProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getImportListSchema();
});

/// Download client schemas provider.
final radarrDownloadClientSchemaProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getDownloadClientSchema();
});

/// Remote path mappings provider.
final radarrRemotePathMappingsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getRemotePathMappings();
});

/// Notifications provider.
final radarrNotificationsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getNotifications();
});

/// Notification schemas provider.
final radarrNotificationSchemaProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getNotificationSchema();
});

/// Metadata configurations provider.
final radarrMetadataConfigsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getMetadataConfigs();
});

/// Metadata schemas provider.
final radarrMetadataSchemaProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getMetadataSchema();
});

/// Delay profiles provider.
final radarrDelayProfilesProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getDelayProfiles();
});

/// Custom formats provider.
final radarrCustomFormatsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getCustomFormats();
});

/// Custom format schemas provider.
final radarrCustomFormatSchemaProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getCustomFormatSchema();
});

// ==========================================
// System providers
// ==========================================

/// System status (version, OS, uptime, etc.).
final radarrSystemStatusProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getSystemStatus();
});

/// Health check warnings/errors.
final radarrHealthProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getHealth();
});

/// Disk space for all root paths.
final radarrDiskSpaceProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getDiskSpace();
});

/// Scheduled tasks list.
final radarrTasksProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getTasks();
});

/// Available software updates.
final radarrUpdatesProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getUpdates();
});

/// Paginated logs. Key is (instance, page, pageSize, level).
final radarrLogsProvider = FutureProvider.autoDispose.family<
    Map<String, dynamic>, (Instance, {int page, int pageSize, String? level})>((
  Ref ref,
  (Instance, {int page, int pageSize, String? level}) key,
) async {
  final (Instance instance, :int page, :int pageSize, :String? level) = key;
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  final bool filterByLevel = level != null && level != 'all';
  return api.getLogs(
    page: page,
    pageSize: pageSize,
    filterKey: filterByLevel ? 'level' : null,
    filterValue: filterByLevel ? level : null,
  );
});

/// Log files list.
final radarrLogFilesProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getLogFiles();
});

/// Backups list.
final radarrBackupsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getBackups();
});

/// Track selection state for Movies
final radarrMoviesSelectionProvider = StateProvider.autoDispose
    .family<Set<int>, Instance>((ref, instance) => <int>{});

/// Track selection state for Queue
final radarrQueueSelectionProvider = StateProvider.autoDispose
    .family<Set<int>, Instance>((ref, instance) => <int>{});

/// Track selection state for Blocklist
final radarrBlocklistSelectionProvider = StateProvider.autoDispose
    .family<Set<int>, Instance>((ref, instance) => <int>{});

/// Track selection state for the Wanted tab movies.
final radarrWantedSelectionProvider = StateProvider.autoDispose
    .family<Set<int>, Instance>((ref, instance) => <int>{});

/// Parse a title / release name
final radarrParseResultProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, (Instance, String)>((
  Ref ref,
  (Instance, String) key,
) async {
  final (Instance instance, String title) = key;
  if (title.trim().isEmpty) return null;
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.parseTitle(title);
});
