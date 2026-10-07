import 'package:atrium/src/screens/instance_form_screen.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// An AdGuard Home instance can be saved with no username and no password.
///
/// A server set up without a user answers anyone, and then there is nothing
/// to enter.
void main() {
  testWidgets('AdGuard Home takes empty credentials',
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
      find.text('AdGuard Home - Network-wide blocking (Beta)'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('AdGuard Home - Network-wide blocking (Beta)'));
    await tester.pumpAndSettle();

    FormField<String> field(String label) => tester.widget<TextFormField>(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(TextFormField),
          ),
        );

    expect(field('Username (Optional)').validator!(''), isNull);
    expect(field('Password (Optional)').validator!(''), isNull);
  });
}
