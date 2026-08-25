@Tags(<String>['live'])
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_lidarr/service_lidarr.dart';

/// Throwaway probe: drives every read endpoint the Lidarr feature code calls
/// against a real server and reports which ones fail to parse.
///
/// A 200 from curl only proves the server answered. This proves the generated
/// models can actually read what it answered, which is where the breakage
/// would be. Not part of the normal suite: needs LIDARR_URL and LIDARR_KEY.
void main() {
  final String url = Platform.environment['LIDARR_URL'] ?? '';
  final String key = Platform.environment['LIDARR_KEY'] ?? '';

  if (url.isEmpty || key.isEmpty) {
    test('skipped: no live server configured', () {}, skip: true);
    return;
  }

  late LidarrApi api;
  final List<String> failures = <String>[];
  final List<String> ok = <String>[];

  setUpAll(() {
    api = LidarrApi(
      Dio(
        BaseOptions(
          baseUrl: url,
          headers: <String, String>{'X-Api-Key': key},
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 60),
        ),
      ),
    );
  });

  /// Runs one call and records whether it parsed.
  Future<void> probe(String label, Future<dynamic> Function() call) async {
    try {
      final dynamic resp = await call();
      // ignore: avoid_dynamic_calls
      final bool success = resp.isSuccess as bool;
      // ignore: avoid_dynamic_calls
      final dynamic data = resp.data;
      if (!success) {
        // ignore: avoid_dynamic_calls
        failures.add('$label -> API error: ${resp.error}');
        return;
      }
      if (data == null) {
        failures.add('$label -> parsed to null');
        return;
      }
      final String n = data is List ? '${data.length}' : 'obj';
      ok.add('$label [$n]');
    } on Object catch (e) {
      failures.add('$label -> THREW ${e.runtimeType}: $e');
    }
  }

  test('every read endpoint parses off a real server', () async {
    // Anchors used by the id-scoped calls below.
    final dynamic artistsResp = await api.artist.getArtist();
    // ignore: avoid_dynamic_calls
    final List<dynamic> artists = (artistsResp.data as List<dynamic>?) ?? <dynamic>[];
    expect(artists, isNotEmpty, reason: 'need at least one artist to probe');
    // ignore: avoid_dynamic_calls
    final int artistId = artists.first.id as int;

    final dynamic albumsResp = await api.album.getAlbum(artistId: artistId);
    // ignore: avoid_dynamic_calls
    final List<dynamic> albums = (albumsResp.data as List<dynamic>?) ?? <dynamic>[];
    final int? albumId =
        // ignore: avoid_dynamic_calls
        albums.isEmpty ? null : albums.first.id as int;

    await probe('artist.getArtist', () => api.artist.getArtist());
    await probe(
      'artist.getArtistById',
      () => api.artist.getArtistById(id: artistId),
    );
    await probe('album.getAlbum', () => api.album.getAlbum());
    if (albumId != null) {
      await probe(
        'album.getAlbumById',
        () => api.album.getAlbumById(id: albumId),
      );
    }
    await probe(
      'artistLookup.getArtistLookup',
      () => api.artistLookup.getArtistLookup(term: 'daft punk'),
    );
    await probe('autoTagging.getAutotagging', () => api.autoTagging.getAutotagging());
    await probe('backup.getSystemBackup', () => api.backup.getSystemBackup());
    await probe('blocklist.getBlocklist', () => api.blocklist.getBlocklist());
    await probe('calendar.getCalendar', () => api.calendar.getCalendar());
    await probe('customFormat.getCustomformat', () => api.customFormat.getCustomformat());
    await probe('cutoff.getWantedCutoff', () => api.cutoff.getWantedCutoff());
    await probe('delayProfile.getDelayprofile', () => api.delayProfile.getDelayprofile());
    await probe('diskSpace.getDiskspace', () => api.diskSpace.getDiskspace());
    await probe(
      'downloadClient.getDownloadclient',
      () => api.downloadClient.getDownloadclient(),
    );
    await probe(
      'downloadClient.getDownloadclientSchema',
      () => api.downloadClient.getDownloadclientSchema(),
    );
    await probe(
      'downloadClientConfig.getConfigDownloadclient',
      () => api.downloadClientConfig.getConfigDownloadclient(),
    );
    await probe('health.getHealth', () => api.health.getHealth());
    await probe('history.getHistory', () => api.history.getHistory());
    await probe(
      'history.getHistoryArtist',
      () => api.history.getHistoryArtist(artistId: artistId),
    );
    await probe('hostConfig.getConfigHost', () => api.hostConfig.getConfigHost());
    await probe('importList.getImportlist', () => api.importList.getImportlist());
    await probe(
      'importList.getImportlistSchema',
      () => api.importList.getImportlistSchema(),
    );
    await probe('indexer.getIndexer', () => api.indexer.getIndexer());
    await probe('indexer.getIndexerSchema', () => api.indexer.getIndexerSchema());
    await probe(
      'indexerConfig.getConfigIndexer',
      () => api.indexerConfig.getConfigIndexer(),
    );
    await probe('log.getLog', () => api.log.getLog());
    await probe('logFile.getLogFile', () => api.logFile.getLogFile());
    await probe(
      'manualImport.getManualimport',
      // Lidarr 500s on artistId alone; the dialog always sends a folder or a
      // downloadId alongside it, so probe it the way the app calls it.
      () => api.manualImport.getManualimport(
        folder: const String.fromEnvironment(
          'LIDARR_FOLDER',
          defaultValue: '/data/media/music',
        ),
        artistId: artistId,
      ),
    );
    await probe(
      'mediaManagementConfig.getConfigMediamanagement',
      () => api.mediaManagementConfig.getConfigMediamanagement(),
    );
    await probe('metadata.getMetadata', () => api.metadata.getMetadata());
    await probe('metadata.getMetadataSchema', () => api.metadata.getMetadataSchema());
    await probe(
      'metadataProfile.getMetadataprofile',
      () => api.metadataProfile.getMetadataprofile(),
    );
    await probe(
      'metadataProfileSchema.getMetadataprofileSchema',
      () => api.metadataProfileSchema.getMetadataprofileSchema(),
    );
    await probe('missing.getWantedMissing', () => api.missing.getWantedMissing());
    await probe('namingConfig.getConfigNaming', () => api.namingConfig.getConfigNaming());
    await probe('notification.getNotification', () => api.notification.getNotification());
    await probe(
      'notification.getNotificationSchema',
      () => api.notification.getNotificationSchema(),
    );
    await probe(
      'qualityDefinition.getQualitydefinition',
      () => api.qualityDefinition.getQualitydefinition(),
    );
    await probe(
      'qualityProfile.getQualityprofile',
      () => api.qualityProfile.getQualityprofile(),
    );
    await probe(
      'qualityProfileSchema.getQualityprofileSchema',
      () => api.qualityProfileSchema.getQualityprofileSchema(),
    );
    await probe('queue.getQueue', () => api.queue.getQueue());
    await probe('release.getRelease', () => api.release.getRelease());
    await probe(
      'releaseProfile.getReleaseprofile',
      () => api.releaseProfile.getReleaseprofile(),
    );
    await probe(
      'renameTrack.getRename',
      () => api.renameTrack.getRename(artistId: artistId),
    );
    await probe(
      'retagTrack.getRetag',
      () => api.retagTrack.getRetag(artistId: artistId),
    );
    await probe('rootFolder.getRootfolder', () => api.rootFolder.getRootfolder());
    await probe('system.getSystemStatus', () => api.system.getSystemStatus());
    await probe('task.getSystemTask', () => api.task.getSystemTask());
    await probe('tag.getTag', () => api.tag.getTag());
    await probe(
      'track.getTrack',
      () => api.track.getTrack(artistId: artistId),
    );
    await probe(
      'trackFile.getTrackfile',
      () => api.trackFile.getTrackfile(artistId: artistId),
    );
    await probe('update.getUpdate', () => api.update.getUpdate());

    // ignore: avoid_print
    print('\n=== PARSED OK (${ok.length}) ===');
    for (final String s in ok) {
      // ignore: avoid_print
      print('  $s');
    }
    // ignore: avoid_print
    print('\n=== FAILURES (${failures.length}) ===');
    for (final String s in failures) {
      // ignore: avoid_print
      print('  $s');
    }

    expect(failures, isEmpty, reason: failures.join('\n'));
  }, timeout: const Timeout(Duration(minutes: 5)),);

  test('a create succeeds even though the resource carries no id', () async {
    // The whole add surface of this module builds its payload from something
    // the server sent that has no id (a lookup result, a provider schema), so
    // this is the case that has to work. A tag is the smallest disposable
    // resource to prove it on, and it is removed again below.
    const String label = 'zz-atrium-selftest';

    final dynamic created = await api.tag.postTag(
      body: const TagResource(label: label),
    );
    // ignore: avoid_dynamic_calls
    final bool ok = created.isSuccess as bool;
    // ignore: avoid_dynamic_calls
    final Object? why = created.error;
    expect(ok, isTrue, reason: 'create rejected: $why');
    // ignore: avoid_dynamic_calls
    final int? newId = created.data?.id as int?;
    expect(newId, isNotNull);

    final dynamic listed = await api.tag.getTag();
    // ignore: avoid_dynamic_calls
    final List<dynamic> tags = (listed.data as List<dynamic>?) ?? <dynamic>[];
    expect(
      // ignore: avoid_dynamic_calls
      tags.any((dynamic t) => t.label == label),
      isTrue,
      reason: 'created tag did not come back from the server',
    );

    final dynamic removed = await api.tag.deleteTagById(id: newId!);
    // ignore: avoid_dynamic_calls
    expect(removed.isSuccess, isTrue, reason: 'cleanup failed: leftover tag');

    final dynamic after = await api.tag.getTag();
    // ignore: avoid_dynamic_calls
    final List<dynamic> left = (after.data as List<dynamic>?) ?? <dynamic>[];
    expect(
      // ignore: avoid_dynamic_calls
      left.any((dynamic t) => t.label == label),
      isFalse,
      reason: 'test tag was left behind on the server',
    );
  }, timeout: const Timeout(Duration(minutes: 2)),);
}
