import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'models/sonarr_episode.dart';
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
    (ref, instance) => SonarrViewMode.grid);

/// Search query string for Sonarr series.
final sonarrSearchQueryProvider =
    StateProvider.family<String, Instance>((ref, instance) => '');

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
            (SonarrSeries s) => s.title.toLowerCase().contains(lowercaseQuery))
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

/// All tags for an instance.
final sonarrTagsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SonarrApi api = await ref.watch(sonarrApiProvider(instance).future);
  return api.getTags();
});
