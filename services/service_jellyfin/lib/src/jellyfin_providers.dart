import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:core_storage/core_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'jellyfin_client.dart';
import 'models/jellyfin_auth.dart';
import 'models/jellyfin_item.dart';
import 'models/jellyfin_remote_image.dart';
import 'models/jellyfin_session.dart';
import 'models/jellyfin_view.dart';

/// A logged-in [JellyfinClient] for an instance.
///
/// Like qBittorrent, Jellyfin can't reuse `instanceDioProvider` - it needs a
/// token acquired at runtime rather than a static key - so it resolves the
/// base URL via the shared [ConnectionResolver] and builds its own Dio.
final jellyfinClientProvider = FutureProvider.family<JellyfinClient, Instance>((
  Ref ref,
  Instance instance,
) async {
  final ConnectionResolver resolver = ref.watch(connectionResolverProvider);
  final Uri baseUrl = await resolver.resolve(instance);
  final (String username, String password) = switch (instance.auth) {
    InstanceAuthUserPass(:final String username, :final String password) => (
        username,
        password
      ),
    _ => ('', ''),
  };
  final Box<String> overridesBox = Hive.box<String>(AtriumBoxes.imageOverrides);
  final JellyfinClient client = JellyfinClient.create(
    baseUrl: baseUrl,
    username: username,
    password: password,
    deviceId: instance.id,
    allowSelfSigned: instance.allowSelfSignedCerts,
    getLocalOverride: (String itemId, String type) => overridesBox.get('${instance.id}_${itemId}_$type'),
    setLocalOverride: (String itemId, String type, String tag) {
      if (tag.isEmpty) {
        overridesBox.delete('${instance.id}_${itemId}_$type');
      } else {
        overridesBox.put('${instance.id}_${itemId}_$type', tag);
      }
    },
  );
  ref.onDispose(client.close);
  return client;
});

/// Libraries for an instance.
final jellyfinViewsProvider = FutureProvider.family<List<JellyfinView>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final JellyfinClient client = await ref.read(jellyfinClientProvider(instance).future);
  return client.getViews();
});

final jellyfinVirtualFoldersProvider = FutureProvider.family<List<JellyfinVirtualFolder>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final JellyfinClient client = await ref.read(jellyfinClientProvider(instance).future);
  return client.getVirtualFolders();
});

/// Flattened items within a root library, using recursive fetch based on CollectionType.
final jellyfinLibraryItemsProvider =
    FutureProvider.family<List<JellyfinItem>, (Instance, JellyfinView)>((
  Ref ref,
  (Instance, JellyfinView) key,
) async {
  final (Instance instance, JellyfinView view) = key;
  final JellyfinClient client =
      await ref.watch(jellyfinClientProvider(instance).future);

  return client.getLibraryItems(view.id, view.collectionType);
});

/// Items within a library. Keyed by (instance, libraryId) - Dart 3 records
/// give the family a structural-equality cache key for free.
final jellyfinItemsProvider =
    FutureProvider.family<List<JellyfinItem>, (Instance, String)>((
  Ref ref,
  (Instance, String) key,
) async {
  final (Instance instance, String libraryId) = key;
  final JellyfinClient client =
      await ref.watch(jellyfinClientProvider(instance).future);

  if (libraryId == 'watched') {
    return client.getWatchedItems();
  }
  if (libraryId == 'unwatched') {
    return client.getUnwatchedItems();
  }

  return client.getItems(libraryId);
});

final jellyfinResumeItemsProvider =
    FutureProvider.family<List<JellyfinItem>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final JellyfinClient client =
      await ref.watch(jellyfinClientProvider(instance).future);
  return client.getResumeItems();
});

final jellyfinNextUpProvider =
    FutureProvider.family<List<JellyfinItem>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final JellyfinClient client =
      await ref.watch(jellyfinClientProvider(instance).future);
  return client.getNextUp();
});

final jellyfinLatestItemsProvider =
    FutureProvider.family<List<JellyfinItem>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final JellyfinClient client =
      await ref.watch(jellyfinClientProvider(instance).future);
  return client.getLatestItems();
});

final jellyfinFavoritesProvider =
    FutureProvider.family<List<JellyfinItem>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final JellyfinClient client =
      await ref.watch(jellyfinClientProvider(instance).future);
  return client.getFavorites();
});

final jellyfinItemDetailsProvider =
    FutureProvider.family<JellyfinItem, (Instance, String)>((
  Ref ref,
  (Instance, String) key,
) async {
  final (Instance instance, String itemId) = key;
  final JellyfinClient client =
      await ref.watch(jellyfinClientProvider(instance).future);
  return client.getItemDetails(itemId);
});

final jellyfinSeasonsProvider =
    FutureProvider.family<List<JellyfinItem>, (Instance, String)>((
  Ref ref,
  (Instance, String) key,
) async {
  final (Instance instance, String seriesId) = key;
  final JellyfinClient client =
      await ref.watch(jellyfinClientProvider(instance).future);
  return client.getSeasons(seriesId);
});

final jellyfinEpisodesProvider =
    FutureProvider.family<List<JellyfinItem>, (Instance, String, String)>((
  Ref ref,
  (Instance, String, String) key,
) async {
  final (Instance instance, String seriesId, String seasonId) = key;
  final JellyfinClient client =
      await ref.watch(jellyfinClientProvider(instance).future);
  return client.getEpisodes(seriesId, seasonId);
});

final jellyfinLibraryScanProvider =
    StreamProvider.autoDispose.family<({String state, double progress})?, Instance>((
  Ref ref,
  Instance instance,
) async* {
  bool disposed = false;
  ref.onDispose(() => disposed = true);

  final JellyfinClient client =
      await ref.watch(jellyfinClientProvider(instance).future);

  // Initial fetch
  yield await client.getLibraryScanProgress();

  // Poll every 2 seconds
  while (!disposed) {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (disposed) break;

    try {
      yield await client.getLibraryScanProgress();
    } catch (_) {
      // Ignore polling errors
    }
  }
});

final jellyfinUsersProvider = FutureProvider.autoDispose.family<List<JellyfinUser>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final JellyfinClient client = await ref.watch(jellyfinClientProvider(instance).future);
  return client.getUsers();
});

final jellyfinCurrentUserProvider = FutureProvider.autoDispose.family<JellyfinUser, Instance>((
  Ref ref,
  Instance instance,
) async {
  final JellyfinClient client = await ref.watch(jellyfinClientProvider(instance).future);
  return client.getCurrentUser();
});

final jellyfinSessionsProvider =
    StreamProvider.autoDispose.family<List<ActiveSession>, Instance>((
  Ref ref,
  Instance instance,
) async* {
  bool disposed = false;
  ref.onDispose(() => disposed = true);

  final JellyfinClient client =
      await ref.watch(jellyfinClientProvider(instance).future);

  while (!disposed) {
    yield await client.getSessions();
    await Future<void>.delayed(const Duration(seconds: 10));
  }
});

final jellyfinToggleWatchedProvider =
    Provider.family<Future<void> Function(String, bool), Instance>((
  Ref ref,
  Instance instance,
) {
  return (String itemId, bool watched) async {
    final JellyfinClient client =
        await ref.watch(jellyfinClientProvider(instance).future);

    // Jellyfin natively supports marking Series/Season/BoxSet as watched
    // with a single API call to the item itself. No need to map episodes!
    if (watched) {
      await client.markAsWatched(itemId);
    } else {
      await client.markAsUnwatched(itemId);
    }

    // Give Jellyfin a moment to recalculate UnplayedItemCount in its database
    await Future<void>.delayed(const Duration(milliseconds: 500));

    ref.invalidate(jellyfinItemsProvider);
    ref.invalidate(jellyfinResumeItemsProvider);
    ref.invalidate(jellyfinItemDetailsProvider((instance, itemId)));
    ref.invalidate(jellyfinNextUpProvider);
  };
});

typedef AlbumScreenData = ({
  List<JellyfinItem> tracks,
  JellyfinItem? artistBio
});

final jellyfinAlbumDataFutureProvider =
    FutureProvider.family<AlbumScreenData, (Instance, String, String)>((
  Ref ref,
  (Instance, String, String) key,
) async {
  final (Instance instance, String albumId, String artistName) = key;
  final JellyfinClient client =
      await ref.watch(jellyfinClientProvider(instance).future);

  final Future<List<JellyfinItem>> tracksFuture = client.getAlbumSongs(albumId);
  final Future<JellyfinItem?> bioFuture = client.getArtistBio(artistName);

  final List<Object?> results =
      await Future.wait<Object?>(<Future<Object?>>[tracksFuture, bioFuture]);

  return (
    tracks: results[0] as List<JellyfinItem>,
    artistBio: results[1] as JellyfinItem?,
  );
});

final jellyfinAlbumSongsProvider =
    FutureProvider.family<List<JellyfinItem>, (Instance, String)>((
  Ref ref,
  (Instance, String) key,
) async {
  final (Instance instance, String albumId) = key;
  final JellyfinClient client =
      await ref.watch(jellyfinClientProvider(instance).future);
  return client.getAlbumSongs(albumId);
});

final jellyfinArtistBioProvider =
    FutureProvider.family<JellyfinItem?, (Instance, String)>((
  Ref ref,
  (Instance, String) key,
) async {
  final (Instance instance, String artistName) = key;
  final JellyfinClient client =
      await ref.watch(jellyfinClientProvider(instance).future);
  return client.getArtistBio(artistName);
});

final jellyfinGridScaleProvider = StateProvider<double>((ref) => 140.0);

enum JellyfinViewMode { grid, list }

final jellyfinViewModeProvider =
    StateProvider.family<JellyfinViewMode, Instance>(
  (Ref ref, Instance instance) => JellyfinViewMode.grid,
);

final jellyfinActiveTabBarIndexProvider =
    StateProvider.family<int, Instance>((Ref ref, Instance instance) => 0);

final jellyfinFastSessionsProvider =
    StreamProvider.autoDispose.family<List<ActiveSession>, Instance>((
  Ref ref,
  Instance instance,
) async* {
  bool disposed = false;
  ref.onDispose(() => disposed = true);

  final JellyfinClient client =
      await ref.watch(jellyfinClientProvider(instance).future);

  // Initial fetch
  yield await client.getSessions();

  // Poll every 1 second
  while (!disposed) {
    await Future<void>.delayed(const Duration(seconds: 1));
    if (disposed) break;
    yield await client.getSessions();
  }
});

final jellyfinRemoteImagesProvider = FutureProvider.family<
    List<JellyfinRemoteImage>, (Instance, String, String)>((
  Ref ref,
  (Instance, String, String) key,
) async {
  final (Instance instance, String itemId, String imageType) = key;
  final JellyfinClient client =
      await ref.watch(jellyfinClientProvider(instance).future);
  return client.getRemoteImages(itemId, imageType);
});
