import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

import 'support/adguard_home_test_instance.dart';
import 'support/pump.dart';

void main() {
  const Key domainField = Key('adguard-rewrite-domain');
  const Key answerField = Key('adguard-rewrite-answer');
  final Finder save = find.widgetWithText(FilledButton, 'Save');

  Future<Pumped> pumpRewrites(
    WidgetTester tester, {
    List<AdguardHomeRewrite>? rewrites,
    bool enabled = true,
    Size size = const Size(360, 2000),
    double textScale = 1,
  }) async {
    final Pumped pumped = await pumpAdguardHome(
      tester,
      const AdguardHomeRewritesScreen(instance: adguardHomeTestInstance),
      rewrites: rewrites,
      rewritesEnabled: enabled,
      size: size,
      textScale: textScale,
    );
    await tester.pumpAndSettle();
    return pumped;
  }

  Finder rowOf(String domain) => find.ancestor(
        of: find.text(domain),
        matching: find.byType(AdguardHomeRewriteRow),
      );

  Finder switchOf(String domain) =>
      find.descendant(of: rowOf(domain), matching: find.byType(Switch));

  testWidgets('lists each rewrite with its answer and its switch',
      (WidgetTester tester) async {
    await pumpRewrites(tester);

    expect(find.byType(AdguardHomeRewriteRow), findsNWidgets(2));
    // The wildcard's answer is that domain too, so the first row by place.
    final Finder first = find.byType(AdguardHomeRewriteRow).first;
    expect(
      find.descendant(of: first, matching: find.text('192.168.1.50')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Switch>(
            find.descendant(of: first, matching: find.byType(Switch)),
          )
          .value,
      isTrue,
    );
    expect(tester.widget<Switch>(switchOf('*.lan.example')).value, isFalse);
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Use rewrites'),
          )
          .value,
      isTrue,
    );
  });

  testWidgets('an older server gets no switches it does not have',
      (WidgetTester tester) async {
    // Before the per-rule switch: no `enabled`, and no rewrite/settings.
    await pumpAdguardHome(
      tester,
      const AdguardHomeRewritesScreen(instance: adguardHomeTestInstance),
      rewrites: AdguardHomeRewrite.listFromJson(<dynamic>[
        <String, dynamic>{'domain': 'nas.home.example', 'answer': '10.0.0.5'},
      ]),
      rewritesEnabledError: const AdguardHomeRequestRefused('404'),
    );
    await tester.pumpAndSettle();

    expect(find.text('nas.home.example'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    expect(find.text('Use rewrites'), findsNothing);
  });

  testWidgets('the switch for all of them shows once its setting is read',
      (WidgetTester tester) async {
    await pumpRewrites(tester);

    expect(find.text('Use rewrites'), findsOneWidget);
  });

  testWidgets('a rewrite is switched on or off', (WidgetTester tester) async {
    final Pumped pumped = await pumpRewrites(tester);

    await tester.tap(switchOf('*.lan.example'));
    await tester.pumpAndSettle();

    expect(pumped.actions.calls, <String>['on *.lan.example']);
  });

  testWidgets('all rewrites are switched off at once, and say so',
      (WidgetTester tester) async {
    final Pumped pumped = await pumpRewrites(tester);

    await tester.tap(find.text('Use rewrites'));
    await tester.pumpAndSettle();

    expect(pumped.actions.calls, <String>['rewrites off']);
  });

  testWidgets('switched off as a whole, the list says none of them apply',
      (WidgetTester tester) async {
    await pumpRewrites(tester, enabled: false);

    expect(find.textContaining('None of these apply'), findsOneWidget);
  });

  testWidgets('a switch the server turns down says why',
      (WidgetTester tester) async {
    final Pumped pumped = await pumpRewrites(tester);
    pumped.actions.writeFailure =
        const AdguardHomeRequestRefused('target rule not found');

    await tester.tap(switchOf('*.lan.example'));
    await tester.pumpAndSettle();

    expect(find.text('target rule not found'), findsOneWidget);
  });

  testWidgets('two rewrites that are the same are both listed',
      (WidgetTester tester) async {
    // The server accepts a duplicate.
    await pumpRewrites(
      tester,
      rewrites: const <AdguardHomeRewrite>[
        AdguardHomeRewrite(domain: 'a.example', answer: '10.0.0.1'),
        AdguardHomeRewrite(domain: 'a.example', answer: '10.0.0.1'),
      ],
    );

    expect(find.byType(AdguardHomeRewriteRow), findsNWidgets(2));
  });

  testWidgets('with none, says so', (WidgetTester tester) async {
    await pumpRewrites(tester, rewrites: const <AdguardHomeRewrite>[]);

    expect(find.text('No rewrites'), findsOneWidget);
  });

  group('a rewrite in its form', () {
    testWidgets('a new one is added, on', (WidgetTester tester) async {
      final Pumped pumped = await pumpRewrites(tester);

      await tester.tap(find.byTooltip('Add rewrite'));
      await tester.pumpAndSettle();
      expect(find.text('New rewrite'), findsOneWidget);
      await tester.enterText(find.byKey(domainField), ' printer.home.example ');
      await tester.enterText(find.byKey(answerField), '192.168.1.60');
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(pumped.actions.calls, <String>[
        'add printer.home.example 192.168.1.60',
      ]);
      expect(find.text('Rewrite added'), findsOneWidget);
    });

    testWidgets('without a domain or an answer says so and sends nothing',
        (WidgetTester tester) async {
      final Pumped pumped = await pumpRewrites(tester);

      await tester.tap(find.byTooltip('Add rewrite'));
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(pumped.actions.calls, isEmpty);
      expect(find.text('Enter a domain.'), findsOneWidget);
      expect(find.text('Enter an answer.'), findsOneWidget);
    });

    testWidgets('one that is there is changed by what it was',
        (WidgetTester tester) async {
      final Pumped pumped = await pumpRewrites(tester);

      await tester.tap(find.text('*.lan.example'));
      await tester.pumpAndSettle();
      expect(find.text('Edit rewrite'), findsOneWidget);
      await tester.enterText(find.byKey(answerField), '10.0.0.9');
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(pumped.actions.calls, <String>[
        'change *.lan.example to *.lan.example 10.0.0.9',
      ]);
      // It was off, and stays off.
      expect(pumped.actions.savedRewrites.single.enabled, isFalse);
    });

    testWidgets('an answer left empty says so and sends nothing',
        (WidgetTester tester) async {
      final Pumped pumped = await pumpRewrites(tester);

      await tester.tap(find.byTooltip('Add rewrite'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(domainField), 'a.example');
      await tester.enterText(find.byKey(answerField), '   ');
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(pumped.actions.calls, isEmpty);
      expect(find.text('Enter an answer.'), findsOneWidget);
      expect(find.text('Enter a domain.'), findsNothing);
    });

    testWidgets('a refusal keeps the form and says why',
        (WidgetTester tester) async {
      final Pumped pumped = await pumpRewrites(tester);
      pumped.actions.writeFailure = const AdguardHomeRequestRefused(
        'normalizing: invalid CNAME target "x y"',
      );

      await tester.tap(find.byTooltip('Add rewrite'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(domainField), 'a.example');
      await tester.enterText(find.byKey(answerField), 'x y');
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(find.textContaining('invalid CNAME target'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('New rewrite'), findsOneWidget);
    });

    testWidgets('delete asks first', (WidgetTester tester) async {
      final Pumped pumped = await pumpRewrites(tester);

      await tester.tap(find.text('*.lan.example'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete rewrite'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(pumped.actions.calls, isEmpty);

      await tester.tap(find.byTooltip('Delete rewrite'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(pumped.actions.calls, <String>['delete *.lan.example']);
      expect(find.text('Edit rewrite'), findsNothing);
      expect(find.text('Rewrite deleted'), findsOneWidget);
    });

    testWidgets('delete of one the server holds twice says every copy goes',
        (WidgetTester tester) async {
      const AdguardHomeRewrite twice = AdguardHomeRewrite(
        domain: 'a.lan',
        answer: '10.0.0.1',
      );
      await pumpRewrites(
        tester,
        rewrites: <AdguardHomeRewrite>[twice, twice.copyWith(enabled: false)],
      );

      await tester.tap(find.text('a.lan').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete rewrite'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('holds it 2 times, and every copy goes'),
        findsOneWidget,
      );
    });

    testWidgets('a save the sign-in was refused for can be tried again',
        (WidgetTester tester) async {
      final Pumped pumped = await pumpRewrites(tester);
      pumped.actions.writeFailure = const AdguardHomeSignInRefused();

      await tester.tap(find.byTooltip('Add rewrite'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(domainField), 'printer.home.example');
      await tester.enterText(find.byKey(answerField), '192.168.1.60');
      await tester.tap(save);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Try again'));
      await tester.pumpAndSettle();

      expect(pumped.actions.calls, <String>[
        'add printer.home.example 192.168.1.60',
        'retry',
        'add printer.home.example 192.168.1.60',
      ]);
      expect(find.text('Rewrite added'), findsOneWidget);
    });

    testWidgets('any other failure offers no Try again',
        (WidgetTester tester) async {
      final Pumped pumped = await pumpRewrites(tester);
      pumped.actions.writeFailure = const AdguardHomeRequestRefused('nope');

      await tester.tap(find.byTooltip('Add rewrite'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(domainField), 'printer.home.example');
      await tester.enterText(find.byKey(answerField), '192.168.1.60');
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(find.text('nope'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
      expect(find.text('OK'), findsOneWidget);
    });

    testWidgets('Save tapped twice is sent once', (WidgetTester tester) async {
      final Pumped pumped = await pumpRewrites(tester);
      pumped.actions.writeHold = Completer<void>();

      await tester.tap(find.byTooltip('Add rewrite'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(domainField), 'a.example');
      await tester.enterText(find.byKey(answerField), 'A');
      await tester.tap(save);
      await tester.pump();
      await tester.tap(save, warnIfMissed: false);
      await tester.pump();

      expect(pumped.actions.calls, hasLength(1));
      pumped.actions.writeHold!.complete();
      await tester.pumpAndSettle();
    });
  });

  for (final double width in <double>[320, 411]) {
    for (final double scale in <double>[1, 2]) {
      testWidgets('layout holds at $width wide and $scale text',
          (WidgetTester tester) async {
        await pumpRewrites(
          tester,
          enabled: false,
          size: Size(width, 2400),
          textScale: scale,
        );
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('*.lan.example'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
