import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_qbittorrent/service_qbittorrent.dart';

class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString('Ok.', 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _RecordingAdapter adapter;
  late QbittorrentClient client;

  setUp(() {
    adapter = _RecordingAdapter();
    client = QbittorrentClient(
      dio: Dio(BaseOptions(baseUrl: 'https://qbit.example.test/'))
        ..httpClientAdapter = adapter,
      cookies: CookieJar(),
      username: '',
      password: '',
      apiKey: 'qbt_placeholder',
    );
  });

  group('QbittorrentClient queue reordering', () {
    test('queueUp posts to increasePrio with pipe-joined hashes', () async {
      await client.queueUp(<String>['hash1', 'hash2']);

      expect(adapter.request!.path, 'api/v2/torrents/increasePrio');
      expect(
        adapter.request!.data,
        <String, dynamic>{'hashes': 'hash1|hash2'},
      );
    });

    test('queueDown posts to decreasePrio with pipe-joined hashes', () async {
      await client.queueDown(<String>['hash1', 'hash2']);

      expect(adapter.request!.path, 'api/v2/torrents/decreasePrio');
      expect(
        adapter.request!.data,
        <String, dynamic>{'hashes': 'hash1|hash2'},
      );
    });

    test('queueTop posts to topPrio with pipe-joined hashes', () async {
      await client.queueTop(<String>['hash1', 'hash2']);

      expect(adapter.request!.path, 'api/v2/torrents/topPrio');
      expect(
        adapter.request!.data,
        <String, dynamic>{'hashes': 'hash1|hash2'},
      );
    });

    test('queueBottom posts to bottomPrio with pipe-joined hashes', () async {
      await client.queueBottom(<String>['hash1', 'hash2']);

      expect(adapter.request!.path, 'api/v2/torrents/bottomPrio');
      expect(
        adapter.request!.data,
        <String, dynamic>{'hashes': 'hash1|hash2'},
      );
    });

    test('setPriority forwards increase to queueUp and decrease to queueDown',
        () async {
      await client.setPriority('hashA', increase: true);
      expect(adapter.request!.path, 'api/v2/torrents/increasePrio');
      expect(adapter.request!.data, <String, dynamic>{'hashes': 'hashA'});

      await client.setPriority('hashB', increase: false);
      expect(adapter.request!.path, 'api/v2/torrents/decreasePrio');
      expect(adapter.request!.data, <String, dynamic>{'hashes': 'hashB'});
    });
  });
}
