import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';

import 'models/radarr_add_models.dart';
import 'models/radarr_blocklist.dart';
import 'models/radarr_history.dart';
import 'models/radarr_movie.dart';
import 'models/radarr_queue.dart';
import 'models/radarr_release.dart';
import 'models/radarr_settings_models.dart';
import 'models/radarr_system.dart';
import 'models/radarr_wanted.dart';

/// Thin typed client over the Radarr v3 REST API.
///
/// Mirrors [SonarrApi]: construction takes a [Dio] already configured for the
/// instance (base URL + `X-Api-Key`), and every method maps transport
/// failures to [NetworkException] so the UI sees one error type.
///
/// [apiKey] is an optional copy of the instance's API key, used only to build
/// authenticated *image* URLs (Radarr's `/MediaCover/...` routes don't read
/// the `X-Api-Key` header - `cached_network_image` fetches the bytes outside
/// of our Dio so the key has to ride as a query param).
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
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/movie/$id');
      return RadarrMovie.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<RadarrQueuePage> getQueue({
    int page = 1,
    int pageSize = 50,
    bool includeMovie = true,
  }) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/queue',
        queryParameters: <String, dynamic>{
          'page': page,
          'pageSize': pageSize,
          'includeMovie': includeMovie,
        },
      );
      return RadarrQueuePage.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Paginated download/import history, newest first.
  Future<RadarrHistoryPage> getHistory({int page = 1, int pageSize = 50}) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/history',
        queryParameters: <String, dynamic>{
          'page': page,
          'pageSize': pageSize,
          'sortKey': 'date',
          'sortDirection': 'descending',
        },
      );
      return RadarrHistoryPage.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Wanted: missing monitored movies, paginated.
  Future<RadarrWantedPage> getWantedMissing({
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/wanted/missing',
        queryParameters: <String, dynamic>{
          'page': page,
          'pageSize': pageSize,
          'sortKey': 'title',
          'sortDirection': 'ascending',
        },
      );
      return RadarrWantedPage.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Wanted: monitored movies below their quality cutoff, paginated.
  Future<RadarrWantedPage> getWantedCutoff({
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/wanted/cutoff',
        queryParameters: <String, dynamic>{
          'page': page,
          'pageSize': pageSize,
          'sortKey': 'title',
          'sortDirection': 'ascending',
        },
      );
      return RadarrWantedPage.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Paginated blocklist of rejected/failed releases, newest first.
  Future<RadarrBlocklistPage> getBlocklist({
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/blocklist',
        queryParameters: <String, dynamic>{
          'page': page,
          'pageSize': pageSize,
          'sortKey': 'date',
          'sortDirection': 'descending',
        },
      );
      return RadarrBlocklistPage.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Removes one blocklist entry.
  Future<void> deleteBlocklist(int id) async {
    try {
      await _dio.delete<dynamic>('$_base/blocklist/$id');
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// System status (version, OS, database, runtime).
  Future<RadarrSystemStatus> getSystemStatus() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/system/status');
      return RadarrSystemStatus.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Disk space per mapped root/drive.
  Future<List<RadarrDiskSpace>> getDiskSpace() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/diskspace');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => RadarrDiskSpace.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Active health warnings.
  Future<List<RadarrHealth>> getHealth() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/health');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => RadarrHealth.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Scheduled tasks.
  Future<List<RadarrSystemTask>> getSystemTasks() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/system/task');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => RadarrSystemTask.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Runs a scheduled task now (by its command name).
  Future<void> runSystemTask(String taskName) async {
    try {
      await _dio.post<dynamic>(
        '$_base/command',
        data: <String, dynamic>{'name': taskName},
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Server backups.
  Future<List<RadarrBackup>> getBackups() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/system/backup');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => RadarrBackup.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Deletes a server backup.
  Future<void> deleteBackup(int id) async {
    try {
      await _dio.delete<dynamic>('$_base/system/backup/$id');
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Kicks off a search for a movie.
  Future<void> searchMovie(int movieId) async {
    try {
      await _dio.post<dynamic>(
        '$_base/command',
        data: <String, dynamic>{
          'name': 'MoviesSearch',
          'movieIds': <int>[movieId],
        },
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<RadarrRelease>> getReleases(int movieId) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/release',
        queryParameters: <String, dynamic>{'movieId': movieId},
        options: Options(
          receiveTimeout: const Duration(seconds: 120),
          sendTimeout: const Duration(seconds: 120),
        ),
      );
      return (resp.data as List<dynamic>)
          .map((dynamic e) => RadarrRelease(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> grabRelease(RadarrRelease release) async {
    try {
      await _dio.post<dynamic>(
        '$_base/release',
        data: release.raw,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Updates a movie. Radarr's PUT wants the FULL movie object; see
  /// [SonarrApi.updateSeriesRaw] for why this takes a raw map.
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

  /// Fetches the FULL movie JSON (untrimmed) for read-modify-write flows.
  Future<Map<String, dynamic>> getMovieRaw(int id) async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/movie/$id');
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Deletes a movie, optionally with its files on disk.
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

  /// Searches the metadata provider for movies matching [term].
  Future<List<RadarrLookupResult>> lookupMovies(String term) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/movie/lookup',
        queryParameters: <String, dynamic>{'term': term},
      );
      return (resp.data as List<dynamic>)
          .map(
            (dynamic e) => RadarrLookupResult(e as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Quality profiles configured on the server.
  Future<List<RadarrQualityProfile>> getQualityProfiles() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/qualityprofile');
      return (resp.data as List<dynamic>)
          .map(
            (dynamic e) =>
                RadarrQualityProfile.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Root folders configured on the server.
  Future<List<RadarrRootFolder>> getRootFolders() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/rootfolder');
      return (resp.data as List<dynamic>)
          .map(
            (dynamic e) =>
                RadarrRootFolder.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Adds a movie from a lookup result.
  ///
  /// [lookup] is the complete raw object from [lookupMovies] - Radarr's POST
  /// expects it back whole, decorated with the library options below.
  Future<void> addMovie(
    RadarrLookupResult lookup, {
    required int qualityProfileId,
    required String rootFolderPath,
    bool monitored = true,
    bool searchOnAdd = true,
  }) async {
    try {
      final Map<String, dynamic> body =
          Map<String, dynamic>.of(lookup.raw)
            ..['qualityProfileId'] = qualityProfileId
            ..['rootFolderPath'] = rootFolderPath
            ..['monitored'] = monitored
            ..['addOptions'] = <String, dynamic>{
              'searchForMovie': searchOnAdd,
            };
      await _dio.post<dynamic>('$_base/movie', data: body);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Removes a queue item, optionally blocklisting the release.
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

  /// Absolute, authenticated URL for a movie image, suitable for
  /// `CachedNetworkImage`.
  ///
  /// Radarr's `images[].url` points at the session-authenticated web-UI
  /// route (`/MediaCover/...`) which bounces `?apikey=` requests to the
  /// login page as HTML; the API route `/api/v3/mediacover/...` serves the
  /// same files and accepts `apikey`. See [SonarrApi.posterUrl].
  String? posterUrl(RadarrImage image) {
    final String? remote = image.url;
    final String? upstream = image.remoteUrl;
    if (remote != null && remote.isNotEmpty) {
      final Uri base = Uri.parse(_dio.options.baseUrl);
      
      String pathOrUrl = remote;
      if (pathOrUrl.startsWith('/MediaCover/')) {
        pathOrUrl = '$_base/mediacover${pathOrUrl.substring('/MediaCover'.length)}';
      } else if (pathOrUrl.startsWith('MediaCover/')) {
        pathOrUrl = '$_base/mediacover${pathOrUrl.substring('MediaCover'.length)}';
      }

      final Uri abs = pathOrUrl.startsWith('http')
          ? Uri.parse(pathOrUrl)
          : base.resolve(pathOrUrl.startsWith('/') ? pathOrUrl.substring(1) : pathOrUrl);

      if (apiKey == null || apiKey!.isEmpty) {
        return abs.toString();
      }
      return abs.replace(
        queryParameters: <String, String>{
          ...abs.queryParameters,
          'apikey': apiKey!,
        },
      ).toString();
    }
    if (upstream != null && upstream.isNotEmpty) {
      return upstream;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Settings: tags
  // ---------------------------------------------------------------------------

  Future<List<RadarrTag>> getTags() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/tag');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => RadarrTag.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> createTag(String label) async {
    try {
      await _dio.post<dynamic>('$_base/tag', data: <String, dynamic>{'label': label});
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

  // ---------------------------------------------------------------------------
  // Settings: indexers
  //
  // Create/update/test take and send the FULL raw object: Radarr's schema is
  // provider-specific (fields differ per indexer type), so trimming it would
  // drop values the server validates and stores. PUT/POST that the server
  // test-validates ride `?forceSave=true` so a failing connection test does
  // not 400 the save.
  // ---------------------------------------------------------------------------

  Future<List<RadarrIndexer>> getIndexers() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/indexer');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => RadarrIndexer.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> getIndexerSchema() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/indexer/schema');
      return (resp.data as List<dynamic>).map((dynamic e) => e as Map<String, dynamic>).toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> createIndexerRaw(Map<String, dynamic> raw) async {
    try {
      await _dio.post<dynamic>(
        '$_base/indexer',
        queryParameters: <String, dynamic>{'forceSave': true},
        data: raw,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateIndexerRaw(Map<String, dynamic> indexerJson) async {
    try {
      await _dio.put<dynamic>(
        '$_base/indexer/${indexerJson['id']}',
        queryParameters: <String, dynamic>{'forceSave': true},
        data: indexerJson,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> testIndexerRaw(Map<String, dynamic> indexerJson) async {
    try {
      await _dio.post<dynamic>('$_base/indexer/test', data: indexerJson);
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

  // ---------------------------------------------------------------------------
  // Settings: download clients
  // ---------------------------------------------------------------------------

  Future<List<RadarrDownloadClient>> getDownloadClients() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/downloadclient');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => RadarrDownloadClient.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> getDownloadClientSchema() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/downloadclient/schema');
      return (resp.data as List<dynamic>).map((dynamic e) => e as Map<String, dynamic>).toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> createDownloadClientRaw(Map<String, dynamic> raw) async {
    try {
      await _dio.post<dynamic>(
        '$_base/downloadclient',
        queryParameters: <String, dynamic>{'forceSave': true},
        data: raw,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateDownloadClientRaw(Map<String, dynamic> clientJson) async {
    try {
      await _dio.put<dynamic>(
        '$_base/downloadclient/${clientJson['id']}',
        queryParameters: <String, dynamic>{'forceSave': true},
        data: clientJson,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> testDownloadClientRaw(Map<String, dynamic> clientJson) async {
    try {
      await _dio.post<dynamic>('$_base/downloadclient/test', data: clientJson);
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

  // ---------------------------------------------------------------------------
  // Settings: notifications
  // ---------------------------------------------------------------------------

  Future<List<RadarrNotification>> getNotifications() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/notification');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => RadarrNotification.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> getNotificationSchema() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/notification/schema');
      return (resp.data as List<dynamic>).map((dynamic e) => e as Map<String, dynamic>).toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> createNotificationRaw(Map<String, dynamic> raw) async {
    try {
      await _dio.post<dynamic>(
        '$_base/notification',
        queryParameters: <String, dynamic>{'forceSave': true},
        data: raw,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateNotificationRaw(Map<String, dynamic> notificationJson) async {
    try {
      await _dio.put<dynamic>(
        '$_base/notification/${notificationJson['id']}',
        queryParameters: <String, dynamic>{'forceSave': true},
        data: notificationJson,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> testNotificationRaw(Map<String, dynamic> notificationJson) async {
    try {
      await _dio.post<dynamic>('$_base/notification/test', data: notificationJson);
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

  // ---------------------------------------------------------------------------
  // Settings: import lists
  // ---------------------------------------------------------------------------

  Future<List<RadarrImportList>> getImportLists() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/importlist');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => RadarrImportList.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<List<Map<String, dynamic>>> getImportListSchema() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/importlist/schema');
      return (resp.data as List<dynamic>).map((dynamic e) => e as Map<String, dynamic>).toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> createImportListRaw(Map<String, dynamic> raw) async {
    try {
      await _dio.post<dynamic>(
        '$_base/importlist',
        queryParameters: <String, dynamic>{'forceSave': true},
        data: raw,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateImportListRaw(Map<String, dynamic> listJson) async {
    try {
      await _dio.put<dynamic>(
        '$_base/importlist/${listJson['id']}',
        queryParameters: <String, dynamic>{'forceSave': true},
        data: listJson,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> testImportListRaw(Map<String, dynamic> listJson) async {
    try {
      await _dio.post<dynamic>('$_base/importlist/test', data: listJson);
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

  // ---------------------------------------------------------------------------
  // Settings: config endpoints (single resource, get + update)
  // ---------------------------------------------------------------------------

  Future<RadarrHostConfig> getHostConfig() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/config/host');
      return RadarrHostConfig.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateHostConfigRaw(Map<String, dynamic> raw) async {
    try {
      await _dio.put<dynamic>('$_base/config/host/${raw['id']}', data: raw);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<RadarrNamingConfig> getNamingConfig() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/config/naming');
      return RadarrNamingConfig.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateNamingConfigRaw(Map<String, dynamic> raw) async {
    try {
      await _dio.put<dynamic>('$_base/config/naming/${raw['id']}', data: raw);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<RadarrMediaManagementConfig> getMediaManagementConfig() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/config/mediamanagement');
      return RadarrMediaManagementConfig.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateMediaManagementConfigRaw(Map<String, dynamic> raw) async {
    try {
      await _dio.put<dynamic>('$_base/config/mediamanagement/${raw['id']}', data: raw);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<RadarrUiConfig> getUiConfig() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/config/ui');
      return RadarrUiConfig.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateUiConfigRaw(Map<String, dynamic> raw) async {
    try {
      await _dio.put<dynamic>('$_base/config/ui/${raw['id']}', data: raw);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Settings: metadata consumers
  // ---------------------------------------------------------------------------

  Future<List<RadarrMetadataProvider>> getMetadataProviders() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/metadata');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => RadarrMetadataProvider.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateMetadataProviderRaw(Map<String, dynamic> raw) async {
    try {
      await _dio.put<dynamic>(
        '$_base/metadata/${raw['id']}',
        queryParameters: <String, dynamic>{'forceSave': true},
        data: raw,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> testMetadataProviderRaw(Map<String, dynamic> raw) async {
    try {
      await _dio.post<dynamic>('$_base/metadata/test', data: raw);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Settings: delay profiles
  // ---------------------------------------------------------------------------

  Future<List<RadarrDelayProfile>> getDelayProfiles() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/delayprofile');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => RadarrDelayProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> createDelayProfileRaw(Map<String, dynamic> raw) async {
    try {
      await _dio.post<dynamic>('$_base/delayprofile', data: raw);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateDelayProfileRaw(Map<String, dynamic> raw) async {
    try {
      await _dio.put<dynamic>('$_base/delayprofile/${raw['id']}', data: raw);
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

  // ---------------------------------------------------------------------------
  // Settings: custom formats
  // ---------------------------------------------------------------------------

  Future<List<RadarrCustomFormat>> getCustomFormats() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/customformat');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => RadarrCustomFormat.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> createCustomFormatRaw(Map<String, dynamic> raw) async {
    try {
      await _dio.post<dynamic>('$_base/customformat', data: raw);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateCustomFormatRaw(Map<String, dynamic> raw) async {
    try {
      await _dio.put<dynamic>('$_base/customformat/${raw['id']}', data: raw);
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

  // ---------------------------------------------------------------------------
  // Settings: quality definitions
  // ---------------------------------------------------------------------------

  Future<List<RadarrQualityDefinition>> getQualityDefinitions() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/qualitydefinition');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => RadarrQualityDefinition.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateQualityDefinitionRaw(Map<String, dynamic> raw) async {
    try {
      await _dio.put<dynamic>('$_base/qualitydefinition/${raw['id']}', data: raw);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Settings: quality profiles
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getQualityProfilesRaw() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/qualityprofile');
      return (resp.data as List<dynamic>).map((dynamic e) => e as Map<String, dynamic>).toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> getQualityProfileSchema() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/qualityprofile/schema');
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> createQualityProfileRaw(Map<String, dynamic> raw) async {
    try {
      await _dio.post<dynamic>('$_base/qualityprofile', data: raw);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateQualityProfileRaw(Map<String, dynamic> raw) async {
    try {
      await _dio.put<dynamic>('$_base/qualityprofile/${raw['id']}', data: raw);
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

  // ---------------------------------------------------------------------------
  // Settings: release profiles
  // ---------------------------------------------------------------------------

  Future<List<RadarrReleaseProfile>> getReleaseProfiles() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/releaseprofile');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => RadarrReleaseProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> createReleaseProfileRaw(Map<String, dynamic> raw) async {
    try {
      await _dio.post<dynamic>('$_base/releaseprofile', data: raw);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateReleaseProfileRaw(Map<String, dynamic> raw) async {
    try {
      await _dio.put<dynamic>('$_base/releaseprofile/${raw['id']}', data: raw);
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

  // ---------------------------------------------------------------------------
  // Settings: import-list exclusions
  // ---------------------------------------------------------------------------

  Future<List<RadarrImportListExclusion>> getImportListExclusions() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/importlistexclusion');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => RadarrImportListExclusion.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> createImportListExclusionRaw(Map<String, dynamic> raw) async {
    try {
      await _dio.post<dynamic>('$_base/importlistexclusion', data: raw);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> deleteImportListExclusion(int id) async {
    try {
      await _dio.delete<dynamic>('$_base/importlistexclusion/$id');
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Settings: auto-tagging rules
  // ---------------------------------------------------------------------------

  Future<List<RadarrAutoTaggingRule>> getAutoTaggingRules() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/autotagging');
      return (resp.data as List<dynamic>)
          .map((dynamic e) => RadarrAutoTaggingRule.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> createAutoTaggingRuleRaw(Map<String, dynamic> raw) async {
    try {
      await _dio.post<dynamic>('$_base/autotagging', data: raw);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> updateAutoTaggingRuleRaw(Map<String, dynamic> raw) async {
    try {
      await _dio.put<dynamic>('$_base/autotagging/${raw['id']}', data: raw);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<void> deleteAutoTaggingRule(int id) async {
    try {
      await _dio.delete<dynamic>('$_base/autotagging/$id');
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }
}
