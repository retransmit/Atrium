import 'package:atrium/src/screens/instance_form_screen.dart';
import 'package:core_models/core_models.dart';
import 'package:core_profile/core_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies MySpeed password authentication in InstanceFormScreen.
void main() {
  FormField<String> passwordField(WidgetTester tester) =>
      tester.widget<TextFormField>(
        find.ancestor(
          of: find.text('Password (optional)'),
          matching: find.byType(TextFormField),
        ),
      );

  testWidgets('MySpeed form shows obscured optional password field',
      (WidgetTester tester) async {
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
      find.text('MySpeed - Internet speed'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('MySpeed - Internet speed'));
    await tester.pumpAndSettle();

    final FormField<String> field = passwordField(tester);
    expect(field.validator!(''), isNull);

    final TextField textField = tester.widget<TextField>(
      find.descendant(
        of: find.ancestor(
          of: find.text('Password (optional)'),
          matching: find.byType(TextFormField),
        ),
        matching: find.byType(TextField),
      ),
    );
    expect(textField.obscureText, isTrue);
    expect(
      find.textContaining('Leave empty if password protection is disabled'),
      findsOneWidget,
    );
  });

  testWidgets('MySpeed edit form hydrates existing password',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const Instance existing = Instance(
      id: 'myspeed-instance-1',
      name: 'Home MySpeed',
      kind: ServiceKind.myspeed,
      localUrl: 'http://192.168.1.50:5216',
      externalUrl: '',
      urlMode: UrlMode.auto,
      auth: InstanceAuth.apiKey(apiKey: 'super-secret-password'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          instanceByIdProvider(existing.id).overrideWithValue(existing),
        ],
        child: const MaterialApp(
          home: InstanceFormScreen(instanceId: 'myspeed-instance-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit service'), findsOneWidget);
    expect(find.text('Password (optional)'), findsOneWidget);

    final TextField textField = tester.widget<TextField>(
      find.descendant(
        of: find.ancestor(
          of: find.text('Password (optional)'),
          matching: find.byType(TextFormField),
        ),
        matching: find.byType(TextField),
      ),
    );
    expect(textField.controller?.text, 'super-secret-password');
    expect(textField.obscureText, isTrue);
  });
}
