import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_speedtest_tracker/service_speedtest_tracker.dart';

import 'fixtures/speedtest_responses.dart';
import 'support/fake_http_client_adapter.dart';

const String placeholderToken = 'placeholder-speedtest-token';

void main() {
  test('lists completed results with compatible pagination and bearer auth',
      () async {
    final FakeHttpClientAdapter adapter = FakeHttpClientAdapter(
      (RequestOptions options) => (
        status: 200,
        data: resultPage(<Map<String, dynamic>>[currentResult]),
      ),
    );
    final Dio dio = _dio(adapter);
    final SpeedtestResultsPage page =
        await SpeedtestTrackerApi(dio).listResults(
      page: 2,
      status: SpeedtestResultStatus.completed,
    );

    expect(page.results, hasLength(1));
    final RequestOptions request = adapter.requests.single;
    expect(request.path, 'api/v1/results');
    expect(request.queryParameters['filter[status]'], 'completed');
    expect(request.queryParameters['sort'], '-created_at');
    expect(request.queryParameters['page'], 2);
    expect(request.queryParameters['page[number]'], 2);
    expect(request.queryParameters['page[size]'], 25);
    expect(request.queryParameters['per_page'], 25);
    expect(request.headers['Authorization'], 'Bearer $placeholderToken');
    expect(request.headers['Accept'], 'application/json');
    expect(request.uri.toString(), isNot(contains(placeholderToken)));
    expect(request.followRedirects, isFalse);
  });

  test('does not follow redirects or authenticate a redirected host', () async {
    final FakeHttpClientAdapter adapter = FakeHttpClientAdapter(
      (RequestOptions options) => (status: 302, data: null),
      headersFactory: (RequestOptions _) => <String, List<String>>{
        'location': <String>[
          'https://redirected.example.test/api/v1/results',
        ],
      },
    );

    await expectLater(
      SpeedtestTrackerApi(_dio(adapter)).listResults(),
      throwsA(
        isA<SpeedtestTrackerException>()
            .having(
              (SpeedtestTrackerException error) => error.statusCode,
              'status',
              302,
            )
            .having(
              (SpeedtestTrackerException error) => error.toString(),
              'safe message',
              isNot(contains(placeholderToken)),
            ),
      ),
    );

    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.uri.host, 'tracker.example.test');
    expect(adapter.requests.single.followRedirects, isFalse);
  });

  test('parses a queued run response without reporting completion', () async {
    final FakeHttpClientAdapter adapter = FakeHttpClientAdapter(
      (RequestOptions options) => (
        status: 201,
        data: resultEnvelope(runningResult),
      ),
    );
    final SpeedtestResult result =
        await SpeedtestTrackerApi(_dio(adapter)).runSpeedtest();

    expect(adapter.requests.single.method, 'POST');
    expect(result.status, SpeedtestResultStatus.running);
    expect(result.status, isNot(SpeedtestResultStatus.completed));
  });

  test('connection health succeeds without probing run permission', () async {
    final FakeHttpClientAdapter adapter = FakeHttpClientAdapter(
      (RequestOptions options) => (
        status: 200,
        data: <String, dynamic>{'message': 'OK'},
      ),
    );

    await SpeedtestTrackerApi(_dio(adapter)).checkHealth();

    expect(adapter.requests.single.path, 'api/healthcheck');
    expect(adapter.requests.single.method, 'GET');
  });

  test('connection failures are reported as offline', () async {
    final FakeHttpClientAdapter adapter = FakeHttpClientAdapter(
      (RequestOptions options) => throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        message: 'placeholder low-level error',
      ),
    );

    await expectLater(
      SpeedtestTrackerApi(_dio(adapter)).checkHealth(),
      throwsA(
        isA<SpeedtestTrackerException>().having(
          (SpeedtestTrackerException error) => error.kind,
          'kind',
          SpeedtestErrorKind.offline,
        ),
      ),
    );
  });

  test('read authentication failures identify the configured token problem',
      () async {
    final FakeHttpClientAdapter adapter = FakeHttpClientAdapter(
      (RequestOptions options) => (status: 401, data: null),
    );

    await expectLater(
      SpeedtestTrackerApi(_dio(adapter)).listResults(),
      throwsA(
        isA<SpeedtestTrackerException>().having(
          (SpeedtestTrackerException error) => error.kind,
          'kind',
          SpeedtestErrorKind.authentication,
        ),
      ),
    );
  });

  test('maps run permission errors and never leaks the token', () async {
    final FakeHttpClientAdapter adapter = FakeHttpClientAdapter(
      (RequestOptions options) => (
        status: 403,
        data: <String, dynamic>{
          'message': 'Denied $placeholderToken',
        },
      ),
    );

    await expectLater(
      SpeedtestTrackerApi(_dio(adapter)).runSpeedtest(),
      throwsA(
        isA<SpeedtestTrackerException>()
            .having(
              (SpeedtestTrackerException error) => error.kind,
              'kind',
              SpeedtestErrorKind.permission,
            )
            .having(
              (SpeedtestTrackerException error) => error.toString(),
              'safe message',
              isNot(contains(placeholderToken)),
            ),
      ),
    );
  });

  test('maps unsupported read and run endpoints separately', () async {
    final FakeHttpClientAdapter adapter = FakeHttpClientAdapter(
      (RequestOptions options) => (status: 404, data: null),
    );
    final SpeedtestTrackerApi api = SpeedtestTrackerApi(_dio(adapter));

    await expectLater(
      api.listResults(),
      throwsA(
        isA<SpeedtestTrackerException>().having(
          (SpeedtestTrackerException error) => error.message,
          'read message',
          contains('1.1'),
        ),
      ),
    );
    await expectLater(
      api.runSpeedtest(),
      throwsA(
        isA<SpeedtestTrackerException>().having(
          (SpeedtestTrackerException error) => error.message,
          'run message',
          contains('1.6'),
        ),
      ),
    );
  });

  test('maps a missing polled result without disabling the installation',
      () async {
    final FakeHttpClientAdapter adapter = FakeHttpClientAdapter(
      (RequestOptions options) => (status: 404, data: null),
    );

    await expectLater(
      SpeedtestTrackerApi(_dio(adapter)).getResult(123),
      throwsA(
        isA<SpeedtestTrackerException>()
            .having(
              (SpeedtestTrackerException error) => error.kind,
              'kind',
              SpeedtestErrorKind.notFound,
            )
            .having(
              (SpeedtestTrackerException error) => error.message,
              'message',
              isNot(contains('1.1')),
            ),
      ),
    );
  });

  test('maps run 401, 406, and 422 to safe useful messages', () async {
    for (final (int, SpeedtestErrorKind, String) expectation
        in <(int, SpeedtestErrorKind, String)>[
      (401, SpeedtestErrorKind.authentication, 'bearer token'),
      (406, SpeedtestErrorKind.other, 'JSON'),
      (422, SpeedtestErrorKind.other, 'parameters'),
    ]) {
      final FakeHttpClientAdapter adapter = FakeHttpClientAdapter(
        (RequestOptions options) => (
          status: expectation.$1,
          data: <String, dynamic>{
            'message': 'Upstream echoed $placeholderToken',
          },
        ),
      );

      await expectLater(
        SpeedtestTrackerApi(_dio(adapter)).runSpeedtest(),
        throwsA(
          isA<SpeedtestTrackerException>()
              .having(
                (SpeedtestTrackerException error) => error.kind,
                'kind',
                expectation.$2,
              )
              .having(
                (SpeedtestTrackerException error) => error.message,
                'useful message',
                contains(expectation.$3),
              )
              .having(
                (SpeedtestTrackerException error) => error.toString(),
                'safe message',
                isNot(contains(placeholderToken)),
              ),
        ),
      );
    }
  });

  test('maps malformed successful responses', () async {
    final FakeHttpClientAdapter adapter = FakeHttpClientAdapter(
      (RequestOptions options) => (
        status: 200,
        data: <String, dynamic>{'unexpected': true},
      ),
    );
    await expectLater(
      SpeedtestTrackerApi(_dio(adapter)).listResults(),
      throwsA(
        isA<SpeedtestTrackerException>().having(
          (SpeedtestTrackerException error) => error.kind,
          'kind',
          SpeedtestErrorKind.malformed,
        ),
      ),
    );
  });
}

Dio _dio(FakeHttpClientAdapter adapter) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'https://tracker.example.test/'));
  dio.httpClientAdapter = adapter;
  dio.interceptors.add(
    const AuthInterceptor(
      kind: ServiceKind.speedtestTracker,
      auth: InstanceAuth.apiKey(apiKey: placeholderToken),
    ),
  );
  return dio;
}
