@Tags(<String>['live'])
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_lidarr/service_lidarr.dart';

/// Track file operations, run against one named album so nothing else in the
/// library can be touched.
///
/// Set LIDARR_TRACKFILE_ALBUM to the album title to operate on. Without it the
/// test skips rather than guessing, because every action here deletes audio
/// from disk.
void main() {
  final String url = Platform.environment['LIDARR_URL'] ?? '';
  final String key = Platform.environment['LIDARR_KEY'] ?? '';
  final String target = Platform.environment['LIDARR_TRACKFILE_ALBUM'] ?? '';

  if (url.isEmpty || key.isEmpty || target.isEmpty) {
    test('skipped: no live server or no target album named', () {}, skip: true);
    return;
  }

  late Dio dio;
  late LidarrApi api;
  final List<String> log = <String>[];

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
    print('\n=== track files ===\n${log.join('\n')}\n');
  });

  test('track files can be listed, edited and deleted', () async {
    final Response<dynamic> albumsResp =
        await dio.get<dynamic>('/api/v1/album');
    final List<dynamic> albums = albumsResp.data as List<dynamic>;
    final Iterable<dynamic> matches = albums.where(
      (dynamic a) => a is Map && '${a['title']}' == target,
    );
    if (matches.isEmpty) {
      log.add('  SKIP  no album titled "$target"');
      return;
    }
    final Map<String, dynamic> album =
        Map<String, dynamic>.from(matches.first as Map);
    final int albumId = album['id'] as int;
    final int artistId = album['artistId'] as int;
    log.add('  target: "$target" album=$albumId artist=$artistId');

    final dynamic filesResp = await api.trackFile.getTrackfile(
      albumId: <int>[albumId],
    );
    // ignore: avoid_dynamic_calls
    final List<dynamic> files = (filesResp.data as List<dynamic>?) ?? <dynamic>[];
    log.add('  found ${files.length} track file(s)');
    if (files.isEmpty) {
      log.add('  SKIP  album has no files on disk');
      return;
    }

    // ignore: avoid_dynamic_calls
    final List<int> ids = files.map((dynamic f) => f.id as int).toList();

    // The editor is what the track files screen uses to change quality in
    // bulk. Re-applying what is already set proves the call works without
    // altering anything.
    // ignore: avoid_dynamic_calls
    final dynamic firstQuality = files.first.quality;
    if (firstQuality != null) {
      final dynamic edited = await api.trackFile.putTrackfileEditor(
        body: TrackFileListResource(
          trackFileIds: ids,
          quality: firstQuality as QualityModel,
        ),
      );
      // ignore: avoid_dynamic_calls
      expect(edited.isSuccess, isTrue, reason: 'editor rejected: ${edited.error}');
      log.add('  OK    trackFile editor applied to ${ids.length} file(s)');
    }

    // Single delete first, then the bulk path for the rest, so both are
    // exercised rather than just one.
    final dynamic one = await api.trackFile.deleteTrackfileById(id: ids.first);
    // ignore: avoid_dynamic_calls
    expect(one.isSuccess, isTrue, reason: 'single delete: ${one.error}');
    log.add('  OK    trackFile single delete');

    if (ids.length > 1) {
      final dynamic many = await api.trackFile.deleteTrackfileBulk(
        body: TrackFileListResource(trackFileIds: ids.sublist(1)),
      );
      // ignore: avoid_dynamic_calls
      expect(many.isSuccess, isTrue, reason: 'bulk delete: ${many.error}');
      log.add('  OK    trackFile bulk delete (${ids.length - 1} file(s))');
    }

    final dynamic after = await api.trackFile.getTrackfile(
      albumId: <int>[albumId],
    );
    // ignore: avoid_dynamic_calls
    final List<dynamic> left = (after.data as List<dynamic>?) ?? <dynamic>[];
    expect(left, isEmpty, reason: '${left.length} file(s) survived');
    log.add('  OK    album has no files left');
  }, timeout: const Timeout(Duration(minutes: 5)),);
}
