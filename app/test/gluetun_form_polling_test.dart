import 'package:atrium/src/screens/instance_form_screen.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A Gluetun instance can set how often it is polled.
///
/// Its screen and dashboard card already polled on the instance's own
/// interval, but the form only offered the field for Glances and Dashdot, so
/// every Gluetun instance was stuck on the five second default.
void main() {
  Future<void> openFormFor(WidgetTester tester, String serviceLabel) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: InstanceFormScreen())),
    );
    await tester.tap(find.byType(DropdownMenu<ServiceKind>));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(serviceLabel),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(serviceLabel));
    await tester.pumpAndSettle();
  }

  testWidgets('Gluetun offers the polling interval',
      (WidgetTester tester) async {
    await openFormFor(tester, 'Gluetun - VPN client');
    await tester.scrollUntilVisible(
      find.text('Polling Interval (seconds)'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Polling Interval (seconds)'), findsOneWidget);
  });
}
