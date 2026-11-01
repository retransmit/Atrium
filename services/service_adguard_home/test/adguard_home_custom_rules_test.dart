import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

import 'support/adguard_home_filters_fixtures.dart';
import 'support/adguard_home_test_instance.dart';
import 'support/pump.dart';

void main() {
  final AdguardHomeFiltering filtering =
      AdguardHomeFiltering.fromJson(filterStatusJson());
  final Finder save = find.widgetWithText(FilledButton, 'Save');
  final Finder editor = find.byKey(const Key('adguard-rules'));

  String text(WidgetTester tester) =>
      tester.widget<TextField>(editor).controller!.text;

  group('the custom rules', () {
    Future<Pumped> pumpRules(
      WidgetTester tester, {
      Size size = const Size(360, 1600),
      double textScale = 1,
    }) async {
      final Pumped pumped = await pumpAdguardHome(
        tester,
        const AdguardHomeCustomRulesScreen(instance: adguardHomeTestInstance),
        filtering: filtering,
        size: size,
        textScale: textScale,
      );
      await tester.pumpAndSettle();
      return pumped;
    }

    testWidgets('open with the rules one to a line, and their count',
        (WidgetTester tester) async {
      await pumpRules(tester);

      expect(text(tester), filtering.userRules.join('\n'));
      expect(find.text('3 rules'), findsOneWidget);
    });

    testWidgets('count again as they are typed, comments left out',
        (WidgetTester tester) async {
      await pumpRules(tester);

      await tester.enterText(
        editor,
        '${filtering.userRules.join('\n')}\n! a note\n||new.example^',
      );
      await tester.pump();

      expect(find.text('4 rules'), findsOneWidget);
    });

    testWidgets('cannot be saved unchanged', (WidgetTester tester) async {
      await pumpRules(tester);

      expect(tester.widget<FilledButton>(save).onPressed, isNull);
    });

    testWidgets('are saved whole, blank lines dropped, and stay open',
        (WidgetTester tester) async {
      final Pumped pumped = await pumpRules(tester);

      await tester.enterText(editor, '||a.example^\n\n\n||b.example^\n');
      await tester.pump();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(
        pumped.actions.savedRules.single,
        <String>['||a.example^', '||b.example^'],
      );
      expect(find.text('Custom rules saved'), findsOneWidget);
      expect(find.byType(AdguardHomeCustomRulesScreen), findsOneWidget);
      // Saved, so there is nothing more to save.
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
    });

    testWidgets('changed on the server meanwhile, ask before overwriting',
        (WidgetTester tester) async {
      final Pumped pumped = await pumpRules(tester);
      final List<String> theirs = <String>[
        ...filtering.userRules,
        '||from-the-log.example^\$important',
      ];
      pumped.actions.rulesFailure = AdguardHomeRulesChanged(theirs);

      await tester.enterText(editor, '||mine.example^');
      await tester.pump();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('The custom rules were changed on the server '
            'since you opened them.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Overwrite'));
      await tester.pumpAndSettle();

      expect(pumped.actions.calls, <String>['rules 1', 'rules 1 overwrite']);
      expect(find.text('Custom rules saved'), findsOneWidget);
    });

    testWidgets('changed on the server meanwhile, can be loaded instead',
        (WidgetTester tester) async {
      final Pumped pumped = await pumpRules(tester);
      final List<String> theirs = <String>['||theirs.example^'];
      pumped.actions.rulesFailure = AdguardHomeRulesChanged(theirs);

      await tester.enterText(editor, '||mine.example^');
      await tester.pump();
      await tester.tap(save);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Load theirs'));
      await tester.pumpAndSettle();

      expect(text(tester), '||theirs.example^');
      expect(pumped.actions.calls, <String>['rules 1']);
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
    });

    testWidgets('a failed save says why and keeps what was typed',
        (WidgetTester tester) async {
      final Pumped pumped = await pumpRules(tester);
      pumped.actions.writeFailure =
          const AdguardHomeRequestRefused('nope');

      await tester.enterText(editor, '||mine.example^');
      await tester.pump();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(find.text('nope'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(text(tester), '||mine.example^');
    });

    testWidgets('a save the sign-in was refused for can be tried again',
        (WidgetTester tester) async {
      final Pumped pumped = await pumpRules(tester);
      pumped.actions.rulesFailure = const AdguardHomeSignInRefused();

      await tester.enterText(editor, '||mine.example^');
      await tester.pump();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('AdGuard Home refused the sign-in.'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Try again'));
      await tester.pumpAndSettle();

      expect(pumped.actions.calls, <String>['rules 1', 'retry', 'rules 1']);
      expect(find.text('Custom rules saved'), findsOneWidget);
      expect(text(tester), '||mine.example^');
    });

    testWidgets('blank entries on the server are not a change',
        (WidgetTester tester) async {
      // What the web UI sends for a box that ends in a newline.
      await pumpAdguardHome(
        tester,
        const AdguardHomeCustomRulesScreen(instance: adguardHomeTestInstance),
        filtering: AdguardHomeFiltering.fromJson(<String, dynamic>{
          ...filterStatusJson(),
          'user_rules': <dynamic>['||a.example^', ''],
        }),
        size: const Size(360, 1600),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<FilledButton>(save).onPressed, isNull);
    });

    testWidgets('wrap long rules until told not to, then scroll sideways',
        (WidgetTester tester) async {
      await pumpRules(tester);
      const String long =
          r"||a-rather-long-domain-name.example.org^$client='Kids tablet'";
      await tester.enterText(editor, '$long\n||b.example^');
      await tester.pump();

      // Where the caret would be at the start and at the end of the rule:
      // on the same line only when the rule is not wrapped.
      bool onOneLine() {
        final RenderEditable editable = tester
            .state<EditableTextState>(find.byType(EditableText))
            .renderEditable;
        return editable
                .getLocalRectForCaret(const TextPosition(offset: 0))
                .top ==
            editable
                .getLocalRectForCaret(const TextPosition(offset: long.length))
                .top;
      }

      expect(onOneLine(), isFalse);
      expect(find.byType(SingleChildScrollView), findsNothing);

      await tester.tap(find.byTooltip('Stop wrapping lines'));
      await tester.pump();

      expect(onOneLine(), isTrue);
      expect(
        tester
            .widget<SingleChildScrollView>(find.byType(SingleChildScrollView))
            .scrollDirection,
        Axis.horizontal,
      );
      expect(text(tester), '$long\n||b.example^');

      await tester.tap(find.byTooltip('Wrap lines'));
      await tester.pump();
      expect(onOneLine(), isFalse);
    });

    testWidgets('leaving with a change asks first', (WidgetTester tester) async {
      await pumpRules(tester);

      await tester.enterText(editor, '||mine.example^');
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
    });

    for (final double width in <double>[320, 411]) {
      for (final double scale in <double>[1, 2]) {
        testWidgets('layout holds at $width wide and $scale text',
            (WidgetTester tester) async {
          await pumpRules(tester, size: Size(width, 900), textScale: scale);

          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('a host check', () {
    Future<Pumped> openCheck(
      WidgetTester tester,
      String name, {
      Size size = const Size(360, 1600),
      double textScale = 1,
    }) async {
      final Pumped pumped = await pumpAdguardHome(
        tester,
        Builder(
          builder: (BuildContext context) => Center(
            child: TextButton(
              onPressed: () => showAdguardHomeHostCheck(
                context,
                instance: adguardHomeTestInstance,
                name: name,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
        filtering: filtering,
        size: size,
        textScale: textScale,
      );
      pumped.actions.hostCheck = AdguardHomeHostCheck.fromJson(
        name,
        hostChecksJson()[name] as Map<String, dynamic>,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      return pumped;
    }

    testWidgets('of a blocked service names the service and the rule',
        (WidgetTester tester) async {
      final Pumped pumped = await openCheck(tester, 'www.tiktok.com');

      expect(pumped.actions.calls, <String>['check www.tiktok.com']);
      expect(find.text('www.tiktok.com'), findsOneWidget);
      expect(find.text('Blocked service'), findsOneWidget);
      // From the catalogue, not the id.
      expect(find.text('TikTok'), findsOneWidget);
      expect(find.text('||tiktok.com^'), findsOneWidget);
      expect(find.text('Blocked services'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Unblock'), findsOneWidget);
    });

    testWidgets('let through by an allowlist names the list',
        (WidgetTester tester) async {
      await openCheck(tester, 'doubleclick.net');

      expect(find.text('Allowed'), findsOneWidget);
      expect(find.text('Allow common services'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Block'), findsOneWidget);
    });

    testWidgets('of a name nothing matched says so, and offers Block',
        (WidgetTester tester) async {
      await openCheck(tester, 'example.com');

      expect(find.text('Processed'), findsOneWidget);
      expect(find.text('No rule matches this name.'), findsOneWidget);
    });

    testWidgets('Block writes the rule and closes',
        (WidgetTester tester) async {
      final Pumped pumped = await openCheck(tester, 'example.com');

      await tester.tap(find.widgetWithText(FilledButton, 'Block'));
      await tester.pumpAndSettle();

      expect(pumped.actions.calls.last, 'block example.com');
      expect(find.byType(AdguardHomeHostCheckSheet), findsNothing);
    });

    testWidgets('a check that fails says why', (WidgetTester tester) async {
      final Pumped pumped = await pumpAdguardHome(
        tester,
        Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () => showAdguardHomeHostCheck(
              context,
              instance: adguardHomeTestInstance,
              name: 'a.example',
            ),
            child: const Text('Open'),
          ),
        ),
      );
      pumped.actions.lookupFailure = const AdguardHomeSignInRefused();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('AdGuard Home refused the sign-in.'), findsOneWidget);

      // Retry has to ask for the sign-in to be tried again, or the session
      // would only refuse it again without a word to the server.
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(
        pumped.actions.calls,
        <String>['check a.example', 'retry', 'check a.example'],
      );
      expect(find.text('No rule matches this name.'), findsOneWidget);
    });

    testWidgets('a check that fails otherwise asks again, sign-in left be',
        (WidgetTester tester) async {
      final Pumped pumped = await pumpAdguardHome(
        tester,
        Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () => showAdguardHomeHostCheck(
              context,
              instance: adguardHomeTestInstance,
              name: 'a.example',
            ),
            child: const Text('Open'),
          ),
        ),
      );
      pumped.actions.lookupFailure = const AdguardHomeUnexpectedAnswer();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      pumped.actions.lookupFailure = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(
        pumped.actions.calls,
        <String>['check a.example', 'check a.example'],
      );
    });

    for (final double width in <double>[320, 411]) {
      testWidgets('layout holds at $width wide and twice the text',
          (WidgetTester tester) async {
        await openCheck(
          tester,
          'www.tiktok.com',
          size: Size(width, 900),
          textScale: 2,
        );

        expect(tester.takeException(), isNull);
      });
    }
  });
}
