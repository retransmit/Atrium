import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef FakeAnswer = Object? Function(RequestOptions request);

/// Prowlarr's `api/v1` as far as the search tests need it. Requests are
/// matched on method and path.
class FakeProwlarr implements HttpClientAdapter {
  FakeProwlarr() {
    on('GET', 'api/v1/indexer', indexersJson());
    on('GET', 'api/v1/indexer/categories', categoriesJson());
    on('GET', 'api/v1/search', <dynamic>[releaseJson('Dune 1080p')]);
  }

  /// Every request that reached the server, in order.
  final List<RequestOptions> requests = <RequestOptions>[];

  final Map<String, FakeAnswer> _answers = <String, FakeAnswer>{};
  final Map<String, int> _failures = <String, int>{};

  /// Answers [method] [path] with [json].
  void on(String method, String path, Object? json) =>
      _answers['$method $path'] = (RequestOptions _) => json;

  /// Answers [method] [path] from the request itself.
  void onCall(String method, String path, FakeAnswer answer) =>
      _answers['$method $path'] = answer;

  /// Answers [method] [path] with a bare [status].
  void fail(String method, String path, int status) =>
      _failures['$method $path'] = status;

  /// Answers [method] [path] as before it was made to [fail].
  void mend(String method, String path) => _failures.remove('$method $path');

  List<RequestOptions> to(String method, String path) => <RequestOptions>[
        for (final RequestOptions request in requests)
          if (request.method == method && request.path == path) request,
      ];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final String key = '${options.method} ${options.path}';
    final int? failure = _failures[key];
    if (failure != null) {
      return ResponseBody.fromString('', failure);
    }
    final FakeAnswer? answer = _answers[key];
    if (answer == null) {
      return ResponseBody.fromString('', 404);
    }
    final Object? json = await answer(options);
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
Dio dioFor(FakeProwlarr server) =>
    Dio(BaseOptions(baseUrl: 'http://prowlarr.test/'))
      ..httpClientAdapter = server;

List<dynamic> indexersJson() => <dynamic>[
      _indexer(1, 'Example Public Tracker', 'torrent'),
      _indexer(2, 'Example Private Tracker', 'torrent'),
      _indexer(4, 'Old Tracker', 'torrent', enable: false),
      _indexer(5, 'Example Usenet Indexer', 'usenet'),
    ];

Map<String, dynamic> _indexer(
  int id,
  String name,
  String protocol, {
  bool enable = true,
}) =>
    <String, dynamic>{
      'id': id,
      'name': name,
      'enable': enable,
      'protocol': protocol,
      'privacy': 'public',
      'priority': 25,
      'tags': <dynamic>[],
    };

List<dynamic> categoriesJson() => <dynamic>[
      _category(2000, 'Movies', <dynamic>[
        _category(2040, 'Movies/HD'),
        _category(2045, 'Movies/UHD'),
      ]),
      _category(5000, 'TV', <dynamic>[_category(5040, 'TV/HD')]),
    ];

Map<String, dynamic> _category(
  int id,
  String name, [
  List<dynamic> subs = const <dynamic>[],
]) =>
    <String, dynamic>{'id': id, 'name': name, 'subCategories': subs};

Map<String, dynamic> releaseJson(String title) => <String, dynamic>{
      'guid': 'fake-$title',
      'indexerId': 1,
      'indexer': 'Example Public Tracker',
      'title': title,
      'size': 1500000000,
      'seeders': 50,
      'leechers': 1,
      'age': 0,
      'ageHours': 0.0,
      'protocol': 'torrent',
      'categories': <dynamic>[
        <String, dynamic>{'id': 2040, 'name': 'Movies/HD'},
      ],
      'publishDate': '2026-11-20T10:00:00Z',
    };
