import 'dart:async';

import 'package:collection/collection.dart';
import 'package:core_models/core_models.dart';
import 'package:core_profile/core_profile.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';
import 'package:service_radarr/service_radarr.dart';
import 'package:service_sonarr/service_sonarr.dart';

import 'letterboxd.dart';
import 'title_resolver.dart';
import 'title_share.dart';

/// Shows what was found on [on], already in its library.
typedef OpenTitle = Future<void> Function(
  BuildContext context,
  Instance on,
  TitleMatch match,
);

/// Takes a movie or show shared from another app all the way to Radarr or
/// Sonarr: finds it, lets the user pick the title and the instance when
/// there is a choice, then opens it if that instance already has it, or the
/// usual add sheet if not. Returns once the add sheet is done, or as soon as
/// the title's own screen is open, so the next share does not wait on it.
///
/// [within], when set, limits the search to those instances, as when a link
/// names the one to use.
///
/// The lookups, the Letterboxd reader and the two endings are parameters so
/// tests can stand in for a server; the defaults are the real ones.
Future<void> runTitleShare(
  WidgetRef ref,
  TitleShare share, {
  required BuildContext? Function() presentContext,
  required Future<void> Function(String message) tell,
  MovieLookup? lookupMovies,
  SeriesLookup? lookupSeries,
  LetterboxdReader? readLetterboxd,
  OpenTitle? openExisting,
  OpenTitle? openAdd,
  List<Instance>? within,
}) async {
  final MovieLookup movies = lookupMovies ??
      (Instance i, String term) async =>
          (await ref.read(radarrApiProvider(i).future)).lookupMovie(term);
  final SeriesLookup series = lookupSeries ??
      (Instance i, String term) async =>
          (await ref.read(sonarrApiProvider(i).future)).lookupSeries(term);

  final List<Instance> active = <Instance>[
    for (final Instance i in ref.read(activeInstancesProvider))
      if (within == null || within.contains(i)) i,
  ];
  final List<Instance> radarrs = active
      .where((Instance i) => i.kind == ServiceKind.radarr)
      .toList(growable: false);
  final List<Instance> sonarrs = active
      .where((Instance i) => i.kind == ServiceKind.sonarr)
      .toList(growable: false);

  final String? missing = switch (share.kind) {
    TitleKind.movie when radarrs.isEmpty => 'No Radarr is set up',
    TitleKind.show when sonarrs.isEmpty => 'No Sonarr is set up',
    _ when radarrs.isEmpty && sonarrs.isEmpty => 'No Radarr or Sonarr is set up',
    _ => null,
  };
  if (missing != null) {
    await tell('$missing in Atrium yet. Add one, then share this again.');
    return;
  }

  final TitleResolution resolution = await _whileFinding(
    presentContext,
    resolveTitleShare(
      share,
      radarrs: radarrs,
      sonarrs: sonarrs,
      lookupMovies: movies,
      lookupSeries: series,
      readLetterboxd: readLetterboxd ??
          (Uri url) => readLetterboxdFilm(letterboxdDio(), url),
    ),
  );

  if (resolution.matches.isEmpty) {
    await tell(
      resolution.unreachable.isNotEmpty
          ? 'Could not reach '
              '${resolution.unreachable.map((Instance i) => i.name).join(', ')}'
              ', so nothing was added.'
          : 'Could not find that title in Radarr or Sonarr, so nothing was '
              'added.',
    );
    return;
  }

  final TitleMatch? picked =
      resolution.byId && resolution.matches.length == 1
          ? resolution.matches.single
          : await _pickMatch(presentContext(), resolution.matches);
  if (picked == null) {
    return;
  }

  final List<Instance> choices =
      picked is MovieMatch ? radarrs : sonarrs;
  final Instance? target = choices.length == 1
      ? choices.single
      : await pickInstance(presentContext(), choices);
  if (target == null) {
    return;
  }

  // The lookup ran on one instance; whether the title is already in the
  // library is a question for the one the user picked. The first result's
  // id is that first instance's library id, so when the chosen one cannot
  // answer for it, the title is treated as not in its library (id 0).
  TitleMatch match = picked;
  if (target != picked.source) {
    try {
      match = switch (picked) {
        MovieMatch(:final RadarrMovie movie) => MovieMatch(
            target,
            (movie.tmdbId == null
                    ? null
                    : (await movies(target, 'tmdb:${movie.tmdbId}'))
                        .firstOrNull) ??
                movie.copyWith(id: 0),
          ),
        SeriesMatch(series: final SonarrSeries s) => SeriesMatch(
            target,
            (s.tvdbId == null
                    ? null
                    : (await series(target, 'tvdb:${s.tvdbId}')).firstOrNull) ??
                s.copyWith(id: 0),
          ),
      };
    } catch (_) {
      await tell('Could not reach ${target.name}, so nothing was added.');
      return;
    }
  }

  final BuildContext? context = presentContext();
  if (context == null || !context.mounted) {
    return;
  }
  final bool inLibrary = switch (match) {
    MovieMatch(:final RadarrMovie movie) => movie.id > 0,
    SeriesMatch(series: final SonarrSeries s) => s.id > 0,
  };
  if (inLibrary) {
    unawaited((openExisting ?? openExistingTitle)(context, target, match));
    return;
  }
  await (openAdd ?? _openAdd)(context, target, match);
}

/// Runs [work] behind a "Finding that title" sheet, closed when it ends.
Future<T> _whileFinding<T>(
  BuildContext? Function() presentContext,
  Future<T> work,
) async {
  final BuildContext? context = presentContext();
  if (context == null || !context.mounted) {
    return work;
  }
  final NavigatorState navigator = Navigator.of(context, rootNavigator: true);
  bool open = true;
  unawaited(
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isDismissible: false,
      enableDrag: false,
      builder: (BuildContext context) => PopScope(
        canPop: false,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            child: Row(
              children: <Widget>[
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicatorM3E(),
                ),
                const SizedBox(width: 20),
                Text(
                  'Finding that title…',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() => open = false),
  );
  try {
    return await work;
  } finally {
    if (open && navigator.mounted) {
      navigator.pop();
    }
  }
}

Future<TitleMatch?> _pickMatch(
  BuildContext? context,
  List<TitleMatch> matches,
) async {
  if (context == null || !context.mounted) {
    return null;
  }
  return showModalBottomSheet<TitleMatch>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (BuildContext context, ScrollController controller) =>
          ListView(
        controller: controller,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Text(
              'Pick the title',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          for (final TitleMatch m in matches) _MatchTile(match: m),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}

class _MatchTile extends ConsumerWidget {
  const _MatchTile({required this.match});

  final TitleMatch match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (String title, int? year, String? poster, String kind) =
        switch (match) {
      MovieMatch(:final RadarrMovie movie) => (
          movie.title,
          movie.year,
          _radarrPoster(ref, match.source, movie),
          'Movie',
        ),
      SeriesMatch(series: final SonarrSeries s) => (
          s.title,
          s.year,
          _sonarrPoster(ref, match.source, s),
          'Show',
        ),
    };
    final ColorScheme cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 40,
          height: 60,
          child: poster == null
              ? ColoredBox(
                  color: cs.surfaceContainerHigh,
                  child: Icon(
                    match is MovieMatch
                        ? Icons.movie_outlined
                        : Icons.tv_outlined,
                    size: 20,
                  ),
                )
              : AtriumNetworkImage(
                  imageUrl: poster,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      ColoredBox(color: cs.surfaceContainerHigh),
                ),
        ),
      ),
      title: Text(year != null && year > 0 ? '$title ($year)' : title),
      subtitle: Text(kind),
      onTap: () => Navigator.of(context).pop(match),
    );
  }
}

String? _radarrPoster(WidgetRef ref, Instance on, RadarrMovie movie) {
  final RadarrImage? image =
      movie.images.firstWhereOrNull((RadarrImage i) => i.coverType == 'poster');
  final RadarrApi? api = ref.watch(radarrApiProvider(on)).value;
  return image == null ? null : api?.posterUrl(image, preferRemote: true);
}

String? _sonarrPoster(WidgetRef ref, Instance on, SonarrSeries s) {
  final SonarrImage? image =
      s.images.firstWhereOrNull((SonarrImage i) => i.coverType == 'poster');
  final SonarrApi? api = ref.watch(sonarrApiProvider(on)).value;
  return image == null ? null : api?.posterUrl(image, preferRemote: true);
}

/// Asks which of [instances] to use, in a sheet. Null when dismissed or
/// when there is nowhere to show it.
Future<Instance?> pickInstance(
  BuildContext? context,
  List<Instance> instances, {
  String title = 'Add to',
}) async {
  if (context == null || !context.mounted) {
    return null;
  }
  return showModalBottomSheet<Instance>(
    context: context,
    useRootNavigator: true,
    builder: (BuildContext context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          for (final Instance instance in instances)
            ListTile(
              leading: Icon(ServiceVisuals.icon(instance.kind)),
              title: Text(instance.name),
              subtitle: Text(instance.kind.displayName),
              onTap: () => Navigator.of(context).pop(instance),
            ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}

/// Opens a movie's or series' own screen on [on].
Future<void> openExistingTitle(
  BuildContext context,
  Instance on,
  TitleMatch match,
) =>
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => switch (match) {
          MovieMatch(:final RadarrMovie movie) =>
            MovieDetailScreen(instance: on, movieId: movie.id, movie: movie),
          SeriesMatch(series: final SonarrSeries s) =>
            SeriesDetailScreen(instance: on, series: s),
        },
      ),
    );

Future<void> _openAdd(BuildContext context, Instance on, TitleMatch match) =>
    showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext context) => switch (match) {
        MovieMatch(:final RadarrMovie movie) =>
          RadarrAddMovieSheet(instance: on, movie: movie),
        SeriesMatch(series: final SonarrSeries s) =>
          SonarrAddSeriesSheet(instance: on, series: s),
      },
    );
