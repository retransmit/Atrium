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
}
