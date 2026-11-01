import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

import 'support/adguard_home_test_instance.dart';
import 'support/pump.dart';

void main() {
  Future<Pumped> pumpServices(
    WidgetTester tester, {
    Size size = const Size(360, 2400),
    double textScale = 1,
  }) async {
    final Pumped pumped = await pumpAdguardHome(
      tester,
      const AdguardHomeGlobalServicesScreen(instance: adguardHomeTestInstance),
      size: size,
      textScale: textScale,
    );
    await tester.pumpAndSettle();
    return pumped;
  }

  testWidgets('shows what is blocked for everyone, by name, and the schedule',
      (WidgetTester tester) async {
    await pumpServices(tester);

    expect(find.text('Blocked services'), findsWidgets);
    expect(find.text('TikTok'), findsOneWidget);
    expect(find.text('Europe/Berlin'), findsOneWidget);
    expect(find.text('09:00 to 17:00'), findsOneWidget);
    expect(find.text('All day'), findsOneWidget);
  });

  testWidgets('the services are picked from the catalogue and saved',
      (WidgetTester tester) async {
    final Pumped pumped = await pumpServices(tester);

    await tester.tap(find.text('TikTok'));
    await tester.pumpAndSettle();
    expect(find.text('Blocked for everyone'), findsOneWidget);
    await tester.tap(find.text('Netflix'));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(pumped.actions.calls, <String>['services tiktok,netflix']);
    expect(find.text('Blocked services saved'), findsOneWidget);
  });

  testWidgets('the picker left unchanged saves nothing',
      (WidgetTester tester) async {
    final Pumped pumped = await pumpServices(tester);

    await tester.tap(find.text('TikTok'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(pumped.actions.calls, isEmpty);
  });

  testWidgets('a change to the schedule is saved', (WidgetTester tester) async {
    final Pumped pumped = await pumpServices(tester);

    await tester.tap(find.text('Sunday'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pause blocking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove pause'));
    await tester.pumpAndSettle();

    expect(pumped.actions.calls, <String>['schedule Europe/Berlin 1']);
    expect(find.text('Schedule saved'), findsOneWidget);
  });

  testWidgets('nothing can be changed while a change is written',
      (WidgetTester tester) async {
    final Pumped pumped = await pumpServices(tester);
    pumped.actions.writeHold = Completer<void>();

    await tester.tap(find.text('Sunday'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pause blocking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove pause'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Monday'));
    await tester.pumpAndSettle();

    expect(find.byType(AdguardHomePauseSheet), findsNothing);
    pumped.actions.writeHold!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('a change the server turns down says why',
      (WidgetTester tester) async {
    final Pumped pumped = await pumpServices(tester);
    pumped.actions.writeFailure = const AdguardHomeRequestRefused(
      'json.Decode: unknown time zone Mars/Base',
    );

    await tester.tap(find.text('Sunday'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pause blocking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove pause'));
    await tester.pumpAndSettle();

    expect(find.textContaining('unknown time zone'), findsOneWidget);
  });

  testWidgets('with nothing blocked, the schedule says it has nothing to '
      'pause', (WidgetTester tester) async {
    await pumpAdguardHome(
      tester,
      const AdguardHomeGlobalServicesScreen(instance: adguardHomeTestInstance),
      globalServices: const AdguardHomeGlobalServices(),
    );
    await tester.pumpAndSettle();

    expect(find.text('None'), findsOneWidget);
    expect(
      find.textContaining('Nothing is blocked'),
      findsOneWidget,
    );
  });

  for (final double width in <double>[320, 411]) {
    for (final double scale in <double>[1, 2]) {
      testWidgets('layout holds at $width wide and $scale text',
          (WidgetTester tester) async {
        await pumpServices(tester, size: Size(width, 3000), textScale: scale);

        expect(tester.takeException(), isNull);
      });
    }
  }
}
