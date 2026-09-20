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
    expect(request.headers.containsKey('x-api-key'), isFalse);
    expect(request.headers.containsKey('X-Api-Key'), isFalse);
    expect(request.queryParameters.values, isNot(contains(token)));
    expect(request.uri.toString(), isNot(contains(token)));
  });

  test('Tracearr token is sent only as a Bearer header without x-api-key', () async {
    const String token = 'placeholder-tracearr-token';
    final _RecordingAdapter adapter = _RecordingAdapter();
    final Dio dio = Dio(BaseOptions(baseUrl: 'https://tracearr.example.test/'))
      ..httpClientAdapter = adapter
      ..interceptors.add(
        const AuthInterceptor(
          kind: ServiceKind.tracearr,
          auth: InstanceAuth.apiKey(apiKey: token),
        ),
      );

    await dio.get<dynamic>('api/v2/public/history');

    final RequestOptions request = adapter.request!;
    expect(request.headers['Authorization'], 'Bearer $token');
    expect(request.headers['Accept'], 'application/json');
    expect(request.headers.containsKey('x-api-key'), isFalse);
    expect(request.headers.containsKey('X-Api-Key'), isFalse);
    expect(request.queryParameters.values, isNot(contains(token)));
    expect(request.uri.toString(), isNot(contains(token)));
  });

  test('MySpeed password is sent as password and x-password headers', () async {
    const String password = 'my secret @ password!';
    final _RecordingAdapter adapter = _RecordingAdapter();
    final Dio dio = Dio(BaseOptions(baseUrl: 'https://myspeed.example.test/'))
      ..httpClientAdapter = adapter
      ..interceptors.add(
        const AuthInterceptor(
          kind: ServiceKind.myspeed,
          auth: InstanceAuth.apiKey(apiKey: password),
        ),
      );

    await dio.get<dynamic>('api/speedtests');

    final RequestOptions request = adapter.request!;
    expect(request.headers['password'], password);
    expect(request.headers['x-password'], Uri.encodeComponent(password));
    expect(request.headers.containsKey('X-Api-Key'), isFalse);
    expect(request.headers.containsKey('Authorization'), isFalse);
  });

  test('a MySpeed password outside ASCII travels only as x-password',
      () async {
    // Dart's HttpHeaders throws on such a value, so the raw header would
    // fail every request rather than merely be ignored.
    const String password = 'pässwörd';
    final _RecordingAdapter adapter = _RecordingAdapter();
    final Dio dio = Dio(BaseOptions(baseUrl: 'https://myspeed.example.test/'))
      ..httpClientAdapter = adapter
      ..interceptors.add(
        const AuthInterceptor(
          kind: ServiceKind.myspeed,
          auth: InstanceAuth.apiKey(apiKey: password),
        ),
      );

    await dio.get<dynamic>('api/speedtests');

    final RequestOptions request = adapter.request!;
    expect(request.headers.containsKey('password'), isFalse);
    expect(request.headers['x-password'], Uri.encodeComponent(password));
  });

  test('MySpeed with empty password sets no auth headers', () async {
    final _RecordingAdapter adapter = _RecordingAdapter();
    final Dio dio = Dio(BaseOptions(baseUrl: 'https://myspeed.example.test/'))
      ..httpClientAdapter = adapter
      ..interceptors.add(
        const AuthInterceptor(
          kind: ServiceKind.myspeed,
          auth: InstanceAuth.apiKey(apiKey: ''),
        ),
      );

    await dio.get<dynamic>('api/speedtests');

    final RequestOptions request = adapter.request!;
    expect(request.headers.containsKey('password'), isFalse);
    expect(request.headers.containsKey('x-password'), isFalse);
    expect(request.headers.containsKey('X-Api-Key'), isFalse);
    expect(request.headers.containsKey('Authorization'), isFalse);
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
