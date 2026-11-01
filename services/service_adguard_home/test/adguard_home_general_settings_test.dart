import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

import 'support/adguard_home_filters_fixtures.dart';
import 'support/adguard_home_test_instance.dart';
import 'support/pump.dart';

void main() {
  final AdguardHomeFiltering filtering =
      AdguardHomeFiltering.fromJson(filterStatusJson());

  Future<Pumped> pumpGeneral(
    WidgetTester tester, {
    Object? settingsError,
    Size size = const Size(360, 1600),
    double textScale = 1,
  }) async {
    final Pumped pumped = await pumpAdguardHome(
      tester,
      const AdguardHomeGeneralSettingsScreen(instance: adguardHomeTestInstance),
      filtering: filtering,
      settingsError: settingsError,
      size: size,
      textScale: textScale,
    );
    await tester.pumpAndSettle();
    return pumped;
  }

  SwitchListTile tile(WidgetTester tester, String title) =>
      tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, title));

  testWidgets('shows each switch as the server has it',
      (WidgetTester tester) async {
    await pumpGeneral(tester);

    expect(
      tile(tester, 'Block domains using filters and hosts files').value,
      isTrue,
    );
    expect(tile(tester, 'Browsing security').value, isTrue);
    expect(tile(tester, 'Parental control').value, isFalse);
    expect(tile(tester, 'Safe search').value, isTrue);
    expect(find.widgetWithText(SwitchListTile, 'YouTube'), findsOneWidget);
  });

  testWidgets('a switch is written at once, and shown moved meanwhile',
      (WidgetTester tester) async {
    final Pumped pumped = await pumpGeneral(tester);
    final Completer<void> hold = Completer<void>();
    pumped.actions.writeHold = hold;

    await tester.tap(find.text('Parental control'));
    await tester.pump();

    expect(pumped.actions.calls, <String>['parental on']);
    expect(tile(tester, 'Parental control').value, isTrue);
    expect(tile(tester, 'Browsing security').onChanged, isNull);
    expect(find.byType(LinearProgressIndicatorM3E), findsOneWidget);

    hold.complete();
    await tester.pumpAndSettle();
    expect(tile(tester, 'Browsing security').onChanged, isNotNull);
    expect(find.byType(LinearProgressIndicatorM3E), findsNothing);
  });

  testWidgets('filtering and browsing security go to their own writes',
      (WidgetTester tester) async {
    final Pumped pumped = await pumpGeneral(tester);

    await tester.tap(find.text('Block domains using filters and hosts files'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Browsing security'));
    await tester.pumpAndSettle();

    expect(
      pumped.actions.calls,
      <String>['filtering off', 'safebrowsing off'],
    );
  });

  testWidgets('a search engine is switched within safe search',
      (WidgetTester tester) async {
    final Pumped pumped = await pumpGeneral(tester);
    final bool youtube = tile(tester, 'YouTube').value;

    await tester.tap(find.text('YouTube'));
    await tester.pumpAndSettle();

    final AdguardHomeSafeSearch sent = pumped.actions.savedSafeSearch.single;
    expect(sent.engines['YouTube'.toLowerCase()], !youtube);
    expect(sent.enabled, isTrue);
  });

  testWidgets('with safe search off, its engines cannot be switched',
      (WidgetTester tester) async {
    await pumpAdguardHome(
      tester,
      const AdguardHomeGeneralSettingsScreen(instance: adguardHomeTestInstance),
      filtering: filtering,
      general: const AdguardHomeGeneralSettings(
        safeBrowsing: true,
        parental: true,
        safeSearch: AdguardHomeSafeSearch(engines: <String, bool>{'bing': true}),
      ),
    );
    await tester.pumpAndSettle();

    expect(tile(tester, 'Bing').onChanged, isNull);
  });

  testWidgets('a write that fails says why, and the switch goes back',
      (WidgetTester tester) async {
    final Pumped pumped = await pumpGeneral(tester);
    pumped.actions.writeFailure = const AdguardHomeRequestRefused('nope');

    await tester.tap(find.text('Parental control'));
    await tester.pumpAndSettle();

    expect(find.text('nope'), findsOneWidget);
    expect(tile(tester, 'Parental control').value, isFalse);
  });

  testWidgets('a refused sign-in shows Try again',
      (WidgetTester tester) async {
    await pumpGeneral(
      tester,
      settingsError: const AdguardHomeSignInRefused(),
    );

    expect(find.text('Try again'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNothing);
  });

  for (final double width in <double>[320, 411]) {
    for (final double scale in <double>[1, 2]) {
      testWidgets('layout holds at $width wide and $scale text',
          (WidgetTester tester) async {
        await pumpGeneral(
          tester,
          size: Size(width, 1600),
          textScale: scale,
        );

        expect(tester.takeException(), isNull);
      });
    }
  }
}
