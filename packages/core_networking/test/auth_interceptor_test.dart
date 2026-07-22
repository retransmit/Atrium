import 'dart:convert';
import 'dart:typed_data';

import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Speedtest Tracker token is sent only as a bearer header', () async {
    const String token = 'placeholder-token-not-a-secret';
    final _RecordingAdapter adapter = _RecordingAdapter();
    final Dio dio = Dio(BaseOptions(baseUrl: 'https://tracker.example.test/'))
      ..httpClientAdapter = adapter
      ..interceptors.add(
        const AuthInterceptor(
          kind: ServiceKind.speedtestTracker,
          auth: InstanceAuth.apiKey(apiKey: token),
        ),
      );

    await dio.get<dynamic>('api/v1/results');

    final RequestOptions request = adapter.request!;
    expect(request.headers['Authorization'], 'Bearer $token');
    expect(request.headers['Accept'], 'application/json');
    expect(request.queryParameters.values, isNot(contains(token)));
    expect(request.uri.toString(), isNot(contains(token)));
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{'data': <dynamic>[]}),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
