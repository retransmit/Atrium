import 'package:core_models/core_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Speedtest Tracker is registered as bearer-auth Analytics service', () {
    expect(ServiceKind.values.last, ServiceKind.speedtestTracker);
    expect(ServiceKind.speedtestTracker.displayName, 'Speedtest Tracker');
    expect(ServiceKind.speedtestTracker.role, ServiceRole.analytics);
    expect(ServiceKind.speedtestTracker.authStyle, AuthStyle.bearerToken);
    expect(ServiceKind.speedtestTracker.defaultPort, isNull);
  });

  test('existing services retain their default ports', () {
    expect(ServiceKind.sonarr.defaultPort, 8989);
    expect(ServiceKind.glances.defaultPort, 61208);
  });
}
