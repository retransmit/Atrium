import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_rtorrent/service_rtorrent.dart';

class _Answer implements HttpClientAdapter {
  _Answer(this.status, this.body, {this.contentType = 'text/xml'});

  final int status;
  final String body;
  final String contentType;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      ResponseBody.fromString(
        body,
        status,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[contentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

class _Recording implements HttpClientAdapter {
  final List<Uri> uris = <Uri>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    uris.add(options.uri);
    return ResponseBody.fromString(
      '<?xml version="1.0"?><methodResponse><params><param><value>'
      '<string>0.16.22</string></value></param></params></methodResponse>',
      200,
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<RtorrentEndpointAnswer> _answering(
  int status,
  String body, {
  String contentType = 'text/xml',
}) =>
    checkRtorrentEndpoint(
      Dio(BaseOptions(baseUrl: 'http://box.test/'))
        ..httpClientAdapter = _Answer(status, body, contentType: contentType),
    );

void main() {
  group('checkRtorrentEndpoint', () {
    test('a methodResponse is rTorrent', () async {
      expect(
        await _answering(
          200,
          '<?xml version="1.0"?><methodResponse><params><param><value>'
          '<string>0.9.8</string></value></param></params></methodResponse>',
        ),
        RtorrentEndpointAnswer.xmlRpc,
      );
    });

    test('a fault is rTorrent too', () async {
      expect(
        await _answering(
          200,
          '<?xml version="1.0"?><methodResponse><fault><value><struct>'
          '<member><name>faultCode</name><value><i4>-506</i4></value></member>'
          '<member><name>faultString</name><value><string>Method not '
          'defined</string></value></member></struct></value></fault>'
          '</methodResponse>',
        ),
        RtorrentEndpointAnswer.xmlRpc,
      );
    });

    test('the ruTorrent page is not', () async {
      expect(
        await _answering(
          200,
          '<!doctype html><html><title>ruTorrent</title></html>',
          contentType: 'text/html',
        ),
        RtorrentEndpointAnswer.notXmlRpc,
      );
    });

    test('a 404 or a proxy error is not', () async {
      expect(
        await _answering(404, 'Not Found'),
        RtorrentEndpointAnswer.notXmlRpc,
      );
      expect(
        await _answering(502, 'Bad Gateway'),
        RtorrentEndpointAnswer.notXmlRpc,
      );
    });

    test('a 401 is refused credentials', () async {
      expect(
        await _answering(401, 'Unauthorized'),
        RtorrentEndpointAnswer.refused,
      );
    });
  });

  group('rtorrentGuessUrl', () {
    test('appends beneath the address, with or without a trailing slash', () {
      expect(
        rtorrentGuessUrl('https://box.test/rutorrent/', 'RPC2'),
        'https://box.test/rutorrent/RPC2',
      );
      expect(
        rtorrentGuessUrl(' https://box.test/rutorrent ', 'RPC2'),
        'https://box.test/rutorrent/RPC2',
      );
    });

    test('does not look beneath an address that is already an endpoint', () {
      expect(
        rtorrentGuessUrl(
          'https://box.test/rutorrent/plugins/httprpc/action.php',
          'RPC2',
        ),
        isNull,
      );
      expect(rtorrentGuessUrl('http://box.test/RPC2/', 'RPC2'), isNull);
    });
  });

  test('calls go to an httprpc address without a trailing slash', () async {
    // nginx answers `.../action.php/` with a 404.
    final _Recording adapter = _Recording();
    await RtorrentApi(
      Dio(
        BaseOptions(
          baseUrl: 'https://box.test/rutorrent/plugins/httprpc/action.php/',
        ),
      )..httpClientAdapter = adapter,
    ).clientVersion();
    expect(
      '${adapter.uris.single}',
      'https://box.test/rutorrent/plugins/httprpc/action.php',
    );
  });

  test('the error for a web page says where rTorrent usually is', () async {
    final RtorrentApi api = RtorrentApi(
      Dio(BaseOptions(baseUrl: 'http://box.test/'))
        ..httpClientAdapter = _Answer(
          200,
          '<html></html>',
          contentType: 'text/html',
        ),
    );
    await expectLater(
      api.getTorrents(),
      throwsA(
        isA<Exception>().having(
          (Exception e) => e.toString(),
          'message',
          contains('/plugins/httprpc/action.php'),
        ),
      ),
    );
  });
}
