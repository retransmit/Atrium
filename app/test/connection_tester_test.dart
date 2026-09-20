import 'dart:typed_data';

import 'package:atrium/src/connection_test/connection_test_result.dart';
import 'package:atrium/src/connection_test/connection_tester.dart';
import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Health maps to a ConnectionTestResult', () {
    expect(
      connectionResultFromHealth(Health.ok).outcome,
      ConnectionOutcome.connected,
    );
    expect(
      connectionResultFromHealth(Health.warning).outcome,
      ConnectionOutcome.authFailed,
    );
    expect(
      connectionResultFromHealth(Health.error).outcome,
      ConnectionOutcome.unreachable,
    );
  });

  test('errors map to a ConnectionTestResult', () {
    expect(
      connectionResultFromError(const NetworkAuthException('rejected')).outcome,
      ConnectionOutcome.authFailed,
    );
    expect(
      connectionResultFromError(Exception('boom')).outcome,
      ConnectionOutcome.unreachable,
    );
  });

  group('Gluetun', () {
    const Instance gluetun = Instance(
      id: 'gluetun',
      name: 'Gluetun',
      kind: ServiceKind.gluetun,
      localUrl: 'http://gluetun.test',
      externalUrl: '',
      urlMode: UrlMode.auto,
      auth: InstanceAuth.apiKey(apiKey: 'k'),
    );

    Future<ConnectionOutcome> testAnswering(int status, String body) async {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          dioFactoryProvider.overrideWithValue(
            _AnsweringDioFactory(status: status, body: body),
          ),
        ],
      );
      addTearDown(container.dispose);
      final ConnectionTestResult result =
          await container.read(connectionTesterProvider).test(
                candidate: gluetun,
                url: UrlMode.forceLocal,
              );
      return result.outcome;
    }

    test('a stopped VPN still tests as connected', () async {
      // The status dot warns while the VPN is down, but the URL and the key
      // are right, which is all Test connection is asking.
      expect(
        await testAnswering(200, '{"status":"stopped"}'),
        ConnectionOutcome.connected,
      );
    });

    test('a refused key still fails', () async {
      expect(
        await testAnswering(401, 'Unauthorized'),
        ConnectionOutcome.authFailed,
      );
    });
  });
}

/// Hands out a Dio that answers every request with one status and body,
/// labelled `text/plain` the way Gluetun labels everything.
class _AnsweringDioFactory implements DioFactory {
  _AnsweringDioFactory({required this.status, required this.body});

  final int status;
  final String body;

  @override
  Future<Dio> create(Instance instance) async =>
      Dio(BaseOptions(baseUrl: 'http://gluetun.test/'))
        ..httpClientAdapter = _Answer(status: status, body: body);
}

class _Answer implements HttpClientAdapter {
  _Answer({required this.status, required this.body});

  final int status;
  final String body;

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
          Headers.contentTypeHeader: <String>['text/plain; charset=utf-8'],
        },
      );

  @override
  void close({bool force = false}) {}
}
