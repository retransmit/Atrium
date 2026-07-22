import 'package:dio/dio.dart';

import 'models/speedtest_tracker_models.dart';

enum SpeedtestErrorKind {
  authentication,
  permission,
  unsupported,
  offline,
  timeout,
  server,
  malformed,
  notFound,
  other,
}

class SpeedtestTrackerException implements Exception {
  const SpeedtestTrackerException(
    this.kind,
    this.message, {
    this.statusCode,
  });

  final SpeedtestErrorKind kind;
  final String message;
  final int? statusCode;

  @override
  String toString() => 'SpeedtestTrackerException: $message';
}

class SpeedtestTrackerApi {
  SpeedtestTrackerApi(this._dio) {
    // A bearer credential must never ride a redirect to another origin.
    // Callers use only relative paths against this client's configured base.
    _dio.options.followRedirects = false;
  }

  final Dio _dio;

  Future<void> checkHealth() async {
    try {
      await _dio.get<dynamic>('api/healthcheck');
    } on DioException catch (error) {
      throw _mapDio(error, operation: _Operation.health);
    }
  }

  Future<SpeedtestResultsPage> listResults({
    int page = 1,
    int pageSize = 25,
    SpeedtestResultStatus? status,
  }) async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        'api/v1/results',
        queryParameters: <String, dynamic>{
          if (status != null) 'filter[status]': status.name,
          'sort': '-created_at',
          'page': page,
          'page[number]': page,
          'page[size]': pageSize,
          'per_page': pageSize,
        },
      );
      final SpeedtestResultsPage parsed = SpeedtestResultsPage.fromJson(
        response.data,
        requestedPage: page,
        pageSize: pageSize,
      );
      if (status == null) {
        return parsed;
      }
      return SpeedtestResultsPage(
        results: <SpeedtestResult>[
          for (final SpeedtestResult result in parsed.results)
            if (result.status == status) result,
        ],
        page: parsed.page,
        hasMore: parsed.hasMore,
      );
    } on SpeedtestProtocolException catch (error) {
      throw SpeedtestTrackerException(
        SpeedtestErrorKind.malformed,
        error.message,
      );
    } on DioException catch (error) {
      throw _mapDio(error, operation: _Operation.list);
    }
  }

  Future<SpeedtestResult> getResult(int id) async {
    try {
      final Response<dynamic> response =
          await _dio.get<dynamic>('api/v1/results/$id');
      return SpeedtestResult.fromJson(_unwrapData(response.data));
    } on SpeedtestProtocolException catch (error) {
      throw SpeedtestTrackerException(
        SpeedtestErrorKind.malformed,
        error.message,
      );
    } on DioException catch (error) {
      throw _mapDio(error, operation: _Operation.result);
    }
  }

  Future<SpeedtestResult> runSpeedtest() async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        'api/v1/speedtests/run',
        data: const <String, dynamic>{},
      );
      return SpeedtestResult.fromJson(_unwrapData(response.data));
    } on SpeedtestProtocolException catch (error) {
      throw SpeedtestTrackerException(
        SpeedtestErrorKind.malformed,
        error.message,
      );
    } on DioException catch (error) {
      throw _mapDio(error, operation: _Operation.run);
    }
  }
}

enum _Operation { health, list, result, run }

Object? _unwrapData(Object? response) {
  if (response is Map && response['data'] != null) {
    return response['data'];
  }
  return response;
}

SpeedtestTrackerException _mapDio(
  DioException error, {
  required _Operation operation,
}) {
  if (error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.sendTimeout ||
      error.type == DioExceptionType.receiveTimeout) {
    return const SpeedtestTrackerException(
      SpeedtestErrorKind.timeout,
      'Speedtest Tracker took too long to respond.',
    );
  }
  if (error.type == DioExceptionType.badCertificate) {
    return const SpeedtestTrackerException(
      SpeedtestErrorKind.offline,
      'The TLS certificate is not trusted. Enable self-signed certificates '
      'only if you trust this server.',
    );
  }
  if (error.type == DioExceptionType.connectionError) {
    return const SpeedtestTrackerException(
      SpeedtestErrorKind.offline,
      'Could not reach Speedtest Tracker.',
    );
  }
  final int? status = error.response?.statusCode;
  if (status != null && status >= 300 && status < 400) {
    return SpeedtestTrackerException(
      SpeedtestErrorKind.other,
      'Speedtest Tracker returned a redirect (HTTP $status). Atrium will not '
      'follow redirects for authenticated requests.',
      statusCode: status,
    );
  }
  if (status == 401) {
    return const SpeedtestTrackerException(
      SpeedtestErrorKind.authentication,
      'The bearer token was rejected. Check the configured API token.',
      statusCode: 401,
    );
  }
  if (status == 403) {
    if (operation == _Operation.run) {
      return const SpeedtestTrackerException(
        SpeedtestErrorKind.permission,
        'The API token lacks the speedtests:run ability.',
        statusCode: 403,
      );
    }
    return const SpeedtestTrackerException(
      SpeedtestErrorKind.authentication,
      'The API token lacks the results:read ability.',
      statusCode: 403,
    );
  }
  if (status == 404) {
    return switch (operation) {
      _Operation.run => const SpeedtestTrackerException(
          SpeedtestErrorKind.unsupported,
          'Remote test execution requires Speedtest Tracker 1.6 or newer.',
          statusCode: 404,
        ),
      _Operation.list => const SpeedtestTrackerException(
          SpeedtestErrorKind.unsupported,
          'Authenticated results require Speedtest Tracker 1.1 or newer.',
          statusCode: 404,
        ),
      _Operation.result => const SpeedtestTrackerException(
          SpeedtestErrorKind.notFound,
          'The queued speed test result is no longer available.',
          statusCode: 404,
        ),
      _Operation.health => const SpeedtestTrackerException(
          SpeedtestErrorKind.other,
          'The Speedtest Tracker health endpoint was not found.',
          statusCode: 404,
        ),
    };
  }
  if (status == 406) {
    return const SpeedtestTrackerException(
      SpeedtestErrorKind.other,
      'Speedtest Tracker rejected the required JSON response format (HTTP 406).',
      statusCode: 406,
    );
  }
  if (status == 422) {
    return const SpeedtestTrackerException(
      SpeedtestErrorKind.other,
      'Speedtest Tracker rejected the request parameters (HTTP 422).',
      statusCode: 422,
    );
  }
  if (status != null && status >= 500) {
    return SpeedtestTrackerException(
      SpeedtestErrorKind.server,
      'Speedtest Tracker returned a server error (HTTP $status).',
      statusCode: status,
    );
  }
  return SpeedtestTrackerException(
    SpeedtestErrorKind.other,
    status == null
        ? 'Speedtest Tracker returned an unexpected network error.'
        : 'Speedtest Tracker returned an unexpected response (HTTP $status).',
    statusCode: status,
  );
}
