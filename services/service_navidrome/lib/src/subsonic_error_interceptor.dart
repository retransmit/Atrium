import 'package:dio/dio.dart';

/// Turns a failed Subsonic envelope into a [DioException].
///
/// Subsonic never uses the HTTP status to report an error. A rejected
/// password, a missing parameter and a healthy server all answer 200; the
/// difference is a `status` of `failed` inside the `subsonic-response`
/// object, with an error code and message beside it.
///
/// Every read method in [NavidromeClient] parses the envelope optimistically
/// and returns an empty list when the data it wants is not there, which is the
/// right behaviour for a genuinely empty library and the wrong one for a
/// rejected credential. Without this interceptor a wrong password renders as
/// "No albums found" on every tab, with nothing logged and nothing shown.
///
/// Rejecting here rather than checking in each of the twenty-odd methods keeps
/// the check in one place and out of the parsing code.
class SubsonicErrorInterceptor extends Interceptor {
  const SubsonicErrorInterceptor();

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final Object? data = response.data;
    if (data is! Map) {
      // Cover art and stream endpoints answer with bytes, not an envelope.
      handler.next(response);
      return;
    }
    final Object? envelope = data['subsonic-response'];
    if (envelope is! Map || envelope['status'] != 'failed') {
      handler.next(response);
      return;
    }

    final Object? error = envelope['error'];
    final String message = error is Map
        ? (error['message'] as String? ?? 'Request failed')
        : 'Request failed';
    final int? code =
        error is Map ? (error['code'] as num?)?.toInt() : null;

    handler.reject(
      DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        error: code == null ? message : '$message (Subsonic error $code)',
      ),
      true,
    );
  }
}
