import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// The real health probe through the real factory, with only the socket
/// replaced.
///
/// rTorrent's XML-RPC is the address itself, not a route beneath it. The
/// factory gives every base URL a trailing slash, and nginx answers
/// `.../plugins/httprpc/action.php/` with a 404 while `.../action.php` is
/// rTorrent (checked against crazymax/rtorrent-rutorrent).
void main() {
  Instance rtorrentAt(String url) => Instance(
        id: 'rtorrent',
        name: 'rTorrent',
        kind: ServiceKind.rtorrent,
        localUrl: url,
        externalUrl: '',
        urlMode: UrlMode.forceLocal,
        auth: const InstanceAuth.userPass(username: '', password: ''),
      );

  Future<Uri> probedUri(String url) async {
    final _RecordingFactory factory = _RecordingFactory();
    final Health health =
        await HealthProbe(dioFactory: factory).check(rtorrentAt(url));
    expect(health, Health.ok);
    return factory.requests.single.uri;
  }

  test('an endpoint below the root is asked for without a trailing slash',
      () async {
    expect(
      '${await probedUri('https://box.test/rutorrent/plugins/httprpc/action.php')}',
      'https://box.test/rutorrent/plugins/httprpc/action.php',
    );
    expect(
      '${await probedUri('https://box.test/RPC2/')}',
      'https://box.test/RPC2',
    );
  });

  test('a bare port is asked for at its root', () async {
    expect('${await probedUri('http://box.test:8000')}', 'http://box.test:8000/');
  });

  test('selfPath leaves the root alone', () {
    expect(selfPath('http://box.test:8000/'), '');
    expect(
      selfPath('http://box.test/RPC2/'),
      'http://box.test/RPC2',
    );
  });
}

class _RecordingFactory extends DioFactory {
  _RecordingFactory()
      : super(resolver: ConnectionResolver(connectivity: Connectivity()));

  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<Dio> create(Instance instance) async =>
      (await super.create(instance))..httpClientAdapter = _Adapter(this);
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.factory);

  final _RecordingFactory factory;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    factory.requests.add(options);
    return ResponseBody.fromString(
      '<?xml version="1.0"?><methodResponse><params><param><value>'
      '<string>0.16.22</string></value></param></params></methodResponse>',
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['text/xml; charset=UTF-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
