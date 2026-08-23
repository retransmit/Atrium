import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Unraid GraphQL health', () {
    test('a query that actually ran is online', () {
      expect(
        interpretServiceHealthResponse(
          ServiceKind.unraid,
          200,
          <String, dynamic>{
            'data': <String, dynamic>{'__typename': 'Query'},
          },
        ),
        Health.ok,
      );
    });

    test('a refused key is a warning even though it answers 200', () {
      // The reason this case exists: GraphQL reports auth failures in the
      // body, so status alone would call a bad key healthy.
      expect(
        interpretServiceHealthResponse(
          ServiceKind.unraid,
          200,
          <String, dynamic>{
            'errors': <dynamic>[
              <String, dynamic>{'message': 'Unauthorized'},
            ],
          },
        ),
        Health.warning,
      );
    });

    test('a proxy or web page answering 200 is a warning, not online', () {
      for (final Object? body in <Object?>[
        '<html>Sign in</html>',
        <String, dynamic>{'data': <String, dynamic>{}},
        null,
      ]) {
        expect(
          interpretServiceHealthResponse(ServiceKind.unraid, 200, body),
          Health.warning,
          reason: 'body: $body',
        );
      }
    });
  });

  group('Speedtest Tracker authenticated health', () {
    test('recognizable results JSON is online', () {
      expect(
        interpretServiceHealthResponse(
          ServiceKind.speedtestTracker,
          200,
          <String, dynamic>{'data': <dynamic>[], 'meta': <String, dynamic>{}},
        ),
        Health.ok,
      );
    });

    test('HTML and malformed successful responses are warnings', () {
      for (final Object? body in <Object?>[
        '<html>Sign in</html>',
        <String, dynamic>{'message': 'Login required'},
        null,
      ]) {
        expect(
          interpretServiceHealthResponse(
            ServiceKind.speedtestTracker,
            200,
            body,
          ),
          Health.warning,
        );
      }
    });

    test('reachable API errors and redirects are warnings', () {
      for (final int status in <int>[301, 401, 403, 404, 422, 503]) {
        expect(
          interpretServiceHealthResponse(
            ServiceKind.speedtestTracker,
            status,
            'potentially sensitive response body',
          ),
          Health.warning,
        );
      }
    });
  });
}
