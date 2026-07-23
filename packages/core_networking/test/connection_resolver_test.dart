import 'dart:convert';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('auto local probe receives the per-instance self-signed opt-in',
      () async {
    final List<bool> selfSignedChoices = <bool>[];
    final ConnectionResolver resolver = ConnectionResolver(
      connectivity: Connectivity(),
      probeClientFactory: (bool allowSelfSignedCerts) {
        selfSignedChoices.add(allowSelfSignedCerts);
        return Dio()..httpClientAdapter = _ReachableAdapter();
      },
    );
    addTearDown(resolver.dispose);
    const Instance instance = Instance(
      id: 'self-signed-probe',
      name: 'Tracker',
      kind: ServiceKind.speedtestTracker,
      localUrl: 'https://tracker.lan',
      externalUrl: 'https://tracker.example.test',
      urlMode: UrlMode.auto,
      auth: InstanceAuth.apiKey(apiKey: 'placeholder-token'),
      allowSelfSignedCerts: true,
    );

    final Uri selected = await resolver.resolve(instance);

    expect(selected, Uri.parse('https://tracker.lan'));
    expect(selfSignedChoices, <bool>[true]);
  });
}

class _ReachableAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      ResponseBody.fromString(
        jsonEncode(<String, dynamic>{'message': 'reachable'}),
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}
