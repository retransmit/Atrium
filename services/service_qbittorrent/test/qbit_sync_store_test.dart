import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_qbittorrent/service_qbittorrent.dart';

import 'support/qbit_fixtures.dart';

/// Answers `/sync/maindata` with the queued bodies in order, recording the
/// `rid` each request asked with. A body may be held back by its completer.
class _MaindataAdapter implements HttpClientAdapter {
  final List<Future<Map<String, dynamic>> Function()> replies =
      <Future<Map<String, dynamic>> Function()>[];
  final List<Object?> rids = <Object?>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    rids.add(options.queryParameters['rid']);
    final Map<String, dynamic> body = await replies.removeAt(0)();
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

QbittorrentClient _clientFor(_MaindataAdapter adapter) => QbittorrentClient(
      dio: Dio(BaseOptions(baseUrl: 'https://qbit.example.test/'))
        ..httpClientAdapter = adapter,
      cookies: CookieJar(),
      username: '',
      password: '',
      apiKey: 'k',
    );

/// A maindata torrent entry: keyed by hash, so the row carries none.
Map<String, dynamic> _entry(String hash, {String name = 'a', int dl = 0}) =>
    torrentRowJson(hash: hash, name: name, dlspeed: dl)..remove('hash');

void main() {
  const String a = 'aaaa';
  const String b = 'bbbb';

  test('a full update lists every torrent with its hash', () {
    final QbitSyncStore store = QbitSyncStore();

    final List<QbitTorrent> list = store.apply(<String, dynamic>{
      'rid': 1,
      'full_update': true,
      'torrents': <String, dynamic>{a: _entry(a), b: _entry(b, name: 'b')},
    });

    expect(store.rid, 1);
    expect(
      list.map((QbitTorrent t) => t.hash),
      unorderedEquals(<String>[a, b]),
    );
  });

  test('a delta changes only the fields it names', () {
    final QbitSyncStore store = QbitSyncStore()
      ..apply(<String, dynamic>{
        'rid': 1,
        'full_update': true,
        'torrents': <String, dynamic>{a: _entry(a, name: 'kept', dl: 5)},
      });

    final List<QbitTorrent> list = store.apply(<String, dynamic>{
      'rid': 2,
      'torrents': <String, dynamic>{
        a: <String, dynamic>{'dlspeed': 99},
      },
    });

    expect(store.rid, 2);
    expect(list.single.name, 'kept');
    expect(list.single.dlspeed, 99);
  });

  test('a removed torrent leaves the list', () {
    final QbitSyncStore store = QbitSyncStore()
      ..apply(<String, dynamic>{
        'rid': 1,
        'full_update': true,
        'torrents': <String, dynamic>{a: _entry(a), b: _entry(b)},
      });

    final List<QbitTorrent> list = store.apply(<String, dynamic>{
      'rid': 2,
      'torrents_removed': <String>[a],
    });

    expect(list.map((QbitTorrent t) => t.hash), <String>[b]);
  });

  test('a full update drops torrents it no longer lists', () {
    final QbitSyncStore store = QbitSyncStore()
      ..apply(<String, dynamic>{
        'rid': 7,
        'full_update': true,
        'torrents': <String, dynamic>{a: _entry(a), b: _entry(b)},
      });

    // What a restarted qBittorrent answers to a rid it no longer knows.
    final List<QbitTorrent> list = store.apply(<String, dynamic>{
      'rid': 1,
      'full_update': true,
      'torrents': <String, dynamic>{b: _entry(b)},
    });

    expect(store.rid, 1);
    expect(list.map((QbitTorrent t) => t.hash), <String>[b]);
  });

  test('a sync fired mid-flight waits and asks with the newer rid', () async {
    final _MaindataAdapter adapter = _MaindataAdapter();
    final Completer<Map<String, dynamic>> first =
        Completer<Map<String, dynamic>>();
    adapter.replies
      ..add(() => first.future)
      ..add(
        () => Future<Map<String, dynamic>>.value(<String, dynamic>{
          'rid': 2,
          'torrents': <String, dynamic>{
            a: <String, dynamic>{'dlspeed': 2},
          },
        }),
      );
    final QbittorrentClient client = _clientFor(adapter);
    final QbitSyncStore store = QbitSyncStore();

    final Future<List<QbitTorrent>> poll = store.sync(client);
    final Future<List<QbitTorrent>> refresh = store.sync(client);
    await pumpEventQueue();
    // The refresh has not gone out with the rid the poll is still answering.
    expect(adapter.rids, <Object?>[0]);

    first.complete(<String, dynamic>{
      'rid': 1,
      'full_update': true,
      'torrents': <String, dynamic>{a: _entry(a, dl: 1)},
    });
    await poll;
    final List<QbitTorrent> list = await refresh;

    expect(adapter.rids, <Object?>[0, 1]);
    expect(store.rid, 2);
    expect(list.single.dlspeed, 2);
  });

  test('a failed sync does not block the next one', () async {
    final _MaindataAdapter adapter = _MaindataAdapter();
    adapter.replies
      ..add(() => Future<Map<String, dynamic>>.error(StateError('down')))
      ..add(
        () => Future<Map<String, dynamic>>.value(<String, dynamic>{
          'rid': 1,
          'full_update': true,
          'torrents': <String, dynamic>{a: _entry(a)},
        }),
      );
    final QbittorrentClient client = _clientFor(adapter);
    final QbitSyncStore store = QbitSyncStore();

    await expectLater(store.sync(client), throwsA(anything));
    final List<QbitTorrent> list = await store.sync(client);

    expect(adapter.rids, <Object?>[0, 0]);
    expect(list.single.hash, a);
  });
}
