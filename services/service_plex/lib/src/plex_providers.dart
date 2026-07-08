import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/plex_models.dart';
import 'models/plex_session.dart';
import 'plex_api.dart';

/// A [PlexApi] for an instance, over the shared `instanceDioProvider`.
final plexApiProvider =
    FutureProvider.family<PlexApi, Instance>((Ref ref, Instance instance) async {
      final dio = await ref.watch(instanceDioProvider(instance).future);
      final String token = switch (instance.auth) {
        InstanceAuthPlex(:final String token) => token,
        _ => '',
      };
      return PlexApi(dio, token: token);
    });

/// Libraries for an instance.
final plexLibrariesProvider =
    FutureProvider.family<List<PlexLibrary>, Instance>((
      Ref ref,
      Instance instance,
    ) async {
      final PlexApi api = await ref.watch(plexApiProvider(instance).future);
      return api.getLibraries();
    });

/// Items within a library, keyed by (instance, sectionKey).
final plexItemsProvider =
    FutureProvider.family<List<PlexMetadata>, (Instance, String)>((
      Ref ref,
      (Instance, String) key,
    ) async {
      final (Instance instance, String sectionKey) = key;
      final PlexApi api = await ref.watch(plexApiProvider(instance).future);
      return api.getItems(sectionKey);
    });

/// Children of a show (seasons) or season (episodes), keyed by
/// (instance, ratingKey).
final plexChildrenProvider =
    FutureProvider.family<List<PlexMetadata>, (Instance, String)>((
      Ref ref,
      (Instance, String) key,
    ) async {
      final (Instance instance, String ratingKey) = key;
      final PlexApi api = await ref.watch(plexApiProvider(instance).future);
      return api.getChildren(ratingKey);
    });

/// Full metadata for one item (detail screen), keyed by (instance, ratingKey).
final plexItemDetailProvider =
    FutureProvider.family<PlexMetadata?, (Instance, String)>((
      Ref ref,
      (Instance, String) key,
    ) async {
      final (Instance instance, String ratingKey) = key;
      final PlexApi api = await ref.watch(plexApiProvider(instance).future);
      return api.getMetadata(ratingKey);
    });

/// "Continue Watching" (on deck) for an instance.
final plexOnDeckProvider =
    FutureProvider.family<List<PlexMetadata>, Instance>((
      Ref ref,
      Instance instance,
    ) async {
      final PlexApi api = await ref.watch(plexApiProvider(instance).future);
      return api.getOnDeck();
    });

/// Recently added items for an instance.
final plexRecentlyAddedProvider =
    FutureProvider.family<List<PlexMetadata>, Instance>((
      Ref ref,
      Instance instance,
    ) async {
      final PlexApi api = await ref.watch(plexApiProvider(instance).future);
      return api.getRecentlyAdded();
    });

/// How often the now-playing sessions refresh while a Plex session screen or
/// the home now-streaming row is visible.
const Duration plexSessionsPollInterval = Duration(seconds: 3);

/// Active playback sessions. Polls while watched; stops on dispose.
final plexSessionsProvider =
    FutureProvider.autoDispose.family<List<PlexSession>, Instance>((
      Ref ref,
      Instance instance,
    ) async {
      ref.pollEvery(plexSessionsPollInterval);
      final PlexApi api = await ref.watch(plexApiProvider(instance).future);
      return api.getSessions();
    });

/// Genre directories for a library section.
final plexGenresProvider =
    FutureProvider.autoDispose.family<List<PlexGenreDir>, (Instance, String)>((
      Ref ref,
      (Instance, String) key,
    ) async {
      final (Instance instance, String sectionKey) = key;
      final PlexApi api = await ref.watch(plexApiProvider(instance).future);
      return api.getGenres(sectionKey);
    });

/// Items in a section filtered by genre, keyed by (instance, section, genre).
final plexGenreItemsProvider = FutureProvider.autoDispose
    .family<List<PlexMetadata>, (Instance, String, String)>((
      Ref ref,
      (Instance, String, String) key,
    ) async {
      final (Instance instance, String sectionKey, String genreKey) = key;
      final PlexApi api = await ref.watch(plexApiProvider(instance).future);
      return api.getItemsByGenre(sectionKey, genreKey);
    });
