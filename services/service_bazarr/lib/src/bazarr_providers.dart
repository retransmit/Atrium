import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bazarr_api.dart';
import 'models/bazarr_models.dart';

/// A [BazarrApi] for an instance, over the shared `instanceDioProvider`.
final bazarrApiProvider =
    FutureProvider.family<BazarrApi, Instance>((Ref ref, Instance instance) async {
      final dio = await ref.watch(instanceDioProvider(instance).future);
      return BazarrApi(dio);
    });

/// Summary badge counts for an instance.
final bazarrBadgesProvider =
    FutureProvider.family<BazarrBadges, Instance>((
      Ref ref,
      Instance instance,
    ) async {
      final BazarrApi api = await ref.watch(bazarrApiProvider(instance).future);
      return api.getBadges();
    });

/// The unified "wanted subtitles" list (episodes + movies) for an instance.
final bazarrWantedProvider =
    FutureProvider.family<List<BazarrWantedRow>, Instance>((
      Ref ref,
      Instance instance,
    ) async {
      final BazarrApi api = await ref.watch(bazarrApiProvider(instance).future);
      final List<BazarrWantedEpisode> eps = await api.getWantedEpisodes();
      final List<BazarrWantedMovie> movies = await api.getWantedMovies();
      return <BazarrWantedRow>[
        for (final BazarrWantedEpisode e in eps)
          BazarrWantedRow(
            title: e.seriesTitle,
            subtitle: <String>[
              if (e.episodeNumber.isNotEmpty) e.episodeNumber,
              if (e.episodeTitle.isNotEmpty) e.episodeTitle,
            ].join(' · '),
            missing: e.missingSubtitles,
            isMovie: false,
          ),
        for (final BazarrWantedMovie m in movies)
          BazarrWantedRow(
            title: m.title,
            subtitle: 'Movie',
            missing: m.missingSubtitles,
            isMovie: true,
          ),
      ];
    });

/// All series with subtitle status, sorted by title.
final bazarrSeriesProvider =
    FutureProvider.family<List<BazarrSeries>, Instance>((
      Ref ref,
      Instance instance,
    ) async {
      final BazarrApi api = await ref.watch(bazarrApiProvider(instance).future);
      final List<BazarrSeries> list = await api.getSeries();
      list.sort(
        (BazarrSeries a, BazarrSeries b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
      return list;
    });

/// All movies with subtitle status, sorted by title.
final bazarrMoviesProvider =
    FutureProvider.family<List<BazarrMovie>, Instance>((
      Ref ref,
      Instance instance,
    ) async {
      final BazarrApi api = await ref.watch(bazarrApiProvider(instance).future);
      final List<BazarrMovie> list = await api.getMovies();
      list.sort(
        (BazarrMovie a, BazarrMovie b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
      return list;
    });

/// Args for [bazarrEpisodesProvider]: an instance plus the Sonarr series id.
typedef BazarrEpisodesArgs = ({Instance instance, int seriesId});

/// Episodes for one series, sorted by season then episode number.
final bazarrEpisodesProvider =
    FutureProvider.family<List<BazarrEpisode>, BazarrEpisodesArgs>((
      Ref ref,
      BazarrEpisodesArgs args,
    ) async {
      final BazarrApi api =
          await ref.watch(bazarrApiProvider(args.instance).future);
      final List<BazarrEpisode> eps = await api.getEpisodes(args.seriesId);
      eps.sort((BazarrEpisode a, BazarrEpisode b) {
        final int s = (a.season ?? 0).compareTo(b.season ?? 0);
        return s != 0 ? s : (a.episode ?? 0).compareTo(b.episode ?? 0);
      });
      return eps;
    });
