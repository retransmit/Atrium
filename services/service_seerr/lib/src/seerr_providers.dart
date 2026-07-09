import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/seerr_counts.dart';
import 'models/seerr_discover.dart';
import 'models/seerr_request.dart';
import 'models/seerr_service.dart';
import 'seerr_api.dart';

/// An [SeerrApi] for an instance, over the shared `instanceDioProvider`.
final seerrApiProvider = FutureProvider.family<SeerrApi, Instance>((
  Ref ref,
  Instance instance,
) async {
  final dio = await ref.watch(instanceDioProvider(instance).future);
  return SeerrApi(dio);
});

final seerrRequestCountsProvider =
    FutureProvider.family<SeerrCounts, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SeerrApi api = await ref.watch(seerrApiProvider(instance).future);
  return api.getRequestCounts();
});

final seerrRequestsProvider =
    FutureProvider.autoDispose.family<List<SeerrRequest>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SeerrApi api = await ref.watch(seerrApiProvider(instance).future);

  final link = ref.keepAlive();
  final timer = Timer(const Duration(seconds: 10), () {
    link.close();
    ref.invalidateSelf();
  });
  ref.onDispose(timer.cancel);

  return api.getAllRequests();
});

final seerrTrendingProvider =
    FutureProvider.family<List<SeerrDiscoverResult>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SeerrApi api = await ref.watch(seerrApiProvider(instance).future);
  return api.getTrending();
});

final seerrUpcomingMoviesProvider =
    FutureProvider.family<List<SeerrDiscoverResult>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SeerrApi api = await ref.watch(seerrApiProvider(instance).future);
  return api.getUpcomingMovies();
});

final seerrUpcomingTvProvider =
    FutureProvider.family<List<SeerrDiscoverResult>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SeerrApi api = await ref.watch(seerrApiProvider(instance).future);
  return api.getUpcomingTvShows();
});

final seerrDiscoverMoviesProvider =
    FutureProvider.family<List<SeerrDiscoverResult>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SeerrApi api = await ref.watch(seerrApiProvider(instance).future);
  return api.discoverMovies();
});

final seerrDiscoverTvProvider =
    FutureProvider.family<List<SeerrDiscoverResult>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SeerrApi api = await ref.watch(seerrApiProvider(instance).future);
  return api.discoverTvShows();
});

final seerrMovieGenresProvider =
    FutureProvider.family<List<SeerrGenre>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SeerrApi api = await ref.watch(seerrApiProvider(instance).future);
  return api.getMovieGenres();
});

final seerrTvGenresProvider =
    FutureProvider.family<List<SeerrGenre>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final SeerrApi api = await ref.watch(seerrApiProvider(instance).future);
  return api.getTvGenres();
});

typedef SeerrSearchArgs = ({Instance instance, String query});

final seerrSearchProvider = FutureProvider.autoDispose
    .family<List<SeerrDiscoverResult>, SeerrSearchArgs>((
  Ref ref,
  SeerrSearchArgs args,
) async {
  final SeerrApi api = await ref.watch(seerrApiProvider(args.instance).future);
  return api.search(args.query);
});

typedef SeerrGenreArgs = ({Instance instance, int genreId, bool isMovie});

final seerrItemsByGenreProvider =
    FutureProvider.family<List<SeerrDiscoverResult>, SeerrGenreArgs>((
  Ref ref,
  SeerrGenreArgs args,
) async {
  final SeerrApi api = await ref.watch(seerrApiProvider(args.instance).future);
  if (args.isMovie) {
    return api.getMoviesByGenre(args.genreId);
  } else {
    return api.getTvShowsByGenre(args.genreId);
  }
});

typedef SeerrMediaDetailsArgs = ({
  Instance instance,
  String mediaType,
  int tmdbId
});

final seerrMediaDetailsProvider =
    FutureProvider.family<SeerrDiscoverResult, SeerrMediaDetailsArgs>((
  Ref ref,
  SeerrMediaDetailsArgs args,
) async {
  final SeerrApi api = await ref.watch(seerrApiProvider(args.instance).future);
  return api.getMediaDetails(args.mediaType, args.tmdbId);
});

typedef SeerrServersArgs = ({Instance instance, String mediaType});

/// Radarr (movie) / Sonarr (tv) servers configured in Seerr, for the request
/// options sheet.
final seerrServersProvider =
    FutureProvider.autoDispose.family<List<SeerrServer>, SeerrServersArgs>((
  Ref ref,
  SeerrServersArgs args,
) async {
  final SeerrApi api = await ref.watch(seerrApiProvider(args.instance).future);
  return api.getServers(args.mediaType);
});

typedef SeerrServerDetailsArgs = ({
  Instance instance,
  String mediaType,
  int serverId
});

/// Quality profiles + root folders for a chosen server.
final seerrServerDetailsProvider = FutureProvider.autoDispose
    .family<SeerrServerDetails, SeerrServerDetailsArgs>((
  Ref ref,
  SeerrServerDetailsArgs args,
) async {
  final SeerrApi api = await ref.watch(seerrApiProvider(args.instance).future);
  return api.getServerDetails(args.mediaType, args.serverId);
});
