import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_seerr/service_seerr.dart';

/// A Seerr holding [requests] requests, whose ids are their places in the
/// list. It slices pages of `/request` by `take` and `skip` like the server,
/// but ignores `sort` and `filter`, and sends only the fields the client
/// reads.
class _FakeSeerr implements HttpClientAdapter {
  _FakeSeerr(
    this.requests, {
    this.countStatus = 200,
    this.countBody,
    this.countError,
    this.failSkip,
    this.held = false,
  });

  final int requests;
  final int countStatus;

  /// What `/request/count` answers with, when not the plain `total`.
  final Map<String, dynamic>? countBody;

  /// How `/request/count` fails without an answer, if it does.
  final DioExceptionType? countError;

  /// The page of `/request` answered with a 500, if any.
  final int? failSkip;

  /// Whether each page waits for its entry in [gates] before it answers.
  final bool held;
  final Map<int, Completer<void>> gates = <int, Completer<void>>{};
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
      if (countError != null) {
        throw DioException(requestOptions: options, type: countError!);
      }
      return _json(
        countBody ?? <String, dynamic>{'total': requests},
        countStatus,
      );
    }
    final int take = options.queryParameters['take'] as int;
    final int skip = options.queryParameters['skip'] as int;
    if (held) {
      await (gates[skip] = Completer<void>()).future;
    }
    if (skip == failSkip) {
      return _json(<String, dynamic>{}, 500);
    }
    final Map<String, dynamic> page = <String, dynamic>{
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
  DioExceptionType? countError,
  int? failSkip,
  bool held = false,
}) {
  final _FakeSeerr server = _FakeSeerr(
    requests,
    countStatus: countStatus,
    countBody: countBody,
    countError: countError,
    failSkip: failSkip,
    held: held,
  );
  final Dio dio = Dio(BaseOptions(baseUrl: 'http://seerr.test/'))
    ..httpClientAdapter = server;
  return (api: SeerrApi(dio), server: server);
}

void main() {
  group('getAllRequests', () {
    test(
      'asks for every page the count covers at once, and keeps their order '
      'whatever order they arrive in',
      () async {
        final r = _build(250, held: true);

        final Future<List<SeerrRequest>> all = r.api.getAllRequests();
        await pumpEventQueue();

        expect(r.server.asked.first.path, endsWith('/request/count'));
        expect(r.server.skips, unorderedEquals(<int>[0, 100, 200]));
        for (final int skip in <int>[200, 100, 0]) {
          r.server.gates[skip]!.complete();
          await pumpEventQueue();
        }
        expect((await all).map((SeerrRequest q) => q.id), <int>[
          for (int i = 0; i < 250; i++) i,
        ]);
      },
    );

    test('fails, rather than returning part of the list, when a page fails',
        () async {
      final r = _build(250, failSkip: 100);

      await expectLater(
        r.api.getAllRequests(),
        throwsA(isA<NetworkServerException>()),
      );
      expect(r.server.skips, unorderedEquals(<int>[0, 100, 200]));
    });

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

    test('gives up without paging when the count times out', () async {
      final r = _build(150, countError: DioExceptionType.receiveTimeout);

      await expectLater(
        r.api.getAllRequests(),
        throwsA(isA<NetworkTimeoutException>()),
      );
      expect(r.server.skips, isEmpty);
    });

    test('gives up without paging when the server cannot be reached', () async {
      final r = _build(150, countError: DioExceptionType.connectionError);

      await expectLater(
        r.api.getAllRequests(),
        throwsA(isA<NetworkUnreachableException>()),
      );
      expect(r.server.skips, isEmpty);
    });
  });
}
