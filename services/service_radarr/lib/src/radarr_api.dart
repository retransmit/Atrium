import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';

import 'models/radarr_blocklist_item.dart';
import 'models/radarr_history_item.dart';
import 'models/radarr_movie.dart';
import 'models/radarr_queue_item.dart';

/// Thin typed client over the Radarr v3 REST API.
class RadarrApi {
  RadarrApi(this._dio, {this.apiKey});

  final Dio _dio;
  final String? apiKey;

  static const String _base = 'api/v3';

  Future<List<RadarrMovie>> getMovies() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/movie');
      return (resp.data as List<dynamic>)
          .map(
            (dynamic e) => RadarrMovie.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<RadarrMovie> getMovieById(int id) async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/movie/$id');
      return RadarrMovie.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> getMovieRaw(int id) async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/movie/$id');
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateMovieRaw(Map<String, dynamic> movieJson) async {
    try {
      await _dio.put<dynamic>(
        '$_base/movie/${movieJson['id']}',
        data: movieJson,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> deleteMovie(int id, {bool deleteFiles = false}) async {
    try {
      await _dio.delete<dynamic>(
        '$_base/movie/$id',
        queryParameters: <String, dynamic>{'deleteFiles': deleteFiles},
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<RadarrMovie>> lookupMovie(String term) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/movie/lookup',
        queryParameters: <String, dynamic>{'term': term},
      );
      return (resp.data as List<dynamic>)
          .map(
            (dynamic e) => RadarrMovie.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> addMovie(Map<String, dynamic> movieJson) async {
    try {
      await _dio.post<dynamic>('$_base/movie', data: movieJson);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> bulkUpdateMovies(Map<String, dynamic> payload) async {
    try {
      await _dio.put<dynamic>('$_base/movie/editor', data: payload);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> bulkDeleteMovies(List<int> ids, {bool deleteFiles = false}) async {
    try {
      await _dio.delete<dynamic>(
        '$_base/movie/editor',
        data: <String, dynamic>{
          'movieIds': ids,
          'deleteFiles': deleteFiles,
        },
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Absolute, authenticated URL for a movie image, suitable for
  /// `CachedNetworkImage`.
  String? posterUrl(
    RadarrImage image, {
    int? width,
    bool preferRemote = false,
  }) {
    final String? remote = image.url;
    final String? upstream = image.remoteUrl;
    if (preferRemote && upstream != null && upstream.isNotEmpty) {
      return upstream;
    }
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

  Future<List<RadarrMovie>> getCalendar({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/calendar',
        queryParameters: <String, dynamic>{
          'start': start.toUtc().toIso8601String(),
          'end': end.toUtc().toIso8601String(),
        },
      );
      return (resp.data as List<dynamic>)
          .map(
            (dynamic e) => RadarrMovie.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<RadarrQueueItem>> getQueue({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/queue',
        queryParameters: <String, dynamic>{
          'page': page,
          'pageSize': pageSize,
          'includeMovie': true,
        },
      );
      final dynamic records = (resp.data as Map<String, dynamic>)['records'];
      if (records is List<dynamic>) {
        return records
            .map(
              (dynamic e) => RadarrQueueItem.fromJson(e as Map<String, dynamic>),
            )
            .toList();
      }
      return <RadarrQueueItem>[];
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> deleteQueueItem(
    int id, {
    bool removeFromClient = true,
    bool blocklist = false,
  }) async {
    try {
      await _dio.delete<dynamic>(
        '$_base/queue/$id',
        queryParameters: <String, dynamic>{
          'removeFromClient': removeFromClient,
          'blocklist': blocklist,
        },
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> bulkDeleteQueue(
    List<int> ids, {
    bool removeFromClient = true,
    bool blocklist = false,
  }) async {
    try {
      await _dio.delete<dynamic>(
        '$_base/queue/bulk',
        data: <String, dynamic>{
          'ids': ids,
          'removeFromClient': removeFromClient,
          'blocklist': blocklist,
        },
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> grabQueueItem(int id) async {
    try {
      await _dio.post<dynamic>('$_base/queue/grab/$id');
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> grabQueueItems(List<int> ids) async {
    try {
      await _dio.post<dynamic>(
        '$_base/queue/grab/bulk',
        data: <String, dynamic>{
          'ids': ids,
        },
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<RadarrHistoryItem>> getHistory({
    int page = 1,
    int pageSize = 20,
    int? movieId,
  }) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/history',
        queryParameters: <String, dynamic>{
          'page': page,
          'pageSize': pageSize,
          'includeMovie': true,
          if (movieId != null) 'movieId': movieId,
        },
      );
      final dynamic records = (resp.data as Map<String, dynamic>)['records'];
      if (records is List<dynamic>) {
        return records
            .map(
              (dynamic e) =>
                  RadarrHistoryItem.fromJson(e as Map<String, dynamic>),
            )
            .toList();
      }
      return <RadarrHistoryItem>[];
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> failHistoryItem(int id) async {
    try {
      await _dio.post<dynamic>('$_base/history/failed/$id');
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<RadarrBlocklistItem>> getBlocklist({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/blocklist',
        queryParameters: <String, dynamic>{
          'page': page,
          'pageSize': pageSize,
        },
      );
      final dynamic records = (resp.data as Map<String, dynamic>)['records'];
      if (records is List<dynamic>) {
        return records
            .map(
              (dynamic e) =>
                  RadarrBlocklistItem.fromJson(e as Map<String, dynamic>),
            )
            .toList();
      }
      return <RadarrBlocklistItem>[];
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> deleteBlocklistItem(int id) async {
    try {
      await _dio.delete<dynamic>('$_base/blocklist/$id');
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> bulkDeleteBlocklist(List<int> ids) async {
    try {
      await _dio.delete<dynamic>(
        '$_base/blocklist/bulk',
        data: <String, dynamic>{
          'ids': ids,
        },
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<RadarrMovie>> getWantedMissing({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/wanted/missing',
        queryParameters: <String, dynamic>{
          'page': page,
          'pageSize': pageSize,
        },
      );
      final dynamic records = (resp.data as Map<String, dynamic>)['records'];
      if (records is List<dynamic>) {
        return records
            .map(
              (dynamic e) => RadarrMovie.fromJson(e as Map<String, dynamic>),
            )
            .toList();
      }
      return <RadarrMovie>[];
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<RadarrMovie>> getWantedCutoff({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/wanted/cutoff',
        queryParameters: <String, dynamic>{
          'page': page,
          'pageSize': pageSize,
        },
      );
      final dynamic records = (resp.data as Map<String, dynamic>)['records'];
      if (records is List<dynamic>) {
        return records
            .map(
              (dynamic e) => RadarrMovie.fromJson(e as Map<String, dynamic>),
            )
            .toList();
      }
      return <RadarrMovie>[];
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> runCommand(Map<String, dynamic> body) async {
    try {
      await _dio.post<dynamic>('$_base/command', data: body);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> cancelCommand(int commandId) async {
    try {
      await _dio.delete<dynamic>('$_base/command/$commandId');
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> getReleases({int? movieId}) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/release',
        queryParameters: <String, dynamic>{
          if (movieId != null) 'movieId': movieId,
        },
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

  Future<List<Map<String, dynamic>>> getMovieFiles({int? movieId}) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/moviefile',
        queryParameters: <String, dynamic>{
          if (movieId != null) 'movieId': movieId,
        },
      );
      return (resp.data as List<dynamic>)
          .map((dynamic e) => e as Map<String, dynamic>)
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> deleteMovieFile(int id) async {
    try {
      await _dio.delete<dynamic>('$_base/moviefile/$id');
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> getRenamePreview(int movieId) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/rename',
        queryParameters: <String, dynamic>{'movieId': movieId},
      );
      return (resp.data as List<dynamic>)
          .map((dynamic e) => e as Map<String, dynamic>)
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> renameFiles(int movieId, List<int> fileIds) async {
    try {
      await _dio.post<dynamic>(
        '$_base/command',
        data: <String, dynamic>{
          'name': 'RenameFiles',
          'movieId': movieId,
          'files': fileIds,
        },
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<dynamic>> getManualImport({
    required String folder,
    int? movieId,
  }) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/manualimport',
        queryParameters: <String, dynamic>{
          'folder': folder,
          if (movieId != null) 'movieId': movieId,
        },
      );
      return resp.data as List<dynamic>;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> executeManualImport(List<dynamic> items) async {
    try {
      await _dio.post<dynamic>('$_base/manualimport', data: items);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> parseTitle(String title) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/parse',
        queryParameters: <String, dynamic>{'title': title},
      );
      return resp.data as Map<String, dynamic>;
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

  Future<Map<String, dynamic>> getQualityProfileSchema() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/qualityprofile/schema');
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> createQualityProfile(
      Map<String, dynamic> payload) async {
    try {
      final Response<dynamic> resp = await _dio.post<dynamic>(
        '$_base/qualityprofile',
        data: payload,
      );
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateQualityProfile(
    Map<String, dynamic> payload,
    int id,
  ) async {
    try {
      await _dio.put<dynamic>(
        '$_base/qualityprofile/$id',
        data: payload,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> deleteQualityProfile(int id) async {
    try {
      await _dio.delete<dynamic>('$_base/qualityprofile/$id');
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> getQualityDefinitions() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/qualitydefinition');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => e as Map<String, dynamic>)
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateQualityDefinitions(List<dynamic> definitions) async {
    try {
      await _dio.put<dynamic>(
        '$_base/qualitydefinition/update',
        data: definitions,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> getRootFolders() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/rootfolder');
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

  Future<Map<String, dynamic>> createTag(String name) async {
    try {
      final Response<dynamic> resp = await _dio.post<dynamic>(
        '$_base/tag',
        data: <String, dynamic>{'label': name},
      );
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> deleteTag(int id) async {
    try {
      await _dio.delete<dynamic>('$_base/tag/$id');
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> getIndexers() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/indexer');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => e as Map<String, dynamic>)
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> getIndexerSchema() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/indexer/schema');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => e as Map<String, dynamic>)
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> createIndexer(
      Map<String, dynamic> payload) async {
    try {
      final Response<dynamic> resp = await _dio.post<dynamic>(
        '$_base/indexer',
        data: payload,
      );
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateIndexer(Map<String, dynamic> payload, int id) async {
    try {
      await _dio.put<dynamic>(
        '$_base/indexer/$id',
        data: payload,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> deleteIndexer(int id) async {
    try {
      await _dio.delete<dynamic>('$_base/indexer/$id');
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> testIndexer(Map<String, dynamic> payload) async {
    try {
      await _dio.post<dynamic>('$_base/indexer/test', data: payload);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> getIndexerConfig() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/config/indexer');
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateIndexerConfig(Map<String, dynamic> config) async {
    try {
      await _dio.put<dynamic>(
        '$_base/config/indexer/${config['id']}',
        data: config,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> getDownloadClients() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/downloadclient');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => e as Map<String, dynamic>)
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> getDownloadClientSchema() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/downloadclient/schema');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => e as Map<String, dynamic>)
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> createDownloadClient(
      Map<String, dynamic> payload) async {
    try {
      final Response<dynamic> resp = await _dio.post<dynamic>(
        '$_base/downloadclient',
        data: payload,
      );
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateDownloadClient(
      Map<String, dynamic> payload, int id) async {
    try {
      await _dio.put<dynamic>(
        '$_base/downloadclient/$id',
        data: payload,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> deleteDownloadClient(int id) async {
    try {
      await _dio.delete<dynamic>('$_base/downloadclient/$id');
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> testDownloadClient(Map<String, dynamic> payload) async {
    try {
      await _dio.post<dynamic>('$_base/downloadclient/test', data: payload);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> getDownloadClientConfig() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/config/downloadclient');
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateDownloadClientConfig(Map<String, dynamic> config) async {
    try {
      await _dio.put<dynamic>(
        '$_base/config/downloadclient/${config['id']}',
        data: config,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/notification');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => e as Map<String, dynamic>)
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> getNotificationSchema() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/notification/schema');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => e as Map<String, dynamic>)
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> createNotification(
      Map<String, dynamic> payload) async {
    try {
      final Response<dynamic> resp = await _dio.post<dynamic>(
        '$_base/notification',
        data: payload,
      );
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateNotification(Map<String, dynamic> payload, int id) async {
    try {
      await _dio.put<dynamic>(
        '$_base/notification/$id',
        data: payload,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> deleteNotification(int id) async {
    try {
      await _dio.delete<dynamic>('$_base/notification/$id');
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> testNotification(Map<String, dynamic> payload) async {
    try {
      await _dio.post<dynamic>('$_base/notification/test', data: payload);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> getMetadataConfigs() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/metadata');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => e as Map<String, dynamic>)
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> getMetadataSchema() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/metadata/schema');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => e as Map<String, dynamic>)
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateMetadataConfig(Map<String, dynamic> payload, int id) async {
    try {
      await _dio.put<dynamic>(
        '$_base/metadata/$id',
        data: payload,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> getCustomFormats() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/customformat');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => e as Map<String, dynamic>)
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> getCustomFormatSchema() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/customformat/schema');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => e as Map<String, dynamic>)
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> createCustomFormat(
      Map<String, dynamic> payload) async {
    try {
      final Response<dynamic> resp = await _dio.post<dynamic>(
        '$_base/customformat',
        data: payload,
      );
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateCustomFormat(Map<String, dynamic> payload, int id) async {
    try {
      await _dio.put<dynamic>(
        '$_base/customformat/$id',
        data: payload,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> deleteCustomFormat(int id) async {
    try {
      await _dio.delete<dynamic>('$_base/customformat/$id');
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> getDelayProfiles() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/delayprofile');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => e as Map<String, dynamic>)
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> createDelayProfile(
      Map<String, dynamic> payload) async {
    try {
      final Response<dynamic> resp = await _dio.post<dynamic>(
        '$_base/delayprofile',
        data: payload,
      );
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateDelayProfile(Map<String, dynamic> payload, int id) async {
    try {
      await _dio.put<dynamic>(
        '$_base/delayprofile/$id',
        data: payload,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> deleteDelayProfile(int id) async {
    try {
      await _dio.delete<dynamic>('$_base/delayprofile/$id');
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> getImportLists() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/importlist');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => e as Map<String, dynamic>)
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> getImportListConfig() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/config/importlist');
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateImportListConfig(Map<String, dynamic> config) async {
    try {
      await _dio.put<dynamic>(
        '$_base/config/importlist/${config['id']}',
        data: config,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> getImportListSchema() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/importlist/schema');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => e as Map<String, dynamic>)
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> createImportList(
      Map<String, dynamic> payload) async {
    try {
      final Response<dynamic> resp = await _dio.post<dynamic>(
        '$_base/importlist',
        data: payload,
      );
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateImportList(Map<String, dynamic> payload, int id) async {
    try {
      await _dio.put<dynamic>(
        '$_base/importlist/$id',
        data: payload,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> deleteImportList(int id) async {
    try {
      await _dio.delete<dynamic>('$_base/importlist/$id');
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> testImportList(Map<String, dynamic> payload) async {
    try {
      await _dio.post<dynamic>('$_base/importlist/test', data: payload);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> getNamingConfig() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/config/naming');
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateNamingConfig(Map<String, dynamic> config) async {
    try {
      await _dio.put<dynamic>(
        '$_base/config/naming/${config['id']}',
        data: config,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> getMediaManagementConfig() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/config/mediamanagement');
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateMediaManagementConfig(Map<String, dynamic> config) async {
    try {
      await _dio.put<dynamic>(
        '$_base/config/mediamanagement/${config['id']}',
        data: config,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> getHostConfig() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/config/host');
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateHostConfig(Map<String, dynamic> config) async {
    try {
      await _dio.put<dynamic>(
        '$_base/config/host/${config['id']}',
        data: config,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> getUiConfig() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/config/ui');
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateUiConfig(Map<String, dynamic> config) async {
    try {
      await _dio.put<dynamic>(
        '$_base/config/ui/${config['id']}',
        data: config,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> getRemotePathMappings() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/remotepathmapping');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => e as Map<String, dynamic>)
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> createRemotePathMapping(
      Map<String, dynamic> payload) async {
    try {
      final Response<dynamic> resp = await _dio.post<dynamic>(
        '$_base/remotepathmapping',
        data: payload,
      );
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateRemotePathMapping(
      Map<String, dynamic> payload, int id) async {
    try {
      await _dio.put<dynamic>(
        '$_base/remotepathmapping/$id',
        data: payload,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> deleteRemotePathMapping(int id) async {
    try {
      await _dio.delete<dynamic>('$_base/remotepathmapping/$id');
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<dynamic>> getFileSystem({
    required String path,
    bool includeFiles = true,
  }) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/filesystem',
        queryParameters: <String, dynamic>{
          'path': path,
          'includeFiles': includeFiles,
        },
      );
      return resp.data as List<dynamic>;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> getSystemStatus() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/system/status');
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> getHealth() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/health');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => e as Map<String, dynamic>)
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> getDiskSpace() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/diskspace');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => e as Map<String, dynamic>)
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> getTasks() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/system/task');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => e as Map<String, dynamic>)
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> getUpdates() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/update');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => e as Map<String, dynamic>)
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> getLogs({
    int page = 1,
    int pageSize = 20,
    String? sortKey,
  }) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/log',
        queryParameters: <String, dynamic>{
          'page': page,
          'pageSize': pageSize,
          if (sortKey != null) 'sortKey': sortKey,
        },
      );
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> getLogFiles() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/log/file');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => e as Map<String, dynamic>)
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> getBackups() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/system/backup');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => e as Map<String, dynamic>)
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> deleteBackup(int id) async {
    try {
      await _dio.delete<dynamic>('$_base/system/backup/$id');
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> restartRadarr() async {
    try {
      await _dio.post<dynamic>('$_base/system/restart');
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> shutdownRadarr() async {
    try {
      await _dio.post<dynamic>('$_base/system/shutdown');
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }
}
