import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:core_storage/core_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';

import 'models/sonarr_add_models.dart';
import 'models/sonarr_blocklist.dart';
import 'models/sonarr_calendar.dart';
import 'models/sonarr_episode.dart';
import 'models/sonarr_history.dart';
import 'models/sonarr_queue.dart';
import 'models/sonarr_release.dart';
import 'models/sonarr_series.dart';
import 'models/sonarr_settings_models.dart';
import 'models/sonarr_system.dart';
import 'models/sonarr_wanted.dart';
import 'sonarr_api.dart';

/// How often the download queue refreshes while a Sonarr screen is visible.
const Duration sonarrQueuePollInterval = Duration(seconds: 3);

/// How often the series library refreshes. Libraries change rarely, so this
/// is mostly about picking up grabs/imports without a manual pull.
const Duration sonarrLibraryPollInterval = Duration(seconds: 60);

/// A [SonarrApi] bound to a specific instance. Depends on the shared
/// `instanceDioProvider` from core_networking, so it automatically picks up
/// the resolved LAN/WAN base URL and auth.
///
/// The instance's API key (when present) is also threaded through to the
/// client so it can build authenticated mediacover image URLs for
/// `CachedNetworkImage`.
///
/// Deliberately NOT autoDispose: the underlying Dio is shared and cheap to
/// keep; disposing it per-screen would re-run the LAN/WAN probe needlessly.
final sonarrApiProvider =
    FutureProvider.family<SonarrApi, Instance>(
        (Ref ref, Instance instance) async {
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

/// One series by id. Used by the detail screen; refreshed on demand.
final sonarrSeriesByIdProvider =
    FutureProvider.autoDispose.family<SonarrSeries, (Instance, int)>((
  Ref ref,
  (Instance, int) key,
) async {
  final (Instance instance, int id) = key;
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getSeriesById(id);
});

/// The download queue for an instance. Polls fast while watched.
final sonarrQueueProvider =
    FutureProvider.autoDispose.family<SonarrQueuePage, Instance>((
  Ref ref,
  Instance instance,
) async {
  ref.pollEvery(sonarrQueuePollInterval);
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getQueue();
});

/// The calendar entries for an instance for a given month.
final sonarrCalendarProvider =
    FutureProvider.autoDispose.family<List<SonarrCalendarEntry>, (Instance, DateTime)>((
  Ref ref,
  (Instance, DateTime) key,
) async {
  final (Instance instance, DateTime month) = key;
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  
  // Calculate local month boundaries
  final DateTime start = DateTime(month.year, month.month);
  final DateTime end = DateTime(month.year, month.month + 1).subtract(const Duration(seconds: 1));

  final List<SonarrCalendarEntry> entries = await api.getCalendar(
    start: start,
    end: end,
  );

  // Sort entries by UTC air date ascending
  entries.sort((a, b) {
    if (a.airDateUtc == null && b.airDateUtc == null) return 0;
    if (a.airDateUtc == null) return 1;
    if (b.airDateUtc == null) return -1;
    return a.airDateUtc!.compareTo(b.airDateUtc!);
  });

  return entries;
});

/// All episodes for a given series. Auto-dispose, family key is (Instance, seriesId).
final sonarrEpisodesProvider =
    FutureProvider.autoDispose.family<List<SonarrEpisode>, (Instance, int)>((
  Ref ref,
  (Instance, int) key,
) async {
  final (Instance instance, int seriesId) = key;
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getEpisodes(seriesId);
});

/// Fetches releases for a given episode. family key is (Instance, episodeId).
final sonarrReleasesProvider =
    FutureProvider.autoDispose.family<List<SonarrRelease>, (Instance, int)>((
  Ref ref,
  (Instance, int) key,
) async {
  final (Instance instance, int episodeId) = key;
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getReleases(episodeId);
});

/// Fetches releases for a given season. family key is (Instance, seriesId, seasonNumber).
final sonarrSeasonReleasesProvider =
    FutureProvider.autoDispose.family<List<SonarrRelease>, (Instance, int, int)>((
  Ref ref,
  (Instance, int, int) key,
) async {
  final (Instance instance, int seriesId, int seasonNumber) = key;
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getSeasonReleases(seriesId, seasonNumber);
});

/// Fetches paginated history. family key is (Instance, page).
final sonarrHistoryProvider =
    FutureProvider.autoDispose.family<SonarrHistoryPage, (Instance, int)>((
  Ref ref,
  (Instance, int) key,
) async {
  final (Instance instance, int page) = key;
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getHistory(page: page);
});

/// Fetches paginated blocklist. family key is (Instance, page).
final sonarrBlocklistProvider =
    FutureProvider.autoDispose.family<SonarrBlocklistPage, (Instance, int)>((
  Ref ref,
  (Instance, int) key,
) async {
  final (Instance instance, int page) = key;
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getBlocklist(page: page);
});

/// Fetches wanted missing episodes. family key is (Instance, page).
final sonarrWantedMissingProvider =
    FutureProvider.autoDispose.family<SonarrWantedPage, (Instance, int)>((
  Ref ref,
  (Instance, int) key,
) async {
  final (Instance instance, int page) = key;
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getWantedMissing(page: page);
});

/// Fetches wanted cutoff unmet episodes. family key is (Instance, page).
final sonarrWantedCutoffProvider =
    FutureProvider.autoDispose.family<SonarrWantedPage, (Instance, int)>((
  Ref ref,
  (Instance, int) key,
) async {
  final (Instance instance, int page) = key;
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getWantedCutoff(page: page);
});

/// Fetches system status.
final sonarrSystemStatusProvider =
    FutureProvider.autoDispose.family<SonarrSystemStatus, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getSystemStatus();
});

/// Fetches disk space.
final sonarrDiskSpaceProvider =
    FutureProvider.autoDispose.family<List<SonarrDiskSpace>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getDiskSpace();
});

/// Fetches scheduled system tasks.
final sonarrSystemTasksProvider =
    FutureProvider.autoDispose.family<List<SonarrSystemTask>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getSystemTasks();
});

/// Fetches active health warning issues.
final sonarrHealthProvider =
    FutureProvider.autoDispose.family<List<SonarrHealth>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getHealth();
});

/// Fetches server backups.
final sonarrBackupsProvider =
    FutureProvider.autoDispose.family<List<SonarrBackup>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getBackups();
});

/// Fetches tags.
final sonarrTagsProvider =
    FutureProvider.autoDispose.family<List<SonarrTag>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getTags();
});

/// Fetches indexers.
final sonarrIndexersProvider =
    FutureProvider.autoDispose.family<List<SonarrIndexer>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getIndexers();
});

/// Fetches download clients.
final sonarrDownloadClientsProvider =
    FutureProvider.autoDispose.family<List<SonarrDownloadClient>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getDownloadClients();
});

/// Fetches notification connections.
final sonarrNotificationsProvider =
    FutureProvider.autoDispose.family<List<SonarrNotification>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getNotifications();
});

/// Fetches import lists.
final sonarrImportListsProvider =
    FutureProvider.autoDispose.family<List<SonarrImportList>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getImportLists();
});

/// Fetches host config settings.
final sonarrHostConfigProvider =
    FutureProvider.autoDispose.family<SonarrHostConfig, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getHostConfig();
});

/// Fetches naming config settings.
final sonarrNamingConfigProvider =
    FutureProvider.autoDispose.family<SonarrNamingConfig, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getNamingConfig();
});

/// Fetches media management config settings.
final sonarrMediaManagementConfigProvider =
    FutureProvider.autoDispose.family<SonarrMediaManagementConfig, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getMediaManagementConfig();
});

/// Fetches UI config settings.
final sonarrUiConfigProvider =
    FutureProvider.autoDispose.family<SonarrUiConfig, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getUiConfig();
});

/// Fetches metadata providers.
final sonarrMetadataProvidersProvider =
    FutureProvider.autoDispose.family<List<SonarrMetadataProvider>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getMetadataProviders();
});

/// Fetches delay profiles.
final sonarrDelayProfilesProvider =
    FutureProvider.autoDispose.family<List<SonarrDelayProfile>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getDelayProfiles();
});

/// Fetches custom formats.
final sonarrCustomFormatsProvider =
    FutureProvider.autoDispose.family<List<SonarrCustomFormat>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getCustomFormats();
});

/// Fetches download client schemas.
final sonarrDownloadClientSchemaProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getDownloadClientSchema();
});

/// Fetches indexer schemas.
final sonarrIndexerSchemaProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getIndexerSchema();
});

/// Fetches notification schemas.
final sonarrNotificationSchemaProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getNotificationSchema();
});

/// Fetches import list schemas.
final sonarrImportListSchemaProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getImportListSchema();
});

/// Fetches quality definitions.
final sonarrQualityDefinitionsProvider =
    FutureProvider.autoDispose.family<List<SonarrQualityDefinition>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getQualityDefinitions();
});

/// Fetches release profiles.
final sonarrReleaseProfilesProvider =
    FutureProvider.autoDispose.family<List<SonarrReleaseProfile>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getReleaseProfiles();
});

/// Fetches import list exclusions.
final sonarrImportListExclusionsProvider =
    FutureProvider.autoDispose.family<List<SonarrImportListExclusion>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getImportListExclusions();
});

/// Fetches auto-tagging rules.
final sonarrAutoTaggingRulesProvider =
    FutureProvider.autoDispose.family<List<SonarrAutoTaggingRule>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getAutoTaggingRules();
});

/// Fetches quality profiles.
final sonarrQualityProfilesProvider =
    FutureProvider.autoDispose.family<List<SonarrQualityProfile>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getQualityProfiles();
});

/// Fetches quality profile schema.
final sonarrQualityProfileSchemaProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getQualityProfileSchema();
});

/// Fetches raw quality profiles.
final sonarrQualityProfilesRawProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getQualityProfilesRaw();
});

/// View mode for the Sonarr series tab (grid or banner list).
enum SonarrViewMode { grid, banner }

/// State notifier to track and persist the user's preferred view mode (grid or banner list) per instance.
final sonarrViewModeProvider =
    NotifierProvider.family<SonarrViewModeNotifier, SonarrViewMode, Instance>(
  SonarrViewModeNotifier.new,
);

/// Tracks the currently active top-level tab index of the Sonarr screen.
final sonarrActiveTabBarIndexProvider = StateProvider.family<int, Instance>((ref, instance) => 0);

class SonarrViewModeNotifier extends FamilyNotifier<SonarrViewMode, Instance> {
  static String _keyFor(String instanceId) => 'sonarr.viewMode.$instanceId';

  Box<String>? get _box => Hive.isBoxOpen(AtriumBoxes.settings)
      ? Hive.box<String>(AtriumBoxes.settings)
      : null;

  @override
  SonarrViewMode build(Instance arg) {
    final String? val = _box?.get(_keyFor(arg.id));
    if (val == 'banner') {
      return SonarrViewMode.banner;
    }
    return SonarrViewMode.grid;
  }

  Future<void> setViewMode(SonarrViewMode mode) async {
    state = mode;
    final Box<String>? box = _box;
    if (box != null) {
      await box.put(_keyFor(arg.id), mode.name);
    }
  }
}

/// Sort options for Sonarr series list.
enum SonarrSortOption {
  titleAsc,
  titleDesc,
  yearAsc,
  yearDesc,
  sizeAsc,
  sizeDesc,
  progressAsc,
  progressDesc,
}

/// Filter options for Sonarr series status.
enum SonarrStatusFilter {
  all,
  continuing,
  ended,
}

/// Filter options for Sonarr series monitored status.
enum SonarrMonitoredFilter {
  all,
  monitored,
  unmonitored,
}

/// Search query provider per instance.
final sonarrSearchQueryProvider = StateProvider.family<String, Instance>((Ref ref, Instance instance) => '');

/// Sort option provider per instance.
final sonarrSortOptionProvider = StateProvider.family<SonarrSortOption, Instance>(
  (Ref ref, Instance instance) => SonarrSortOption.titleAsc,
);

/// Status filter provider per instance.
final sonarrStatusFilterProvider = StateProvider.family<SonarrStatusFilter, Instance>(
  (Ref ref, Instance instance) => SonarrStatusFilter.all,
);

/// Monitored filter provider per instance.
final sonarrMonitoredFilterProvider = StateProvider.family<SonarrMonitoredFilter, Instance>(
  (Ref ref, Instance instance) => SonarrMonitoredFilter.all,
);

/// Selector provider that automatically filters, searches, and sorts series list based on user preferences.
final sonarrFilteredSeriesProvider = Provider.autoDispose.family<AsyncValue<List<SonarrSeries>>, Instance>((Ref ref, Instance instance) {
  final AsyncValue<List<SonarrSeries>> seriesVal = ref.watch(sonarrSeriesProvider(instance));
  
  return seriesVal.whenData((List<SonarrSeries> list) {
    final String query = ref.watch(sonarrSearchQueryProvider(instance)).trim().toLowerCase();
    final SonarrSortOption sortOption = ref.watch(sonarrSortOptionProvider(instance));
    final SonarrStatusFilter statusFilter = ref.watch(sonarrStatusFilterProvider(instance));
    final SonarrMonitoredFilter monitoredFilter = ref.watch(sonarrMonitoredFilterProvider(instance));
    
    // 1. Filter
    final List<SonarrSeries> filtered = list.where((SonarrSeries s) {
      // Search query filter
      if (query.isNotEmpty && !s.title.toLowerCase().contains(query)) {
        return false;
      }
      // Status filter
      if (statusFilter != SonarrStatusFilter.all) {
        final String? status = s.status?.toLowerCase();
        if (statusFilter == SonarrStatusFilter.continuing && status != 'continuing') {
          return false;
        }
        if (statusFilter == SonarrStatusFilter.ended && status != 'ended') {
          return false;
        }
      }
      // Monitored filter
      if (monitoredFilter != SonarrMonitoredFilter.all) {
        if (monitoredFilter == SonarrMonitoredFilter.monitored && !s.monitored) {
          return false;
        }
        if (monitoredFilter == SonarrMonitoredFilter.unmonitored && s.monitored) {
          return false;
        }
      }
      return true;
    }).toList();
    
    // 2. Sort
    filtered.sort((SonarrSeries a, SonarrSeries b) {
      switch (sortOption) {
        case SonarrSortOption.titleAsc:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case SonarrSortOption.titleDesc:
          return b.title.toLowerCase().compareTo(a.title.toLowerCase());
        case SonarrSortOption.yearAsc:
          return (a.year ?? 0).compareTo(b.year ?? 0);
        case SonarrSortOption.yearDesc:
          return (b.year ?? 0).compareTo(a.year ?? 0);
        case SonarrSortOption.sizeAsc:
          return (a.statistics?.sizeOnDisk ?? 0).compareTo(b.statistics?.sizeOnDisk ?? 0);
        case SonarrSortOption.sizeDesc:
          return (b.statistics?.sizeOnDisk ?? 0).compareTo(a.statistics?.sizeOnDisk ?? 0);
        case SonarrSortOption.progressAsc:
          final double progressA = a.statistics == null || a.statistics!.totalEpisodeCount == 0
              ? 0
              : a.statistics!.episodeFileCount / a.statistics!.totalEpisodeCount;
          final double progressB = b.statistics == null || b.statistics!.totalEpisodeCount == 0
              ? 0
              : b.statistics!.episodeFileCount / b.statistics!.totalEpisodeCount;
          return progressA.compareTo(progressB);
        case SonarrSortOption.progressDesc:
          final double progressA = a.statistics == null || a.statistics!.totalEpisodeCount == 0
              ? 0
              : a.statistics!.episodeFileCount / a.statistics!.totalEpisodeCount;
          final double progressB = b.statistics == null || b.statistics!.totalEpisodeCount == 0
              ? 0
              : b.statistics!.episodeFileCount / b.statistics!.totalEpisodeCount;
          return progressB.compareTo(progressA);
      }
    });
    
    return filtered;
  });
});

