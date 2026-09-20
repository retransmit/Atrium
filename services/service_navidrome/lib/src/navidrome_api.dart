import 'dart:convert';
import 'dart:math';

import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import 'models/navidrome_models.dart';

export 'models/navidrome_models.dart';

class NavidromeServerInfo {
  const NavidromeServerInfo({
    required this.status,
    required this.subsonicVersion,
    required this.serverVersion,
    required this.type,
  });

  final String status;
  final String subsonicVersion;
  final String serverVersion;
  final String type;

  factory NavidromeServerInfo.fromJson(Map<String, dynamic> json) {
    final dynamic resp = json['subsonic-response'] ?? json;
    final Map<String, dynamic> map =
        resp is Map<String, dynamic> ? resp : const <String, dynamic>{};
    return NavidromeServerInfo(
      status: (map['status'] as String?) ?? 'ok',
      subsonicVersion: (map['version'] as String?) ?? '1.16.1',
      serverVersion: (map['serverVersion'] as String?) ?? '',
      type: (map['type'] as String?) ?? 'navidrome',
    );
  }
}

class NavidromeScanStatus {
  const NavidromeScanStatus({
    required this.scanning,
    required this.count,
  });

  final bool scanning;
  final int count;

  factory NavidromeScanStatus.fromJson(Map<String, dynamic> json) {
    final dynamic resp = json['subsonic-response'] ?? json;
    final Map<String, dynamic> map =
        resp is Map<String, dynamic> ? resp : const <String, dynamic>{};
    final dynamic scan = map['scanStatus'];
    final Map<String, dynamic> scanMap =
        scan is Map<String, dynamic> ? scan : const <String, dynamic>{};
    return NavidromeScanStatus(
      scanning: (scanMap['scanning'] as bool?) ?? false,
      count: (scanMap['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class NavidromeClient {
  NavidromeClient({
    required this.instance,
    required this.dio,
    this.cacheBuster = 0,
  });

  final Instance instance;
  final Dio dio;
  final int cacheBuster;

  // Shared with AuthInterceptor, which signs the health probe and the
  // connection test for this kind. Keeping one definition means the probe and
  // the service module cannot start claiming different protocol versions.
  static const String clientName = subsonicClientName;
  static const String apiVersion = subsonicApiVersion;

  Map<String, dynamic> _buildAuthParams([Map<String, dynamic>? extra]) {
    final Map<String, dynamic> params = <String, dynamic>{
      'v': apiVersion,
      'c': clientName,
      'f': 'json',
      if (extra != null) ...extra,
    };

    final InstanceAuth auth = instance.auth;
    if (auth is InstanceAuthUserPass) {
      if (auth.username.isNotEmpty) {
        params['u'] = auth.username;
        if (auth.password.isNotEmpty) {
          final String salt = _randomSalt();
          final String token =
              md5.convert(utf8.encode('${auth.password}$salt')).toString();
          params['t'] = token;
          params['s'] = salt;
        }
      }
    }

    return params;
  }

  /// [Random.secure] rather than [Random]: the salt travels in the clear next
  /// to the hash it salts, so a predictable one lets anyone who captures a
  /// single request precompute against it.
  static String _randomSalt([int length = 16]) {
    const String chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final Random rnd = Random.secure();
    return List<String>.generate(
      length,
      (_) => chars[rnd.nextInt(chars.length)],
    ).join();
  }

  /// Builds a deterministic cover art URL so image caches can key properly.
  String? getCoverArtUrl(String? coverArtId, {int? size}) {
    if (coverArtId == null || coverArtId.isEmpty) return null;
    final String rawBase = dio.options.baseUrl.isNotEmpty
        ? dio.options.baseUrl
        : (instance.localUrl.isNotEmpty
            ? instance.localUrl
            : instance.externalUrl);
    final String baseUrl = rawBase.trim();
    if (baseUrl.isEmpty) return null;
    final String cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    final Map<String, String> query = <String, String>{
      'id': coverArtId,
      'v': apiVersion,
      'c': clientName,
      'f': 'json',
    };
    if (size != null && size > 0) {
      query['size'] = size.toString();
    }
    if (cacheBuster > 0) {
      query['_b'] = cacheBuster.toString();
    }

    final InstanceAuth auth = instance.auth;
    if (auth is InstanceAuthUserPass && auth.username.isNotEmpty) {
      query['u'] = auth.username;
      if (auth.password.isNotEmpty) {
        final String stableSalt = md5
            .convert(utf8.encode('${instance.id}_salt'))
            .toString()
            .substring(0, 8);
        final String stableToken =
            md5.convert(utf8.encode('${auth.password}$stableSalt')).toString();
        query['t'] = stableToken;
        query['s'] = stableSalt;
      }
    }

    return Uri.parse('$cleanBase/rest/getCoverArt.view')
        .replace(queryParameters: query)
        .toString();
  }

  Future<NavidromeServerInfo> ping() async {
    final Response<dynamic> response = await dio.get<dynamic>(
      'rest/ping.view',
      queryParameters: _buildAuthParams(),
    );
    if (response.data is Map<String, dynamic>) {
      return NavidromeServerInfo.fromJson(
        response.data as Map<String, dynamic>,
      );
    }
    return const NavidromeServerInfo(
      status: 'ok',
      subsonicVersion: '1.16.1',
      serverVersion: '',
      type: 'navidrome',
    );
  }

  Future<NavidromeScanStatus> getScanStatus() async {
    final Response<dynamic> response = await dio.get<dynamic>(
      'rest/getScanStatus.view',
      queryParameters: _buildAuthParams(),
    );
    if (response.data is Map<String, dynamic>) {
      return NavidromeScanStatus.fromJson(
        response.data as Map<String, dynamic>,
      );
    }
    return const NavidromeScanStatus(scanning: false, count: 0);
  }

  Future<NavidromeScanStatus> startScan({bool fullScan = false}) async {
    final Response<dynamic> response = await dio.get<dynamic>(
      'rest/startScan.view',
      queryParameters: _buildAuthParams(<String, String>{
        'fullScan': fullScan ? 'true' : 'false',
      }),
    );
    if (response.data is Map<String, dynamic>) {
      return NavidromeScanStatus.fromJson(
        response.data as Map<String, dynamic>,
      );
    }
    return const NavidromeScanStatus(scanning: true, count: 0);
  }

  Future<void> setRating(String id, int rating) async {
    final int clamped = rating.clamp(0, 5);
    final Response<dynamic> response = await dio.get<dynamic>(
      'rest/setRating.view',
      queryParameters: _buildAuthParams(<String, String>{
        'id': id,
        'rating': clamped.toString(),
      }),
    );
    if (response.data is Map<String, dynamic>) {
      final Map<String, dynamic> data = response.data as Map<String, dynamic>;
      final dynamic resp = data['subsonic-response'] ?? data;
      if (resp is Map<String, dynamic> && resp['status'] == 'failed') {
        final dynamic err = resp['error'];
        final String msg = (err is Map<String, dynamic>)
            ? (err['message'] as String? ?? 'Failed to set rating')
            : 'Failed to set rating';
        throw Exception(msg);
      }
    }
  }

  Future<void> star({
    String? id,
    String? albumId,
    String? artistId,
  }) async {
    final Response<dynamic> response = await dio.get<dynamic>(
      'rest/star.view',
      queryParameters: _buildAuthParams(<String, String>{
        if (id != null) 'id': id,
        if (albumId != null) 'albumId': albumId,
        if (artistId != null) 'artistId': artistId,
      }),
    );
    if (response.data is Map<String, dynamic>) {
      final Map<String, dynamic> data = response.data as Map<String, dynamic>;
      final dynamic resp = data['subsonic-response'] ?? data;
      if (resp is Map<String, dynamic> && resp['status'] == 'failed') {
        final dynamic err = resp['error'];
        final String msg = (err is Map<String, dynamic>)
            ? (err['message'] as String? ?? 'Failed to favorite')
            : 'Failed to favorite';
        throw Exception(msg);
      }
    }
  }

  Future<void> unstar({
    String? id,
    String? albumId,
    String? artistId,
  }) async {
    final Response<dynamic> response = await dio.get<dynamic>(
      'rest/unstar.view',
      queryParameters: _buildAuthParams(<String, String>{
        if (id != null) 'id': id,
        if (albumId != null) 'albumId': albumId,
        if (artistId != null) 'artistId': artistId,
      }),
    );
    if (response.data is Map<String, dynamic>) {
      final Map<String, dynamic> data = response.data as Map<String, dynamic>;
      final dynamic resp = data['subsonic-response'] ?? data;
      if (resp is Map<String, dynamic> && resp['status'] == 'failed') {
        final dynamic err = resp['error'];
        final String msg = (err is Map<String, dynamic>)
            ? (err['message'] as String? ?? 'Failed to unfavorite')
            : 'Failed to unfavorite';
        throw Exception(msg);
      }
    }
  }

  Future<List<NavidromeArtistIndex>> getArtists() async {
    final Response<dynamic> response = await dio.get<dynamic>(
      'rest/getArtists.view',
      queryParameters: _buildAuthParams(),
    );
    if (response.data is! Map<String, dynamic>) {
      return const <NavidromeArtistIndex>[];
    }
    final Map<String, dynamic> data = response.data as Map<String, dynamic>;
    final dynamic resp = data['subsonic-response'] ?? data;
    if (resp is! Map<String, dynamic>) {
      return const <NavidromeArtistIndex>[];
    }
    final dynamic artists = resp['artists'];
    if (artists is! Map<String, dynamic>) {
      return const <NavidromeArtistIndex>[];
    }
    final dynamic index = artists['index'];
    if (index is List) {
      return index
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => NavidromeArtistIndex.fromJson(m.cast<String, dynamic>()))
          .toList();
    } else if (index is Map) {
      return <NavidromeArtistIndex>[
        NavidromeArtistIndex.fromJson(index.cast<String, dynamic>()),
      ];
    }
    return const <NavidromeArtistIndex>[];
  }

  Future<NavidromeArtistDetail> getArtist(String artistId) async {
    final Response<dynamic> response = await dio.get<dynamic>(
      'rest/getArtist.view',
      queryParameters: _buildAuthParams(<String, String>{'id': artistId}),
    );
    if (response.data is Map<String, dynamic>) {
      return NavidromeArtistDetail.fromJson(
        response.data as Map<String, dynamic>,
      );
    }
    return NavidromeArtistDetail(
      artist: NavidromeArtist(id: artistId, name: 'Unknown Artist'),
      albums: const <NavidromeAlbum>[],
    );
  }

  Future<NavidromeArtistInfo?> getArtistInfo(String artistId) async {
    try {
      final Response<dynamic> response = await dio.get<dynamic>(
        'rest/getArtistInfo2.view',
        queryParameters: _buildAuthParams(<String, String>{'id': artistId}),
      );
      if (response.data is! Map<String, dynamic>) return null;
      final Map<String, dynamic> data = response.data as Map<String, dynamic>;
      final dynamic resp = data['subsonic-response'] ?? data;
      if (resp is! Map<String, dynamic>) return null;
      final dynamic info = resp['artistInfo2'] ?? resp['artistInfo'];
      if (info is Map<String, dynamic>) {
        return NavidromeArtistInfo.fromJson(info);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<NavidromeAlbum>> getAlbumList({
    String type = 'recent',
    int size = 50,
    int offset = 0,
  }) async {
    if (type == 'starred') {
      return _getStarredAlbums(size: size, offset: offset);
    }

    final Response<dynamic> response = await dio.get<dynamic>(
      'rest/getAlbumList2.view',
      queryParameters: _buildAuthParams(<String, String>{
        'type': type,
        'size': size.toString(),
        'offset': offset.toString(),
      }),
    );
    if (response.data is! Map<String, dynamic>) {
      return const <NavidromeAlbum>[];
    }
    final Map<String, dynamic> data = response.data as Map<String, dynamic>;
    final dynamic resp = data['subsonic-response'] ?? data;
    if (resp is! Map<String, dynamic>) {
      return const <NavidromeAlbum>[];
    }
    final dynamic albumList = resp['albumList2'] ?? resp['albumList'];
    if (albumList is! Map<String, dynamic>) {
      return const <NavidromeAlbum>[];
    }
    final dynamic albums = albumList['album'];
    if (albums is List) {
      return albums
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => NavidromeAlbum.fromJson(m.cast<String, dynamic>()))
          .toList();
    } else if (albums is Map) {
      return <NavidromeAlbum>[
        NavidromeAlbum.fromJson(albums.cast<String, dynamic>()),
      ];
    }
    return const <NavidromeAlbum>[];
  }

  Future<List<NavidromeAlbum>> _getStarredAlbums({
    int size = 50,
    int offset = 0,
  }) async {
    final Map<String, NavidromeAlbum> resultMap = <String, NavidromeAlbum>{};

    // 1. Primary: getAlbumList2 with type: 'starred'
    try {
      final Response<dynamic> response = await dio.get<dynamic>(
        'rest/getAlbumList2.view',
        queryParameters: _buildAuthParams(<String, String>{
          'type': 'starred',
          'size': size.toString(),
          'offset': offset.toString(),
        }),
      );
      if (response.data is Map<String, dynamic>) {
        final Map<String, dynamic> data = response.data as Map<String, dynamic>;
        final dynamic resp = data['subsonic-response'] ?? data;
        if (resp is Map<String, dynamic>) {
          final dynamic albumList = resp['albumList2'] ?? resp['albumList'];
          if (albumList is Map<String, dynamic>) {
            final dynamic albums = albumList['album'];
            if (albums is List) {
              for (final dynamic item in albums) {
                if (item is Map<dynamic, dynamic>) {
                  final NavidromeAlbum a =
                      NavidromeAlbum.fromJson(item.cast<String, dynamic>());
                  if (a.id.isNotEmpty) resultMap[a.id] = a;
                }
              }
            } else if (albums is Map) {
              final NavidromeAlbum a =
                  NavidromeAlbum.fromJson(albums.cast<String, dynamic>());
              if (a.id.isNotEmpty) resultMap[a.id] = a;
            }
          }
        }
      }
    } catch (_) {}

    // 2. Query getStarred2.view to catch directly starred albums and albums of starred songs
    try {
      final Response<dynamic> response = await dio.get<dynamic>(
        'rest/getStarred2.view',
        queryParameters: _buildAuthParams(),
      );
      if (response.data is Map<String, dynamic>) {
        final Map<String, dynamic> data = response.data as Map<String, dynamic>;
        final dynamic resp = data['subsonic-response'] ?? data;
        if (resp is Map<String, dynamic>) {
          final dynamic starred2 = resp['starred2'] ?? resp['starred'];
          if (starred2 is Map<String, dynamic>) {
            // Directly starred albums
            final dynamic albums = starred2['album'];
            if (albums is List) {
              for (final dynamic item in albums) {
                if (item is Map<dynamic, dynamic>) {
                  final NavidromeAlbum a =
                      NavidromeAlbum.fromJson(item.cast<String, dynamic>());
                  if (a.id.isNotEmpty) resultMap[a.id] = a;
                }
              }
            } else if (albums is Map) {
              final NavidromeAlbum a =
                  NavidromeAlbum.fromJson(albums.cast<String, dynamic>());
              if (a.id.isNotEmpty) resultMap[a.id] = a;
            }

            // Albums from starred songs
            final dynamic songs = starred2['song'];
            if (songs is List) {
              for (final dynamic item in songs) {
                if (item is Map<dynamic, dynamic>) {
                  final String? albumId =
                      (item['albumId'] ?? item['parent']) as String?;
                  if (albumId != null &&
                      albumId.isNotEmpty &&
                      !resultMap.containsKey(albumId)) {
                    resultMap[albumId] = NavidromeAlbum(
                      id: albumId,
                      name: (item['album'] as String?) ?? 'Unknown Album',
                      artist: (item['artist'] as String?) ?? 'Unknown Artist',
                      artistId: item['artistId'] as String?,
                      coverArt: (item['coverArt'] as String?) ?? albumId,
                      year: (item['year'] as num?)?.toInt(),
                      genre: item['genre'] as String?,
                      starred: 'true',
                    );
                  }
                }
              }
            }
          }
        }
      }
    } catch (_) {}

    return resultMap.values.toList();
  }

  Future<NavidromeAlbumDetail> getAlbum(String albumId) async {
    final Response<dynamic> response = await dio.get<dynamic>(
      'rest/getAlbum.view',
      queryParameters: _buildAuthParams(<String, String>{'id': albumId}),
    );
    if (response.data is Map<String, dynamic>) {
      return NavidromeAlbumDetail.fromJson(
        response.data as Map<String, dynamic>,
      );
    }
    return NavidromeAlbumDetail(
      album: NavidromeAlbum(id: albumId, name: 'Unknown Album'),
      songs: const <NavidromeSong>[],
    );
  }

  Future<List<NavidromePlaylist>> getPlaylists() async {
    final Response<dynamic> response = await dio.get<dynamic>(
      'rest/getPlaylists.view',
      queryParameters: _buildAuthParams(),
    );
    if (response.data is! Map<String, dynamic>) {
      return const <NavidromePlaylist>[];
    }
    final Map<String, dynamic> data = response.data as Map<String, dynamic>;
    final dynamic resp = data['subsonic-response'] ?? data;
    if (resp is! Map<String, dynamic>) {
      return const <NavidromePlaylist>[];
    }
    final dynamic playlists = resp['playlists'];
    if (playlists is! Map<String, dynamic>) {
      return const <NavidromePlaylist>[];
    }
    final dynamic playlist = playlists['playlist'];
    if (playlist is List) {
      return playlist
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => NavidromePlaylist.fromJson(m.cast<String, dynamic>()))
          .toList();
    } else if (playlist is Map) {
      return <NavidromePlaylist>[
        NavidromePlaylist.fromJson(playlist.cast<String, dynamic>()),
      ];
    }
    return const <NavidromePlaylist>[];
  }

  Future<NavidromePlaylistDetail> getPlaylist(String playlistId) async {
    final Response<dynamic> response = await dio.get<dynamic>(
      'rest/getPlaylist.view',
      queryParameters: _buildAuthParams(<String, String>{'id': playlistId}),
    );
    if (response.data is Map<String, dynamic>) {
      return NavidromePlaylistDetail.fromJson(
        response.data as Map<String, dynamic>,
      );
    }
    return NavidromePlaylistDetail(
      playlist: NavidromePlaylist(id: playlistId, name: 'Untitled Playlist'),
      songs: const <NavidromeSong>[],
    );
  }

  Future<NavidromePlaylist> createPlaylist({
    required String name,
    List<String>? songIds,
  }) async {
    final Map<String, dynamic> extra = <String, dynamic>{
      'name': name,
    };
    if (songIds != null && songIds.isNotEmpty) {
      extra['songId'] = songIds;
    }
    final Response<dynamic> response = await dio.get<dynamic>(
      'rest/createPlaylist.view',
      queryParameters: _buildAuthParams(extra),
      options: Options(listFormat: ListFormat.multi),
    );
    if (response.data is Map<String, dynamic>) {
      final Map<String, dynamic> data = response.data as Map<String, dynamic>;
      final dynamic resp = data['subsonic-response'];
      if (resp is Map<String, dynamic>) {
        if (resp['status'] == 'failed') {
          final dynamic err = resp['error'];
          final String msg =
              err is Map ? err['message']?.toString() ?? 'Error' : 'Error';
          throw Exception(msg);
        }
        final dynamic pl = resp['playlist'];
        if (pl is Map<String, dynamic>) {
          return NavidromePlaylist.fromJson(pl.cast<String, dynamic>());
        }
      }
    }
    return NavidromePlaylist(id: '', name: name);
  }

  Future<void> updatePlaylist({
    required String playlistId,
    String? name,
    String? comment,
    bool? public,
    List<String>? songIdsToAdd,
    List<int>? songIndexesToRemove,
  }) async {
    final Map<String, dynamic> extra = <String, dynamic>{
      'playlistId': playlistId,
    };
    if (name != null && name.isNotEmpty) {
      extra['name'] = name;
    }
    if (comment != null) {
      extra['comment'] = comment;
    }
    if (public != null) {
      extra['public'] = public.toString();
    }
    if (songIdsToAdd != null && songIdsToAdd.isNotEmpty) {
      extra['songIdToAdd'] = songIdsToAdd;
    }
    if (songIndexesToRemove != null && songIndexesToRemove.isNotEmpty) {
      extra['songIndexToRemove'] =
          songIndexesToRemove.map((int i) => i.toString()).toList();
    }
    final Response<dynamic> response = await dio.get<dynamic>(
      'rest/updatePlaylist.view',
      queryParameters: _buildAuthParams(extra),
      options: Options(listFormat: ListFormat.multi),
    );
    if (response.data is Map<String, dynamic>) {
      final Map<String, dynamic> data = response.data as Map<String, dynamic>;
      final dynamic resp = data['subsonic-response'];
      if (resp is Map<String, dynamic> && resp['status'] == 'failed') {
        final dynamic err = resp['error'];
        final String msg =
            err is Map ? err['message']?.toString() ?? 'Error' : 'Error';
        throw Exception(msg);
      }
    }
  }

  Future<void> deletePlaylist(String playlistId) async {
    final Response<dynamic> response = await dio.get<dynamic>(
      'rest/deletePlaylist.view',
      queryParameters: _buildAuthParams(<String, dynamic>{'id': playlistId}),
    );
    if (response.data is Map<String, dynamic>) {
      final Map<String, dynamic> data = response.data as Map<String, dynamic>;
      final dynamic resp = data['subsonic-response'];
      if (resp is Map<String, dynamic> && resp['status'] == 'failed') {
        final dynamic err = resp['error'];
        final String msg =
            err is Map ? err['message']?.toString() ?? 'Error' : 'Error';
        throw Exception(msg);
      }
    }
  }

  Future<NavidromeSearchResult> search(String query) async {
    if (query.trim().isEmpty) {
      return const NavidromeSearchResult();
    }
    final Response<dynamic> response = await dio.get<dynamic>(
      'rest/search3.view',
      queryParameters: _buildAuthParams(<String, String>{
        'query': query,
        'artistCount': '20',
        'albumCount': '20',
        'songCount': '50',
      }),
    );
    if (response.data is Map<String, dynamic>) {
      return NavidromeSearchResult.fromJson(
        response.data as Map<String, dynamic>,
      );
    }
    return const NavidromeSearchResult();
  }

  List<NavidromeSong> _parseSongs(dynamic songData) {
    if (songData is List) {
      return songData
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => NavidromeSong.fromJson(m.cast<String, dynamic>()))
          .toList();
    } else if (songData is Map) {
      return <NavidromeSong>[
        NavidromeSong.fromJson(songData.cast<String, dynamic>()),
      ];
    }
    return const <NavidromeSong>[];
  }

  /// Gets top songs for an artist using external metadata agent (Last.fm/Deezer/ListenBrainz/Local).
  Future<List<NavidromeSong>> getTopSongs({
    String? artist,
    String? artistId,
    int count = 50,
  }) async {
    final Map<String, dynamic> extra = <String, dynamic>{
      'count': count.toString(),
    };
    if (artist != null && artist.trim().isNotEmpty) {
      extra['artist'] = artist.trim();
    }
    if (artistId != null && artistId.trim().isNotEmpty) {
      extra['id'] = artistId.trim();
    }
    final Response<dynamic> response = await dio.get<dynamic>(
      'rest/getTopSongs.view',
      queryParameters: _buildAuthParams(extra),
    );
    if (response.data is! Map<String, dynamic>) {
      return const <NavidromeSong>[];
    }
    final Map<String, dynamic> data = response.data as Map<String, dynamic>;
    final dynamic resp = data['subsonic-response'] ?? data;
    if (resp is! Map<String, dynamic>) {
      return const <NavidromeSong>[];
    }
    final dynamic topSongs = resp['topSongs'];
    if (topSongs is! Map<String, dynamic>) {
      return const <NavidromeSong>[];
    }
    return _parseSongs(topSongs['song']);
  }

  /// Gets similar songs for a track using external metadata agent.
  Future<List<NavidromeSong>> getSimilarSongs({
    required String songId,
    int count = 50,
  }) async {
    final Response<dynamic> response = await dio.get<dynamic>(
      'rest/getSimilarSongs.view',
      queryParameters: _buildAuthParams(<String, dynamic>{
        'id': songId,
        'count': count.toString(),
      }),
    );
    if (response.data is! Map<String, dynamic>) {
      return const <NavidromeSong>[];
    }
    final Map<String, dynamic> data = response.data as Map<String, dynamic>;
    final dynamic resp = data['subsonic-response'] ?? data;
    if (resp is! Map<String, dynamic>) {
      return const <NavidromeSong>[];
    }
    final dynamic similarSongs = resp['similarSongs'];
    if (similarSongs is! Map<String, dynamic>) {
      return const <NavidromeSong>[];
    }
    return _parseSongs(similarSongs['song']);
  }

  /// Gets similar songs with full track metadata (Subsonic 1.11.0+), falling back to getSimilarSongs.
  Future<List<NavidromeSong>> getSimilarSongs2({
    required String songId,
    int count = 50,
  }) async {
    try {
      final Response<dynamic> response = await dio.get<dynamic>(
        'rest/getSimilarSongs2.view',
        queryParameters: _buildAuthParams(<String, dynamic>{
          'id': songId,
          'count': count.toString(),
        }),
      );
      if (response.data is Map<String, dynamic>) {
        final Map<String, dynamic> data = response.data as Map<String, dynamic>;
        final dynamic resp = data['subsonic-response'] ?? data;
        if (resp is Map<String, dynamic>) {
          final dynamic similarSongs2 = resp['similarSongs2'];
          if (similarSongs2 is Map<String, dynamic>) {
            return _parseSongs(similarSongs2['song']);
          }
        }
      }
    } catch (_) {
      // Fallback
    }
    return getSimilarSongs(songId: songId, count: count);
  }

  /// Gets currently playing or recently played tracks across the server.
  Future<List<NavidromeSong>> getNowPlaying() async {
    final Response<dynamic> response = await dio.get<dynamic>(
      'rest/getNowPlaying.view',
      queryParameters: _buildAuthParams(),
    );
    if (response.data is! Map<String, dynamic>) {
      return const <NavidromeSong>[];
    }
    final Map<String, dynamic> data = response.data as Map<String, dynamic>;
    final dynamic resp = data['subsonic-response'] ?? data;
    if (resp is! Map<String, dynamic>) {
      return const <NavidromeSong>[];
    }
    final dynamic nowPlaying = resp['nowPlaying'];
    if (nowPlaying is! Map<String, dynamic>) {
      return const <NavidromeSong>[];
    }
    return _parseSongs(nowPlaying['entry']);
  }
}

