import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// What a failed response turns into for the person reading it.
///
/// The case that drove these: a Seerr request came back 403 because the
/// server's CSRF protection was on, and the app answered "check API key or
/// password" about a key that was working perfectly for every read. A server
/// that troubled itself to say why should be quoted, not overruled.
DioException _badResponse(int status, {Object? body}) {
  final RequestOptions options = RequestOptions(path: '/api/v1/request');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<Object?>(
      requestOptions: options,
      statusCode: status,
      data: body,
    ),
  );
}

void main() {
  group('403 and 401', () {
    test('the server\'s own reason is shown rather than a guess at the key',
        () {
      final NetworkException e = NetworkException.fromDio(
        _badResponse(
          403,
          body: <String, dynamic>{
            'message': 'You have exceeded your request quota for movies.',
          },
        ),
      );
      expect(e, isA<NetworkAuthException>());
      expect(e.message, 'You have exceeded your request quota for movies.');
      expect(e.message, isNot(contains('API key')));
    });

    test('a permission refusal is quoted too', () {
      final NetworkException e = NetworkException.fromDio(
        _badResponse(
          403,
          body: <String, dynamic>{
            'message': 'You do not have permission to request this.',
          },
        ),
      );
      expect(e.message, 'You do not have permission to request this.');
    });

    test('a CSRF rejection is explained instead of quoted verbatim', () {
      // `invalid csrf token` is accurate and tells a person nothing, so this
      // is the one case worth translating.
      final NetworkException e = NetworkException.fromDio(
        _badResponse(403, body: <String, dynamic>{'message': 'invalid csrf token'}),
      );
      expect(e, isA<NetworkAuthException>());
      expect(e.message, contains('cross-site'));
      expect(e.message, contains('CSRF'));
      expect(e.message, isNot(contains('invalid csrf token')));
    });

    test('a 403 with nothing to say still suggests the credentials', () {
      final NetworkException e = NetworkException.fromDio(_badResponse(403));
      expect(e, isA<NetworkAuthException>());
      expect(e.message, contains('API key'));
      expect(e.message, contains('403'));
    });

    test('a 401 behaves the same way', () {
      expect(
        NetworkException.fromDio(
          _badResponse(401, body: <String, dynamic>{'message': 'Bad token.'}),
        ).message,
        'Bad token.',
      );
      expect(
        NetworkException.fromDio(_badResponse(401)).message,
        contains('API key'),
      );
    });

    test('an HTML error page is not mistaken for a message', () {
      // A proxy login page would otherwise be quoted back as the reason.
      final NetworkException e = NetworkException.fromDio(
        _badResponse(403, body: '<html><body>Forbidden</body></html>'),
      );
      expect(e.message, contains('API key'));
    });
  });

  group('other statuses are unchanged', () {
    test('404 reports a missing resource', () {
      expect(
        NetworkException.fromDio(_badResponse(404)),
        isA<NetworkNotFoundException>(),
      );
    });

    test('500 keeps the server detail', () {
      final NetworkException e = NetworkException.fromDio(
        _badResponse(500, body: <String, dynamic>{'message': 'boom'}),
      );
      expect(e, isA<NetworkServerException>());
      expect(e.message, contains('boom'));
    });
  });
}
