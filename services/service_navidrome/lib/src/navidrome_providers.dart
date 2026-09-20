import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'navidrome_api.dart';
import 'subsonic_error_interceptor.dart';

/// Epoch timestamp used to bust image caches upon hard refresh.
final navidromeImageEpochProvider =
    StateProvider.family<int, Instance>((Ref ref, Instance instance) => 0);

final navidromeClientProvider =
    FutureProvider.family<NavidromeClient, Instance>(
        (Ref ref, Instance instance) async {
  final int epoch = ref.watch(navidromeImageEpochProvider(instance));
  // instanceDioProvider rather than building one straight off the factory,
  // because it closes the client on dispose. This provider watches the image
  // epoch above, so it rebuilds on every hard refresh; a Dio created here
  // would be abandoned, connection pool and all, each time the user pulled
  // to refresh.
  final Dio dio = await ref.watch(instanceDioProvider(instance).future);
  // Subsonic reports its errors inside a 200, so without this a rejected
  // password arrives as an ordinary empty response and every screen renders
  // its "nothing here" state instead of an error.
  if (!dio.interceptors.any((Interceptor i) => i is SubsonicErrorInterceptor)) {
    dio.interceptors.add(const SubsonicErrorInterceptor());
  }
  return NavidromeClient(instance: instance, dio: dio, cacheBuster: epoch);
});

final navidromeServerInfoProvider =
    FutureProvider.family<NavidromeServerInfo, Instance>(
        (Ref ref, Instance instance) async {
  final NavidromeClient client =
      await ref.watch(navidromeClientProvider(instance).future);
  return client.ping();
});

final navidromeScanStatusProvider =
    FutureProvider.family<NavidromeScanStatus, Instance>(
        (Ref ref, Instance instance) async {
  final NavidromeClient client =
      await ref.watch(navidromeClientProvider(instance).future);
  return client.getScanStatus();
});

/// Fetches albums by category: 'recent', 'frequent', 'starred', 'newest', 'random'.
final navidromeAlbumsProvider =
    FutureProvider.family<List<NavidromeAlbum>, (Instance, String)>((
  Ref ref,
  (Instance, String) args,
) async {
  final (Instance instance, String type) = args;
  final NavidromeClient client =
      await ref.watch(navidromeClientProvider(instance).future);
  return client.getAlbumList(type: type);
});

/// Fetches all artists indexed alphabetically.
final navidromeArtistsProvider =
    FutureProvider.family<List<NavidromeArtistIndex>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final NavidromeClient client =
      await ref.watch(navidromeClientProvider(instance).future);
  return client.getArtists();
});

/// Fetches an artist's full detail including their albums and external artist info.
final navidromeArtistDetailProvider =
    FutureProvider.family<NavidromeArtistDetail, (Instance, String)>((
  Ref ref,
  (Instance, String) args,
) async {
  final (Instance instance, String artistId) = args;
  final NavidromeClient client =
      await ref.watch(navidromeClientProvider(instance).future);
  final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
    client.getArtist(artistId),
    client.getArtistInfo(artistId),
  ]);
  final NavidromeArtistDetail detail = results[0] as NavidromeArtistDetail;
  final NavidromeArtistInfo? info = results[1] as NavidromeArtistInfo?;
  return detail.copyWith(info: info);
});

/// Fetches an album's full detail including tracklist.
final navidromeAlbumDetailProvider =
    FutureProvider.family<NavidromeAlbumDetail, (Instance, String)>((
  Ref ref,
  (Instance, String) args,
) async {
  final (Instance instance, String albumId) = args;
  final NavidromeClient client =
      await ref.watch(navidromeClientProvider(instance).future);
  return client.getAlbum(albumId);
});

/// Fetches all playlists.
final navidromePlaylistsProvider =
    FutureProvider.family<List<NavidromePlaylist>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final NavidromeClient client =
      await ref.watch(navidromeClientProvider(instance).future);
  return client.getPlaylists();
});

/// Fetches a playlist's full detail including songs.
final navidromePlaylistDetailProvider =
    FutureProvider.family<NavidromePlaylistDetail, (Instance, String)>((
  Ref ref,
  (Instance, String) args,
) async {
  final (Instance instance, String playlistId) = args;
  final NavidromeClient client =
      await ref.watch(navidromeClientProvider(instance).future);
  return client.getPlaylist(playlistId);
});

/// Searches artists, albums, and tracks.
final navidromeSearchProvider =
    FutureProvider.family<NavidromeSearchResult, (Instance, String)>((
  Ref ref,
  (Instance, String) args,
) async {
  final (Instance instance, String query) = args;
  if (query.trim().isEmpty) {
    return const NavidromeSearchResult();
  }
  final NavidromeClient client =
      await ref.watch(navidromeClientProvider(instance).future);
  return client.search(query);
});

/// Fetches top songs for an artist via external agents (Last.fm/Deezer/ListenBrainz/Local).
final navidromeTopSongsProvider =
    FutureProvider.family<List<NavidromeSong>, (Instance, String)>((
  Ref ref,
  (Instance, String) args,
) async {
  final (Instance instance, String artist) = args;
  if (artist.trim().isEmpty) {
    return const <NavidromeSong>[];
  }
  final NavidromeClient client =
      await ref.watch(navidromeClientProvider(instance).future);
  return client.getTopSongs(artist: artist);
});

/// Fetches similar songs for a track via external agents.
final navidromeSimilarSongsProvider =
    FutureProvider.family<List<NavidromeSong>, (Instance, String)>((
  Ref ref,
  (Instance, String) args,
) async {
  final (Instance instance, String songId) = args;
  if (songId.trim().isEmpty) {
    return const <NavidromeSong>[];
  }
  final NavidromeClient client =
      await ref.watch(navidromeClientProvider(instance).future);
  return client.getSimilarSongs2(songId: songId);
});

/// Fetches frequent/top albums for overview (only listened albums).
final navidromeFrequentAlbumsProvider =
    FutureProvider.family<List<NavidromeAlbum>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final NavidromeClient client =
      await ref.watch(navidromeClientProvider(instance).future);
  return client.getAlbumList(type: 'frequent', size: 9);
});

/// Fetches top artists for overview chips.
final navidromeOverviewArtistsProvider =
    FutureProvider.family<List<String>, Instance>((
  Ref ref,
  Instance instance,
) async {
  final List<NavidromeAlbum> albums =
      await ref.watch(navidromeFrequentAlbumsProvider(instance).future);
  final Set<String> artists = <String>{};
  for (final NavidromeAlbum a in albums) {
    if (a.artist.isNotEmpty && a.artist != 'Unknown Artist') {
      artists.add(a.artist);
    }
  }
  if (artists.isNotEmpty) {
    return artists.take(8).toList();
  }
  final List<NavidromeArtistIndex> indexes =
      await ref.watch(navidromeArtistsProvider(instance).future);
  for (final NavidromeArtistIndex idx in indexes) {
    for (final NavidromeArtist ar in idx.artists) {
      if (ar.name.isNotEmpty) {
        artists.add(ar.name);
        if (artists.length >= 8) break;
      }
    }
    if (artists.length >= 8) break;
  }
  return artists.toList();
});

@immutable
class NavidromeLastListened {
  const NavidromeLastListened({
    this.artist,
    this.artistId,
    this.song,
  });

  final String? artist;
  final String? artistId;
  final NavidromeSong? song;
}

/// Fetches the last listened to artist and song (via getNowPlaying fallback to recent album).
final navidromeLastListenedProvider =
    FutureProvider.family<NavidromeLastListened, Instance>((
  Ref ref,
  Instance instance,
) async {
  final NavidromeClient client =
      await ref.watch(navidromeClientProvider(instance).future);

  try {
    final List<NavidromeSong> np = await client.getNowPlaying();
    if (np.isNotEmpty) {
      final NavidromeSong s = np.first;
      return NavidromeLastListened(
        artist: s.artist,
        artistId: s.artistId,
        song: s,
      );
    }
  } catch (_) {}

  try {
    final List<NavidromeAlbum> recent =
        await client.getAlbumList(size: 1);
    if (recent.isNotEmpty) {
      final NavidromeAlbum alb = recent.first;
      final NavidromeAlbumDetail detail = await client.getAlbum(alb.id);
      final NavidromeSong? s =
          detail.songs.isNotEmpty ? detail.songs.first : null;
      return NavidromeLastListened(
        artist: alb.artist,
        artistId: alb.artistId,
        song: s,
      );
    }
  } catch (_) {}

  return const NavidromeLastListened();
});

/// Persists active tab across screen transitions.
final navidromeActiveTabIndexProvider =
    StateProvider.family<int, Instance>((Ref ref, Instance instance) => 0);

/// Controls bottom navbar visibility during scroll.
final navidromeBottomNavVisibleProvider =
    StateProvider.family<bool, Instance>((Ref ref, Instance instance) => true);

/// Performs a deep hard refresh of all Navidrome metadata, caches, and images.
Future<void> hardRefreshNavidrome(dynamic ref, Instance instance) async {
  PaintingBinding.instance.imageCache.clear();
  PaintingBinding.instance.imageCache.clearLiveImages();
  final int now = DateTime.now().millisecondsSinceEpoch;

  if (ref is WidgetRef) {
    ref.read(navidromeImageEpochProvider(instance).notifier).state = now;
    ref.invalidate(navidromeAlbumsProvider);
    ref.invalidate(navidromeArtistsProvider);
    ref.invalidate(navidromeArtistDetailProvider);
    ref.invalidate(navidromeAlbumDetailProvider);
    ref.invalidate(navidromePlaylistsProvider);
    ref.invalidate(navidromePlaylistDetailProvider);
    ref.invalidate(navidromeScanStatusProvider);
    ref.invalidate(navidromeServerInfoProvider);
    ref.invalidate(navidromeFrequentAlbumsProvider);
    ref.invalidate(navidromeOverviewArtistsProvider);
    ref.invalidate(navidromeTopSongsProvider);
    ref.invalidate(navidromeSimilarSongsProvider);
    ref.invalidate(navidromeLastListenedProvider);
  } else if (ref is Ref) {
    ref.read(navidromeImageEpochProvider(instance).notifier).state = now;
    ref.invalidate(navidromeAlbumsProvider);
    ref.invalidate(navidromeArtistsProvider);
    ref.invalidate(navidromeArtistDetailProvider);
    ref.invalidate(navidromeAlbumDetailProvider);
    ref.invalidate(navidromePlaylistsProvider);
    ref.invalidate(navidromePlaylistDetailProvider);
    ref.invalidate(navidromeScanStatusProvider);
    ref.invalidate(navidromeServerInfoProvider);
    ref.invalidate(navidromeFrequentAlbumsProvider);
    ref.invalidate(navidromeOverviewArtistsProvider);
    ref.invalidate(navidromeTopSongsProvider);
    ref.invalidate(navidromeSimilarSongsProvider);
    ref.invalidate(navidromeLastListenedProvider);
  }
}

