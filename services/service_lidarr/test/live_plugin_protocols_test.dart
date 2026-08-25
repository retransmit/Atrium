@Tags(<String>['live'])
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_lidarr/service_lidarr.dart';

/// Parses a plugin-enabled Lidarr's own schemas through the app's models.
///
/// Issue #134: a build with Tubifarry installed advertises protocols no
/// released spec lists, and the old models threw on them, taking down
/// interactive search. This reads the real schemas off a live server rather
/// than a fixture, so it fails if a future plugin build changes the shape
/// again. Read-only.
void main() {
  final String url = Platform.environment['LIDARR_URL'] ?? '';
  final String key = Platform.environment['LIDARR_KEY'] ?? '';

  if (url.isEmpty || key.isEmpty) {
    test('skipped: no live server configured', () {}, skip: true);
    return;
  }

  late Dio dio;
  late LidarrApi api;

  setUpAll(() {
    dio = Dio(
      BaseOptions(
        baseUrl: url,
        headers: <String, String>{'X-Api-Key': key},
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
    api = LidarrApi(dio);
  });

  test('every advertised indexer parses, whatever protocol it claims',
      () async {
    final dynamic resp = await api.indexer.getIndexerSchema();
    // ignore: avoid_dynamic_calls
    expect(resp.isSuccess, isTrue, reason: 'schema fetch failed');
    // ignore: avoid_dynamic_calls
    final List<dynamic> all = (resp.data as List<dynamic>?) ?? <dynamic>[];
    expect(all, isNotEmpty);

    // What the server actually said, before the models touched it.
    final Response<dynamic> rawResp =
        await dio.get<dynamic>('/api/v1/indexer/schema');
    final Set<String> rawProtocols = <String>{
      for (final dynamic e in rawResp.data as List<dynamic>)
        if (e is Map && e['protocol'] != null) '${e['protocol']}',
    };
    // ignore: avoid_print
    print('\n  protocols this server advertises: ${rawProtocols.toList()..sort()}');

    final List<String> impls = all
        // ignore: avoid_dynamic_calls
        .map((dynamic e) => '${e.implementation}')
        .toList();
    // ignore: avoid_print
    print('  indexer implementations parsed: ${impls.length}');

    // Nothing may parse to null, which is what a throw used to produce.
    for (final dynamic e in all) {
      // ignore: avoid_dynamic_calls
      final Object? proto = e.protocol;
      // ignore: avoid_dynamic_calls
      final String impl = '${e.implementation}';
      expect(proto, isNotNull, reason: '$impl lost its protocol');
    }

    // The two the spec does know must survive the longer spelling rather than
    // degrading, or every torrent indexer reads as unknown.
    final Iterable<dynamic> torrents = all.where(
      // ignore: avoid_dynamic_calls
      (dynamic e) => '${e.implementation}' == 'Torznab',
    );
    if (torrents.isNotEmpty) {
      // ignore: avoid_dynamic_calls
      expect(torrents.first.protocol, DownloadProtocol.torrent);
    }
  }, timeout: const Timeout(Duration(minutes: 3)),);

  test('every advertised download client parses too', () async {
    final dynamic resp = await api.downloadClient.getDownloadclientSchema();
    // ignore: avoid_dynamic_calls
    final List<dynamic> all = (resp.data as List<dynamic>?) ?? <dynamic>[];
    expect(all, isNotEmpty);
    for (final dynamic e in all) {
      // ignore: avoid_dynamic_calls
      final Object? proto = e.protocol;
      // ignore: avoid_dynamic_calls
      final String impl = '${e.implementation}';
      expect(proto, isNotNull, reason: '$impl lost its protocol');
    }
    final Iterable<dynamic> qbit = all.where(
      // ignore: avoid_dynamic_calls
      (dynamic e) => '${e.implementation}' == 'QBittorrent',
    );
    if (qbit.isNotEmpty) {
      // ignore: avoid_dynamic_calls
      expect(qbit.first.protocol, DownloadProtocol.torrent);
    }
  }, timeout: const Timeout(Duration(minutes: 3)),);
}
