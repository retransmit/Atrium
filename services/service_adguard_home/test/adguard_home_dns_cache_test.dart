import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

import 'support/adguard_home_test_instance.dart';
import 'support/pump.dart';

void main() {
  final Finder save = find.widgetWithText(FilledButton, 'Save');
  Finder field(String key) => find.byKey(Key('adguard-cache-$key'));

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
              builder: (BuildContext _) => const AdguardHomeDnsCacheScreen(
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

  testWidgets('opens as the server has it, the size also in MB',
      (WidgetTester tester) async {
    await open(tester);

    expect(
      tester.widget<TextField>(field('size')).controller!.text,
      '4194304',
    );
    expect(find.text('4 MB'), findsOneWidget);
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
  });

  testWidgets('saves only what was changed', (WidgetTester tester) async {
    final Pumped pumped = await open(tester);

    await tester.enterText(field('size'), '8388608');
    await tester.pump();
    expect(find.text('8 MB'), findsOneWidget);
    await tester.tap(find.text('Optimistic caching'));
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(pumped.actions.savedDns.single, <String, dynamic>{
      'cache_size': 8388608,
      'cache_optimistic': true,
    });
    expect(find.text('Cache settings saved'), findsOneWidget);
  });

  testWidgets('a minimum TTL above the maximum says so',
      (WidgetTester tester) async {
    final Pumped pumped = await open(tester);

    await tester.enterText(field('min'), '600');
    await tester.enterText(field('max'), '60');
    await tester.pump();
    expect(find.text('Has to be at most the maximum.'), findsOneWidget);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(pumped.actions.calls, isEmpty);

    // A maximum of 0 is no maximum.
    await tester.enterText(field('max'), '0');
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(pumped.actions.savedDns.single, <String, dynamic>{
      'cache_ttl_min': 600,
    });
  });

  testWidgets('Clear cache asks first', (WidgetTester tester) async {
    final Pumped pumped = await open(tester);

    await tester.tap(find.text('Clear cache'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(pumped.actions.calls, isEmpty);

    await tester.tap(find.text('Clear cache'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
    await tester.pumpAndSettle();

    expect(pumped.actions.calls, <String>['clear cache']);
    expect(find.text('DNS cache cleared'), findsOneWidget);
  });

  testWidgets('a clear refused for the sign-in offers Try again, which '
      'does not ask again', (WidgetTester tester) async {
    final Pumped pumped = await open(tester);
    pumped.actions.writeFailure = const AdguardHomeSignInRefused();

    await tester.tap(find.text('Clear cache'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SnackBarAction, 'Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Clear the DNS cache?'), findsNothing);
    expect(
      pumped.actions.calls,
      <String>['clear cache', 'retry', 'clear cache'],
    );
    expect(find.text('DNS cache cleared'), findsOneWidget);
  });

  testWidgets('any other failure says why, with no Try again',
      (WidgetTester tester) async {
    final Pumped pumped = await open(tester);
    pumped.actions.writeFailure = const AdguardHomeRequestRefused('nope');

    await tester.tap(find.text('Clear cache'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
    await tester.pumpAndSettle();

    expect(find.text('nope'), findsOneWidget);
    expect(find.byType(SnackBarAction), findsNothing);
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
