import 'package:dio/dio.dart';

import 'generated/generated.dart';

/// Drops null values from outgoing request bodies.
///
/// The generated models make every field nullable and serialise all of them,
/// so anything the app has not filled in goes out as an explicit null. Lidarr
/// declares those same fields as non-nullable value types, and its
/// deserialiser refuses a null outright: the request fails with a JSON
/// conversion error before any validation runs, naming only the first
/// offender. That is what broke adding an artist (`id`), every provider and
/// profile (`id`, and nested ids inside quality profile items), and adding a
/// root folder (`accessible`).
///
/// Omitting the key instead lets Lidarr apply its own default, which is what
/// its API expects from a partial body. Nulls are never meaningful here: a
/// request carrying one is rejected wholesale, so there is nothing to
/// preserve by sending them.
class _StripNullsFix extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Not filtered by verb: the bulk endpoints send their payload on a DELETE,
    // and a null is just as fatal there as on a create.
    options.data = _clean(options.data);
    handler.next(options);
  }

  static Object? _clean(Object? node) {
    if (node is Map) {
      final Map<String, dynamic> out = <String, dynamic>{};
      node.forEach((Object? k, Object? v) {
        if (v != null) out['$k'] = _clean(v);
      });
      return out;
    }
    if (node is List) {
      return node.map(_clean).toList();
    }
    return node;
  }
}

/// Unified instance-scoped API client aggregating all generated Lidarr Raw API endpoints.
class LidarrApi {
  final Dio dio;

  LidarrApi(this.dio) {
    // First in the chain so it still applies when a caller (a test, say) has
    // already installed an interceptor that answers requests itself.
    if (!dio.interceptors.any((Interceptor i) => i is _StripNullsFix)) {
      dio.interceptors.insert(0, _StripNullsFix());
    }
  }

  /// Dispatches a command by name with optional parameter payload (e.g. RefreshArtist, ArtistSearch, AlbumSearch).
  Future<ApiResponse<CommandResource>> executeCommand(
    String name, [
    Map<String, dynamic>? extraBody,
  ]) async {
    try {
      final Response<dynamic> resp = await dio.post<dynamic>(
        '/api/v1/command',
        data: <String, dynamic>{
          'name': name,
          if (extraBody != null) ...extraBody,
        },
      );
      final CommandResource? data = resp.data is Map<String, dynamic>
          ? CommandResource.fromJson(resp.data as Map<String, dynamic>)
          : null;
      return ApiResponse.success(data, statusCode: resp.statusCode);
    } on DioException catch (e) {
      return ApiResponse.error(
        LidarrError.fromDio(e),
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Fetches raw log file text content with candidate endpoint fallback.
  Future<ApiResponse<String>> getLogFileContent(
    String filename, {
    String? contentsUrl,
    String? downloadUrl,
  }) async {
    final List<String> candidates = <String>[
      if (downloadUrl != null && downloadUrl.isNotEmpty) downloadUrl,
      '/logfile/${Uri.encodeComponent(filename)}',
      if (contentsUrl != null && contentsUrl.isNotEmpty) contentsUrl,
      '/api/v1/log/file/${Uri.encodeComponent(filename)}',
    ];

    DioException? lastError;
    for (final String path in candidates) {
      try {
        final Response<String> resp = await dio.get<String>(
          path,
          options: Options(responseType: ResponseType.plain),
        );
        final String body = resp.data ?? '';
        if (body.trimLeft().startsWith('<!DOCTYPE html') ||
            body.trimLeft().startsWith('<html')) {
          continue;
        }
        return ApiResponse.success(body, statusCode: resp.statusCode);
      } on DioException catch (e) {
        lastError = e;
      } catch (_) {}
    }

    if (lastError != null) {
      return ApiResponse.error(
        LidarrError.fromDio(lastError),
        statusCode: lastError.response?.statusCode,
      );
    }
    return const ApiResponse.error(
      LidarrError(message: 'Failed to read log file contents'),
      statusCode: 404,
    );
  }

  RawAlbumApi get album => RawAlbumApi(dio);
  RawAlbumLookupApi get albumLookup => RawAlbumLookupApi(dio);
  RawAlbumStudioApi get albumStudio => RawAlbumStudioApi(dio);
  RawApiInfoApi get apiInfo => RawApiInfoApi(dio);
  RawArtistApi get artist => RawArtistApi(dio);
  RawArtistEditorApi get artistEditor => RawArtistEditorApi(dio);
  RawArtistLookupApi get artistLookup => RawArtistLookupApi(dio);
  RawAuthenticationApi get authentication => RawAuthenticationApi(dio);
  RawAutoTaggingApi get autoTagging => RawAutoTaggingApi(dio);
  RawBackupApi get backup => RawBackupApi(dio);
  RawBlocklistApi get blocklist => RawBlocklistApi(dio);
  RawCalendarApi get calendar => RawCalendarApi(dio);
  RawCalendarFeedApi get calendarFeed => RawCalendarFeedApi(dio);
  RawCommandApi get command => RawCommandApi(dio);
  RawCustomFilterApi get customFilter => RawCustomFilterApi(dio);
  RawCustomFormatApi get customFormat => RawCustomFormatApi(dio);
  RawCutoffApi get cutoff => RawCutoffApi(dio);
  RawDelayProfileApi get delayProfile => RawDelayProfileApi(dio);
  RawDiskSpaceApi get diskSpace => RawDiskSpaceApi(dio);
  RawDownloadClientApi get downloadClient => RawDownloadClientApi(dio);
  RawDownloadClientConfigApi get downloadClientConfig =>
      RawDownloadClientConfigApi(dio);
  RawFileSystemApi get fileSystem => RawFileSystemApi(dio);
  RawHealthApi get health => RawHealthApi(dio);
  RawHistoryApi get history => RawHistoryApi(dio);
  RawHostConfigApi get hostConfig => RawHostConfigApi(dio);
  RawImportListApi get importList => RawImportListApi(dio);
  RawImportListExclusionApi get importListExclusion =>
      RawImportListExclusionApi(dio);
  RawIndexerApi get indexer => RawIndexerApi(dio);
  RawIndexerConfigApi get indexerConfig => RawIndexerConfigApi(dio);
  RawIndexerFlagApi get indexerFlag => RawIndexerFlagApi(dio);
  RawLanguageApi get language => RawLanguageApi(dio);
  RawLocalizationApi get localization => RawLocalizationApi(dio);
  RawLogApi get log => RawLogApi(dio);
  RawLogFileApi get logFile => RawLogFileApi(dio);
  RawManualImportApi get manualImport => RawManualImportApi(dio);
  RawMediaCoverApi get mediaCover => RawMediaCoverApi(dio);
  RawMediaManagementConfigApi get mediaManagementConfig =>
      RawMediaManagementConfigApi(dio);
  RawMetadataApi get metadata => RawMetadataApi(dio);
  RawMetadataProfileApi get metadataProfile => RawMetadataProfileApi(dio);
  RawMetadataProfileSchemaApi get metadataProfileSchema =>
      RawMetadataProfileSchemaApi(dio);
  RawMetadataProviderConfigApi get metadataProviderConfig =>
      RawMetadataProviderConfigApi(dio);
  RawMissingApi get missing => RawMissingApi(dio);
  RawNamingConfigApi get namingConfig => RawNamingConfigApi(dio);
  RawNotificationApi get notification => RawNotificationApi(dio);
  RawParseApi get parse => RawParseApi(dio);
  RawPingApi get ping => RawPingApi(dio);
  RawQualityDefinitionApi get qualityDefinition => RawQualityDefinitionApi(dio);
  RawQualityProfileApi get qualityProfile => RawQualityProfileApi(dio);
  RawQualityProfileSchemaApi get qualityProfileSchema =>
      RawQualityProfileSchemaApi(dio);
  RawQueueApi get queue => RawQueueApi(dio);
  RawQueueActionApi get queueAction => RawQueueActionApi(dio);
  RawQueueDetailsApi get queueDetails => RawQueueDetailsApi(dio);
  RawQueueStatusApi get queueStatus => RawQueueStatusApi(dio);
  RawReleaseApi get release => RawReleaseApi(dio);
  RawReleaseProfileApi get releaseProfile => RawReleaseProfileApi(dio);
  RawReleasePushApi get releasePush => RawReleasePushApi(dio);
  RawRemotePathMappingApi get remotePathMapping => RawRemotePathMappingApi(dio);
  RawRenameTrackApi get renameTrack => RawRenameTrackApi(dio);
  RawRetagTrackApi get retagTrack => RawRetagTrackApi(dio);
  RawRootFolderApi get rootFolder => RawRootFolderApi(dio);
  RawSearchApi get search => RawSearchApi(dio);
  RawStaticResourceApi get staticResource => RawStaticResourceApi(dio);
  RawSystemApi get system => RawSystemApi(dio);
  RawTagApi get tag => RawTagApi(dio);
  RawTagDetailsApi get tagDetails => RawTagDetailsApi(dio);
  RawTaskApi get task => RawTaskApi(dio);
  RawTrackApi get track => RawTrackApi(dio);
  RawTrackFileApi get trackFile => RawTrackFileApi(dio);
  RawUiConfigApi get uiConfig => RawUiConfigApi(dio);
  RawUpdateApi get update => RawUpdateApi(dio);
  RawUpdateLogFileApi get updateLogFile => RawUpdateLogFileApi(dio);

  /// Fetches directory entries for interactive filesystem browsing.
  Future<List<Map<String, dynamic>>> getFileSystem({
    String? path,
    bool includeFiles = false,
  }) async {
    try {
      final Response<dynamic> resp = await dio.get<dynamic>(
        '/api/v1/filesystem',
        queryParameters: <String, dynamic>{
          if (path != null && path.isNotEmpty) 'path': path,
          'includeFiles': includeFiles,
        },
      );
      if (resp.data is Map<String, dynamic>) {
        final map = resp.data as Map<String, dynamic>;
        final dirs = (map['directories'] as List<dynamic>?) ?? <dynamic>[];
        return dirs.whereType<Map<String, dynamic>>().toList();
      } else if (resp.data is List<dynamic>) {
        return (resp.data as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .toList();
      }
    } catch (_) {}
    return <Map<String, dynamic>>[];
  }
}
