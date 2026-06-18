import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';

import 'models/bazarr_models.dart';

/// Thin client over the Bazarr API.
///
/// Auth is an API-key header (added by `core_networking`'s [AuthInterceptor]),
/// so this rides the shared `instanceDioProvider` Dio.
class BazarrApi {
  BazarrApi(this._dio);

  final Dio _dio;

  Future<BazarrBadges> getBadges() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('api/badges');
      return BazarrBadges.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<BazarrWantedEpisode>> getWantedEpisodes() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        'api/episodes/wanted',
        queryParameters: <String, dynamic>{'start': 0, 'length': -1},
      );
      return BazarrWantedEpisodes.fromJson(resp.data as Map<String, dynamic>)
          .data;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<BazarrWantedMovie>> getWantedMovies() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        'api/movies/wanted',
        queryParameters: <String, dynamic>{'start': 0, 'length': -1},
      );
      return BazarrWantedMovies.fromJson(resp.data as Map<String, dynamic>).data;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// All series (Sonarr-backed) with subtitle status. `length=-1` returns the
  /// whole list; Bazarr's series rows are lightweight (no episodes).
  Future<List<BazarrSeries>> getSeries() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        'api/series',
        queryParameters: <String, dynamic>{'start': 0, 'length': -1},
      );
      final List<dynamic> data =
          (resp.data as Map<String, dynamic>)['data'] as List<dynamic>;
      return data
          .map((dynamic e) => BazarrSeries.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// All movies (Radarr-backed) with their present/missing subtitle lists.
  Future<List<BazarrMovie>> getMovies() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        'api/movies',
        queryParameters: <String, dynamic>{'start': 0, 'length': -1},
      );
      final List<dynamic> data =
          (resp.data as Map<String, dynamic>)['data'] as List<dynamic>;
      return data
          .map((dynamic e) => BazarrMovie.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Episodes for one series (`seriesid[]=`), each with subtitle status.
  Future<List<BazarrEpisode>> getEpisodes(int seriesId) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        'api/episodes',
        queryParameters: <String, dynamic>{'seriesid[]': seriesId},
      );
      final List<dynamic> data =
          (resp.data as Map<String, dynamic>)['data'] as List<dynamic>;
      return data
          .map((dynamic e) => BazarrEpisode.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Manual subtitle search for one episode (`GET /providers/episodes`). Hits
  /// live providers, so it gets a long receive timeout.
  Future<List<BazarrSubtitleSearchResult>> searchEpisodeSubtitles(
    int episodeId,
  ) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        'api/providers/episodes',
        queryParameters: <String, dynamic>{'episodeid': episodeId},
        options: Options(receiveTimeout: const Duration(seconds: 120)),
      );
      return _parseResults(resp.data);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Manual subtitle search for one movie (`GET /providers/movies`).
  Future<List<BazarrSubtitleSearchResult>> searchMovieSubtitles(
    int radarrId,
  ) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        'api/providers/movies',
        queryParameters: <String, dynamic>{'radarrid': radarrId},
        options: Options(receiveTimeout: const Duration(seconds: 120)),
      );
      return _parseResults(resp.data);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  List<BazarrSubtitleSearchResult> _parseResults(dynamic data) {
    final List<dynamic> list = data is Map<String, dynamic>
        ? ((data['data'] as List<dynamic>?) ?? const <dynamic>[])
        : (data as List<dynamic>);
    return list
        .map(
          (dynamic e) =>
              BazarrSubtitleSearchResult.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  /// Downloads a chosen manual-search result for an episode
  /// (`POST /providers/episodes`). Round-trips the result's provider/token/flags.
  Future<void> downloadEpisodeSubtitle({
    required int seriesId,
    required int episodeId,
    required BazarrSubtitleSearchResult result,
  }) async {
    try {
      await _dio.post<dynamic>(
        'api/providers/episodes',
        queryParameters: <String, dynamic>{
          'seriesid': seriesId,
          'episodeid': episodeId,
          'hi': result.hearingImpaired,
          'forced': result.forced,
          'original_format': result.originalFormat,
          'provider': result.provider,
          'subtitle': result.subtitle,
        },
        options: Options(receiveTimeout: const Duration(seconds: 120)),
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Downloads a chosen manual-search result for a movie
  /// (`POST /providers/movies`).
  Future<void> downloadMovieSubtitle({
    required int radarrId,
    required BazarrSubtitleSearchResult result,
  }) async {
    try {
      await _dio.post<dynamic>(
        'api/providers/movies',
        queryParameters: <String, dynamic>{
          'radarrid': radarrId,
          'hi': result.hearingImpaired,
          'forced': result.forced,
          'original_format': result.originalFormat,
          'provider': result.provider,
          'subtitle': result.subtitle,
        },
        options: Options(receiveTimeout: const Duration(seconds: 120)),
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Deletes a downloaded subtitle from an episode (`DELETE /episodes/subtitles`).
  Future<void> deleteEpisodeSubtitle({
    required int seriesId,
    required int episodeId,
    required BazarrSubtitle subtitle,
  }) async {
    try {
      await _dio.delete<dynamic>(
        'api/episodes/subtitles',
        queryParameters: <String, dynamic>{
          'seriesid': seriesId,
          'episodeid': episodeId,
          'language':
              subtitle.code2.isNotEmpty ? subtitle.code2 : subtitle.code3,
          'forced': subtitle.forced ? 'True' : 'False',
          'hi': subtitle.hi ? 'True' : 'False',
          'path': subtitle.path ?? '',
        },
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Deletes a downloaded subtitle from a movie (`DELETE /movies/subtitles`).
  Future<void> deleteMovieSubtitle({
    required int radarrId,
    required BazarrSubtitle subtitle,
  }) async {
    try {
      await _dio.delete<dynamic>(
        'api/movies/subtitles',
        queryParameters: <String, dynamic>{
          'radarrid': radarrId,
          'language':
              subtitle.code2.isNotEmpty ? subtitle.code2 : subtitle.code3,
          'forced': subtitle.forced ? 'True' : 'False',
          'hi': subtitle.hi ? 'True' : 'False',
          'path': subtitle.path ?? '',
        },
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }
}
