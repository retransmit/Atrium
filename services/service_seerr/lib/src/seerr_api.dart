import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';

import 'models/seerr_counts.dart';
import 'models/seerr_discover.dart';
import 'models/seerr_issue.dart';
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

  /// All requests, paged in until a short page is returned (the `/request`
  /// endpoint caps each page, so a single call would only ever return one
  /// page). A safety cap stops runaway paging on very large libraries.
  Future<List<SeerrRequest>> getAllRequests({
    String sort = 'added',
    String? filter,
  }) async {
    const int pageSize = 100;
    const int maxItems = 2000;
    final List<SeerrRequest> all = <SeerrRequest>[];
    int skip = 0;
    while (true) {
      final List<SeerrRequest> page = await getRequests(
        take: pageSize,
        skip: skip,
        sort: sort,
        filter: filter,
      );
      all.addAll(page);
      if (page.length < pageSize || all.length >= maxItems) {
        break;
      }
      skip += pageSize;
    }
    return all;
  }

  Future<SeerrCounts> getRequestCounts() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/request/count');
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
        if (rootFolder != null && rootFolder.isNotEmpty)
          'rootFolder': rootFolder,
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

  // --- Issues ---

  Future<List<SeerrIssue>> getIssues({
    int take = 100,
    int skip = 0,
    String filter = 'all',
  }) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/issue',
        queryParameters: <String, dynamic>{
          'take': take,
          'skip': skip,
          'sort': 'added',
          'filter': filter,
        },
      );
      return SeerrIssuePage.fromJson(resp.data as Map<String, dynamic>).results;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<SeerrIssue> getIssue(int id) async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/issue/$id');
      return SeerrIssue.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// [mediaId] is the internal Seerr media DB id ([SeerrMedia.id]), not the
  /// TMDB id.
  Future<SeerrIssue> createIssue({
    required int issueType,
    required String message,
    required int mediaId,
  }) async {
    try {
      final Response<dynamic> resp = await _dio.post<dynamic>(
        '$_base/issue',
        data: <String, dynamic>{
          'issueType': issueType,
          'message': message,
          'mediaId': mediaId,
        },
      );
      return SeerrIssue.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> addIssueComment(int issueId, String message) async {
    try {
      await _dio.post<dynamic>(
        '$_base/issue/$issueId/comment',
        data: <String, dynamic>{'message': message},
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> setIssueStatus(int issueId, {required bool resolved}) =>
      _post('$_base/issue/$issueId/${resolved ? 'resolved' : 'open'}');

  // --- Seerr / Discover Endpoints ---

  Future<SeerrDiscoverResult> getMediaDetails(
    String mediaType,
    int tmdbId,
  ) async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/$mediaType/$tmdbId');
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
      return SeerrDiscoverPage.fromJson(resp.data as Map<String, dynamic>)
          .results;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<SeerrDiscoverResult>> discoverMovies() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/discover/movies');
      return SeerrDiscoverPage.fromJson(resp.data as Map<String, dynamic>)
          .results;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<SeerrGenre>> getMovieGenres() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/genres/movie');
      final List<dynamic> list = resp.data as List<dynamic>;
      return list
          .map((dynamic e) => SeerrGenre.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<SeerrDiscoverResult>> getMoviesByGenre(int genreId) async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/discover/movies/genre/$genreId');
      return SeerrDiscoverPage.fromJson(resp.data as Map<String, dynamic>)
          .results;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<SeerrDiscoverResult>> getUpcomingMovies() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/discover/movies/upcoming');
      return SeerrDiscoverPage.fromJson(resp.data as Map<String, dynamic>)
          .results;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<SeerrDiscoverResult>> discoverTvShows() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/discover/tv');
      return SeerrDiscoverPage.fromJson(resp.data as Map<String, dynamic>)
          .results;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<SeerrGenre>> getTvGenres() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/genres/tv');
      final List<dynamic> list = resp.data as List<dynamic>;
      return list
          .map((dynamic e) => SeerrGenre.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<SeerrDiscoverResult>> getTvShowsByGenre(int genreId) async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/discover/tv/genre/$genreId');
      return SeerrDiscoverPage.fromJson(resp.data as Map<String, dynamic>)
          .results;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<SeerrDiscoverResult>> getUpcomingTvShows() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/discover/tv/upcoming');
      return SeerrDiscoverPage.fromJson(resp.data as Map<String, dynamic>)
          .results;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<SeerrDiscoverResult>> getTrending() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/discover/trending');
      return SeerrDiscoverPage.fromJson(resp.data as Map<String, dynamic>)
          .results;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<SeerrDiscoverResult>> getRecommendations(
    String mediaType,
    int tmdbId,
  ) async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/$mediaType/$tmdbId/recommendations');
      return SeerrDiscoverPage.fromJson(resp.data as Map<String, dynamic>)
          .results;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<SeerrDiscoverResult>> getSimilar(
    String mediaType,
    int tmdbId,
  ) async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/$mediaType/$tmdbId/similar');
      return SeerrDiscoverPage.fromJson(resp.data as Map<String, dynamic>)
          .results;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// The signed-in user's watchlist.
  ///
  /// Watchlist entries can come back in a Plex-flavoured shape carrying a
  /// `tmdbId` but no TMDB `id`, so entries are normalised before parsing and
  /// anything with no usable id is dropped instead of failing the whole page.
  Future<List<SeerrDiscoverResult>> getWatchlist() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/discover/watchlist');
      final Map<String, dynamic> data = resp.data as Map<String, dynamic>;
      final List<dynamic> raw =
          (data['results'] as List<dynamic>?) ?? <dynamic>[];
      final List<Map<String, dynamic>> results = <Map<String, dynamic>>[];
      for (final dynamic e in raw) {
        if (e is! Map<String, dynamic>) continue;
        e['id'] ??= e['tmdbId'];
        if (e['id'] != null) results.add(e);
      }
      data['results'] = results;
      return SeerrDiscoverPage.fromJson(data).results;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }
}
