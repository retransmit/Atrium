@Tags(<String>['live'])
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_lidarr/service_lidarr.dart';

/// Third part of the live write coverage: the actions that operate on library
/// content rather than configuration, plus the provider connectivity tests.
///
/// The destructive ones work on a disposable artist this file adds and removes
/// itself, so nothing in the real library is touched.
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
        receiveTimeout: const Duration(seconds: 120),
      ),
    );
    api = LidarrApi(dio);
  });

  tearDownAll(() {
    // ignore: avoid_print
    print('\n=== writes (part 3) ===\n${log.join('\n')}\n');
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

  Future<dynamic> rawGet(String path) async {
    final Response<dynamic> r = await dio.get<dynamic>(path);
    return r.data;
  }

  /// Runs one call and records the outcome, without letting a throw abort the
  /// rest of the sweep.
  Future<bool> step(String label, Future<dynamic> Function() call) async {
    try {
      final dynamic resp = await call();
      // ignore: avoid_dynamic_calls
      final bool ok = resp.isSuccess == true;
      // ignore: avoid_dynamic_calls
      final Object? err = resp.error;
      if (ok) {
        pass(label);
        return true;
      }
      fail(label, err);
      return false;
    } on Object catch (e) {
      fail(label, '${e.runtimeType}: $e');
      return false;
    }
  }

  test('provider connectivity tests can be run', () async {
    // These post the saved provider back to its /test endpoint. A provider
    // that is genuinely misconfigured will report so, which is a real answer
    // rather than a failure of the app, so only a transport-level break counts.
    for (final (String label, String path) probes in <(String, String)>[
      ('indexer', '/api/v1/indexer'),
      ('downloadClient', '/api/v1/downloadclient'),
    ]) {
      final (String label, String path) = probes;
      final dynamic list = await rawGet(path);
      if (list is! List || list.isEmpty) {
        log.add('  SKIP  $label test (none configured)');
        continue;
      }
      final Map<String, dynamic> first =
          Map<String, dynamic>.from(list.first as Map);
      try {
        if (label == 'indexer') {
          final dynamic r = await api.indexer
              .postIndexerTest(body: IndexerResource.fromJson(first));
          // ignore: avoid_dynamic_calls
          log.add('  OK    indexer test ran (accepted=${r.isSuccess})');
        } else {
          final dynamic r = await api.downloadClient.postDownloadclientTest(
            body: DownloadClientResource.fromJson(first),
          );
          // ignore: avoid_dynamic_calls
          log.add('  OK    downloadClient test ran (accepted=${r.isSuccess})');
        }
      } on Object catch (e) {
        fail('$label test', '${e.runtimeType}: $e');
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 4)),);

  test('library actions work on a disposable artist', () async {
    int? artistId;
    try {
      // Add an artist nobody would miss, unmonitored and with no search, so
      // adding it cannot start a download.
      final dynamic look = await api.artistLookup.getArtistLookup(
        term: 'lidarr:db92a151-1ac2-438b-bc43-b82e149ddd50',
      );
      // ignore: avoid_dynamic_calls
      final List<dynamic> hits = (look.data as List<dynamic>?) ?? <dynamic>[];
      if (hits.isEmpty) {
        log.add('  SKIP  library actions (lookup returned nothing)');
        return;
      }
      final List<dynamic> folders = await rawGet('/api/v1/rootfolder') as List<dynamic>;
      final List<dynamic> qps = await rawGet('/api/v1/qualityprofile') as List<dynamic>;
      final List<dynamic> mps = await rawGet('/api/v1/metadataprofile') as List<dynamic>;

      // ignore: avoid_dynamic_calls
      final ArtistResource candidate = (hits.first as ArtistResource).copyWith(
        rootFolderPath: (folders.first as Map<String, dynamic>)['path'] as String,
        qualityProfileId: (qps.first as Map<String, dynamic>)['id'] as int,
        metadataProfileId: (mps.first as Map<String, dynamic>)['id'] as int,
        monitored: false,
        addOptions: const AddArtistOptions(
          monitor: MonitorTypes.none,
          monitored: false,
          searchForMissingAlbums: false,
        ),
      );

      final dynamic added = await api.artist.postArtist(body: candidate);
      // ignore: avoid_dynamic_calls
      if (added.isSuccess != true) {
        // ignore: avoid_dynamic_calls
        fail('disposable artist add', added.error);
        return;
      }
      // ignore: avoid_dynamic_calls
      artistId = added.data!.id as int;
      pass('artist add (unmonitored, no search)');

      // Bulk editor, the path the multi-select bar uses.
      await step(
        'artistEditor bulk edit',
        () => api.artistEditor.putArtistEditor(
          body: ArtistEditorResource(
            artistIds: <int>[artistId!],
            monitored: true,
          ),
        ),
      );

      final dynamic reread = await api.artist.getArtistById(id: artistId);
      // ignore: avoid_dynamic_calls
      final bool nowMonitored = reread.data?.monitored == true;
      if (nowMonitored) {
        pass('artistEditor bulk edit took effect');
      } else {
        fail('artistEditor bulk edit', 'monitored did not change');
      }

      // Album level writes, on this artist's own albums only.
      final dynamic albumsResp = await api.album.getAlbum(artistId: artistId);
      // ignore: avoid_dynamic_calls
      final List<dynamic> albums = (albumsResp.data as List<dynamic>?) ?? <dynamic>[];
      if (albums.isNotEmpty) {
        // ignore: avoid_dynamic_calls
        final int albumId = albums.first.id as int;
        await step(
          'album monitor toggle',
          () => api.album.putAlbumMonitor(
            body: AlbumsMonitoredResource(
              albumIds: <int>[albumId],
              monitored: true,
            ),
          ),
        );
        await step(
          'albumStudio bulk monitor',
          () => api.albumStudio.postAlbumstudio(
            body: AlbumStudioResource(
              artist: <AlbumStudioArtistResource>[
                AlbumStudioArtistResource(id: artistId),
              ],
              monitoringOptions: const MonitoringOptions(monitor: MonitorTypes.none),
            ),
          ),
        );
      } else {
        log.add('  SKIP  album writes (artist has no albums)');
      }

      // Bulk delete, which is the other half of the multi-select bar.
      await step(
        'artistEditor bulk delete',
        () => api.artistEditor.deleteArtistEditor(
          body: ArtistEditorResource(artistIds: <int>[artistId!]),
        ),
      );
      final dynamic after = await rawGet('/api/v1/artist');
      final bool stillThere = (after as List<dynamic>).any(
        (dynamic a) => a is Map && a['id'] == artistId,
      );
      if (stillThere) {
        fail('artistEditor bulk delete', 'artist survived the delete');
      } else {
        pass('artistEditor bulk delete removed it');
        artistId = null;
      }
    } on Object catch (e) {
      fail('library actions', '${e.runtimeType}: $e');
    } finally {
      if (artistId != null) {
        try {
          await api.artist.deleteArtistById(id: artistId, deleteFiles: false);
          log.add('  ..    disposable artist cleaned up after failure');
        } on Object catch (_) {
          log.add('  WARN  disposable artist LEFT BEHIND id=$artistId');
        }
      }
    }

    expect(failures, isEmpty, reason: failures.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 8)),);
}
