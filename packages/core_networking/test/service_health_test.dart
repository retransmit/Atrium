import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
