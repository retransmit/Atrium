import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

import 'support/adguard_home_test_instance.dart';
import 'support/pump.dart';

void main() {
  final Finder save = find.widgetWithText(FilledButton, 'Save');
  Finder box(String key) => find.byKey(Key('adguard-access-$key'));

  Future<Pumped> open(
    WidgetTester tester, {
    Size size = const Size(360, 1800),
    double textScale = 1,
  }) async {
    final Pumped pumped = await pumpAdguardHome(
      tester,
      Builder(
        builder: (BuildContext context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext _) => const AdguardHomeAccessScreen(
                instance: adguardHomeTestInstance,
              ),
            ),
          ),
          child: const Text('Open'),
        ),
      ),
      size: size,
      textScale: textScale,
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return pumped;
  }

  testWidgets('opens with the lists as the server has them',
      (WidgetTester tester) async {
    await open(tester);

    expect(tester.widget<TextField>(box('allowed')).controller!.text, isEmpty);
    expect(
      tester.widget<TextField>(box('domains')).controller!.text,
      isNotEmpty,
    );
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
  });

  testWidgets('Save asks first, and Cancel sends nothing',
      (WidgetTester tester) async {
    final Pumped pumped = await open(tester);

    await tester.enterText(box('disallowed'), '10.0.0.9');
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.text('Save the access settings?'), findsOneWidget);
    expect(find.textContaining('A wrong entry'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(pumped.actions.calls, isEmpty);

    await tester.tap(save);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save').last);
    await tester.pumpAndSettle();

    expect(
      pumped.actions.savedAccess.single.disallowedClients,
      <String>['10.0.0.9'],
    );
    expect(find.text('Access settings saved'), findsOneWidget);
  });

  testWidgets('allowed clients turn the disallowed box off, and the '
      'question says what is at stake', (WidgetTester tester) async {
    await open(tester);

    await tester.enterText(box('allowed'), '192.168.1.0/24\n\n');
    await tester.pump();

    expect(tester.widget<TextField>(box('disallowed')).enabled, isFalse);
    expect(
      find.text('Not in force while there are allowed clients.'),
      findsOneWidget,
    );

    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.textContaining('Only the allowed clients'), findsOneWidget);
  });

  testWidgets('blank lines and spaces are dropped', (WidgetTester tester) async {
    final Pumped pumped = await open(tester);

    await tester.enterText(box('domains'), ' id.server \n\nversion.bind\n');
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save').last);
    await tester.pumpAndSettle();

    expect(
      pumped.actions.savedAccess.single.blockedHosts,
      <String>['id.server', 'version.bind'],
    );
  });

  testWidgets('Try again after a refused sign-in does not ask twice',
      (WidgetTester tester) async {
    final Pumped pumped = await open(tester);
    pumped.actions.writeFailure = const AdguardHomeSignInRefused();

    await tester.enterText(box('disallowed'), '10.0.0.9');
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Save the access settings?'), findsNothing);
    expect(pumped.actions.calls, <String>['access', 'retry', 'access']);
  });

  for (final double width in <double>[320, 411]) {
    for (final double scale in <double>[1, 2]) {
      testWidgets('layout holds at $width wide and $scale text',
          (WidgetTester tester) async {
        await open(tester, size: Size(width, 2400), textScale: scale);

        expect(tester.takeException(), isNull);
      });
    }
  }
}
