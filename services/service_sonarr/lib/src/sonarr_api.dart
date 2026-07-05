import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';

import 'models/sonarr_episode.dart';
import 'models/sonarr_series.dart';

/// Thin typed client over the Sonarr v3 REST API.
class SonarrApi {
  SonarrApi(this._dio, {this.apiKey});

  final Dio _dio;
  final String? apiKey;

  static const String _base = 'api/v3';

  Future<List<SonarrSeries>> getSeries() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/series');
      return (resp.data as List<dynamic>)
          .map(
            (dynamic e) => SonarrSeries.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<SonarrSeries> getSeriesById(int id) async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/series/$id');
      return SonarrSeries.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<SonarrEpisode>> getEpisodes(int seriesId) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/episode',
        queryParameters: <String, dynamic>{'seriesId': seriesId},
      );
      return (resp.data as List<dynamic>)
          .map(
            (dynamic e) => SonarrEpisode.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Fetches the FULL series JSON (untrimmed) for read-modify-write flows.
  Future<Map<String, dynamic>> getSeriesRaw(int id) async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/series/$id');
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateSeriesRaw(Map<String, dynamic> seriesJson) async {
    try {
      await _dio.put<dynamic>(
        '$_base/series/${seriesJson['id']}',
        data: seriesJson,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> deleteSeries(int id, {bool deleteFiles = false}) async {
    try {
      await _dio.delete<dynamic>(
        '$_base/series/$id',
        queryParameters: <String, dynamic>{'deleteFiles': deleteFiles},
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Absolute, authenticated URL for a series image, suitable for
  /// `CachedNetworkImage`.
  String? posterUrl(SonarrImage image, {int? width}) {
    final String? remote = image.url;
    final String? upstream = image.remoteUrl;
    if (remote != null && remote.isNotEmpty) {
      final Uri base = Uri.parse(_dio.options.baseUrl);
      String pathOrUrl = remote;

      if (width != null) {
        final int queryIdx = pathOrUrl.indexOf('?');
        final String pathPart =
            queryIdx == -1 ? pathOrUrl : pathOrUrl.substring(0, queryIdx);
        final String queryPart =
            queryIdx == -1 ? '' : pathOrUrl.substring(queryIdx);

        final int dotIdx = pathPart.lastIndexOf('.');
        if (dotIdx != -1) {
          final String basePart = pathPart.substring(0, dotIdx);
          final String extPart = pathPart.substring(dotIdx);
          pathOrUrl = '$basePart-$width$extPart$queryPart';
        }
      }

      if (pathOrUrl.startsWith('/MediaCover/')) {
        pathOrUrl =
            '$_base/mediacover${pathOrUrl.substring('/MediaCover'.length)}';
      }
      final String separator = pathOrUrl.contains('?') ? '&' : '?';
      return base.resolve('$pathOrUrl${separator}apikey=$apiKey').toString();
    }
    return upstream;
  }

  Future<void> runCommand(Map<String, dynamic> body) async {
    try {
      await _dio.post<dynamic>('$_base/command', data: body);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> getRenamePreview(int seriesId) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/rename',
        queryParameters: <String, dynamic>{'seriesId': seriesId},
      );
      return (resp.data as List<dynamic>)
          .map((dynamic e) => e as Map<String, dynamic>)
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> renameFiles(int seriesId, List<int> fileIds) async {
    try {
      await runCommand(<String, dynamic>{
        'name': 'RenameFiles',
        'seriesId': seriesId,
        'files': fileIds,
      });
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> getReleases({
    int? episodeId,
    int? seriesId,
    int? seasonNumber,
  }) async {
    try {
      final Map<String, dynamic> qParams = <String, dynamic>{};
      if (episodeId != null) {
        qParams['episodeId'] = episodeId;
      }
      if (seriesId != null) {
        qParams['seriesId'] = seriesId;
      }
      if (seasonNumber != null) {
        qParams['seasonNumber'] = seasonNumber;
      }
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/release',
        queryParameters: qParams,
      );
      return (resp.data as List<dynamic>)
          .map((dynamic e) => e as Map<String, dynamic>)
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> downloadRelease(Map<String, dynamic> release) async {
    try {
      await _dio.post<dynamic>('$_base/release', data: release);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> deleteEpisodeFile(int fileId) async {
    try {
      await _dio.delete<dynamic>('$_base/episodefile/$fileId');
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateEpisode(Map<String, dynamic> episode) async {
    try {
      await _dio.put<dynamic>('$_base/episode/${episode['id']}', data: episode);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> getQualityProfiles() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/qualityprofile');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => e as Map<String, dynamic>)
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> getTags() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/tag');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => e as Map<String, dynamic>)
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }
}
