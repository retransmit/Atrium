import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:core_profile/core_profile.dart';
import 'package:core_router/core_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:service_radarr/service_radarr.dart';
import 'package:service_sonarr/service_sonarr.dart';

import 'atrium_link.dart';
import 'title_resolver.dart';
import 'title_share.dart';
import 'title_share_flow.dart';

/// Fetches a movie by its ID in [on]'s own library.
typedef MovieById = Future<RadarrMovie> Function(Instance on, int id);

/// Fetches a series by its ID in [on]'s own library.
typedef SeriesById = Future<SonarrSeries> Function(Instance on, int id);

/// Takes the user where an `atrium://` link points: a service's screen, or a
/// movie or series in Radarr or Sonarr.
///
/// It only ever navigates. A title that is not in the library ends on the
/// usual add sheet, where adding still takes the user's tap, so a link on any
/// web page cannot change anything by itself.
///
/// [go] moves the router to a location. The fetches, the lookups and the
/// screen opener are parameters so tests can stand in for a server; the
/// defaults are the real ones.
Future<void> openAtriumLink(
  WidgetRef ref,
  AtriumLink link, {
  required BuildContext? Function() presentContext,
  required Future<void> Function(String message) tell,
  required void Function(String location) go,
  MovieById? movieById,
  SeriesById? seriesById,
  OpenTitle? openExisting,
  MovieLookup? lookupMovies,
  SeriesLookup? lookupSeries,
}) async {
  final String service = link.service.displayName;
  final List<Instance> ofKind = ref
      .read(activeInstancesProvider)
      .where((Instance i) => i.kind == link.service)
      .toList(growable: false);
  if (ofKind.isEmpty) {
    await tell('No $service is set up in Atrium yet.');
    return;
  }
  final String? name = link.instanceName?.toLowerCase();
  final List<Instance> candidates = name == null
      ? ofKind
      : ofKind
          .where((Instance i) => i.name.toLowerCase() == name)
          .toList(growable: false);
  // The name is not repeated back: any web page can open a link, and the
  // message would show its text inside Atrium.
  if (candidates.isEmpty) {
    await tell('No $service with that name is set up in Atrium.');
    return;
  }

  Future<Instance?> chosen() async => candidates.length == 1
      ? candidates.single
      : pickInstance(presentContext(), candidates, title: 'Open in');

  if (link.item == LinkItem.none) {
    final Instance? on = await chosen();
    if (on != null) {
      go(AtriumRoutes.servicePath(on.kind.name, on.id));
    }
    return;
  }

  final int? libraryId = link.libraryId;
  if (libraryId != null) {
    final Instance? on = await chosen();
    if (on == null) {
      return;
    }
    final TitleMatch match;
    try {
      match = link.item == LinkItem.movie
          ? MovieMatch(
              on,
              await (movieById ?? _movieById(ref))(on, libraryId),
            )
          : SeriesMatch(
              on,
              await (seriesById ?? _seriesById(ref))(on, libraryId),
            );
    } on NetworkNotFoundException {
      final String what = link.item == LinkItem.movie ? 'movie' : 'series';
      await tell('${on.name} has no $what with ID $libraryId.');
      return;
    } on NetworkUnreachableException {
      await tell('Could not reach ${on.name}.');
      return;
    } on NetworkException catch (e) {
      // The server answered, so "could not reach" would be wrong. Its own
      // reason, a refused API key or a server error, says what to fix.
      await tell('${on.name}: ${e.message}');
      return;
    } catch (_) {
      await tell('Could not reach ${on.name}.');
      return;
    }
    final BuildContext? context = presentContext();
    if (context == null || !context.mounted) {
      return;
    }
    // Not awaited: the screen's future ends only when the user leaves it,
    // and the next link or share should not wait for that.
    unawaited((openExisting ?? openExistingTitle)(context, on, match));
    return;
  }

  await runTitleShare(
    ref,
    TitleShare(
      kind: link.item == LinkItem.movie ? TitleKind.movie : TitleKind.show,
      imdbId: link.imdbId,
      tmdbId: link.tmdbId,
      tvdbId: link.tvdbId,
    ),
    presentContext: presentContext,
    tell: tell,
    lookupMovies: lookupMovies,
    lookupSeries: lookupSeries,
    openExisting: openExisting,
    within: candidates,
  );
}

MovieById _movieById(WidgetRef ref) => (Instance on, int id) async =>
    (await ref.read(radarrApiProvider(on).future)).getMovieById(id);

SeriesById _seriesById(WidgetRef ref) => (Instance on, int id) async =>
    (await ref.read(sonarrApiProvider(on).future)).getSeriesById(id);
