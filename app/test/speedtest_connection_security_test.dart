import 'package:atrium/src/screens/instance_form_screen.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:service_speedtest_tracker/service_speedtest_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('connection-test messages never expose exception contents', () {
    const String token = 'placeholder-token-must-never-appear';
    for (final SpeedtestErrorKind kind in SpeedtestErrorKind.values) {
      final String message = speedtestConnectionErrorMessage(
        SpeedtestTrackerException(kind, 'Upstream echoed $token'),
      );
      expect(message, isNot(contains(token)));
    }
    expect(speedtestConnectionSuccessMessage, isNot(contains(token)));
  });

  testWidgets('bearer field stays obscured and external HTTP shows a warning',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: InstanceFormScreen()),
      ),
    );

    await tester.tap(find.byType(DropdownMenu<ServiceKind>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Speedtest Tracker - Internet performance'));
    await tester.pumpAndSettle();

    final Finder bearerField = find.ancestor(
      of: find.text('Bearer API token'),
      matching: find.byType(TextFormField),
    );
    expect(bearerField, findsOneWidget);
    final EditableText bearerEditable = tester.widget<EditableText>(
      find.descendant(of: bearerField, matching: find.byType(EditableText)),
    );
    expect(bearerEditable.obscureText, isTrue);
    expect(find.byIcon(Icons.visibility), findsNothing);
    expect(find.byIcon(Icons.visibility_off), findsNothing);

    final Finder externalField = find.ancestor(
      of: find.text('External URL'),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(externalField, 'http://tracker.example.test');
    await tester.pump();

    expect(
      find.textContaining('does not protect the bearer token with TLS'),
      findsOneWidget,
    );
    expect(find.textContaining('placeholder-token'), findsNothing);
  });
}
