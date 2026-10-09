import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_seerr/service_seerr.dart';

/// A Seerr holding [requests] requests, newest first, that answers
/// `/request/count` and pages of `/request` the way the server does.
class _FakeSeerr implements HttpClientAdapter {
  _FakeSeerr(this.requests, {this.countStatus = 200, this.countBody});

  final int requests;
  final int countStatus;

  /// What `/request/count` answers with, when not the plain `total`.
  final Map<String, dynamic>? countBody;
  final List<RequestOptions> asked = <RequestOptions>[];

  List<int> get skips => <int>[
        for (final RequestOptions o in asked)
          if (o.path.endsWith('/request')) o.queryParameters['skip'] as int,
      ];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    asked.add(options);
    if (options.path.endsWith('/request/count')) {
      return _json(
        countBody ?? <String, dynamic>{'total': requests},
        countStatus,
      );
    }
    final int take = options.queryParameters['take'] as int;
    final int skip = options.queryParameters['skip'] as int;
    final Map<String, dynamic> page = <String, dynamic>{
      'pageInfo': <String, dynamic>{'results': requests},
      'results': <Map<String, dynamic>>[
        for (int id = skip; id < requests && id < skip + take; id++)
          <String, dynamic>{'id': id},
      ],
    };
    return _json(page, 200);
  }

  ResponseBody _json(Map<String, dynamic> body, int status) =>
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

({SeerrApi api, _FakeSeerr server}) _build(
  int requests, {
  int countStatus = 200,
  Map<String, dynamic>? countBody,
}) {
  final _FakeSeerr server = _FakeSeerr(
    requests,
    countStatus: countStatus,
    countBody: countBody,
  );
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://seerr.test/'))
    ..httpClientAdapter = server;
  return (api: SeerrApi(dio), server: server);
}

void main() {
  group('getAllRequests', () {
    test(
      'asks for exactly the pages the count covers, and keeps their order',
      () async {
        final r = _build(250);

        final List<SeerrRequest> all = await r.api.getAllRequests();

        expect(r.server.skips, unorderedEquals(<int>[0, 100, 200]));
        expect(all.map((SeerrRequest q) => q.id), <int>[
          for (int i = 0; i < 250; i++) i,
        ]);
      },
    );

    test('asks for one page when the count is zero', () async {
      final r = _build(0);

      expect(await r.api.getAllRequests(), isEmpty);
      expect(r.server.skips, <int>[0]);
    });

    test('pages one at a time when the count has no total', () async {
      final r = _build(150, countBody: <String, dynamic>{});

      final List<SeerrRequest> all = await r.api.getAllRequests();

      expect(r.server.skips, <int>[0, 100]);
      expect(all, hasLength(150));
    });

    test('stops at the safety cap on a very large instance', () async {
      final r = _build(5000);

      final List<SeerrRequest> all = await r.api.getAllRequests();

      expect(r.server.skips, hasLength(20));
      expect(all, hasLength(2000));
    });

    test(
      'pages one at a time until a short page when the count fails',
      () async {
        final r = _build(150, countStatus: 500);

        final List<SeerrRequest> all = await r.api.getAllRequests();

        expect(r.server.skips, <int>[0, 100]);
        expect(all, hasLength(150));
      },
    );
  });
}
