import 'dart:convert';
import 'dart:typed_data';

import 'package:atrium/src/connection_test/connection_test_result.dart';
import 'package:atrium/src/connection_test/connection_tester.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test connection for Seerr, through the real factory, interceptor and
/// session, against a Seerr that answers `auth/me` only to its key or to a
/// session one of its sign-ins handed out.
void main() {
  Instance seerr(InstanceAuth auth) => Instance(
        id: 'seerr',
        name: 'Seerr',
        kind: ServiceKind.seerr,
        localUrl: 'http://seerr.example.test',
        externalUrl: '',
        urlMode: UrlMode.auto,
        auth: auth,
      );

  Future<(ConnectionTestResult, _FakeSeerr)> testWith(
    InstanceAuth auth,
  ) async {
    final _FakeSeerr server = _FakeSeerr();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[dioFactoryProvider.overrideWithValue(server)],
    );
    addTearDown(container.dispose);
    final ConnectionTestResult result = await container
        .read(connectionTesterProvider)
        .test(candidate: seerr(auth), url: UrlMode.forceLocal);
    return (result, server);
  }

  test('a right API key connects', () async {
    final (ConnectionTestResult result, _FakeSeerr server) =
        await testWith(const InstanceAuth.apiKey(apiKey: _FakeSeerr.key));

    expect(result.outcome, ConnectionOutcome.connected);
    expect(result.message, 'Connected');
    expect(server.paths, <String>['/api/v1/auth/me']);
  });

  test('a wrong API key is refused', () async {
    final (ConnectionTestResult result, _) =
        await testWith(const InstanceAuth.apiKey(apiKey: 'wrong'));

    expect(result.outcome, ConnectionOutcome.authFailed);
  });

  test('a local account says who it signed in as', () async {
    final (ConnectionTestResult result, _FakeSeerr server) = await testWith(
      const InstanceAuth.cookieLogin(
        username: _FakeSeerr.email,
        password: _FakeSeerr.password,
      ),
    );

    expect(result.outcome, ConnectionOutcome.connected);
    expect(result.message, 'Signed in as Kid');
    expect(server.paths, <String>['/api/v1/auth/local', '/api/v1/auth/me']);
  });

  test('a Jellyfin or Emby account signs in through Seerr', () async {
    final (ConnectionTestResult result, _FakeSeerr server) = await testWith(
      const InstanceAuth.userPass(
        username: _FakeSeerr.username,
        password: _FakeSeerr.password,
      ),
    );

    expect(result.message, 'Signed in as Kid');
    expect(server.paths.first, '/api/v1/auth/jellyfin');
  });

  test('a wrong password says the sign-in was rejected', () async {
    final (ConnectionTestResult result, _FakeSeerr server) = await testWith(
      const InstanceAuth.cookieLogin(
        username: _FakeSeerr.email,
        password: 'wrong',
      ),
    );

    expect(result.outcome, ConnectionOutcome.authFailed);
    expect(
      result.message,
      'Seerr rejected the sign-in. Check the email and password.',
    );
    expect(server.paths, <String>['/api/v1/auth/local']);
  });
}

class _FakeSeerr extends DioFactory {
  _FakeSeerr()
      : super(resolver: ConnectionResolver(connectivity: Connectivity()));

  static const String key = 'right-key';
  static const String email = 'kid@example.com';
  static const String username = 'kid';
  static const String password = 'pw-ok';

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
    final String path = options.uri.path;
    server.paths.add(path);
    final Map<String, dynamic> body = options.data is Map
        ? Map<String, dynamic>.from(options.data as Map)
        : <String, dynamic>{};
    if (path.endsWith('auth/local') || path.endsWith('auth/jellyfin')) {
      final Object? who =
          path.endsWith('auth/local') ? body['email'] : body['username'];
      final bool ok = (who == _FakeSeerr.email || who == _FakeSeerr.username) &&
          body['password'] == _FakeSeerr.password;
      return _json(
        ok ? <String, dynamic>{'id': 7} : <String, dynamic>{'message': 'no'},
        ok ? 200 : 403,
        cookie: ok ? 'connect.sid=s1; Path=/; HttpOnly' : null,
      );
    }
    final bool keyed = options.headers['X-Api-Key'] == _FakeSeerr.key;
    final bool session =
        '${options.headers['cookie'] ?? ''}'.contains('connect.sid=s1');
    if (!keyed && !session) {
      return _json(<String, dynamic>{'message': 'Unauthorized'}, 403);
    }
    return _json(
      <String, dynamic>{
        'id': keyed ? 1 : 7,
        'displayName': keyed ? 'Owner' : 'Kid',
        'permissions': keyed ? 2 : 32,
      },
      200,
    );
  }

  ResponseBody _json(
    Map<String, dynamic> data,
    int status, {
    String? cookie,
  }) =>
      ResponseBody.fromString(
        jsonEncode(data),
        status,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          if (cookie != null) 'set-cookie': <String>[cookie],
        },
      );

  @override
  void close({bool force = false}) {}
}
