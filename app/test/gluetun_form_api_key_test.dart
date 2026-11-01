import 'package:atrium/src/screens/instance_form_screen.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A Gluetun instance can be saved without an API key.
///
/// Gluetun's control server can run with auth turned off, through a role
/// with auth = "none", and then there is no key to enter. The form demanded
/// one anyway.
void main() {
  Future<void> openForm(WidgetTester tester, {ServiceKind kind = ServiceKind.sonarr}) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: InstanceFormScreen(initialKind: kind),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  FormField<String> keyField(WidgetTester tester, String label) =>
      tester.widget<TextFormField>(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(TextFormField),
        ),
      );

  testWidgets('Gluetun takes an empty API key', (WidgetTester tester) async {
    await openForm(tester, kind: ServiceKind.gluetun);

    expect(keyField(tester, 'API key (optional)').validator!(''), isNull);
    expect(find.textContaining('auth turned off'), findsOneWidget);
  });

  testWidgets('a service that needs its key still requires one',
      (WidgetTester tester) async {
    // The form opens on Sonarr.
    await openForm(tester);

    expect(keyField(tester, 'API key').validator!(''), 'Required');
    expect(find.text('API key (optional)'), findsNothing);
  });
}
