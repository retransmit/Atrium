@Tags(<String>['live'])
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_lidarr/service_lidarr.dart';

/// Second half of the live write coverage: the resource types with no schema
/// endpoint, and the configuration screens.
///
/// Same contract as `live_writes_test.dart`: anything created is deleted,
/// anything saved is compared against what was there before, so a passing run
/// leaves the server untouched.
void main() {
  final String url = Platform.environment['LIDARR_URL'] ?? '';
  final String key = Platform.environment['LIDARR_KEY'] ?? '';
  final String scratchRoot =
      Platform.environment['LIDARR_SCRATCH_ROOT'] ?? '/data/media/zzatrium';

  if (url.isEmpty || key.isEmpty) {
    test('skipped: no live server configured', () {}, skip: true);
    return;
  }

  late Dio dio;
  late LidarrApi api;
  final List<String> log = <String>[];
  final List<String> failures = <String>[];

  setUpAll(() {
    dio = Dio(
      BaseOptions(
        baseUrl: url,
        headers: <String, String>{'X-Api-Key': key},
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 90),
      ),
    );
    api = LidarrApi(dio);
  });

  tearDownAll(() {
    // ignore: avoid_print
    print('\n=== writes (part 2) ===\n${log.join('\n')}\n');
  });

  void pass(String what) => log.add('  OK    $what');

  String describe(Object? why) {
    if (why is LidarrError) {
      final String m = why.message ?? why.description ?? 'unknown';
      return why.errors.isEmpty ? m : '$m ${why.errors}';
    }
    return '$why';
  }

  void fail(String what, Object? why) {
    log.add('  FAIL  $what -> ${describe(why)}');
    failures.add('$what: ${describe(why)}');
  }

  Future<List<dynamic>> raw(String path) async {
    final Response<dynamic> r = await dio.get<dynamic>(path);
    final dynamic d = r.data;
    return d is List ? d : <dynamic>[d];
  }

  /// Create, confirm listed, delete, confirm gone. For types Lidarr offers no
  /// schema for, so the smallest valid body is written out by hand.
  Future<void> bare({
    required String label,
    required String listPath,
    required Map<String, dynamic> body,
    required Future<dynamic> Function(Map<String, dynamic>) create,
    required Future<dynamic> Function(int) remove,
  }) async {
    int? id;
    try {
      final dynamic made = await create(body);
      // ignore: avoid_dynamic_calls
      final bool ok = made.isSuccess == true;
      // ignore: avoid_dynamic_calls
      final Object? err = made.error;
      if (!ok) {
        fail('$label create', err);
        return;
      }
      // ignore: avoid_dynamic_calls
      id = made.data?.id as int?;
      if (id == null) {
        fail('$label create', 'no id came back');
        return;
      }
      final List<dynamic> now = await raw(listPath);
      if (!now.any((dynamic e) => e is Map && e['id'] == id)) {
        fail('$label create', 'created but not listed');
        return;
      }
      final dynamic gone = await remove(id);
      // ignore: avoid_dynamic_calls
      final bool removed = gone.isSuccess == true;
      // ignore: avoid_dynamic_calls
      final Object? gerr = gone.error;
      if (!removed) {
        fail('$label delete', gerr);
        return;
      }
      final List<dynamic> post = await raw(listPath);
      if (post.any((dynamic e) => e is Map && e['id'] == id)) {
        fail('$label delete', 'still present after delete');
        return;
      }
      id = null;
      pass('$label create + delete');
    } on Object catch (e) {
      fail(label, '${e.runtimeType}: $e');
    } finally {
      if (id != null) {
        try {
          await remove(id);
          log.add('  ..    $label cleaned up after failure');
        } on Object catch (_) {
          log.add('  WARN  $label LEFT BEHIND id=$id');
        }
      }
    }
  }

  test('resource types without a schema can be created and deleted', () async {
    final int qpId =
        ((await raw('/api/v1/qualityprofile')).first as Map<String, dynamic>)
            ['id'] as int;
    final int mpId =
        ((await raw('/api/v1/metadataprofile')).first as Map<String, dynamic>)
            ['id'] as int;

    // Lidarr refuses a delay profile or an auto tag that applies to nothing,
    // so both need a real tag to point at. Removed again at the end.
    final dynamic madeTag =
        await api.tag.postTag(body: const TagResource(label: 'zz-atrium-tmp'));
    // ignore: avoid_dynamic_calls
    final int tmpTagId = madeTag.data!.id as int;
    addTearDown(() => api.tag.deleteTagById(id: tmpTagId));

    await bare(
      label: 'rootFolder',
      listPath: '/api/v1/rootfolder',
      body: <String, dynamic>{
        'path': scratchRoot,
        'name': 'zz-atrium',
        'defaultQualityProfileId': qpId,
        'defaultMetadataProfileId': mpId,
        'defaultMonitorOption': 'all',
        'defaultNewItemMonitorOption': 'all',
        'defaultTags': <int>[],
      },
      create: (Map<String, dynamic> b) =>
          api.rootFolder.postRootfolder(body: RootFolderResource.fromJson(b)),
      remove: (int id) => api.rootFolder.deleteRootfolderById(id: id),
    );

    await bare(
      label: 'delayProfile',
      listPath: '/api/v1/delayprofile',
      body: <String, dynamic>{
        'enableUsenet': true,
        'enableTorrent': true,
        'preferredProtocol': 'usenet',
        'usenetDelay': 0,
        'torrentDelay': 0,
        'bypassIfHighestQuality': false,
        'bypassIfAboveCustomFormatScore': false,
        'minimumCustomFormatScore': 0,
        'order': 99,
        'tags': <int>[tmpTagId],
      },
      create: (Map<String, dynamic> b) => api.delayProfile
          .postDelayprofile(body: DelayProfileResource.fromJson(b)),
      remove: (int id) => api.delayProfile.deleteDelayprofileById(id: id),
    );

    await bare(
      label: 'releaseProfile',
      listPath: '/api/v1/releaseprofile',
      body: <String, dynamic>{
        'enabled': true,
        'required': <String>['zzatrium'],
        'ignored': <String>[],
        'indexerId': 0,
        'tags': <int>[],
      },
      create: (Map<String, dynamic> b) => api.releaseProfile
          .postReleaseprofile(body: ReleaseProfileResource.fromJson(b)),
      remove: (int id) => api.releaseProfile.deleteReleaseprofileById(id: id),
    );

    await bare(
      label: 'customFormat',
      listPath: '/api/v1/customformat',
      body: <String, dynamic>{
        'name': 'zz-atrium-cf',
        'includeCustomFormatWhenRenaming': false,
        'specifications': <dynamic>[
          <String, dynamic>{
            'name': 'zz',
            'implementation': 'ReleaseTitleSpecification',
            'negate': false,
            'required': false,
            'fields': <dynamic>[
              <String, dynamic>{'name': 'value', 'value': 'zzatrium'},
            ],
          },
        ],
      },
      create: (Map<String, dynamic> b) => api.customFormat
          .postCustomformat(body: CustomFormatResource.fromJson(b)),
      remove: (int id) => api.customFormat.deleteCustomformatById(id: id),
    );

    await bare(
      label: 'autoTagging',
      listPath: '/api/v1/autotagging',
      body: <String, dynamic>{
        'name': 'zz-atrium-at',
        'removeTagsAutomatically': false,
        'tags': <int>[tmpTagId],
        'specifications': <dynamic>[
          <String, dynamic>{
            'name': 'zz',
            'implementation': 'GenreSpecification',
            'negate': false,
            'required': false,
            'fields': <dynamic>[
              <String, dynamic>{'name': 'value', 'value': 'zzatrium'},
            ],
          },
        ],
      },
      create: (Map<String, dynamic> b) => api.autoTagging
          .postAutotagging(body: AutoTaggingResource.fromJson(b)),
      remove: (int id) => api.autoTagging.deleteAutotaggingById(id: id),
    );

    expect(failures, isEmpty, reason: failures.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 5)),);

  test('saving configuration back unchanged does not move any setting',
      () async {
    /// Reads a config, saves it straight back through the app, reads it again
    /// and compares. A save that quietly rewrites settings is the worst thing
    /// that can go wrong on these screens, so the comparison matters far more
    /// than the status code.
    Future<void> roundTrip(
      String label,
      String path,
      Future<dynamic> Function(int id, Map<String, dynamic> body) put,
    ) async {
      try {
        final Response<dynamic> before = await dio.get<dynamic>(path);
        final Map<String, dynamic> was =
            Map<String, dynamic>.from(before.data as Map);
        final int id = was['id'] as int;

        final dynamic saved =
            await put(id, Map<String, dynamic>.from(was));
        // ignore: avoid_dynamic_calls
        final bool ok = saved.isSuccess == true;
        // ignore: avoid_dynamic_calls
        final Object? err = saved.error;
        if (!ok) {
          fail('$label save', err);
          return;
        }

        final Response<dynamic> after = await dio.get<dynamic>(path);
        final Map<String, dynamic> now =
            Map<String, dynamic>.from(after.data as Map);
        final List<String> moved = <String>[];
        for (final String k in was.keys) {
          if ('${was[k]}' != '${now[k]}') {
            moved.add('$k: ${was[k]} -> ${now[k]}');
          }
        }
        if (moved.isEmpty) {
          pass('$label save is lossless');
        } else {
          fail('$label save CHANGED SETTINGS', moved.join('; '));
        }
      } on Object catch (e) {
        fail(label, '${e.runtimeType}: $e');
      }
    }

    await roundTrip(
      'namingConfig',
      '/api/v1/config/naming',
      (int id, Map<String, dynamic> b) => api.namingConfig.putConfigNamingById(
        id: '$id',
        body: NamingConfigResource.fromJson(b),
      ),
    );
    await roundTrip(
      'mediaManagementConfig',
      '/api/v1/config/mediamanagement',
      (int id, Map<String, dynamic> b) =>
          api.mediaManagementConfig.putConfigMediamanagementById(
        id: '$id',
        body: MediaManagementConfigResource.fromJson(b),
      ),
    );
    await roundTrip(
      'indexerConfig',
      '/api/v1/config/indexer',
      (int id, Map<String, dynamic> b) =>
          api.indexerConfig.putConfigIndexerById(
        id: '$id',
        body: IndexerConfigResource.fromJson(b),
      ),
    );
    await roundTrip(
      'hostConfig',
      '/api/v1/config/host',
      (int id, Map<String, dynamic> b) => api.hostConfig.putConfigHostById(
        id: '$id',
        body: HostConfigResource.fromJson(b),
      ),
    );

    expect(failures, isEmpty, reason: failures.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 5)),);

  test('existing providers and profiles can be saved back unchanged', () async {
    /// The edit path for things that already exist, which is what the settings
    /// screens actually do most of the time.
    Future<void> resave(
      String label,
      String listPath,
      Future<dynamic> Function(int id, Map<String, dynamic> body) put,
    ) async {
      try {
        final List<dynamic> all = await raw(listPath);
        if (all.isEmpty || all.first is! Map) {
          log.add('  SKIP  $label (none configured)');
          return;
        }
        final Map<String, dynamic> was =
            Map<String, dynamic>.from(all.first as Map);
        final int id = was['id'] as int;
        final dynamic saved = await put(id, Map<String, dynamic>.from(was));
        // ignore: avoid_dynamic_calls
        final bool ok = saved.isSuccess == true;
        // ignore: avoid_dynamic_calls
        final Object? err = saved.error;
        if (!ok) {
          fail('$label resave', err);
          return;
        }
        final List<dynamic> after = await raw(listPath);
        final Map<String, dynamic> now = Map<String, dynamic>.from(
          after.firstWhere((dynamic e) => e is Map && e['id'] == id) as Map,
        );
        final List<String> moved = <String>[];
        for (final String k in was.keys) {
          if ('${was[k]}' != '${now[k]}') {
            moved.add('$k changed');
          }
        }
        if (moved.isEmpty) {
          pass('$label resave is lossless');
        } else {
          fail('$label resave CHANGED IT', moved.join('; '));
        }
      } on Object catch (e) {
        fail(label, '${e.runtimeType}: $e');
      }
    }

    await resave(
      'indexer',
      '/api/v1/indexer',
      (int id, Map<String, dynamic> b) => api.indexer
          .putIndexerById(id: id, body: IndexerResource.fromJson(b)),
    );
    await resave(
      'downloadClient',
      '/api/v1/downloadclient',
      (int id, Map<String, dynamic> b) => api.downloadClient
          .putDownloadclientById(
        id: id,
        body: DownloadClientResource.fromJson(b),
      ),
    );
    await resave(
      'qualityProfile',
      '/api/v1/qualityprofile',
      (int id, Map<String, dynamic> b) => api.qualityProfile
          .putQualityprofileById(
        id: '$id',
        body: QualityProfileResource.fromJson(b),
      ),
    );
    await resave(
      'metadataProfile',
      '/api/v1/metadataprofile',
      (int id, Map<String, dynamic> b) => api.metadataProfile
          .putMetadataprofileById(
        id: '$id',
        body: MetadataProfileResource.fromJson(b),
      ),
    );
    await resave(
      'delayProfile',
      '/api/v1/delayprofile',
      (int id, Map<String, dynamic> b) => api.delayProfile
          .putDelayprofileById(
        id: '$id',
        body: DelayProfileResource.fromJson(b),
      ),
    );
    await resave(
      'metadata',
      '/api/v1/metadata',
      (int id, Map<String, dynamic> b) => api.metadata
          .putMetadataById(id: id, body: MetadataResource.fromJson(b)),
    );
    await resave(
      'qualityDefinition',
      '/api/v1/qualitydefinition',
      (int id, Map<String, dynamic> b) => api.qualityDefinition
          .putQualitydefinitionById(
        id: '$id',
        body: QualityDefinitionResource.fromJson(b),
      ),
    );

    expect(failures, isEmpty, reason: failures.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 8)),);
}
