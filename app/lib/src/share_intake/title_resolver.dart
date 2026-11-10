import 'package:core_models/core_models.dart';
import 'package:service_radarr/service_radarr.dart';
import 'package:service_sonarr/service_sonarr.dart';

import 'letterboxd.dart';
import 'title_share.dart';

/// A lookup result, with the instance that returned it.
sealed class TitleMatch {
  const TitleMatch(this.source);

  final Instance source;
}

final class MovieMatch extends TitleMatch {
  const MovieMatch(super.source, this.movie);

  final RadarrMovie movie;
}

final class SeriesMatch extends TitleMatch {
  const SeriesMatch(super.source, this.series);

  final SonarrSeries series;
}

class TitleResolution {
  const TitleResolution({
    required this.matches,
    required this.byId,
    this.unreachable = const <Instance>[],
  });

  /// Movies first, then shows.
  final List<TitleMatch> matches;

  /// True when an ID found them, so a single match needs no picking.
  final bool byId;

  /// Every instance that failed to answer.
  final List<Instance> unreachable;
}

typedef MovieLookup = Future<List<RadarrMovie>> Function(
  Instance instance,
  String term,
);
typedef SeriesLookup = Future<List<SonarrSeries>> Function(
  Instance instance,
  String term,
);
typedef LetterboxdReader = Future<LetterboxdFilm?> Function(Uri url);

/// Looks a shared title up on the user's own Radarr and Sonarr.
///
/// An ID is searched as `imdb:` or `tmdb:`, which both servers accept, and
/// otherwise the title is. Only the service matching the kind is asked, or
/// both when the kind is unknown. Within a service the instances are tried
/// in order until one answers, since they all draw on the same metadata.
Future<TitleResolution> resolveTitleShare(
  TitleShare share, {
  required List<Instance> radarrs,
  required List<Instance> sonarrs,
  required MovieLookup lookupMovies,
  required SeriesLookup lookupSeries,
  required LetterboxdReader readLetterboxd,
}) async {
  int? tmdbId = share.tmdbId;
  TitleKind kind = share.kind;
  final Uri? letterboxd = share.letterboxdUrl;
  if (letterboxd != null && share.imdbId == null && tmdbId == null) {
    final LetterboxdFilm? film = await readLetterboxd(letterboxd);
    if (film != null) {
      tmdbId = film.tmdbId;
      kind = film.kind;
    }
  }

  final String? idTerm = share.imdbId != null
      ? 'imdb:${share.imdbId}'
      : tmdbId != null
          ? 'tmdb:$tmdbId'
          : null;
  final String? term = idTerm ?? share.title;
  if (term == null) {
    return const TitleResolution(matches: <TitleMatch>[], byId: false);
  }

  final List<Instance> unreachable = <Instance>[];

  Future<List<TitleMatch>> ask<T>(
    List<Instance> instances,
    Future<List<T>> Function(Instance, String) lookup,
    TitleMatch Function(Instance, T) wrap,
  ) async {
    for (final Instance instance in instances) {
      try {
        final List<T> found = await lookup(instance, term);
        return <TitleMatch>[for (final T item in found) wrap(instance, item)];
      } catch (_) {
        unreachable.add(instance);
      }
    }
    return const <TitleMatch>[];
  }

  final List<List<TitleMatch>> found = await Future.wait(<Future<List<TitleMatch>>>[
    if (kind != TitleKind.show)
      ask<RadarrMovie>(radarrs, lookupMovies, MovieMatch.new),
    if (kind != TitleKind.movie)
      ask<SonarrSeries>(sonarrs, lookupSeries, SeriesMatch.new),
  ]);

  return TitleResolution(
    matches: <TitleMatch>[for (final List<TitleMatch> f in found) ...f],
    byId: idTerm != null,
    unreachable: unreachable,
  );
}
