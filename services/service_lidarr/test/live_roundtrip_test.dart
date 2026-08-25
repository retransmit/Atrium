@Tags(<String>['live'])
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_lidarr/service_lidarr.dart';

/// Checks that every resource the app can save survives a parse-and-serialize
/// round trip without losing anything.
///
/// This is the same class of defect as the null `id` that broke adding an
/// artist, but caught without writing: each PUT in this app sends
/// `model.toJson()`, so any field the model drops on the way in is a field
/// that gets blanked on the way out. Reading the server's own JSON, running it
/// through the model, and diffing shows exactly what a save would destroy.
/// Nothing is written, so running this cannot damage a real server.
void main() {
  final String url = Platform.environment['LIDARR_URL'] ?? '';
  final String key = Platform.environment['LIDARR_KEY'] ?? '';

  if (url.isEmpty || key.isEmpty) {
    test('skipped: no live server configured', () {}, skip: true);
    return;
  }

  late Dio dio;
  final List<String> report = <String>[];
  final List<String> losses = <String>[];

  setUpAll(() {
    dio = Dio(
      BaseOptions(
        baseUrl: url,
        headers: <String, String>{'X-Api-Key': key},
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
  });

  /// Fields the server computes and never reads back. Sending them stale is
  /// harmless, and their absence from a model is not a loss worth reporting.
  const Set<String> ignored = <String>{
    'statistics',
    'images',
    'links',
    'ratings',
    'added',
    'addOptions',
    'remotePoster',
    'lastInfoSync',
    'nextAiring',
    'previousAiring',
    'artist',
    'album',
    'media',
    'presets',
    'fields',
    'infoLink',
    'message',
  };

  /// Compares the server's JSON against what the model would send back.
  ///
  /// Only reports a key the server gave a real value for that the model would
  /// send as null or drop entirely, which is what a save would actually erase.
  void diff(String label, Map<String, dynamic> from, Map<String, dynamic> to) {
    final List<String> lost = <String>[];
    for (final MapEntry<String, dynamic> e in from.entries) {
      if (ignored.contains(e.key)) continue;
      final Object? original = e.value;
      if (original == null) continue;
      if (original is List && original.isEmpty) continue;
      if (original is Map && original.isEmpty) continue;
      if (!to.containsKey(e.key) || to[e.key] == null) {
        lost.add('${e.key} (was ${_short(original)})');
      }
    }
    if (lost.isEmpty) {
      report.add('  OK    $label');
    } else {
      report.add('  LOSS  $label -> ${lost.join(', ')}');
      losses.add('$label: ${lost.join(', ')}');
    }
  }

  Future<Map<String, dynamic>?> getOne(String path) async {
    final Response<dynamic> r = await dio.get<dynamic>(path);
    final dynamic d = r.data;
    if (d is Map<String, dynamic>) return d;
    if (d is List && d.isNotEmpty && d.first is Map<String, dynamic>) {
      return d.first as Map<String, dynamic>;
    }
    return null;
  }

  test('saveable resources survive a parse and serialize round trip',
      () async {
    Future<void> check(
      String label,
      String path,
      Map<String, dynamic> Function(Map<String, dynamic>) trip,
    ) async {
      final Map<String, dynamic>? raw = await getOne(path);
      if (raw == null) {
        report.add('  SKIP  $label (nothing configured)');
        return;
      }
      try {
        diff(label, raw, trip(raw));
      } on Object catch (e) {
        report.add('  THREW $label -> ${e.runtimeType}: $e');
        losses.add('$label threw ${e.runtimeType}');
      }
    }

    await check('ArtistResource', '/api/v1/artist',
        (Map<String, dynamic> j) => ArtistResource.fromJson(j).toJson(),
    );
    await check('AlbumResource', '/api/v1/album',
        (Map<String, dynamic> j) => AlbumResource.fromJson(j).toJson(),
    );
    await check('QualityProfileResource', '/api/v1/qualityprofile',
        (Map<String, dynamic> j) => QualityProfileResource.fromJson(j).toJson(),
    );
    await check(
        'MetadataProfileResource',
        '/api/v1/metadataprofile',
        (Map<String, dynamic> j) =>
            MetadataProfileResource.fromJson(j).toJson(),
    );
    await check('DelayProfileResource', '/api/v1/delayprofile',
        (Map<String, dynamic> j) => DelayProfileResource.fromJson(j).toJson(),
    );
    await check('IndexerResource', '/api/v1/indexer',
        (Map<String, dynamic> j) => IndexerResource.fromJson(j).toJson(),
    );
    await check(
        'DownloadClientResource',
        '/api/v1/downloadclient',
        (Map<String, dynamic> j) =>
            DownloadClientResource.fromJson(j).toJson(),
    );
    await check('NotificationResource', '/api/v1/notification',
        (Map<String, dynamic> j) => NotificationResource.fromJson(j).toJson(),
    );
    await check('MetadataResource', '/api/v1/metadata',
        (Map<String, dynamic> j) => MetadataResource.fromJson(j).toJson(),
    );
    await check('ImportListResource', '/api/v1/importlist',
        (Map<String, dynamic> j) => ImportListResource.fromJson(j).toJson(),
    );
    await check('CustomFormatResource', '/api/v1/customformat',
        (Map<String, dynamic> j) => CustomFormatResource.fromJson(j).toJson(),
    );
    await check('AutoTaggingResource', '/api/v1/autotagging',
        (Map<String, dynamic> j) => AutoTaggingResource.fromJson(j).toJson(),
    );
    await check('ReleaseProfileResource', '/api/v1/releaseprofile',
        (Map<String, dynamic> j) => ReleaseProfileResource.fromJson(j).toJson(),
    );
    await check(
        'QualityDefinitionResource',
        '/api/v1/qualitydefinition',
        (Map<String, dynamic> j) =>
            QualityDefinitionResource.fromJson(j).toJson(),
    );
    await check('HostConfigResource', '/api/v1/config/host',
        (Map<String, dynamic> j) => HostConfigResource.fromJson(j).toJson(),
    );
    await check('NamingConfigResource', '/api/v1/config/naming',
        (Map<String, dynamic> j) => NamingConfigResource.fromJson(j).toJson(),
    );
    await check('IndexerConfigResource', '/api/v1/config/indexer',
        (Map<String, dynamic> j) => IndexerConfigResource.fromJson(j).toJson(),
    );
    await check(
        'MediaManagementConfigResource',
        '/api/v1/config/mediamanagement',
        (Map<String, dynamic> j) =>
            MediaManagementConfigResource.fromJson(j).toJson(),
    );
    await check('RootFolderResource', '/api/v1/rootfolder',
        (Map<String, dynamic> j) => RootFolderResource.fromJson(j).toJson(),
    );

    // ignore: avoid_print
    print('\n=== round trip ===\n${report.join('\n')}\n');

    expect(losses, isEmpty, reason: losses.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 5)),);
}

String _short(Object? v) {
  final String s = v.toString();
  return s.length <= 40 ? s : '${s.substring(0, 40)}...';
}
