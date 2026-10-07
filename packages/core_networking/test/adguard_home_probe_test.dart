import 'dart:convert';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// The real health probe, through the real factory and interceptor, with
/// only the socket replaced.
///
/// AdGuard Home counts every wrong `Authorization: Basic` as a failed
/// sign-in and refuses the address for fifteen minutes after five. The probe
/// runs about twice a minute, so what it puts on the wire is pinned here end
/// to end rather than piece by piece.
void main() {
  const Instance adguard = Instance(
    id: 'adguard',
    name: 'AdGuard Home',
    kind: ServiceKind.adguardHome,
    localUrl: 'http://adguard.example.test',
    externalUrl: '',
    // Forced, so the resolver answers without probing the network.
    urlMode: UrlMode.forceLocal,
    auth: InstanceAuth.userPass(username: 'admin', password: 'wrong'),
  );

  test('the probe carries no Authorization, its own or the profile one',
      () async {
    final _RecordingFactory factory = _RecordingFactory(
      const <String, String>{
        'Authorization': 'Basic for-a-proxy',
        'CF-Access-Client-Id': 'id',
      },
    );

    final Health health = await HealthProbe(dioFactory: factory).check(adguard);

    final RequestOptions sent = factory.requests.single;
    expect(sent.uri.path, '/control/status');
    expect(
      sent.headers.keys.map((String name) => name.toLowerCase()),
      isNot(contains('authorization')),
    );
    // The rest of the profile's headers still go: a proxy in front may need
    // them to let the probe through at all.
    expect(sent.headers['CF-Access-Client-Id'], 'id');
    // The bare 401 a protected server answers with is a server that is up.
    expect(health, Health.ok);
  });

  test('every other request through the same factory is signed', () async {
    final _RecordingFactory factory =
        _RecordingFactory(const <String, String>{});
    final Dio dio = await factory.create(adguard);

    await dio.get<dynamic>(
      'control/stats',
      options: Options(validateStatus: (_) => true),
    );

    expect(
      factory.requests.single.headers['Authorization'],
      'Basic ${base64Encode(utf8.encode('admin:wrong'))}',
    );
  });
}

/// The real factory, with the socket of every client it makes replaced by
/// one that notes the request and refuses it the way AdGuard Home does.
class _RecordingFactory extends DioFactory {
  _RecordingFactory(Map<String, String> profileHeaders)
      : super(
          resolver: ConnectionResolver(connectivity: Connectivity()),
          globalHeaders: profileHeaders,
        );

  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<Dio> create(Instance instance) async =>
      (await super.create(instance))..httpClientAdapter = _Refusing(requests);
}

class _Refusing implements HttpClientAdapter {
  _Refusing(this._requests);

  final List<RequestOptions> _requests;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    _requests.add(options);
    return ResponseBody.fromString('', 401);
  }

  @override
  void close({bool force = false}) {}
}
