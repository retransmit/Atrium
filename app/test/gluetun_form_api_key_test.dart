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
  Future<void> openForm(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: InstanceFormScreen())),
    );
  }

  FormField<String> keyField(WidgetTester tester, String label) =>
      tester.widget<TextFormField>(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(TextFormField),
        ),
      );

  testWidgets('Gluetun takes an empty API key', (WidgetTester tester) async {
    await openForm(tester);
    await tester.tap(find.byType(DropdownMenu<ServiceKind>));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Gluetun - VPN client'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gluetun - VPN client'));
    await tester.pumpAndSettle();

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
