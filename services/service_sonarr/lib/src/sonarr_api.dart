import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';

import 'models/sonarr_blocklist_item.dart';
import 'models/sonarr_episode.dart';
import 'models/sonarr_history_item.dart';
import 'models/sonarr_queue_item.dart';
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

  Future<List<SonarrEpisode>> getCalendar({
    required DateTime start,
    required DateTime end,
    bool includeSeries = true,
  }) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/calendar',
        queryParameters: <String, dynamic>{
          'start': start.toUtc().toIso8601String(),
          'end': end.toUtc().toIso8601String(),
          'includeSeries': includeSeries,
        },
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

  Future<void> updateSeasonPass({
    required List<int> seriesIds,
    required String monitorType,
  }) async {
    try {
      final List<Map<String, dynamic>> seriesList = seriesIds
          .map(
            (id) => <String, dynamic>{
              'id': id,
              'monitored': monitorType != 'none',
            },
          )
          .toList();

      await _dio.post<dynamic>(
        '$_base/seasonpass',
        data: {
          'series': seriesList,
          'monitoringOptions': {
            'monitor': monitorType,
            'ignoreEpisodesWithFiles': false,
            'ignoreEpisodesWithoutFiles': false,
          },
        },
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Absolute, authenticated URL for a series image, suitable for
  /// `CachedNetworkImage`.
  String? posterUrl(
    SonarrImage image, {
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
        options: Options(
          receiveTimeout: Duration.zero,
        ),
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

  Future<List<Map<String, dynamic>>> getEpisodeFiles(int seriesId) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/episodefile',
        queryParameters: <String, dynamic>{'seriesId': seriesId},
      );
      return (resp.data as List<dynamic>)
          .map((dynamic e) => e as Map<String, dynamic>)
          .toList();
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
    Map<String, dynamic> payload,
  ) async {
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
  ) async {
    try {
      await _dio.put<dynamic>(
        '$_base/qualityprofile/${payload['id']}',
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

  Future<List<SonarrSeries>> lookupSeries(String term) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/series/lookup',
        queryParameters: <String, dynamic>{'term': term},
      );
      return (resp.data as List<dynamic>)
          .map(
            (dynamic e) => SonarrSeries.fromJson(e as Map<String, dynamic>),
          )
          .toList();
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

  Future<void> addSeries(Map<String, dynamic> seriesJson) async {
    try {
      await _dio.post<dynamic>(
        '$_base/series',
        data: seriesJson,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<SonarrQueueItem>> getQueue({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/queue',
        queryParameters: <String, dynamic>{
          'page': page,
          'pageSize': pageSize,
          'includeSeries': true,
          'includeEpisode': true,
        },
      );
      final dynamic records = (resp.data as Map<String, dynamic>)['records'];
      if (records is List<dynamic>) {
        return records
            .map(
              (dynamic e) =>
                  SonarrQueueItem.fromJson(e as Map<String, dynamic>),
            )
            .toList();
      }
      return <SonarrQueueItem>[];
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

  Future<List<SonarrHistoryItem>> getHistory({
    int page = 1,
    int pageSize = 20,
    int? episodeId,
  }) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/history',
        queryParameters: <String, dynamic>{
          'page': page,
          'pageSize': pageSize,
          'includeSeries': true,
          'includeEpisode': true,
          if (episodeId != null) 'episodeId': episodeId,
        },
      );
      final dynamic records = (resp.data as Map<String, dynamic>)['records'];
      if (records is List<dynamic>) {
        return records
            .map(
              (dynamic e) =>
                  SonarrHistoryItem.fromJson(e as Map<String, dynamic>),
            )
            .toList();
      }
      return <SonarrHistoryItem>[];
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

  Future<List<SonarrBlocklistItem>> getBlocklist({
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
                  SonarrBlocklistItem.fromJson(e as Map<String, dynamic>),
            )
            .toList();
      }
      return <SonarrBlocklistItem>[];
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

  Future<List<SonarrEpisode>> getWantedMissing({
    int page = 1,
    int pageSize = 150,
    String? sortKey,
    String? sortDirection,
  }) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/wanted/missing',
        queryParameters: <String, dynamic>{
          'page': page,
          'pageSize': pageSize,
          'includeSeries': true,
          if (sortKey != null) 'sortKey': sortKey,
          if (sortDirection != null) 'sortDirection': sortDirection,
        },
      );
      final Map<String, dynamic> data = resp.data as Map<String, dynamic>;
      final List<dynamic> records = data['records'] as List<dynamic>;
      return records
          .map(
            (dynamic e) => SonarrEpisode.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<SonarrEpisode>> getWantedCutoff({
    int page = 1,
    int pageSize = 150,
    String? sortKey,
    String? sortDirection,
  }) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/wanted/cutoff',
        queryParameters: <String, dynamic>{
          'page': page,
          'pageSize': pageSize,
          'includeSeries': true,
          'includeEpisodeFile': true,
          if (sortKey != null) 'sortKey': sortKey,
          if (sortDirection != null) 'sortDirection': sortDirection,
        },
      );
      final Map<String, dynamic> data = resp.data as Map<String, dynamic>;
      final List<dynamic> records = data['records'] as List<dynamic>;
      return records
          .map(
            (dynamic e) => SonarrEpisode.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateEpisodeMonitor({
    required List<int> episodeIds,
    required bool monitored,
  }) async {
    try {
      await _dio.put<dynamic>(
        '$_base/episode/monitor',
        data: <String, dynamic>{
          'episodeIds': episodeIds,
          'monitored': monitored,
        },
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> performEpisodeSearch(List<int> episodeIds) async {
    try {
      await _dio.post<dynamic>(
        '$_base/command',
        data: <String, dynamic>{
          'name': 'EpisodeSearch',
          'episodeIds': episodeIds,
        },
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> performMissingEpisodeSearch() async {
    try {
      await _dio.post<dynamic>(
        '$_base/command',
        data: <String, dynamic>{
          'name': 'MissingEpisodeSearch',
        },
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> performCutoffUnmetEpisodeSearch() async {
    try {
      await _dio.post<dynamic>(
        '$_base/command',
        data: <String, dynamic>{
          'name': 'CutoffUnmetEpisodeSearch',
        },
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<dynamic>> getFileSystem({
    required String path,
    bool includeFiles = false,
    bool allowFoldersWithoutTrailingSlashes = true,
  }) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/filesystem',
        queryParameters: <String, dynamic>{
          'path': path,
          'includeFiles': includeFiles,
          'allowFoldersWithoutTrailingSlashes':
              allowFoldersWithoutTrailingSlashes,
        },
      );
      final dynamic data = resp.data;
      if (data is Map<String, dynamic>) {
        return (data['directories'] as List<dynamic>?) ?? <dynamic>[];
      } else if (data is List<dynamic>) {
        return data;
      }
      return <dynamic>[];
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<dynamic>> getManualImport({
    required String folder,
    bool filterExistingFiles = false,
    CancelToken? cancelToken,
  }) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/manualimport',
        queryParameters: <String, dynamic>{
          'folder': folder,
          'filterExistingFiles': filterExistingFiles,
        },
        cancelToken: cancelToken,
        options: Options(
          receiveTimeout: const Duration(seconds: 180),
        ),
      );
      return resp.data as List<dynamic>;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> executeManualImport({
    required List<dynamic> files,
    String importMode = 'Move',
  }) async {
    try {
      await _dio.post<dynamic>(
        '$_base/command',
        data: <String, dynamic>{
          'name': 'ManualImport',
          'importMode': importMode,
          'files': files,
        },
      );
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

  Future<void> updateDownloadClient(Map<String, dynamic> client) async {
    try {
      await _dio.put<dynamic>(
        '$_base/downloadclient/${client['id']}',
        queryParameters: <String, dynamic>{'forceSave': true},
        data: client,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  // --- Indexers CRUD ---
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
    Map<String, dynamic> payload,
  ) async {
    try {
      final Response<dynamic> resp = await _dio.post<dynamic>(
        '$_base/indexer',
        queryParameters: <String, dynamic>{'forceSave': true},
        data: payload,
      );
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateIndexer(
    Map<String, dynamic> payload,
  ) async {
    try {
      await _dio.put<dynamic>(
        '$_base/indexer/${payload['id']}',
        queryParameters: <String, dynamic>{'forceSave': true},
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

  Future<void> testIndexer(
    Map<String, dynamic> payload,
  ) async {
    try {
      await _dio.post<dynamic>(
        '$_base/indexer/test',
        data: payload,
      );
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

  // --- Import Lists CRUD ---
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
    Map<String, dynamic> payload,
  ) async {
    try {
      final Response<dynamic> resp = await _dio.post<dynamic>(
        '$_base/importlist',
        queryParameters: <String, dynamic>{'forceSave': true},
        data: payload,
      );
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateImportList(
    Map<String, dynamic> payload,
  ) async {
    try {
      await _dio.put<dynamic>(
        '$_base/importlist/${payload['id']}',
        queryParameters: <String, dynamic>{'forceSave': true},
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

  Future<void> testImportList(
    Map<String, dynamic> payload,
  ) async {
    try {
      await _dio.post<dynamic>(
        '$_base/importlist/test',
        data: payload,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  // --- Download Clients CRUD additions ---
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
    Map<String, dynamic> payload,
  ) async {
    try {
      final Response<dynamic> resp = await _dio.post<dynamic>(
        '$_base/downloadclient',
        queryParameters: <String, dynamic>{'forceSave': true},
        data: payload,
      );
      return resp.data as Map<String, dynamic>;
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

  Future<void> testDownloadClient(
    Map<String, dynamic> payload,
  ) async {
    try {
      await _dio.post<dynamic>(
        '$_base/downloadclient/test',
        data: payload,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  // --- Remote Path Mappings CRUD ---
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
    Map<String, dynamic> payload,
  ) async {
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
    Map<String, dynamic> payload,
  ) async {
    try {
      await _dio.put<dynamic>(
        '$_base/remotepathmapping/${payload['id']}',
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

  // --- Connect / Notifications CRUD ---
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
    Map<String, dynamic> payload,
  ) async {
    try {
      final Response<dynamic> resp = await _dio.post<dynamic>(
        '$_base/notification',
        queryParameters: <String, dynamic>{'forceSave': true},
        data: payload,
      );
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateNotification(
    Map<String, dynamic> payload,
  ) async {
    try {
      await _dio.put<dynamic>(
        '$_base/notification/${payload['id']}',
        queryParameters: <String, dynamic>{'forceSave': true},
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

  Future<void> testNotification(
    Map<String, dynamic> payload,
  ) async {
    try {
      await _dio.post<dynamic>(
        '$_base/notification/test',
        data: payload,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  // --- Metadata Consumers ---
  Future<List<Map<String, dynamic>>> getMetadataConfigs() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/metadata');
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

  Future<void> updateMetadataConfig(
    Map<String, dynamic> payload,
  ) async {
    try {
      await _dio.put<dynamic>(
        '$_base/metadata/${payload['id']}',
        queryParameters: <String, dynamic>{'forceSave': true},
        data: payload,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  // --- Delay Profiles CRUD ---
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
    Map<String, dynamic> payload,
  ) async {
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

  Future<void> updateDelayProfile(
    Map<String, dynamic> payload,
  ) async {
    try {
      await _dio.put<dynamic>(
        '$_base/delayprofile/${payload['id']}',
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

  // --- Release Profiles CRUD ---
  Future<List<Map<String, dynamic>>> getReleaseProfiles() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/releaseprofile');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => e as Map<String, dynamic>)
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> createReleaseProfile(
    Map<String, dynamic> payload,
  ) async {
    try {
      final Response<dynamic> resp = await _dio.post<dynamic>(
        '$_base/releaseprofile',
        data: payload,
      );
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateReleaseProfile(
    Map<String, dynamic> payload,
  ) async {
    try {
      await _dio.put<dynamic>(
        '$_base/releaseprofile/${payload['id']}',
        data: payload,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> deleteReleaseProfile(int id) async {
    try {
      await _dio.delete<dynamic>('$_base/releaseprofile/$id');
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  // --- Custom Formats CRUD ---
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
    Map<String, dynamic> payload,
  ) async {
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

  Future<void> updateCustomFormat(
    Map<String, dynamic> payload,
  ) async {
    try {
      await _dio.put<dynamic>(
        '$_base/customformat/${payload['id']}',
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
  // ==========================================
  // System endpoints
  // ==========================================

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
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/diskspace');
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
    int pageSize = 50,
    String sortKey = 'time',
    String sortDirection = 'descending',
    String? level,
  }) async {
    try {
      final Map<String, dynamic> queryParams = <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
        'sortKey': sortKey,
        'sortDirection': sortDirection,
      };
      if (level != null) {
        queryParams['level'] = level;
      }
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/log',
        queryParameters: queryParams,
      );
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> getLogFiles() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/log/file');
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

  Future<void> restartSonarr() async {
    try {
      await _dio.post<dynamic>('$_base/system/restart');
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> shutdownSonarr() async {
    try {
      await _dio.post<dynamic>('$_base/system/shutdown');
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
        queryParameters: <String, dynamic>{
          'removeFromClient': removeFromClient,
          'blocklist': blocklist,
        },
        data: <String, dynamic>{
          'ids': ids,
        },
      );
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

  Future<void> bulkUpdateSeries(Map<String, dynamic> payload) async {
    try {
      await _dio.put<dynamic>(
        '$_base/series/editor',
        data: payload,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> bulkDeleteSeries(
    List<int> seriesIds, {
    bool deleteFiles = false,
  }) async {
    try {
      await _dio.delete<dynamic>(
        '$_base/series/editor',
        data: <String, dynamic>{
          'seriesIds': seriesIds,
          'deleteFiles': deleteFiles,
          'addImportListExclusion': false,
        },
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> parseTitle(String title) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/parse',
        queryParameters: <String, dynamic>{
          'title': title,
        },
      );
      return resp.data as Map<String, dynamic>;
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
}
