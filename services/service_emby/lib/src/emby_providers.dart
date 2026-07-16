import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:core_storage/core_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'emby_client.dart';
import 'models/emby_item.dart';
import 'models/emby_remote_image.dart';
import 'models/emby_session.dart';
import 'models/emby_view.dart';

/// A logged-in [EmbyClient] for an instance. Resolves the base URL via the
/// shared [ConnectionResolver] then builds its own token-aware Dio.
final embyClientProvider = FutureProvider.family<EmbyClient, Instance>((
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
  final Map<String, String> customHeaders = mergeHeaders(
    ref.watch(globalHeadersProvider),
    instance.customHeaders,
  );
  final EmbyClient client = EmbyClient.create(
    baseUrl: baseUrl,
    username: username,
    password: password,
    deviceId: instance.id,
    allowSelfSigned: instance.allowSelfSignedCerts,
    customHeaders: customHeaders,
    getLocalOverride: (String itemId, String type) =>
        overridesBox.get('${instance.id}_${itemId}_$type'),
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
final embyViewsProvider = FutureProvider.family<List<EmbyView>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final EmbyClient client =
      await ref.watch(embyClientProvider(instance).future);
  return client.getViews();
});

/// Flattened items within a root library, using recursive fetch based on CollectionType.
final embyLibraryItemsProvider =
    FutureProvider.family<List<EmbyItem>, (Instance, EmbyView)>((
  Ref ref,
  (Instance, EmbyView) key,
) async {
  final (Instance instance, EmbyView view) = key;
  final EmbyClient client =
      await ref.watch(embyClientProvider(instance).future);

  return client.getLibraryItems(view.id, view.collectionType);
});

/// Items within a folder, keyed by (instance, folderId).
final embyItemsProvider =
    FutureProvider.family<List<EmbyItem>, (Instance, String)>((
  Ref ref,
  (Instance, String) key,
) async {
  final (Instance instance, String libraryId) = key;
  final EmbyClient client =
      await ref.watch(embyClientProvider(instance).future);

  if (libraryId == 'watched') {
    return client.getWatchedItems();
  } else if (libraryId == 'unwatched') {
    return client.getUnwatchedItems();
  }

  return client.getItems(libraryId);
});

final embyResumeItemsProvider =
    FutureProvider.family<List<EmbyItem>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final EmbyClient client =
      await ref.watch(embyClientProvider(instance).future);
  return client.getResumeItems();
});

final embySessionsProvider =
    StreamProvider.autoDispose.family<List<ActiveSession>, Instance>((
  Ref ref,
  Instance instance,
) async* {
  bool disposed = false;
  ref.onDispose(() => disposed = true);

  final EmbyClient client =
      await ref.watch(embyClientProvider(instance).future);

  // Initial fetch
  yield await client.getSessions();

  // Poll every 10 seconds
  while (!disposed) {
    await Future<void>.delayed(const Duration(seconds: 10));
    if (disposed) break;

    try {
      yield await client.getSessions();
    } catch (_) {
      // Ignore polling errors, let the UI keep the last known good state
    }
  }
});

final embyFastSessionsProvider =
    StreamProvider.autoDispose.family<List<ActiveSession>, Instance>((
  Ref ref,
  Instance instance,
) async* {
  bool disposed = false;
  ref.onDispose(() => disposed = true);

  final EmbyClient client =
      await ref.watch(embyClientProvider(instance).future);

  // Initial fetch
  yield await client.getSessions();

  // Poll every 1 second
  while (!disposed) {
    await Future<void>.delayed(const Duration(seconds: 1));
    if (disposed) break;

    try {
      yield await client.getSessions();
    } catch (_) {
      // Ignore polling errors, let the UI keep the last known good state
    }
  }
});

final embyLibraryScanProvider = StreamProvider.autoDispose
    .family<({String state, double progress})?, Instance>((
  Ref ref,
  Instance instance,
) async* {
  bool disposed = false;
  ref.onDispose(() => disposed = true);

  final EmbyClient client =
      await ref.watch(embyClientProvider(instance).future);

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

final embyNextUpProvider = FutureProvider.family<List<EmbyItem>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final EmbyClient client =
      await ref.watch(embyClientProvider(instance).future);
  return client.getNextUp();
});

final embyLatestItemsProvider =
    FutureProvider.family<List<EmbyItem>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final EmbyClient client =
      await ref.watch(embyClientProvider(instance).future);
  return client.getLatestItems();
});

final embyFavoritesProvider = FutureProvider.family<List<EmbyItem>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final EmbyClient client =
      await ref.watch(embyClientProvider(instance).future);
  return client.getFavorites();
});

typedef AlbumScreenData = ({List<EmbyItem> tracks, EmbyItem? artistBio});

final embyAlbumDataFutureProvider =
    FutureProvider.family<AlbumScreenData, (Instance, String, String)>((
  Ref ref,
  (Instance, String, String) key,
) async {
  final (Instance instance, String albumId, String artistName) = key;
  final EmbyClient client =
      await ref.watch(embyClientProvider(instance).future);

  final Future<List<EmbyItem>> tracksFuture = client.getAlbumSongs(albumId);
  final Future<EmbyItem?> bioFuture = client.getArtistBio(artistName);

  final List<Object?> results =
      await Future.wait<Object?>(<Future<Object?>>[tracksFuture, bioFuture]);

  return (
    tracks: results[0] as List<EmbyItem>,
    artistBio: results[1] as EmbyItem?,
  );
});

final embyItemDetailsProvider =
    FutureProvider.family<EmbyItem, (Instance, String)>((
  Ref ref,
  (Instance, String) key,
) async {
  final (Instance instance, String itemId) = key;
  final EmbyClient client =
      await ref.watch(embyClientProvider(instance).future);
  return client.getItemDetails(itemId);
});

// --- State Providers ---

/// Selected library view (e.g. 'home', 'movies', 'shows')
final embyHomeSelectedViewProvider = StateProvider<String>((ref) => 'home');

enum EmbyViewMode { list, grid }

/// View mode for library items (list or grid)
final embyViewModeProvider =
    StateProvider.family<EmbyViewMode, Instance>((ref, instance) {
  return EmbyViewMode.grid;
});

/// A controller to toggle watched/unwatched status and invalidate affected providers.
final embyToggleWatchedProvider = Provider.family<
    Future<void> Function(String itemId, bool markWatched),
    Instance>((Ref ref, Instance instance) {
  return (String itemId, bool markWatched) async {
    final EmbyClient client =
        await ref.read(embyClientProvider(instance).future);
    if (markWatched) {
      await client.markAsWatched(itemId);
    } else {
      await client.markAsUnwatched(itemId);
    }
    // Invalidate item grids to refresh watched/unwatched lists
    ref.invalidate(embyItemsProvider);
    ref.invalidate(embyLibraryItemsProvider);
    // Also invalidate specific item details if they are currently loaded
    ref.invalidate(embyItemDetailsProvider);
    // And next up in case it affected what's next
    ref.invalidate(embyNextUpProvider);
  };
});

final embySeasonsProvider =
    FutureProvider.family<List<EmbyItem>, (Instance, String)>((
  Ref ref,
  (Instance, String) key,
) async {
  final (Instance instance, String seriesId) = key;
  final EmbyClient client =
      await ref.watch(embyClientProvider(instance).future);
  return client.getSeasons(seriesId);
});

final embyEpisodesProvider =
    FutureProvider.family<List<EmbyItem>, (Instance, String)>((
  Ref ref,
  (Instance, String) key,
) async {
  final (Instance instance, String seasonId) = key;
  final EmbyClient client =
      await ref.watch(embyClientProvider(instance).future);
  return client.getEpisodes(seasonId);
});

final embyAlbumSongsProvider =
    FutureProvider.family<List<EmbyItem>, (Instance, String)>((
  Ref ref,
  (Instance, String) key,
) async {
  final (Instance instance, String albumId) = key;
  final EmbyClient client =
      await ref.watch(embyClientProvider(instance).future);
  return client.getAlbumSongs(albumId);
});

final embyArtistBioProvider =
    FutureProvider.family<EmbyItem?, (Instance, String)>((
  Ref ref,
  (Instance, String) key,
) async {
  final (Instance instance, String artistName) = key;
  final EmbyClient client =
      await ref.watch(embyClientProvider(instance).future);
  return client.getArtistBio(artistName);
});

final embyRemoteImagesProvider = FutureProvider.autoDispose
    .family<List<EmbyRemoteImage>, (Instance, String, String)>((
  Ref ref,
  (Instance, String, String) key,
) async {
  final (Instance instance, String itemId, String imageType) = key;
  final EmbyClient client =
      await ref.watch(embyClientProvider(instance).future);
  return client.getRemoteImages(itemId, imageType);
});

final embyActiveTabBarIndexProvider =
    StateProvider.family<int, Instance>((Ref ref, Instance instance) => 0);
