@Tags(<String>['live'])
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_lidarr/service_lidarr.dart';

/// Exercises every write the Lidarr module can perform, against a real server.
///
/// Runs through [LidarrApi] rather than raw HTTP so it covers the same
/// generated client, models and interceptors the screens use. Everything it
/// creates it deletes again, and anything it edits it puts back, so a passing
/// run leaves the server as it found it.
///
/// Needs LIDARR_URL and LIDARR_KEY. Never runs in the normal suite.
void main() {
  final String url = Platform.environment['LIDARR_URL'] ?? '';
  final String key = Platform.environment['LIDARR_KEY'] ?? '';

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
    print('\n=== writes ===\n${log.join('\n')}\n');
  });

  void pass(String what) => log.add('  OK    $what');

  /// LidarrError has no useful toString, so pull the message out by hand.
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

  /// Raw fetch, used to confirm a create or delete really landed.
  Future<List<dynamic>> raw(String path) async {
    final Response<dynamic> r = await dio.get<dynamic>(path);
    final dynamic d = r.data;
    return d is List ? d : <dynamic>[d];
  }

  /// Creates from the server's own schema, checks it exists, deletes it,
  /// checks it is gone. The create is the case that was broken, so it is the
  /// one worth running against every provider type rather than just one.
  Future<void> lifecycle({
    required String label,
    required String schemaPath,
    required String listPath,
    required Future<dynamic> Function(Map<String, dynamic> body) create,
    required Future<dynamic> Function(int id) remove,
    Map<String, dynamic> Function(Map<String, dynamic>)? tweak,
    int schemaIndex = 0,
  }) async {
    const String name = 'zz-atrium-test';
    int? madeId;
    try {
      final List<dynamic> schemas = await raw(schemaPath);
      if (schemas.isEmpty || schemas.first is! Map) {
        log.add('  SKIP  $label (no schema)');
        return;
      }
      final Map<String, dynamic> body = Map<String, dynamic>.from(
        schemas[schemaIndex.clamp(0, schemas.length - 1)] as Map,
      )..['name'] = name;
      final Map<String, dynamic> payload =
          tweak == null ? body : tweak(body);

      final dynamic made = await create(payload);
      // ignore: avoid_dynamic_calls
      if (made.isSuccess != true) {
        // ignore: avoid_dynamic_calls
        fail('$label create', made.error);
        return;
      }
      // ignore: avoid_dynamic_calls
      madeId = made.data?.id as int?;
      if (madeId == null) {
        fail('$label create', 'no id came back');
        return;
      }

      final List<dynamic> after = await raw(listPath);
      final bool there = after.any(
        (dynamic e) => e is Map && e['id'] == madeId,
      );
      if (!there) {
        fail('$label create', 'created but not in the list');
        return;
      }

      final dynamic gone = await remove(madeId);
      // ignore: avoid_dynamic_calls
      if (gone.isSuccess != true) {
        // ignore: avoid_dynamic_calls
        fail('$label delete', gone.error);
        return;
      }
      final List<dynamic> post = await raw(listPath);
      if (post.any((dynamic e) => e is Map && e['id'] == madeId)) {
        fail('$label delete', 'still present after delete');
        return;
      }
      madeId = null;
      pass('$label create + delete');
    } on Object catch (e) {
      fail(label, '${e.runtimeType}: $e');
    } finally {
      if (madeId != null) {
        // Never leave a test object behind, even on an unexpected throw.
        try {
          await remove(madeId);
          log.add('  ..    $label cleaned up after failure');
        } on Object catch (_) {
          log.add('  WARN  $label LEFT BEHIND id=$madeId');
        }
      }
    }
  }

  test('providers can be created and deleted', () async {
    final List<dynamic> folders = await raw('/api/v1/rootfolder');
    final String rootFolder =
        (folders.first as Map<String, dynamic>)['path'] as String;
    final List<dynamic> qps = await raw('/api/v1/qualityprofile');
    final int qualityProfileId = (qps.first as Map<String, dynamic>)['id'] as int;
    final List<dynamic> mps = await raw('/api/v1/metadataprofile');
    final int metadataProfileId =
        (mps.first as Map<String, dynamic>)['id'] as int;

    await lifecycle(
      label: 'indexer',
      schemaPath: '/api/v1/indexer/schema',
      listPath: '/api/v1/indexer',
      create: (Map<String, dynamic> b) =>
          api.indexer.postIndexer(body: IndexerResource.fromJson(b)),
      remove: (int id) => api.indexer.deleteIndexerById(id: id),
    );

    await lifecycle(
      label: 'downloadClient',
      schemaPath: '/api/v1/downloadclient/schema',
      listPath: '/api/v1/downloadclient',
      create: (Map<String, dynamic> b) => api.downloadClient
          .postDownloadclient(body: DownloadClientResource.fromJson(b)),
      remove: (int id) =>
          api.downloadClient.deleteDownloadclientById(id: id),
    );

    await lifecycle(
      label: 'notification',
      schemaPath: '/api/v1/notification/schema',
      listPath: '/api/v1/notification',
      create: (Map<String, dynamic> b) => api.notification
          .postNotification(body: NotificationResource.fromJson(b)),
      remove: (int id) => api.notification.deleteNotificationById(id: id),
    );

    await lifecycle(
      label: 'importList',
      schemaPath: '/api/v1/importlist/schema',
      listPath: '/api/v1/importlist',
      create: (Map<String, dynamic> b) =>
          api.importList.postImportlist(body: ImportListResource.fromJson(b)),
      remove: (int id) => api.importList.deleteImportlistById(id: id),
      // The schema ships placeholders for these; a real one is only valid once
      // the user has picked a folder and profiles, so the test does the same.
      tweak: (Map<String, dynamic> b) => b
        ..['rootFolderPath'] = rootFolder
        ..['qualityProfileId'] = qualityProfileId
        ..['metadataProfileId'] = metadataProfileId,
    );

    expect(failures, isEmpty, reason: failures.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 5)),);

  test('profiles and tags can be created and deleted', () async {
    // A tag is the simplest resource there is: no schema, just a label.
    int? tagId;
    try {
      final dynamic made =
          await api.tag.postTag(body: const TagResource(label: 'zz-atrium'));
      // ignore: avoid_dynamic_calls
      tagId = made.data?.id as int?;
      // ignore: avoid_dynamic_calls
      if (made.isSuccess == true && tagId != null) {
        await api.tag.deleteTagById(id: tagId);
        tagId = null;
        pass('tag create + delete');
      } else {
        // ignore: avoid_dynamic_calls
        fail('tag', made.error);
      }
    } on Object catch (e) {
      fail('tag', e);
    } finally {
      if (tagId != null) {
        await api.tag.deleteTagById(id: tagId);
      }
    }

    await lifecycle(
      label: 'qualityProfile',
      schemaPath: '/api/v1/qualityprofile/schema',
      listPath: '/api/v1/qualityprofile',
      create: (Map<String, dynamic> b) => api.qualityProfile
          .postQualityprofile(body: QualityProfileResource.fromJson(b)),
      remove: (int id) =>
          api.qualityProfile.deleteQualityprofileById(id: id),
      // Every quality in the schema arrives disallowed, and Lidarr refuses a
      // profile that permits nothing, so allow one and cut off there.
      tweak: (Map<String, dynamic> b) {
        final List<dynamic> items = (b['items'] as List<dynamic>?) ?? <dynamic>[];
        for (final dynamic raw in items) {
          if (raw is Map<String, dynamic> && raw['id'] != null) {
            raw['allowed'] = true;
            b['cutoff'] = raw['id'];
            break;
          }
        }
        return b;
      },
    );

    await lifecycle(
      label: 'metadataProfile',
      schemaPath: '/api/v1/metadataprofile',
      listPath: '/api/v1/metadataprofile',
      create: (Map<String, dynamic> b) => api.metadataProfile
          .postMetadataprofile(body: MetadataProfileResource.fromJson(b)),
      remove: (int id) =>
          api.metadataProfile.deleteMetadataprofileById(id: id),
      tweak: (Map<String, dynamic> b) => b..remove('id'),
    );

    expect(failures, isEmpty, reason: failures.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 5)),);
}
