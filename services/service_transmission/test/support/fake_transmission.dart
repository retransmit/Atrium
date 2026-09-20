import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// One RPC call the fake was sent.
class RpcCall {
  const RpcCall(this.method, this.arguments);

  final String method;
  final Map<String, dynamic> arguments;
}

typedef RpcAnswer = Object? Function(Map<String, dynamic> arguments);

/// Transmission's RPC endpoint, as far as the tests need it.
///
/// Every request is a POST to one path carrying `method` and `arguments`, so
/// answers are keyed by method rather than path. The first request without
/// the current session id gets the daemon's 409 with the id in a header, and
/// the client is expected to retry with it; [rejections] counts those.
class FakeTransmission implements HttpClientAdapter {
  FakeTransmission({this.sessionId = 'session-1'});

  String sessionId;
  int rejections = 0;
  final List<RpcCall> calls = <RpcCall>[];
  final Map<String, RpcAnswer> _answers = <String, RpcAnswer>{};
  final Map<String, String> _errors = <String, String>{};

  /// Answers [method] with [arguments] under `result: success`.
  void on(String method, Object? arguments) =>
      _answers[method] = (Map<String, dynamic> _) => arguments;

  /// Answers [method] from the request's own arguments.
  void onCall(String method, RpcAnswer answer) => _answers[method] = answer;

  /// Answers [method] with `result` set to [result], the way the daemon
  /// reports an error inside an HTTP 200.
  void fail(String method, String result) => _errors[method] = result;

  List<RpcCall> to(String method) => <RpcCall>[
        for (final RpcCall c in calls)
          if (c.method == method) c,
      ];

  RpcCall single(String method) => to(method).single;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.headers['X-Transmission-Session-Id'] != sessionId) {
      rejections++;
      return ResponseBody.fromString(
        '<h1>409: Conflict</h1>',
        409,
        headers: <String, List<String>>{
          'x-transmission-session-id': <String>[sessionId],
          Headers.contentTypeHeader: <String>['text/html'],
        },
      );
    }
    final Map<String, dynamic> body =
        (options.data as Map<Object?, Object?>).cast<String, dynamic>();
    final String method = body['method'] as String;
    final Map<String, dynamic> args =
        (body['arguments'] as Map<Object?, Object?>?)
                ?.cast<String, dynamic>() ??
            <String, dynamic>{};
    calls.add(RpcCall(method, args));
    final String? error = _errors[method];
    if (error != null) {
      return _json(<String, Object?>{
        'result': error,
        'arguments': <String, Object?>{},
      });
    }
    final RpcAnswer? answer = _answers[method];
    return _json(<String, Object?>{
      'result': 'success',
      'arguments': answer == null ? <String, Object?>{} : answer(args),
    });
  }

  ResponseBody _json(Object? body) => ResponseBody.fromString(
        jsonEncode(body),
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['application/json'],
        },
      );

  @override
  void close({bool force = false}) {}
}

/// A Dio set up the way an instance's would be, talking to [fake].
Dio fakeTransmissionDio(FakeTransmission fake) =>
    Dio(BaseOptions(baseUrl: 'http://transmission.test/'))
      ..httpClientAdapter = fake;
