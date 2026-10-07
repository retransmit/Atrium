import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'adguard_home_clients_fixtures.dart';
import 'adguard_home_fixtures.dart';
import 'adguard_home_query_log_fixtures.dart';

typedef FakeAnswer = Object? Function(RequestOptions request);

/// AdGuard Home's `control/` API, as far as the tests need it.
///
/// Out of the box it answers the reads with the captured fixtures and
/// accepts the writes. Requests are matched on method and path.
class FakeAdguardHome implements HttpClientAdapter {
  FakeAdguardHome() {
    on('GET', 'control/status', statusJson());
    on('GET', 'control/stats', statsJson());
    on('GET', 'control/filtering/status', filteringJson());
    on('GET', 'control/stats/config', statsConfigJson());
    on('GET', 'control/querylog', queryLogJson());
    on('GET', 'control/querylog/config', queryLogConfigJson());
    on('GET', 'control/access/list', accessListJson());
    on('GET', 'control/clients', clientListJson());
    on('GET', 'control/blocked_services/all', blockedServicesJson());
    on('GET', 'control/safesearch/status', safeSearchJson());
    onCall('POST', 'control/clients/search', _search);
    on('POST', 'control/protection', null);
    on('POST', 'control/filtering/set_rules', null);
    on('POST', 'control/querylog_clear', null);
    on('POST', 'control/access/set', null);
    on('POST', 'control/clients/add', null);
    on('POST', 'control/clients/update', null);
    on('POST', 'control/clients/delete', null);
  }

  /// What the server says of each id it is asked about: the captured answer
  /// where there is one, and otherwise what it says of an address it knows
  /// nothing of.
  static Object? _search(RequestOptions request) {
    final Object? body = request.data;
    final Object? asked =
        body is Map<Object?, Object?> ? body['clients'] : null;
    final Map<Object?, Object?> known = <Object?, Object?>{
      for (final Object? row in clientSearchJson())
        if (row is Map<Object?, Object?>) ...row,
    };
    return <dynamic>[
      if (asked is List)
        for (final Object? one in asked)
          if (one is Map<Object?, Object?>)
            <String, dynamic>{
              '${one['id']}': known[one['id']] ??
                  <String, dynamic>{
                    'disallowed': false,
                    'whois_info': <String, dynamic>{},
                    'name': '',
                    'ids': <dynamic>[one['id']],
                  },
            },
    ];
  }

  /// Every request that reached the server, in order.
  final List<RequestOptions> requests = <RequestOptions>[];

  /// Answers every request with a bare 401, the way the real server answers
  /// a wrong password and, identically, an address it has locked out.
  bool refusing = false;

  /// While set, a request that has arrived waits on this before it is
  /// answered, so a test can look at what is in flight.
  Completer<void>? hold;

  final Map<String, FakeAnswer> _answers = <String, FakeAnswer>{};
  final Map<String, (int, String, String)> _failures =
      <String, (int, String, String)>{};

  /// Answers [method] [path] with [json]; null answers a bare 200, as the
  /// server does for a write.
  void on(String method, String path, Object? json) =>
      _answers['$method $path'] = (RequestOptions _) => json;

  /// Answers [method] [path] from the request itself.
  void onCall(String method, String path, FakeAnswer answer) =>
      _answers['$method $path'] = answer;

  /// Answers [method] [path] with [status] and a plain-text [message].
  void fail(
    String method,
    String path,
    int status,
    String message, {
    String contentType = 'text/plain; charset=utf-8',
  }) =>
      _failures['$method $path'] = (status, message, contentType);

  List<RequestOptions> to(String method, String path) => <RequestOptions>[
        for (final RequestOptions request in requests)
          if (request.method == method && request.path == path) request,
      ];

  RequestOptions single(String method, String path) => to(method, path).single;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final Completer<void>? held = hold;
    if (held != null) await held.future;
    if (refusing) return ResponseBody.fromString('', 401);

    final String key = '${options.method} ${options.path}';
    final (int, String, String)? failure = _failures[key];
    if (failure != null) {
      return ResponseBody.fromString(
        '${failure.$2}\n',
        failure.$1,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[failure.$3],
        },
      );
    }
    final FakeAnswer? answer = _answers[key];
    if (answer == null) {
      return ResponseBody.fromString(
        '404 page not found\n',
        404,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['text/plain; charset=utf-8'],
        },
      );
    }
    final Object? json = answer(options);
    if (json == null) return ResponseBody.fromString('', 200);
    return ResponseBody.fromString(
      jsonEncode(json),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A Dio that talks to [server].
Dio dioFor(FakeAdguardHome server) =>
    Dio(BaseOptions(baseUrl: 'http://adguard.test/'))
      ..httpClientAdapter = server;
