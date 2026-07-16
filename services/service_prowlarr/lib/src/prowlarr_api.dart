import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';

import 'models/prowlarr_application.dart';
import 'models/prowlarr_history.dart';
import 'models/prowlarr_indexer.dart';
import 'models/prowlarr_indexer_stats.dart';
import 'models/prowlarr_release.dart';
import 'models/prowlarr_system.dart';

/// Thin typed client over the Prowlarr v1 REST API.
///
/// Construction takes a [Dio] already configured for the instance (base URL +
/// `X-Api-Key`). Every method maps transport failures to [NetworkException].
class ProwlarrApi {
  ProwlarrApi(this._dio);

  final Dio _dio;

  static const String _base = 'api/v1';

  Future<List<ProwlarrIndexer>> getIndexers() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/indexer');
      return (resp.data as List<dynamic>)
          .map(
            (dynamic e) => ProwlarrIndexer.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  Future<ProwlarrIndexerStats> getIndexerStats() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/indexerstats');
      return ProwlarrIndexerStats.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Tests a single indexer; throws on failure, returns normally on success.
  ///
  /// The *arr test route wants the full indexer resource as the body
  /// (`POST /indexer/test`); there is no per-id test route - POSTing to
  /// `/indexer/{id}/test` is a 405. The test waits on the live tracker, so
  /// it gets extra receive-timeout headroom.
  Future<void> testIndexer(int id) async {
    final Map<String, dynamic> raw = await getIndexerRaw(id);
    await testIndexerRaw(raw);
  }

  /// Tests an arbitrary (possibly unsaved) indexer definition - used by the
  /// add/edit form before saving. Waits on the live tracker, so it gets extra
  /// receive-timeout headroom.
  Future<void> testIndexerRaw(Map<String, dynamic> indexer) async {
    try {
      await _dio.post<dynamic>(
        '$_base/indexer/test',
        data: indexer,
        options: Options(receiveTimeout: const Duration(seconds: 60)),
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// All addable indexer definitions (`GET /indexer/schema`). Prowlarr returns
  /// hundreds (every Cardigann/Torznab/Newznab tracker), so the picker filters
  /// them. Kept as raw maps because the add POST round-trips the whole object.
  Future<List<Map<String, dynamic>>> getIndexerSchemas() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/indexer/schema');
      return (resp.data as List<dynamic>)
          .map(
            (dynamic e) =>
                Map<String, dynamic>.from(e as Map<dynamic, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Creates a new indexer (`POST /indexer`). `forceSave=true` for the same
  /// reason as [updateIndexerRaw] - don't block the save on tracker reachability.
  Future<void> createIndexerRaw(Map<String, dynamic> indexer) async {
    try {
      await _dio.post<dynamic>(
        '$_base/indexer',
        queryParameters: <String, dynamic>{'forceSave': 'true'},
        data: indexer,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Deletes an indexer (`DELETE /indexer/{id}`).
  Future<void> deleteIndexer(int id) async {
    try {
      await _dio.delete<dynamic>('$_base/indexer/$id');
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// App (sync) profiles (`GET /appprofile`), for the indexer form's
  /// sync-profile picker. Raw maps - only id/name are needed.
  Future<List<Map<String, dynamic>>> getAppProfiles() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/appprofile');
      return (resp.data as List<dynamic>)
          .map(
            (dynamic e) =>
                Map<String, dynamic>.from(e as Map<dynamic, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Raw indexer object for read-modify-write updates. The PUT endpoint
  /// expects the complete definition (fields, capabilities, ...), and
  /// [ProwlarrIndexer] is a trimmed projection of it.
  Future<Map<String, dynamic>> getIndexerRaw(int id) async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/indexer/$id');
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// `forceSave=true` skips Prowlarr's test-on-save: without it, enabling an
  /// indexer whose tracker is unreachable (or slow) rejects the PUT with a
  /// validation error. A user flipping the enable switch should not be
  /// blocked on tracker reachability.
  Future<void> updateIndexerRaw(Map<String, dynamic> indexer) async {
    try {
      await _dio.put<dynamic>(
        '$_base/indexer/${indexer['id']}',
        queryParameters: <String, dynamic>{'forceSave': 'true'},
        data: indexer,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Enables or disables an indexer via read-modify-write on the raw object.
  Future<void> setIndexerEnabled(int id, {required bool enabled}) async {
    final Map<String, dynamic> raw = await getIndexerRaw(id);
    raw['enable'] = enabled;
    await updateIndexerRaw(raw);
  }

  /// Manual search across indexers. Empty [indexerIds] means all enabled
  /// indexers.
  ///
  /// The request fans out to every indexer and waits for the slow ones, so it
  /// gets far more receive-timeout headroom than the Dio default.
  Future<List<ProwlarrRelease>> search(
    String query, {
    List<int> indexerIds = const <int>[],
    List<int> categories = const <int>[],
    int limit = 150,
  }) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/search',
        queryParameters: <String, dynamic>{
          'query': query,
          'type': 'search',
          'limit': limit,
          'offset': 0,
          if (indexerIds.isNotEmpty) 'indexerIds': indexerIds,
          if (categories.isNotEmpty) 'categories': categories,
        },
        options: Options(receiveTimeout: const Duration(seconds: 120)),
      );
      return (resp.data as List<dynamic>)
          .map(
            (dynamic e) => ProwlarrRelease.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Asks Prowlarr to grab [release] and push it to the download client
  /// configured for its protocol. Only `guid` + `indexerId` are needed -
  /// Prowlarr resolves the release from its cache.
  Future<void> grabRelease(ProwlarrRelease release) async {
    try {
      await _dio.post<dynamic>(
        '$_base/search',
        data: <String, dynamic>{
          'guid': release.guid,
          'indexerId': release.indexerId,
        },
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  // --- Applications (Sonarr/Radarr/... sync targets) ---

  /// All configured application targets (`GET /applications`).
  Future<List<ProwlarrApplication>> getApplications() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/applications');
      return (resp.data as List<dynamic>)
          .map(
            (dynamic e) =>
                ProwlarrApplication.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Addable application definitions (`GET /applications/schema`): Sonarr,
  /// Radarr, Lidarr, Readarr, ... Kept as raw maps because the add POST
  /// round-trips the whole object.
  Future<List<Map<String, dynamic>>> getApplicationSchemas() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/applications/schema');
      return (resp.data as List<dynamic>)
          .map(
            (dynamic e) =>
                Map<String, dynamic>.from(e as Map<dynamic, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Raw application object for read-modify-write updates
  /// (`GET /applications/{id}`).
  Future<Map<String, dynamic>> getApplicationRaw(int id) async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/applications/$id');
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Creates an application (`POST /applications`). `forceSave=true` skips the
  /// connectivity test-on-save, mirroring the indexer create.
  Future<void> createApplicationRaw(Map<String, dynamic> app) async {
    try {
      await _dio.post<dynamic>(
        '$_base/applications',
        queryParameters: <String, dynamic>{'forceSave': 'true'},
        data: app,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Updates an application (`PUT /applications/{id}`, `forceSave=true`).
  Future<void> updateApplicationRaw(Map<String, dynamic> app) async {
    try {
      await _dio.put<dynamic>(
        '$_base/applications/${app['id']}',
        queryParameters: <String, dynamic>{'forceSave': 'true'},
        data: app,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Deletes an application (`DELETE /applications/{id}`).
  Future<void> deleteApplication(int id) async {
    try {
      await _dio.delete<dynamic>('$_base/applications/$id');
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Tests a (possibly unsaved) application definition
  /// (`POST /applications/test`). Waits on the live *arr connection, so it gets
  /// extra receive-timeout headroom.
  Future<void> testApplicationRaw(Map<String, dynamic> app) async {
    try {
      await _dio.post<dynamic>(
        '$_base/applications/test',
        data: app,
        options: Options(receiveTimeout: const Duration(seconds: 60)),
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  // --- Generic provider resources: download clients, notifications, indexer
  // proxies. They share Servarr's /{endpoint}, /{endpoint}/schema,
  // /{endpoint}/test and /{endpoint}/{id} routes, so one set of raw-map helpers
  // serves them all. (Applications use the dedicated methods above for their
  // typed list model and sync-level handling.)

  /// Configured instances of a provider resource (`GET /{endpoint}`).
  Future<List<Map<String, dynamic>>> getProviders(String endpoint) async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/$endpoint');
      return (resp.data as List<dynamic>)
          .map(
            (dynamic e) =>
                Map<String, dynamic>.from(e as Map<dynamic, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Addable definitions for a provider resource (`GET /{endpoint}/schema`).
  Future<List<Map<String, dynamic>>> getProviderSchemas(String endpoint) async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/$endpoint/schema');
      return (resp.data as List<dynamic>)
          .map(
            (dynamic e) =>
                Map<String, dynamic>.from(e as Map<dynamic, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Raw provider object for read-modify-write updates (`GET /{endpoint}/{id}`).
  Future<Map<String, dynamic>> getProviderRaw(String endpoint, int id) async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/$endpoint/$id');
      return resp.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Creates a provider (`POST /{endpoint}`, `forceSave=true`).
  Future<void> createProvider(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      await _dio.post<dynamic>(
        '$_base/$endpoint',
        queryParameters: <String, dynamic>{'forceSave': 'true'},
        data: body,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Updates a provider (`PUT /{endpoint}/{id}`, `forceSave=true`).
  Future<void> updateProvider(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      await _dio.put<dynamic>(
        '$_base/$endpoint/${body['id']}',
        queryParameters: <String, dynamic>{'forceSave': 'true'},
        data: body,
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Deletes a provider (`DELETE /{endpoint}/{id}`).
  Future<void> deleteProvider(String endpoint, int id) async {
    try {
      await _dio.delete<dynamic>('$_base/$endpoint/$id');
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Tests a (possibly unsaved) provider definition (`POST /{endpoint}/test`).
  /// Waits on the live connection, so it gets extra receive-timeout headroom.
  Future<void> testProvider(String endpoint, Map<String, dynamic> body) async {
    try {
      await _dio.post<dynamic>(
        '$_base/$endpoint/test',
        data: body,
        options: Options(receiveTimeout: const Duration(seconds: 60)),
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Paged history, newest first. [eventType] filters server-side by
  /// HistoryEventType (1 grabbed, 2 query, 3 RSS, 4 auth); null returns all.
  /// Filtering server-side is essential - RSS syncs flood the feed and would
  /// otherwise bury grabs many pages deep.
  Future<ProwlarrHistoryPage> getHistory({
    int page = 1,
    int pageSize = 50,
    int? eventType,
  }) async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>(
        '$_base/history',
        queryParameters: <String, dynamic>{
          'page': page,
          'pageSize': pageSize,
          'sortKey': 'date',
          'sortDirection': 'descending',
          if (eventType != null) 'eventType': eventType,
        },
      );
      return ProwlarrHistoryPage.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// System status (version, OS, runtime, ...).
  Future<ProwlarrSystemStatus> getSystemStatus() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/system/status');
      return ProwlarrSystemStatus.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Active health warnings/errors (`GET /health`).
  Future<List<ProwlarrHealth>> getHealth() async {
    try {
      final Response<dynamic> resp = await _dio.get<dynamic>('$_base/health');
      return (resp.data as List<dynamic>)
          .map(
            (dynamic e) => ProwlarrHealth.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Scheduled tasks (`GET /system/task`).
  Future<List<ProwlarrSystemTask>> getTasks() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/system/task');
      return (resp.data as List<dynamic>)
          .map(
            (dynamic e) =>
                ProwlarrSystemTask.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Existing backups (`GET /system/backup`).
  Future<List<ProwlarrBackup>> getBackups() async {
    try {
      final Response<dynamic> resp =
          await _dio.get<dynamic>('$_base/system/backup');
      return (resp.data as List<dynamic>)
          .map(
            (dynamic e) => ProwlarrBackup.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Runs a command (`POST /command`), e.g. a task's `taskName` or `Backup`.
  Future<void> runCommand(String name) async {
    try {
      await _dio.post<dynamic>(
        '$_base/command',
        data: <String, dynamic>{'name': name},
      );
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }

  /// Deletes a backup (`DELETE /system/backup/{id}`).
  Future<void> deleteBackup(int id) async {
    try {
      await _dio.delete<dynamic>('$_base/system/backup/$id');
    } on DioException catch (e) {
      throw NetworkException.fromDio(e);
    }
  }
}
