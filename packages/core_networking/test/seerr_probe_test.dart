import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// The real health probe, through the real factory and interceptor, with
/// only the socket replaced, against a Seerr that answers `status` to anyone
/// and `auth/me` only to its own key.
void main() {
  Instance seerr(InstanceAuth auth) => Instance(
        id: 'seerr',
        name: 'Seerr',
        kind: ServiceKind.seerr,
        localUrl: 'http://seerr.example.test',
        externalUrl: '',
        urlMode: UrlMode.forceLocal,
        auth: auth,
      );

  test('a right API key is healthy', () async {
    final _FakeSeerr factory = _FakeSeerr();

    final Health health = await HealthProbe(dioFactory: factory)
        .check(seerr(const InstanceAuth.apiKey(apiKey: _FakeSeerr.key)));

    expect(factory.paths, <String>['/api/v1/auth/me']);
    expect(health, Health.ok);
  });

  test('a wrong API key is a warning, not healthy', () async {
    // The public status page would have called this healthy.
    final Health health = await HealthProbe(dioFactory: _FakeSeerr())
        .check(seerr(const InstanceAuth.apiKey(apiKey: 'wrong')));

    expect(health, Health.warning);
  });

  for (final (String who, InstanceAuth auth) in <(String, InstanceAuth)>[
    (
      'a local account',
      const InstanceAuth.cookieLogin(username: 'kid@example.com', password: 'p'),
    ),
    (
      'a Jellyfin or Emby account',
      const InstanceAuth.userPass(username: 'kid', password: 'p'),
    ),
  ]) {
    test('$who is probed at status and never signs in', () async {
      final _FakeSeerr factory = _FakeSeerr();

      final Health health = await HealthProbe(dioFactory: factory).check(
        seerr(auth),
      );

      expect(factory.paths, <String>['/api/v1/status']);
      expect(health, Health.ok);
    });
  }
}

class _FakeSeerr extends DioFactory {
  _FakeSeerr()
      : super(resolver: ConnectionResolver(connectivity: Connectivity()));

  static const String key = 'right-key';

  final List<String> paths = <String>[];

  @override
  Future<Dio> create(Instance instance) async =>
      (await super.create(instance))..httpClientAdapter = _Adapter(this);
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.server);

  final _FakeSeerr server;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    server.paths.add(options.uri.path);
    final bool open = options.uri.path.endsWith('/status');
    final bool keyed = options.headers['X-Api-Key'] == _FakeSeerr.key;
    return ResponseBody.fromString(
      open || keyed ? '{"id":1}' : '{"message":"Unauthorized"}',
      open || keyed ? 200 : 403,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
