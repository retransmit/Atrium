import 'package:dio/dio.dart';

import 'tracearr_auth_manager.dart';

/// Intercepts requests to inject the Tracearr session token and handles
/// 401/403 responses by clearing the token and retrying the request.
class TracearrAuthInterceptor extends QueuedInterceptor {
  TracearrAuthInterceptor({
    required this.manager,
    required this.dio,
  });

  final TracearrAuthManager manager;
  final Dio dio;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Avoid intercepting the login paths themselves.
    if (options.path.contains('auth/sign-in')) {
      return handler.next(options);
    }

    try {
      final String token = await manager.ensureToken();
      options.headers['Authorization'] = 'Bearer $token';
      return handler.next(options);
    } catch (e, st) {
      return handler.reject(
        DioException(
          requestOptions: options,
          error: e,
          stackTrace: st,
        ),
      );
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401 || err.response?.statusCode == 403) {
      if (err.requestOptions.path.contains('auth/sign-in')) {
        return handler.next(err);
      }

      manager.clearToken();

      try {
        final String token = await manager.ensureToken();
        final RequestOptions options = err.requestOptions;
        options.headers['Authorization'] = 'Bearer $token';

        final Response<dynamic> retry = await dio.fetch<dynamic>(options);
        return handler.resolve(retry);
      } catch (e) {
        return handler.next(err);
      }
    }

    return handler.next(err);
  }
}
