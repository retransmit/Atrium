import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'jellyfin_client.dart';
import 'models/jellyfin_item.dart';
import 'models/jellyfin_session.dart';
import 'models/jellyfin_view.dart';

/// A logged-in [JellyfinClient] for an instance.
///
/// Like qBittorrent, Jellyfin can't reuse `instanceDioProvider` - it needs a
/// token acquired at runtime rather than a static key - so it resolves the
/// base URL via the shared [ConnectionResolver] and builds its own Dio.
final jellyfinClientProvider =
    FutureProvider.family<JellyfinClient, Instance>((
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
  final JellyfinClient client = JellyfinClient.create(
    baseUrl: baseUrl,
    username: username,
    password: password,
    deviceId: instance.id,
    allowSelfSigned: instance.allowSelfSignedCerts,
  );
  ref.onDispose(client.close);
  return client;
});

/// Libraries for an instance.
final jellyfinViewsProvider =
    FutureProvider.family<List<JellyfinView>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final JellyfinClient client =
      await ref.watch(jellyfinClientProvider(instance).future);
  return client.getViews();
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



final jellyfinSessionsProvider =
    StreamProvider.family<List<ActiveSession>, Instance>((
  Ref ref,
  Instance instance,
) async* {
  final JellyfinClient client =
      await ref.watch(jellyfinClientProvider(instance).future);
      
  while (true) {
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
