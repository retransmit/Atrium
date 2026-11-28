import 'package:dio/dio.dart';

/// Refused API authentication (e.g. invalid API token).
class TechnitiumAuthException implements Exception {
  const TechnitiumAuthException([this.message = 'Invalid API key']);
  final String message;

  @override
  String toString() => 'TechnitiumAuthException: $message';
}

/// The endpoint answered, but not with Technitium's API structure.
class TechnitiumUnexpectedAnswer implements Exception {
  const TechnitiumUnexpectedAnswer([
    this.message = 'Unexpected answer from server',
  ]);
  final String message;

  @override
  String toString() => 'TechnitiumUnexpectedAnswer: $message';
}

/// A request to Technitium failed with a server-reported error message.
class TechnitiumRequestException implements Exception {
  const TechnitiumRequestException(this.message);
  final String message;

  @override
  String toString() => 'TechnitiumRequestException: $message';
}

/// Converts any error caught while calling Technitium into a human string.
String describeTechnitiumError(Object error) {
  if (error is TechnitiumAuthException) {
    return error.message;
  }
  if (error is TechnitiumRequestException) {
    return error.message;
  }
  if (error is TechnitiumUnexpectedAnswer) {
    return error.message;
  }
  if (error is DioException) {
    final int? code = error.response?.statusCode;
    if (code == 401 || code == 403) {
      return 'Invalid API key (HTTP $code)';
    }
    if (code == 404) {
      return 'Endpoint not found (HTTP 404)';
    }
    if (error.message != null && error.message!.isNotEmpty) {
      return error.message!;
    }
  }
  return error.toString();
}
