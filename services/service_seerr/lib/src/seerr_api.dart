import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';

import 'models/seerr_counts.dart';
import 'models/seerr_discover.dart';
import 'models/seerr_request.dart';
import 'models/seerr_service.dart';

/// Thin client over the Seerr / Jellyseerr API.
///
/// Auth is an `X-Api-Key` header (added by `core_networking`'s
/// [AuthInterceptor]), so this rides the shared `instanceDioProvider` Dio.
class SeerrApi {
  SeerrApi(this._dio);

  final Dio _dio;

  static const String _base = 'api/v1';

  Future<List<SeerrRequest>> getRequests({
    int take = 30,
    int skip = 0,
    String sort = 'added',
    String? filter,
  }) async {
    try {
      final Map<String, dynamic> query = <String, dynamic>{
        'take': take,
        'skip': skip,
        'sort': sort,
      };
      if (filter != null) query['filter'] = filter;
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/request',
        queryParameters: query,
      );
      return SeerrRequestPage.fromJson(resp.data as Map<String, dynamic>)
          .results;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<SeerrCounts> getRequestCounts() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/request/count');
      return SeerrCounts.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<SeerrRequest> createRequest({
    required String mediaType,
    required int mediaId,
    bool is4k = false,
    int? serverId,
    int? profileId,
    String? rootFolder,
  }) async {
    try {
      final Map<String, dynamic> data = <String, dynamic>{
        'mediaType': mediaType,
        'mediaId': mediaId,
        'is4k': is4k,
        if (serverId != null) 'serverId': serverId,
        if (profileId != null) 'profileId': profileId,
        if (rootFolder != null && rootFolder.isNotEmpty) 'rootFolder': rootFolder,
      };
      if (mediaType.toLowerCase() == 'tv') {
        data['seasons'] = 'all';
      }
      final Response<dynamic> resp = await _dio.post<dynamic>(
        '$_base/request',
        data: data,
      );
      return SeerrRequest.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Radarr (movie) or Sonarr (tv) servers configured in Seerr. Used to offer
  /// quality-profile / root-folder choices when requesting.
  Future<List<SeerrServer>> getServers(String mediaType) async {
    final String svc = mediaType.toLowerCase() == 'tv' ? 'sonarr' : 'radarr';
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/service/$svc');
      final List<dynamic> list = (resp.data as List<dynamic>?) ?? <dynamic>[];
      return list
          .map((dynamic e) => SeerrServer.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Quality profiles + root folders for one [serverId].
  Future<SeerrServerDetails> getServerDetails(
    String mediaType,
    int serverId,
  ) async {
    final String svc = mediaType.toLowerCase() == 'tv' ? 'sonarr' : 'radarr';
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/service/$svc/$serverId');
      return SeerrServerDetails.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> deleteRequest(int requestId) async {
    try {
      await _dio.delete<dynamic>('$_base/request/$requestId');
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> retryRequest(int requestId) =>
      _post('$_base/request/$requestId/retry');

  Future<void> approve(int requestId) =>
      _post('$_base/request/$requestId/approve');

  Future<void> decline(int requestId) =>
      _post('$_base/request/$requestId/decline');

  Future<void> _post(String path) async {
    try {
      await _dio.post<dynamic>(path);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  // --- Seerr / Discover Endpoints ---

  Future<SeerrDiscoverResult> getMediaDetails(String mediaType, int tmdbId) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/$mediaType/$tmdbId');
      final Map<String, dynamic> data = resp.data as Map<String, dynamic>;
      // The endpoints return full details but include mediaInfo. mediaType is not always set by default.
      data['mediaType'] ??= mediaType;
      return SeerrDiscoverResult.fromJson(data);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<SeerrDiscoverResult>> search(String query) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/search?query=${Uri.encodeComponent(query)}',
      );
      return SeerrDiscoverPage.fromJson(resp.data as Map<String, dynamic>).results;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<SeerrDiscoverResult>> discoverMovies() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/discover/movies');
      return SeerrDiscoverPage.fromJson(resp.data as Map<String, dynamic>).results;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<SeerrGenre>> getMovieGenres() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/genres/movie');
      final List<dynamic> list = resp.data as List<dynamic>;
      return list.map((dynamic e) => SeerrGenre.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<SeerrDiscoverResult>> getMoviesByGenre(int genreId) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/discover/movies/genre/$genreId');
      return SeerrDiscoverPage.fromJson(resp.data as Map<String, dynamic>).results;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<SeerrDiscoverResult>> getUpcomingMovies() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/discover/movies/upcoming');
      return SeerrDiscoverPage.fromJson(resp.data as Map<String, dynamic>).results;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<SeerrDiscoverResult>> discoverTvShows() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/discover/tv');
      return SeerrDiscoverPage.fromJson(resp.data as Map<String, dynamic>).results;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<SeerrGenre>> getTvGenres() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/genres/tv');
      final List<dynamic> list = resp.data as List<dynamic>;
      return list.map((dynamic e) => SeerrGenre.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<SeerrDiscoverResult>> getTvShowsByGenre(int genreId) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/discover/tv/genre/$genreId');
      return SeerrDiscoverPage.fromJson(resp.data as Map<String, dynamic>).results;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<SeerrDiscoverResult>> getUpcomingTvShows() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/discover/tv/upcoming');
      return SeerrDiscoverPage.fromJson(resp.data as Map<String, dynamic>).results;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<SeerrDiscoverResult>> getTrending() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/discover/trending');
      return SeerrDiscoverPage.fromJson(resp.data as Map<String, dynamic>).results;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }
}
