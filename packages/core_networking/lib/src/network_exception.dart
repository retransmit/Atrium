import 'package:dio/dio.dart';

/// Typed error surfaced by service modules. Every API call should map raw
/// `DioException`s to one of these via [NetworkException.fromDio] so the UI
/// layer can render meaningful messages without picking through HTTP errors.
sealed class NetworkException implements Exception {
  const NetworkException(this.message);
  final String message;

  static NetworkException fromDio(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        const NetworkTimeoutException('Server took too long to respond.'),
      DioExceptionType.connectionError =>
        NetworkUnreachableException(e.message ?? 'Could not reach the server.'),
      DioExceptionType.badCertificate =>
        const NetworkTlsException(
          'TLS certificate not trusted. Enable "Allow self-signed certs" '
          'in this instance\'s settings if you trust the server.',
        ),
      DioExceptionType.cancel =>
        const NetworkCancelledException('Request was cancelled.'),
      DioExceptionType.badResponse => _fromBadResponse(e),
      DioExceptionType.unknown =>
        NetworkUnknownException(e.message ?? 'Unknown network error.'),
    };
  }

  static NetworkException _fromBadResponse(DioException e) {
    final int? status = e.response?.statusCode;
    if (status == null) {
      return const NetworkUnknownException('Empty response from server.');
    }
    if (status == 401 || status == 403) {
      return NetworkAuthException(
        'Authentication failed (HTTP $status). Check API key or password.',
      );
    }
    if (status == 404) {
      return const NetworkNotFoundException('Resource not found.');
    }
    if (status >= 500) {
      return NetworkServerException(
        'Server error (HTTP $status). Try again in a moment.',
        status: status,
      );
    }
    return NetworkBadResponseException(
      'Unexpected response (HTTP $status).',
      status: status,
    );
  }

  @override
  String toString() => '$runtimeType: $message';
}

class NetworkTimeoutException extends NetworkException {
  const NetworkTimeoutException(super.message);
}

class NetworkUnreachableException extends NetworkException {
  const NetworkUnreachableException(super.message);
}

class NetworkTlsException extends NetworkException {
  const NetworkTlsException(super.message);
}

class NetworkCancelledException extends NetworkException {
  const NetworkCancelledException(super.message);
}

class NetworkAuthException extends NetworkException {
  const NetworkAuthException(super.message);
}

class NetworkNotFoundException extends NetworkException {
  const NetworkNotFoundException(super.message);
}

class NetworkServerException extends NetworkException {
  const NetworkServerException(super.message, {required this.status});
  final int status;
}

class NetworkBadResponseException extends NetworkException {
  const NetworkBadResponseException(super.message, {required this.status});
  final int status;
}

class NetworkUnknownException extends NetworkException {
  const NetworkUnknownException(super.message);
}
