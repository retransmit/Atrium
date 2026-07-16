import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';

import 'models/plex_models.dart';
import 'models/plex_session.dart';

/// Query params that route a player command through the server to a client
/// via Plex Companion. Pure so it can be unit-tested without a live server.
Map<String, dynamic> plexCommandParams({
  required String machineIdentifier,
  required String clientIdentifier,
  required int commandId,
  int? offsetMs,
}) {
  return <String, dynamic>{
    'X-Plex-Target-Client-Identifier': machineIdentifier,
    'X-Plex-Client-Identifier': clientIdentifier,
    'commandID': commandId,
    if (offsetMs != null) 'offset': offsetMs,
  };
}

/// Thin client over the Plex Media Server API.
///
/// Plex uses a static `X-Plex-Token`, attached (with `Accept: application/json`)
/// by `core_networking`'s [AuthInterceptor], so unlike Jellyfin/Emby this can
/// ride the shared `instanceDioProvider` Dio. The token is also needed to
/// build poster URLs, so we pass it in separately.
class PlexApi {
  PlexApi(this._dio, {required this.token});

  final Dio _dio;
  final String token;

  Future<List<PlexLibrary>> getLibraries() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('library/sections');
      return PlexLibrariesResponse.fromJson(resp.data as Map<String, dynamic>)
              .mediaContainer
              ?.directory ??
          <PlexLibrary>[];
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<PlexMetadata>> getItems(String sectionKey) async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('library/sections/$sectionKey/all');
      return PlexItemsResponse.fromJson(resp.data as Map<String, dynamic>)
              .mediaContainer
              ?.metadata ??
          <PlexMetadata>[];
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Children of a show (its seasons) or a season (its episodes).
  Future<List<PlexMetadata>> getChildren(String ratingKey) async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('library/metadata/$ratingKey/children');
      return PlexItemsResponse.fromJson(resp.data as Map<String, dynamic>)
              .mediaContainer
              ?.metadata ??
          <PlexMetadata>[];
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Full metadata for one item (the detail screen): summary, cast, genres,
  /// ratings. Returns null when the server has no such item.
  Future<PlexMetadata?> getMetadata(String ratingKey) async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('library/metadata/$ratingKey');
      final List<PlexMetadata> items =
          PlexItemsResponse.fromJson(resp.data as Map<String, dynamic>)
                  .mediaContainer
                  ?.metadata ??
              <PlexMetadata>[];
      return items.isEmpty ? null : items.first;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// "Continue Watching" - in-progress items plus the next unwatched episode
  /// of shows being watched, across all libraries.
  Future<List<PlexMetadata>> getOnDeck() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('library/onDeck');
      return PlexItemsResponse.fromJson(resp.data as Map<String, dynamic>)
              .mediaContainer
              ?.metadata ??
          <PlexMetadata>[];
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Recently added items across all libraries.
  Future<List<PlexMetadata>> getRecentlyAdded() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('library/recentlyAdded');
      return PlexItemsResponse.fromJson(resp.data as Map<String, dynamic>)
              .mediaContainer
              ?.metadata ??
          <PlexMetadata>[];
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Global search across libraries. Returns a flat, mixed-type list.
  Future<List<PlexMetadata>> search(String query) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        'search',
        queryParameters: <String, dynamic>{'query': query},
      );
      return PlexItemsResponse.fromJson(resp.data as Map<String, dynamic>)
              .mediaContainer
              ?.metadata ??
          <PlexMetadata>[];
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Marks an item watched ([watched] true) or unwatched (false) via Plex's
  /// scrobble endpoints. Built as an absolute URL so the leading `/:/` segment
  /// is not mangled by relative-path resolution.
  Future<void> setWatched(String ratingKey, {required bool watched}) async {
    final String base = _dio.options.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final String action = watched ? 'scrobble' : 'unscrobble';
    try {
      await _dio.get<dynamic>(
        '$base/:/$action',
        queryParameters: <String, dynamic>{
          'key': ratingKey,
          'identifier': 'com.plexapp.plugins.library',
        },
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Builds an absolute poster URL from a relative [thumb] path. Returns null
  /// when the item has no thumbnail. The Dio base URL is the already-resolved
  /// LAN/WAN address.
  String? imageUrl(String? thumb) {
    if (thumb == null || thumb.isEmpty) {
      return null;
    }
    final String base = _dio.options.baseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base$thumb?X-Plex-Token=$token';
  }

  /// Stable-ish client id for Companion command routing + a per-client
  /// monotonically increasing command id (Plex requires increasing ids).
  static const String _clientIdentifier = 'atrium-plex-controller';
  int _commandId = 0;

  /// Active playback sessions (`GET /status/sessions`). No Plex Pass needed.
  Future<List<PlexSession>> getSessions() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('status/sessions');
      return PlexSessionsResponse.fromJson(resp.data as Map<String, dynamic>)
              .mediaContainer
              ?.metadata ??
          <PlexSession>[];
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Sends a transport command to a controllable client. Commands:
  /// playPause, stop, skipNext, skipPrevious, seekTo (offsetMs required).
  /// Throws NetworkException on failure (no Plex Pass / client gone / not
  /// controllable) so the UI can degrade gracefully.
  Future<void> sendPlayerCommand(
    String command, {
    required String machineIdentifier,
    int? offsetMs,
  }) async {
    _commandId += 1;
    try {
      await _dio.get<dynamic>(
        'player/playback/$command',
        queryParameters: plexCommandParams(
          machineIdentifier: machineIdentifier,
          clientIdentifier: _clientIdentifier,
          commandId: _commandId,
          offsetMs: offsetMs,
        ),
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Ends someone's stream. Requires Plex Pass server-side; a 403 surfaces as
  /// a NetworkException the UI turns into a "needs Plex Pass" message.
  Future<void> terminateSession(
    String sessionId, {
    String reason = 'Stopped from Atrium',
  }) async {
    try {
      await _dio.get<dynamic>(
        'status/sessions/terminate',
        queryParameters: <String, dynamic>{
          'sessionId': sessionId,
          'reason': reason,
        },
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Genre directories for a library section
  /// (`GET /library/sections/{key}/genre`).
  Future<List<PlexGenreDir>> getGenres(String sectionKey) async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('library/sections/$sectionKey/genre');
      return PlexLibrariesResponse.fromJson(resp.data as Map<String, dynamic>)
              .mediaContainer
              ?.directory
              .map((PlexLibrary d) => PlexGenreDir(key: d.key, title: d.title))
              .toList() ??
          <PlexGenreDir>[];
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Items in a section filtered by a genre key
  /// (`GET /library/sections/{key}/all?genre={id}`).
  Future<List<PlexMetadata>> getItemsByGenre(
    String sectionKey,
    String genreKey,
  ) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        'library/sections/$sectionKey/all',
        queryParameters: <String, dynamic>{'genre': genreKey},
      );
      return PlexItemsResponse.fromJson(resp.data as Map<String, dynamic>)
              .mediaContainer
              ?.metadata ??
          <PlexMetadata>[];
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }
}
