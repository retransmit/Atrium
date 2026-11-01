import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

import 'support/adguard_home_filters_fixtures.dart';
import 'support/adguard_home_test_instance.dart';
import 'support/pump.dart';

void main() {
  final AdguardHomeFiltering filtering =
      AdguardHomeFiltering.fromJson(filterStatusJson());
  const Widget tab = AdguardHomeFiltersTab(instance: adguardHomeTestInstance);

  Future<Pumped> pumpTab(
    WidgetTester tester, {
    bool rewritesEnabled = true,
    Object? filteringError,
    Size size = const Size(360, 1600),
    double textScale = 1,
  }) async {
    final Pumped pumped = await pumpAdguardHome(
      tester,
      tab,
      filtering: filtering,
      filteringError: filteringError,
      rewritesEnabled: rewritesEnabled,
      size: size,
      textScale: textScale,
    );
    await tester.pumpAndSettle();
    return pumped;
  }

  Finder tile(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(ListTile));

  bool says(String title, String text) => find
      .descendant(of: tile(title), matching: find.text(text))
      .evaluate()
      .isNotEmpty;

  testWidgets('sums up each section', (WidgetTester tester) async {
    await pumpTab(tester);

    expect(says('Blocklists', '2 lists, 1 on · 186,502 rules'), isTrue);
    expect(says('Allowlists', '1 list, 1 on · 3,554 rules'), isTrue);
    expect(says('Custom rules', '3 rules'), isTrue);
    expect(says('Blocked services', '1 service · pauses on 2 days'), isTrue);
    expect(says('DNS rewrites', '2 rewrites, 1 on'), isTrue);
  });

  testWidgets('says when rewrites are off as a whole',
      (WidgetTester tester) async {
    await pumpTab(tester, rewritesEnabled: false);

    expect(says('DNS rewrites', 'Off · 2 rewrites'), isTrue);
  });

  testWidgets('counts rewrites without switches as all on, saying nothing '
      'of it', (WidgetTester tester) async {
    await pumpAdguardHome(
      tester,
      tab,
      filtering: filtering,
      rewrites: AdguardHomeRewrite.listFromJson(<dynamic>[
        <String, dynamic>{'domain': 'a.example', 'answer': '10.0.0.1'},
        <String, dynamic>{'domain': 'b.example', 'answer': '10.0.0.2'},
      ]),
      rewritesEnabledError: const AdguardHomeRequestRefused('404'),
      size: const Size(360, 1600),
    );
    await tester.pumpAndSettle();

    expect(says('DNS rewrites', '2 rewrites'), isTrue);
  });

  testWidgets('each section opens its screen', (WidgetTester tester) async {
    await pumpTab(tester);

    final Map<String, Type> screens = <String, Type>{
      'Blocklists': AdguardHomeFilterListsScreen,
      'Allowlists': AdguardHomeFilterListsScreen,
      'Custom rules': AdguardHomeCustomRulesScreen,
      'Blocked services': AdguardHomeGlobalServicesScreen,
      'DNS rewrites': AdguardHomeRewritesScreen,
    };
    for (final MapEntry<String, Type> section in screens.entries) {
      await tester.tap(find.text(section.key));
      await tester.pumpAndSettle();
      expect(find.byType(section.value), findsOneWidget, reason: section.key);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Allowlists opens the allowlists, not the blocklists',
      (WidgetTester tester) async {
    await pumpTab(tester);

    await tester.tap(find.text('Allowlists'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<AdguardHomeFilterListsScreen>(
            find.byType(AdguardHomeFilterListsScreen),
          )
          .allowlist,
      isTrue,
    );
  });

  testWidgets('Check a host asks about the name typed',
      (WidgetTester tester) async {
    final Pumped pumped = await pumpTab(tester);

    await tester.enterText(find.byType(TextField), '  ads.example  ');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(pumped.actions.calls, <String>['check ads.example']);
    expect(find.byType(AdguardHomeHostCheckSheet), findsOneWidget);
  });

  testWidgets('Check a host with nothing typed asks nothing',
      (WidgetTester tester) async {
    final Pumped pumped = await pumpTab(tester);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(pumped.actions.calls, isEmpty);
  });

  testWidgets('a refused sign-in shows the refused view',
      (WidgetTester tester) async {
    await pumpTab(tester, filteringError: const AdguardHomeSignInRefused());

    expect(find.byType(AdguardHomeRefusedView), findsOneWidget);
    expect(find.text('Blocklists'), findsNothing);
  });

  for (final double width in <double>[320, 411]) {
    for (final double scale in <double>[1, 2]) {
      testWidgets('layout holds at $width wide and $scale text',
          (WidgetTester tester) async {
        await pumpTab(tester, size: Size(width, 2000), textScale: scale);

        expect(tester.takeException(), isNull);
      });
    }
  }
}
