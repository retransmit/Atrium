import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';

import 'models/plex_models.dart';

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
          await _dio.get<dynamic>('/library/sections');
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
          await _dio.get<dynamic>('/library/sections/$sectionKey/all');
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
          await _dio.get<dynamic>('/library/metadata/$ratingKey/children');
      return PlexItemsResponse.fromJson(resp.data as Map<String, dynamic>)
              .mediaContainer
              ?.metadata ??
          <PlexMetadata>[];
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Resolves the streamable part key for a playable [item].
  ///
  /// Library listings usually inline `Media`/`Part` for movies, but not always
  /// for episodes - so if the listed item has no part we fetch its full
  /// metadata. Returns null if the item has no playable file.
  Future<String?> resolvePartKey(PlexMetadata item) async {
    final String? inline = _firstPartKey(item);
    if (inline != null) {
      return inline;
    }
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('/library/metadata/${item.ratingKey}');
      final List<PlexMetadata> detail =
          PlexItemsResponse.fromJson(resp.data as Map<String, dynamic>)
                  .mediaContainer
                  ?.metadata ??
              <PlexMetadata>[];
      return detail.isEmpty ? null : _firstPartKey(detail.first);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  String? _firstPartKey(PlexMetadata item) {
    for (final PlexMedia m in item.media) {
      for (final PlexPart p in m.parts) {
        if (p.key != null && p.key!.isNotEmpty) {
          return p.key;
        }
      }
    }
    return null;
  }

  /// Absolute direct-play URL for a part key. media_kit fetches the bytes
  /// directly, so the token rides in the query string.
  String streamUrl(String partKey) {
    final String base = _dio.options.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final String sep = partKey.contains('?') ? '&' : '?';
    return '$base$partKey${sep}X-Plex-Token=$token';
  }

  /// Best-effort playback timeline report. Plex uses milliseconds.
  Future<void> reportTimeline(
    String ratingKey, {
    required String state, // 'playing' | 'paused' | 'stopped'
    required int timeMs,
    int? durationMs,
  }) async {
    try {
      await _dio.get<dynamic>(
        '/:/timeline',
        queryParameters: <String, dynamic>{
          'ratingKey': ratingKey,
          'key': '/library/metadata/$ratingKey',
          'state': state,
          'time': timeMs,
          if (durationMs != null) 'duration': durationMs,
          'X-Plex-Token': token,
        },
      );
    } on DioException {
      // Best-effort; ignore.
    }
  }

  /// Builds an absolute poster URL from a relative [thumb] path. Returns null
  /// when the item has no thumbnail. The Dio base URL is the already-resolved
  /// LAN/WAN address.
  String? imageUrl(String? thumb) {
    if (thumb == null || thumb.isEmpty) {
      return null;
    }
    final String base =
        _dio.options.baseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base$thumb?X-Plex-Token=$token';
  }
}
