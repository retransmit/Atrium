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
/// aria2's credential is not an HTTP credential: the daemon reads its
/// `--rpc-secret` from the first parameter of every RPC call. So the probe
/// has to put the secret in the JSON-RPC body and nowhere else - a secret in
/// a header would be handed to every proxy on the way.
void main() {
  const Instance aria2 = Instance(
    id: 'aria2',
    name: 'aria2',
    kind: ServiceKind.aria2,
    localUrl: 'http://aria2.example.test',
    externalUrl: '',
    urlMode: UrlMode.forceLocal,
    auth: InstanceAuth.apiKey(apiKey: 'hunter2'),
  );

  const Instance openAria2 = Instance(
    id: 'aria2-open',
    name: 'aria2',
    kind: ServiceKind.aria2,
    localUrl: 'http://aria2.example.test',
    externalUrl: '',
    urlMode: UrlMode.forceLocal,
    auth: InstanceAuth.apiKey(apiKey: ''),
  );

  test('the probe posts a JSON-RPC call with the secret in the body', () async {
    final _RecordingFactory factory = _RecordingFactory(
      status: 200,
      body: jsonEncode(<String, dynamic>{
        'id': 'atrium',
        'jsonrpc': '2.0',
        'result': <String, dynamic>{
          'version': '1.37.0',
          'enabledFeatures': <String>['HTTP', 'BitTorrent'],
        },
      }),
    );

    final Health health = await HealthProbe(dioFactory: factory).check(aria2);

    final RequestOptions sent = factory.requests.single;
    expect(sent.method, 'POST');
    expect(sent.uri.path, '/jsonrpc');

    final Map<String, dynamic> body =
        jsonDecode(sent.data as String) as Map<String, dynamic>;
    expect(body['jsonrpc'], '2.0');
    expect(body['method'], 'aria2.getVersion');
    // aria2 refuses a request with no id at all.
    expect(body['id'], isNotNull);
    expect(body['params'], <dynamic>['token:hunter2']);

    // The secret is a parameter, never a header.
    expect(
      sent.headers.keys.map((String name) => name.toLowerCase()),
      isNot(contains('x-api-key')),
    );
    expect(sent.headers.values.join(), isNot(contains('hunter2')));

    expect(health, Health.ok);
  });

  test('a daemon with no secret gets no token parameter', () async {
    final _RecordingFactory factory = _RecordingFactory(
      status: 200,
      body: jsonEncode(<String, dynamic>{
        'id': 'atrium',
        'jsonrpc': '2.0',
        'result': <String, dynamic>{'version': '1.37.0'},
      }),
    );

    final Health health =
        await HealthProbe(dioFactory: factory).check(openAria2);

    final Map<String, dynamic> body =
        jsonDecode(factory.requests.single.data as String)
            as Map<String, dynamic>;
    expect(body['params'], isEmpty);
    expect(health, Health.ok);
  });

  test('a refused secret is a warning, not a broken server', () async {
    // aria2 answers a wrong secret with HTTP 400 and an `error` envelope.
    final _RecordingFactory factory = _RecordingFactory(
      status: 400,
      body: jsonEncode(<String, dynamic>{
        'id': 'atrium',
        'jsonrpc': '2.0',
        'error': <String, dynamic>{'code': 1, 'message': 'Unauthorized'},
      }),
    );

    expect(await HealthProbe(dioFactory: factory).check(aria2), Health.warning);
  });

  test('a 200 that is not aria2 is a warning', () async {
    // Something else on the port: a proxy, or another service's API.
    final _RecordingFactory factory = _RecordingFactory(
      status: 200,
      body: jsonEncode(<String, dynamic>{'hello': 'world'}),
    );

    expect(await HealthProbe(dioFactory: factory).check(aria2), Health.warning);
  });

  test('no answer at all is offline', () async {
    final _RecordingFactory factory = _RecordingFactory(status: 0, body: '');

    expect(await HealthProbe(dioFactory: factory).check(aria2), Health.error);
  });
}

/// The real factory, with the socket of every client it makes replaced by one
/// that answers with a canned aria2 reply.
class _RecordingFactory extends DioFactory {
  _RecordingFactory({required int status, required String body})
      : _status = status,
        _body = body,
        super(
          resolver: ConnectionResolver(connectivity: Connectivity()),
        );

  final int _status;
  final String _body;
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
      factory._body,
      factory._status,
      headers: <String, List<String>>{
        // The content type aria2 actually labels its replies with.
        Headers.contentTypeHeader: <String>['application/json-rpc'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
