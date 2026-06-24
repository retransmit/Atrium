import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/radarr_blocklist.dart';
import 'models/radarr_history.dart';
import 'models/radarr_movie.dart';
import 'models/radarr_queue.dart';
import 'models/radarr_release.dart';
import 'models/radarr_settings_models.dart';
import 'models/radarr_system.dart';
import 'models/radarr_wanted.dart';
import 'radarr_api.dart';

/// How often the download queue refreshes while a Radarr screen is visible.
const Duration radarrQueuePollInterval = Duration(seconds: 3);

/// How often the movie library refreshes.
const Duration radarrLibraryPollInterval = Duration(seconds: 60);

/// A [RadarrApi] bound to a specific instance. Depends on the shared
/// `instanceDioProvider` from core_networking, so it picks up the resolved
/// LAN/WAN base URL and auth automatically.
///
/// The instance's API key is also threaded through to the client so it can
/// build authenticated mediacover image URLs for `CachedNetworkImage`.
///
/// Deliberately NOT autoDispose: the underlying Dio is shared and cheap to
/// keep; disposing it per-screen would re-run the LAN/WAN probe needlessly.
final radarrApiProvider =
    FutureProvider.family<RadarrApi, Instance>((
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

/// One movie by id. Used by the detail screen; refreshed on demand.
final radarrMovieByIdProvider =
    FutureProvider.autoDispose.family<RadarrMovie, (Instance, int)>((
      Ref ref,
      (Instance, int) key,
    ) async {
      final (Instance instance, int id) = key;
      final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
      return api.getMovieById(id);
    });

/// The download queue for an instance. Polls fast while watched.
final radarrQueueProvider =
    FutureProvider.autoDispose.family<RadarrQueuePage, Instance>((
      Ref ref,
      Instance instance,
    ) async {
      ref.pollEvery(radarrQueuePollInterval);
      final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
      return api.getQueue();
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
  final DateTime end = DateTime(month.year, month.month + 1).subtract(const Duration(seconds: 1));
  
  final List<RadarrMovie> movies = await api.getCalendar(
    start: start,
    end: end,
  );
  
  return movies;
});

/// Fetches releases for a given movie. family key is (Instance, movieId).
final radarrReleasesProvider =
    FutureProvider.autoDispose.family<List<RadarrRelease>, (Instance, int)>((
  Ref ref,
  (Instance, int) key,
) async {
  final (Instance instance, int movieId) = key;
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getReleases(movieId);
});

/// Paginated history. family key is (Instance, page).
final radarrHistoryProvider =
    FutureProvider.autoDispose.family<RadarrHistoryPage, (Instance, int)>((
  Ref ref,
  (Instance, int) key,
) async {
  final (Instance instance, int page) = key;
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getHistory(page: page);
});

/// Wanted: missing movies, paginated. family key is (Instance, page).
final radarrWantedMissingProvider =
    FutureProvider.autoDispose.family<RadarrWantedPage, (Instance, int)>((
  Ref ref,
  (Instance, int) key,
) async {
  final (Instance instance, int page) = key;
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getWantedMissing(page: page);
});

/// Wanted: cutoff-unmet movies, paginated. family key is (Instance, page).
final radarrWantedCutoffProvider =
    FutureProvider.autoDispose.family<RadarrWantedPage, (Instance, int)>((
  Ref ref,
  (Instance, int) key,
) async {
  final (Instance instance, int page) = key;
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getWantedCutoff(page: page);
});

/// Paginated blocklist. family key is (Instance, page).
final radarrBlocklistProvider =
    FutureProvider.autoDispose.family<RadarrBlocklistPage, (Instance, int)>((
  Ref ref,
  (Instance, int) key,
) async {
  final (Instance instance, int page) = key;
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getBlocklist(page: page);
});

/// System status.
final radarrSystemStatusProvider =
    FutureProvider.autoDispose.family<RadarrSystemStatus, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getSystemStatus();
});

/// Disk space.
final radarrDiskSpaceProvider =
    FutureProvider.autoDispose.family<List<RadarrDiskSpace>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getDiskSpace();
});

/// Active health warnings.
final radarrHealthProvider =
    FutureProvider.autoDispose.family<List<RadarrHealth>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getHealth();
});

/// Scheduled tasks.
final radarrSystemTasksProvider =
    FutureProvider.autoDispose.family<List<RadarrSystemTask>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getSystemTasks();
});

/// Server backups.
final radarrBackupsProvider =
    FutureProvider.autoDispose.family<List<RadarrBackup>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getBackups();
});

// ---------------------------------------------------------------------------
// Settings providers
// ---------------------------------------------------------------------------

/// Fetches tags.
final radarrTagsProvider =
    FutureProvider.autoDispose.family<List<RadarrTag>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getTags();
});

/// Fetches indexers.
final radarrIndexersProvider =
    FutureProvider.autoDispose.family<List<RadarrIndexer>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getIndexers();
});

/// Fetches indexer schemas.
final radarrIndexerSchemaProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getIndexerSchema();
});

/// Fetches download clients.
final radarrDownloadClientsProvider =
    FutureProvider.autoDispose.family<List<RadarrDownloadClient>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getDownloadClients();
});

/// Fetches download client schemas.
final radarrDownloadClientSchemaProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getDownloadClientSchema();
});

/// Fetches notification connections.
final radarrNotificationsProvider =
    FutureProvider.autoDispose.family<List<RadarrNotification>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getNotifications();
});

/// Fetches notification schemas.
final radarrNotificationSchemaProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getNotificationSchema();
});

/// Fetches import lists.
final radarrImportListsProvider =
    FutureProvider.autoDispose.family<List<RadarrImportList>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getImportLists();
});

/// Fetches import list schemas.
final radarrImportListSchemaProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getImportListSchema();
});

/// Fetches host config settings.
final radarrHostConfigProvider =
    FutureProvider.autoDispose.family<RadarrHostConfig, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getHostConfig();
});

/// Fetches naming config settings.
final radarrNamingConfigProvider =
    FutureProvider.autoDispose.family<RadarrNamingConfig, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getNamingConfig();
});

/// Fetches media management config settings.
final radarrMediaManagementConfigProvider =
    FutureProvider.autoDispose.family<RadarrMediaManagementConfig, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getMediaManagementConfig();
});

/// Fetches UI config settings.
final radarrUiConfigProvider =
    FutureProvider.autoDispose.family<RadarrUiConfig, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getUiConfig();
});

/// Fetches metadata consumers.
final radarrMetadataProvidersProvider =
    FutureProvider.autoDispose.family<List<RadarrMetadataProvider>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getMetadataProviders();
});

/// Fetches delay profiles.
final radarrDelayProfilesProvider =
    FutureProvider.autoDispose.family<List<RadarrDelayProfile>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getDelayProfiles();
});

/// Fetches custom formats.
final radarrCustomFormatsProvider =
    FutureProvider.autoDispose.family<List<RadarrCustomFormat>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getCustomFormats();
});

/// Fetches quality definitions.
final radarrQualityDefinitionsProvider =
    FutureProvider.autoDispose.family<List<RadarrQualityDefinition>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getQualityDefinitions();
});

/// Fetches quality profiles (raw).
final radarrQualityProfilesRawProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getQualityProfilesRaw();
});

/// Fetches quality profile schema.
final radarrQualityProfileSchemaProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getQualityProfileSchema();
});

/// Fetches release profiles.
final radarrReleaseProfilesProvider =
    FutureProvider.autoDispose.family<List<RadarrReleaseProfile>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getReleaseProfiles();
});

/// Fetches import list exclusions.
final radarrImportListExclusionsProvider =
    FutureProvider.autoDispose.family<List<RadarrImportListExclusion>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getImportListExclusions();
});

/// Fetches auto-tagging rules.
final radarrAutoTaggingRulesProvider =
    FutureProvider.autoDispose.family<List<RadarrAutoTaggingRule>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final RadarrApi api = await ref.watch(radarrApiProvider(instance).future);
  return api.getAutoTaggingRules();
});

/// Sort options for the Radarr movie list.
enum RadarrSortOption { titleAsc, titleDesc, yearAsc, yearDesc, sizeAsc, sizeDesc }

/// Filter by download status (uses hasFile).
enum RadarrStatusFilter { all, downloaded, missing }

/// Filter by monitored status.
enum RadarrMonitoredFilter { all, monitored, unmonitored }

/// Search query per instance.
final radarrSearchQueryProvider =
    StateProvider.family<String, Instance>((Ref ref, Instance instance) => '');

/// Sort option per instance.
final radarrSortOptionProvider =
    StateProvider.family<RadarrSortOption, Instance>(
  (Ref ref, Instance instance) => RadarrSortOption.titleAsc,
);

/// Status filter per instance.
final radarrStatusFilterProvider =
    StateProvider.family<RadarrStatusFilter, Instance>(
  (Ref ref, Instance instance) => RadarrStatusFilter.all,
);

/// Monitored filter per instance.
final radarrMonitoredFilterProvider =
    StateProvider.family<RadarrMonitoredFilter, Instance>(
  (Ref ref, Instance instance) => RadarrMonitoredFilter.all,
);

/// Filters, searches, and sorts the movie list per user preferences.
final radarrFilteredMoviesProvider =
    Provider.autoDispose.family<AsyncValue<List<RadarrMovie>>, Instance>(
        (Ref ref, Instance instance) {
  final AsyncValue<List<RadarrMovie>> moviesVal =
      ref.watch(radarrMoviesProvider(instance));
  return moviesVal.whenData((List<RadarrMovie> list) {
    final String query =
        ref.watch(radarrSearchQueryProvider(instance)).trim().toLowerCase();
    final RadarrSortOption sortOption =
        ref.watch(radarrSortOptionProvider(instance));
    final RadarrStatusFilter statusFilter =
        ref.watch(radarrStatusFilterProvider(instance));
    final RadarrMonitoredFilter monitoredFilter =
        ref.watch(radarrMonitoredFilterProvider(instance));

    final List<RadarrMovie> filtered = list.where((RadarrMovie m) {
      if (query.isNotEmpty && !m.title.toLowerCase().contains(query)) {
        return false;
      }
      if (statusFilter == RadarrStatusFilter.downloaded && !m.hasFile) {
        return false;
      }
      if (statusFilter == RadarrStatusFilter.missing && m.hasFile) {
        return false;
      }
      if (monitoredFilter == RadarrMonitoredFilter.monitored && !m.monitored) {
        return false;
      }
      if (monitoredFilter == RadarrMonitoredFilter.unmonitored && m.monitored) {
        return false;
      }
      return true;
    }).toList();

    filtered.sort((RadarrMovie a, RadarrMovie b) {
      switch (sortOption) {
        case RadarrSortOption.titleAsc:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case RadarrSortOption.titleDesc:
          return b.title.toLowerCase().compareTo(a.title.toLowerCase());
        case RadarrSortOption.yearAsc:
          return (a.year ?? 0).compareTo(b.year ?? 0);
        case RadarrSortOption.yearDesc:
          return (b.year ?? 0).compareTo(a.year ?? 0);
        case RadarrSortOption.sizeAsc:
          return a.sizeOnDisk.compareTo(b.sizeOnDisk);
        case RadarrSortOption.sizeDesc:
          return b.sizeOnDisk.compareTo(a.sizeOnDisk);
      }
    });
    return filtered;
  });
});

