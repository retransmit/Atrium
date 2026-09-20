import 'dart:typed_data';

import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Recorder implements HttpClientAdapter {
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString('{}', 200);
  }

  @override
  void close({bool force = false}) {}
}

/// Ombi reads only its own `ApiKey` header. Checked against Ombi v4.53:
/// every protected route answers 401 to `X-Api-Key`.
void main() {
  const InstanceAuth key = InstanceAuth.apiKey(apiKey: 'secret');

  test('Ombi gets its key as ApiKey and never as X-Api-Key', () async {
    final _Recorder recorder = _Recorder();
    final Dio dio = Dio(BaseOptions(baseUrl: 'http://ombi.test/'))
      ..httpClientAdapter = recorder
      ..interceptors
          .add(const AuthInterceptor(kind: ServiceKind.ombi, auth: key));

    await dio.get<dynamic>('api/v1/Request/count');

    expect(recorder.last!.headers['ApiKey'], 'secret');
    expect(recorder.last!.headers.containsKey('X-Api-Key'), isFalse);
  });

  test('the header list agrees', () {
    expect(serviceAuthHeaderNames(ServiceKind.ombi, key), <String>{'ApiKey'});
  });
}
