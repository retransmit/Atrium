import 'package:dio/dio.dart';

/// Why a request to Gluetun failed, in terms the user can act on.
///
/// Current Gluetun refuses any route its auth config does not grant, so a 401
/// or 403 almost always means the role for the API key is missing [route].
/// The raw DioException says none of that and runs to a screenful of
/// boilerplate.
String describeGluetunFailure(Object error, String route) {
  if (error is DioException) {
    final int? status = error.response?.statusCode;
    if (status == 401 || status == 403) {
      return 'Gluetun refused it. Check that the role for this API key '
          'grants $route.';
    }
    if (status != null && status >= 200 && status < 300) {
      // Something answered, just not with Gluetun's JSON. Usually a login
      // page from a proxy in front of it, otherwise a URL pointing elsewhere.
      return 'Something other than Gluetun answered. Check the URL, and any '
          'login page in front of it.';
    }
    if (status != null) {
      return 'Gluetun answered HTTP $status.';
    }
    return 'Gluetun could not be reached.';
  }
  return 'Something went wrong.';
}
