import 'dart:convert';
import 'dart:typed_data';

import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_rtorrent/service_rtorrent.dart';

/// Records what was asked of it and answers with a canned body.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.body, {this.status = 200});

  final List<RequestOptions> requests = <RequestOptions>[];
  final List<int> body;
  final int status;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromBytes(body, status);
  }

  @override
  void close({bool force = false}) {}
}

const String _okResponse = '<?xml version="1.0"?><methodResponse><params>'
    '<param><value><i8>0</i8></value></param></params></methodResponse>';

({RtorrentApi api, _FakeAdapter rpc, _FakeAdapter fetch}) _build({
  List<int>? torrentBytes,
  int fetchStatus = 200,
}) {
  final _FakeAdapter rpc = _FakeAdapter(utf8.encode(_okResponse));
  final _FakeAdapter fetch = _FakeAdapter(
    torrentBytes ?? <int>[1, 2, 3, 4, 5],
    status: fetchStatus,
  );
  final Dio rpcDio = Dio(BaseOptions(baseUrl: 'http://host:8000/'))
    ..httpClientAdapter = rpc;
  final Dio fetchDio = Dio()..httpClientAdapter = fetch;
  return (api: RtorrentApi(rpcDio, fetchDio: fetchDio), rpc: rpc, fetch: fetch);
}

void main() {
  group('addUrl', () {
    // A magnet has nothing to pre-fetch, so it goes straight to rTorrent.
    test('hands a magnet to load.start_verbose untouched', () async {
      final r = _build();
      const String magnet = 'magnet:?xt=urn:btih:ABC123&dn=thing';
      await r.api.addUrl(magnet);

      expect(r.fetch.requests, isEmpty, reason: 'must not fetch a magnet');
      expect(r.rpc.requests, hasLength(1));
      final String sent = r.rpc.requests.single.data as String;
      expect(sent, contains('load.start_verbose'));
      // The & in a magnet's query is XML-escaped on the way out, which is the
      // codec doing its job rather than the link being mangled.
      expect(sent, contains('magnet:?xt=urn:btih:ABC123&amp;dn=thing'));
    });

    test('uses load.verbose when adding stopped', () async {
      final r = _build();
      await r.api.addUrl('magnet:?xt=urn:btih:ABC123', start: false);
      final String sent = r.rpc.requests.single.data as String;
      expect(sent, contains('load.verbose'));
      expect(sent, isNot(contains('load.start_verbose')));
    });

    // rTorrent answers 0 and then silently does nothing for an http(s)
    // .torrent, so the app downloads it and sends the bytes instead.
    test('downloads an http .torrent and sends it as raw bytes', () async {
      final List<int> torrent = <int>[100, 56, 58, 97, 110];
      final r = _build(torrentBytes: torrent);
      await r.api.addUrl('https://example.test/thing.torrent');

      expect(r.fetch.requests, hasLength(1));
      expect(
        r.fetch.requests.single.path,
        'https://example.test/thing.torrent',
      );

      final String sent = r.rpc.requests.single.data as String;
      expect(sent, contains('load.raw_start_verbose'));
      expect(sent, contains(base64Encode(torrent)));
      // The URL itself must not be forwarded once we have the bytes.
      expect(sent, isNot(contains('example.test')));
    });

    test('a plain http URL takes the same path as https', () async {
      final r = _build();
      await r.api.addUrl('http://example.test/thing.torrent');
      expect(r.fetch.requests, hasLength(1));
      expect(
        r.rpc.requests.single.data as String,
        contains('load.raw_start_verbose'),
      );
    });

    // A dead link is the common mistake, and it must read as a download
    // failure rather than as rTorrent rejecting something.
    test('a failed download is reported and nothing is sent on', () async {
      final r = _build(fetchStatus: 404);
      await expectLater(
        r.api.addUrl('https://example.test/missing.torrent'),
        throwsA(isA<NetworkBadResponseException>()),
      );
      expect(r.rpc.requests, isEmpty, reason: 'nothing should reach rTorrent');
    });

    test('an empty download is reported rather than sent on', () async {
      final r = _build(torrentBytes: <int>[]);
      await expectLater(
        r.api.addUrl('https://example.test/nothing.torrent'),
        throwsA(isA<NetworkBadResponseException>()),
      );
      expect(r.rpc.requests, isEmpty, reason: 'nothing should reach rTorrent');
    });

    test('a destination becomes a d.directory.set command', () async {
      final r = _build();
      await r.api.addUrl(
        'magnet:?xt=urn:btih:ABC123',
        directory: '/downloads/films',
      );
      // Quotes need no escaping in element text, so the command reaches
      // rTorrent exactly as it must parse it.
      expect(
        r.rpc.requests.single.data as String,
        contains('d.directory.set="/downloads/films"'),
      );
    });

    test('no destination adds no extra command', () async {
      final r = _build();
      await r.api.addUrl('magnet:?xt=urn:btih:ABC123');
      expect(
        r.rpc.requests.single.data as String,
        isNot(contains('d.directory.set')),
      );
    });
  });

  group('addFile', () {
    test('sends the bytes as base64 to load.raw_start_verbose', () async {
      final r = _build();
      final Uint8List bytes = Uint8List.fromList(<int>[9, 8, 7]);
      await r.api.addFile(bytes);
      final String sent = r.rpc.requests.single.data as String;
      expect(sent, contains('load.raw_start_verbose'));
      expect(sent, contains('<base64>${base64Encode(bytes)}</base64>'));
    });

    test('adds stopped with load.raw_verbose', () async {
      final r = _build();
      await r.api.addFile(Uint8List.fromList(<int>[1]), start: false);
      expect(
        r.rpc.requests.single.data as String,
        contains('load.raw_verbose'),
      );
    });
  });
}
