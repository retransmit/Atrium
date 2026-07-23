import 'package:atrium/src/connection_test/connection_test_result.dart';
import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Health maps to a ConnectionTestResult', () {
    expect(
      connectionResultFromHealth(Health.ok).outcome,
      ConnectionOutcome.connected,
    );
    expect(
      connectionResultFromHealth(Health.warning).outcome,
      ConnectionOutcome.authFailed,
    );
    expect(
      connectionResultFromHealth(Health.error).outcome,
      ConnectionOutcome.unreachable,
    );
  });

  test('errors map to a ConnectionTestResult', () {
    expect(
      connectionResultFromError(const NetworkAuthException('rejected')).outcome,
      ConnectionOutcome.authFailed,
    );
    expect(
      connectionResultFromError(Exception('boom')).outcome,
      ConnectionOutcome.unreachable,
    );
  });
}
