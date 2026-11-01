@Tags(<String>['live'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_aria2/service_aria2.dart';

/// Drives [Aria2Api] against a real aria2 daemon.
///
/// The fixture tests prove the models can read a reply that was captured once.
/// This proves they can read the one the daemon is serving now, and that the
/// write calls land on a daemon that is really running: a download really
/// transfers, the bytes really land on disk, and a download really pauses and
/// resumes.
///
/// Not part of the normal suite. Needs ARIA2_URL and ARIA2_SECRET, and it
/// *writes*: it adds downloads, changes the global speed limits and removes
/// the results again, so it wants a scratch daemon rather than a busy one.
void main() {
  final String url = Platform.environment['ARIA2_URL'] ?? '';
  final String secret = Platform.environment['ARIA2_SECRET'] ?? '';

  if (url.isEmpty || secret.isEmpty) {
    test('skipped: no live server configured', () {}, skip: true);
    return;
  }

  late Aria2Api api;
  late HttpServer payloadServer;
  late Uint8List payload;

  /// A per-run id, so a second run of this test does not collide with the
  /// files the first one left behind: aria2 renames a file it would
  /// overwrite and the run would then assert the wrong name.
  late String runId;

  setUpAll(() async {
    runId = DateTime.now().millisecondsSinceEpoch.toString();

    api = Aria2Api(
      Dio(
        BaseOptions(
          baseUrl: url.endsWith('/') ? url : '$url/',
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 60),
        ),
      ),
      secret: secret,
    );

    // Four megabytes of deterministic noise: big enough that a throttled
    // download stays running long enough to be paused, small enough to be
    // quick when it is not.
    final Random random = Random(20261021);
    payload = Uint8List(4 * 1024 * 1024);
    for (int i = 0; i < payload.length; i++) {
      payload[i] = random.nextInt(256);
    }

    payloadServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    payloadServer.listen((HttpRequest request) {
      request.response.headers.contentType = ContentType.binary;
      request.response.add(payload);
      request.response.close();
    });
  });

  tearDownAll(() async {
    await payloadServer.close(force: true);
  });

  /// The URL of a file the payload server serves, and the name aria2 will
  /// save it under.
  ///
  /// The name carries the run id: aria2 renames a file it would overwrite,
  /// so a second run of this test would otherwise assert the wrong name.
  ({String url, String name}) payloadFile(String name) {
    final String file = '$name-$runId.bin';
    return (
      url:
          'http://${payloadServer.address.address}:${payloadServer.port}/$file',
      name: file,
    );
  }

  /// Waits for a download to reach one of [wanted].
  Future<Aria2Download> waitForStatus(
    String gid,
    Set<String> wanted, {
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final DateTime deadline = DateTime.now().add(timeout);
    Aria2Download download = await api.tellStatus(gid);
    while (!wanted.contains(download.status) &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      download = await api.tellStatus(gid);
    }
    expect(
      wanted,
      contains(download.status),
      reason: 'the download stayed "${download.status}"',
    );
    return download;
  }

  /// Removes a download and forgets its result.
  ///
  /// aria2 stops a download in the background, and a result can only be
  /// purged once the download has stopped: asking too early comes back as
  /// "Could not remove download result of GID#...". A download that is not
  /// there any more is not a problem either.
  Future<void> removeAndPurge(String gid) async {
    try {
      await api.remove(gid);
    } on Aria2RpcException {
      // Already gone.
    }
    try {
      await waitForStatus(gid, <String>{'removed', 'error', 'complete'});
    } on Aria2RpcException {
      // Gone with the result, nothing left to purge.
      return;
    }
    await api.removeDownloadResult(gid);
  }

  test('the daemon answers with its version and its totals', () async {
    final Aria2Version version = await api.getVersion();
    expect(version.version, isNotEmpty);

    final Aria2GlobalStat stat = await api.getGlobalStat();
    expect(stat.downloadSpeed, greaterThanOrEqualTo(0));
    expect(stat.numActive, greaterThanOrEqualTo(0));

    // ignore: avoid_print
    print(
      '\n  aria2 ${version.version}'
      '\n  features: ${version.enabledFeatures.join(', ')}'
      '\n  active ${stat.numActive}, waiting ${stat.numWaiting}, '
      'stopped ${stat.numStopped}',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('the snapshot is one batched request and the lists agree', () async {
    final Aria2Snapshot snapshot = await api.getSnapshot();

    expect(snapshot.version.version, isNotEmpty);
    expect(snapshot.stat.numActive, greaterThanOrEqualTo(0));
    expect(snapshot.active, isA<List<Aria2Download>>());
    expect(snapshot.waiting, isA<List<Aria2Download>>());
    expect(snapshot.stopped, isA<List<Aria2Download>>());

    // The daemon hands the stopped list out from the least recently stopped
    // download, and the snapshot turns it around. Whatever order the daemon
    // uses, the two views must be the same list the other way round.
    final List<Aria2Download> raw = await api.tellStopped();
    expect(
      snapshot.stopped.map((Aria2Download d) => d.gid).toList(),
      raw.map((Aria2Download d) => d.gid).toList().reversed.toList(),
    );

    // ignore: avoid_print
    print(
      '\n  active ${snapshot.active.length}, '
      'waiting ${snapshot.waiting.length}, '
      'stopped ${snapshot.stopped.length}',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('a real download transfers and lands on disk', () async {
    final ({String url, String name}) file = payloadFile('complete');
    final String gid = await api.addUri(<String>[file.url]);

    final Aria2Download download = await waitForStatus(gid, <String>{
      'complete',
      'error',
    });
    expect(download.status, 'complete', reason: download.errorMessage);
    expect(download.totalLength, payload.length);
    expect(download.completedLength, payload.length);
    expect(download.progress, 1.0);

    final List<Aria2File> files = await api.getFiles(gid);
    expect(files, hasLength(1));
    expect(files.first.length, payload.length);
    expect(files.first.completedLength, payload.length);
    expect(files.first.selected, isTrue);
    expect(files.first.name, file.name);
    expect(files.first.uris, isNotEmpty);

    // The bytes on disk are the bytes that were served: the whole transfer,
    // not just the counters.
    final File onDisk = File(files.first.path);
    expect(onDisk.existsSync(), isTrue, reason: '${onDisk.path} is not there');
    expect(onDisk.lengthSync(), payload.length);
    expect(onDisk.readAsBytesSync().sublist(0, 64), payload.sublist(0, 64));

    // ignore: avoid_print
    print(
      '\n  downloaded ${files.first.path}'
      '\n  ${download.completedLength} of ${download.totalLength} bytes',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('a download pauses and resumes', () async {
    // A limit slow enough that the download is still running when it is
    // paused, so the pause is not a race.
    await api.setGlobalDownloadLimit(64 * 1024);
    try {
      final ({String url, String name}) file = payloadFile('pause');
      final String gid = await api.addUri(<String>[file.url]);
      await waitForStatus(gid, <String>{'active'});

      await api.pause(gid);
      final Aria2Download paused = await api.tellStatus(gid);
      expect(paused.status, 'paused');

      await api.unpause(gid);
      final Aria2Download resumed = await api.tellStatus(gid);
      expect(resumed.status, isNot('paused'));

      await removeAndPurge(gid);

      // ignore: avoid_print
      print(
        '\n  paused at ${paused.completedLength} bytes, '
        'resumed as "${resumed.status}"',
      );
    } finally {
      await api.setGlobalDownloadLimit(0);
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('the global speed limit is read back as it was set', () async {
    final Map<String, String> before = await api.getGlobalOption();
    expect(before.containsKey('max-overall-download-limit'), isTrue);
    expect(before.containsKey('max-overall-upload-limit'), isTrue);

    await api.setGlobalDownloadLimit(512 * 1024);
    await api.setGlobalUploadLimit(128 * 1024);

    final Map<String, String> after = await api.getGlobalOption();
    expect(after['max-overall-download-limit'], '524288');
    expect(after['max-overall-upload-limit'], '131072');

    await api.setGlobalDownloadLimit(0);
    await api.setGlobalUploadLimit(0);

    final Map<String, String> reset = await api.getGlobalOption();
    expect(reset['max-overall-download-limit'], '0');
    expect(reset['max-overall-upload-limit'], '0');

    // ignore: avoid_print
    print(
      '\n  download limit ${after['max-overall-download-limit']} B/s, '
      'upload limit ${after['max-overall-upload-limit']} B/s',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('a torrent is accepted and its metadata is read', () async {
    // The options matter: aria2 reads them by position, so a torrent added
    // with options and without a list of sources has to carry an empty list
    // in that slot. The daemon answers 'The parameter at 1 has wrong type.'
    // when it does not.
    // The name carries the run id, and with it the info hash: the daemon
    // refuses a torrent it already knows ('InfoHash ... is already
    // registered'), so a fixed torrent would only work on a fresh daemon.
    final String name = 'torrent-payload-$runId.bin';
    final String gid = await api.addTorrent(
      _torrentBase64(payload, name),
      options: <String, String>{'max-download-limit': '0'},
    );
    addTearDown(() => removeAndPurge(gid));

    final Aria2Download download = await api.tellStatus(gid);
    expect(download.gid, gid);
    expect(download.infoHash, isNotEmpty);
    expect(download.torrentName, name);

    // A torrent with no peers goes straight to the active list: there is
    // nothing to queue behind, it goes looking for peers instead.
    final List<Aria2Download> live = <Aria2Download>[
      ...await api.tellActive(),
      ...await api.tellWaiting(),
    ];
    expect(live.map((Aria2Download d) => d.gid), contains(gid));

    // ignore: avoid_print
    print(
      '\n  torrent ${download.torrentName} '
      '(${download.infoHash.substring(0, 8)}) accepted as "${download.status}"',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('a wrong secret is refused', () async {
    final Aria2Api wrong = Aria2Api(
      Dio(BaseOptions(baseUrl: url.endsWith('/') ? url : '$url/')),
      secret: 'not-the-secret',
    );

    Object? caught;
    try {
      await wrong.getVersion();
    } catch (error) {
      caught = error;
    }
    expect(caught, isA<Aria2RpcException>());
    expect(
      (caught! as Aria2RpcException).message.toLowerCase(),
      contains('unauthorized'),
    );

    // A daemon with a secret answers nobody without one.
    final Aria2Api anonymous = Aria2Api(
      Dio(BaseOptions(baseUrl: url.endsWith('/') ? url : '$url/')),
    );
    Object? caughtAnonymous;
    try {
      await anonymous.getVersion();
    } catch (error) {
      caughtAnonymous = error;
    }
    expect(caughtAnonymous, isA<Aria2RpcException>());

    // ignore: avoid_print
    print('\n  refused: ${caught.runtimeType} "$caught"');
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('a removed download is forgotten', () async {
    final ({String url, String name}) file = payloadFile('removed');
    final String gid = await api.addUri(<String>[file.url]);
    await api.remove(gid);
    await waitForStatus(gid, <String>{'removed', 'error', 'complete'});

    final Aria2Download removed = await api.tellStatus(gid);
    expect(removed.status, 'removed');

    await api.removeDownloadResult(gid);

    Object? caught;
    try {
      await api.tellStatus(gid);
    } catch (error) {
      caught = error;
    }
    expect(caught, isA<Aria2RpcException>());

    // ignore: avoid_print
    print('\n  removed "${removed.status}", then forgotten');
  }, timeout: const Timeout(Duration(minutes: 2)));
}

/// A bencoded byte string, which is not necessarily text.
class _Bytes {
  const _Bytes(this.value);

  final List<int> value;
}

/// Bencode, just enough to build a `.torrent`.
String _bencode(Object? value) {
  if (value is int) {
    return 'i${value}e';
  }
  if (value is _Bytes) {
    return '${value.value.length}:${String.fromCharCodes(value.value)}';
  }
  if (value is String) {
    return '${utf8.encode(value).length}:$value';
  }
  if (value is List) {
    return 'l${value.map(_bencode).join()}e';
  }
  if (value is Map) {
    final List<String> keys =
        value.keys.map((Object? k) => k! as String).toList()..sort();
    final StringBuffer buffer = StringBuffer('d');
    for (final String key in keys) {
      buffer
        ..write(_bencode(key))
        ..write(_bencode(value[key]));
    }
    buffer.write('e');
    return buffer.toString();
  }
  throw ArgumentError('cannot bencode ${value.runtimeType}');
}

/// A single-file torrent for [content] named [name], base64 encoded the way
/// aria2 wants it.
String _torrentBase64(Uint8List content, String name) {
  const int pieceLength = 16 * 1024;
  final List<int> pieces = <int>[];
  for (int offset = 0; offset < content.length; offset += pieceLength) {
    final int end = min(offset + pieceLength, content.length);
    pieces.addAll(sha1.convert(content.sublist(offset, end)).bytes);
  }

  final Map<String, Object?> torrent = <String, Object?>{
    'announce': 'http://127.0.0.1:1/announce',
    'created by': 'atrium live test',
    'info': <String, Object?>{
      'length': content.length,
      'name': name,
      'piece length': pieceLength,
      'pieces': _Bytes(pieces),
    },
  };

  return base64Encode(latin1.encode(_bencode(torrent)));
}
