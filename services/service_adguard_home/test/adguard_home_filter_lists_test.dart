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

  test('the update interval is named as the web UI names it', () {
    expect(adguardHomeIntervalLabel(0), 'Never');
    expect(adguardHomeIntervalLabel(1), 'Every hour');
    expect(adguardHomeIntervalLabel(12), 'Every 12 hours');
    expect(adguardHomeIntervalLabel(24), 'Every 24 hours');
    expect(adguardHomeIntervalLabel(72), 'Every 3 days');
    expect(adguardHomeIntervalLabel(168), 'Every 7 days');
    expect(adguardHomeIntervalLabel(7), 'Every 7 hours');
  });

  test('a list address is checked as the web UI checks it', () {
    expect(adguardHomeListUrlProblem('https://lists.example/a.txt'), isNull);
    expect(adguardHomeListUrlProblem('http://10.0.0.2/hosts'), isNull);
    expect(adguardHomeListUrlProblem('/opt/adguardhome/lists/mine.txt'), isNull);
    expect(adguardHomeListUrlProblem(''), isNotNull);
    expect(adguardHomeListUrlProblem('   '), isNotNull);
    expect(adguardHomeListUrlProblem('lists.example/a.txt'), isNotNull);
    expect(adguardHomeListUrlProblem('ftp://lists.example/a.txt'), isNotNull);
    expect(adguardHomeListUrlProblem('https://'), isNotNull);
  });

  /// Pumps the lists screen of one kind.
  Future<Pumped> pumpLists(
    WidgetTester tester, {
    bool allowlist = false,
    AdguardHomeFiltering? lists,
    Size size = const Size(360, 2000),
    double textScale = 1,
  }) async {
    final Pumped pumped = await pumpAdguardHome(
      tester,
      AdguardHomeFilterListsScreen(
        instance: adguardHomeTestInstance,
        allowlist: allowlist,
      ),
      filtering: lists ?? filtering,
      size: size,
      textScale: textScale,
    );
    await tester.pumpAndSettle();
    return pumped;
  }

  Finder rowOf(String name) => find.ancestor(
        of: find.text(name),
        matching: find.byType(AdguardHomeFilterListRow),
      );

  group('the blocklists', () {
    testWidgets('are listed with their address, rules, date and switch',
        (WidgetTester tester) async {
      await pumpLists(tester);

      expect(find.text('Blocklists'), findsOneWidget);
      expect(find.byType(AdguardHomeFilterListRow), findsNWidgets(2));
      expect(
        find.descendant(
          of: rowOf('AdGuard DNS filter'),
          matching: find.textContaining('186,502 rules'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: rowOf('AdGuard DNS filter'),
          matching: find.textContaining('filter_1.txt'),
        ),
        findsOneWidget,
      );
      // A list that is off has no rules loaded; it says so.
      expect(
        find.descendant(
          of: rowOf('AdAway Default Blocklist'),
          matching: find.textContaining('Off'),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Switch>(
              find.descendant(
                of: rowOf('AdAway Default Blocklist'),
                matching: find.byType(Switch),
              ),
            )
            .value,
        isFalse,
      );
    });

    testWidgets('show how often they are updated, and change it',
        (WidgetTester tester) async {
      final Pumped pumped = await pumpLists(tester);

      expect(find.text('Every 24 hours'), findsOneWidget);
      await tester.tap(find.text('Every 24 hours'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Every 7 days'));
      await tester.pumpAndSettle();

      expect(pumped.actions.calls, <String>['interval 168']);
      expect(find.text('The lists will update every 7 days'), findsOneWidget);
    });

    testWidgets('a new interval shows while it is written, and goes back if '
        'it fails', (WidgetTester tester) async {
      final Pumped pumped = await pumpLists(tester);
      final Completer<void> hold = Completer<void>();
      pumped.actions.writeHold = hold;

      await tester.tap(find.text('Every 24 hours'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Never'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Never'), findsOneWidget);
      expect(find.byType(LinearProgressIndicatorM3E), findsOneWidget);
      expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'Update the lists'))
            .enabled,
        isFalse,
      );

      pumped.actions.writeFailure = const AdguardHomeRequestRefused('nope');
      hold.complete();
      await tester.pumpAndSettle();

      expect(find.text('Every 24 hours'), findsOneWidget);
      expect(find.text('nope'), findsOneWidget);
      expect(find.byType(LinearProgressIndicatorM3E), findsNothing);
    });

    testWidgets('Never says the lists no longer update',
        (WidgetTester tester) async {
      await pumpLists(tester);

      await tester.tap(find.text('Every 24 hours'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Never'));
      await tester.pumpAndSettle();

      expect(
        find.text('The lists will no longer update by themselves'),
        findsOneWidget,
      );
    });

    testWidgets('an interval the web UI does not offer is still offered',
        (WidgetTester tester) async {
      await pumpLists(
        tester,
        lists: AdguardHomeFiltering.fromJson(
          filterStatusJson()..['interval'] = 7,
        ),
      );

      await tester.tap(find.text('Every 7 hours'));
      await tester.pumpAndSettle();

      expect(find.text('Every 7 hours'), findsNWidgets(2));
      expect(find.text('Never'), findsOneWidget);
    });

    testWidgets('a switch turns its list on or off',
        (WidgetTester tester) async {
      final Pumped pumped = await pumpLists(tester);

      await tester.tap(
        find.descendant(
          of: rowOf('AdAway Default Blocklist'),
          matching: find.byType(Switch),
        ),
      );
      await tester.pumpAndSettle();

      expect(pumped.actions.calls, <String>['on AdAway Default Blocklist']);
    });

    testWidgets('a switch cannot be flipped again while it is being written',
        (WidgetTester tester) async {
      final Pumped pumped = await pumpLists(tester);
      pumped.actions.writeHold = Completer<void>();
      final Finder toggle = find.descendant(
        of: rowOf('AdAway Default Blocklist'),
        matching: find.byType(Switch),
      );

      await tester.tap(toggle);
      await tester.pump();
      await tester.tap(toggle, warnIfMissed: false);
      await tester.pump();

      expect(pumped.actions.calls, hasLength(1));
      pumped.actions.writeHold!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a switch the server turns down says why',
        (WidgetTester tester) async {
      final Pumped pumped = await pumpLists(tester);
      pumped.actions.writeFailure =
          const AdguardHomeRequestRefused("url doesn't exist");

      await tester.tap(
        find.descendant(
          of: rowOf('AdAway Default Blocklist'),
          matching: find.byType(Switch),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("url doesn't exist"), findsOneWidget);
    });

    testWidgets('Check for updates says what came of it',
        (WidgetTester tester) async {
      final Pumped pumped = await pumpLists(tester);
      pumped.actions.listsUpdated = 2;

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check for updates'));
      await tester.pumpAndSettle();

      expect(pumped.actions.calls, <String>['refresh blocklists']);
      expect(find.text('2 lists updated'), findsOneWidget);
    });

    testWidgets('Check for updates with nothing new says so',
        (WidgetTester tester) async {
      await pumpLists(tester);

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check for updates'));
      await tester.pumpAndSettle();

      expect(find.text('All lists are up to date'), findsOneWidget);
    });
  });

  group('the allowlists', () {
    testWidgets('are listed, without the update interval',
        (WidgetTester tester) async {
      await pumpLists(tester, allowlist: true);

      expect(find.text('Allowlists'), findsOneWidget);
      expect(find.byType(AdguardHomeFilterListRow), findsOneWidget);
      expect(find.text('Allow common services'), findsOneWidget);
      expect(find.text('Every 24 hours'), findsNothing);
    });

    testWidgets('when there are none, say so', (WidgetTester tester) async {
      await pumpLists(
        tester,
        allowlist: true,
        lists: const AdguardHomeFiltering(),
      );

      expect(find.text('No allowlists'), findsOneWidget);
    });
  });

  group('a list in its form', () {
    final Finder save = find.widgetWithText(FilledButton, 'Save');
    const Key nameField = Key('adguard-list-name');
    const Key urlField = Key('adguard-list-url');

    testWidgets('a new one is added with its name and address',
        (WidgetTester tester) async {
      final Pumped pumped = await pumpLists(tester);

      await tester.tap(find.byTooltip('Add blocklist'));
      await tester.pumpAndSettle();
      expect(find.text('New blocklist'), findsOneWidget);
      await tester.enterText(find.byKey(nameField), 'Mine');
      await tester.enterText(
        find.byKey(urlField),
        ' https://lists.example/mine.txt ',
      );
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(pumped.actions.calls, <String>[
        'add blocklist Mine https://lists.example/mine.txt',
      ]);
      expect(find.text('New blocklist'), findsNothing);
      expect(find.text('List added'), findsOneWidget);
    });

    testWidgets('an address that is no address says so and sends nothing',
        (WidgetTester tester) async {
      final Pumped pumped = await pumpLists(tester);

      await tester.tap(find.byTooltip('Add blocklist'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(urlField), 'lists.example/a.txt');
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(pumped.actions.calls, isEmpty);
      expect(
        find.text('An address starting with http:// or https://, or the '
            'full path of a file on the server.'),
        findsOneWidget,
      );
    });

    testWidgets('one that is there opens with its name and address, and is '
        'changed under the address it had', (WidgetTester tester) async {
      final Pumped pumped = await pumpLists(tester);

      await tester.tap(find.text('AdAway Default Blocklist'));
      await tester.pumpAndSettle();
      expect(find.text('Edit blocklist'), findsOneWidget);
      await tester.enterText(find.byKey(nameField), 'AdAway');
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(pumped.actions.calls, <String>[
        'change ${filtering.blocklists.last.url} to blocklist AdAway '
            '${filtering.blocklists.last.url}',
      ]);
      expect(find.text('List saved'), findsOneWidget);
    });

    testWidgets('a refusal keeps the form and says why',
        (WidgetTester tester) async {
      final Pumped pumped = await pumpLists(tester);
      pumped.actions.writeFailure = const AdguardHomeRequestRefused(
        'Filter with URL "https://lists.example/a.txt": url already exists',
      );

      await tester.tap(find.byTooltip('Add blocklist'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(urlField), 'https://lists.example/a.txt');
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(find.text('Not saved'), findsOneWidget);
      expect(find.textContaining('url already exists'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('New blocklist'), findsOneWidget);
    });

    testWidgets('while the server fetches the list, the form waits',
        (WidgetTester tester) async {
      final Pumped pumped = await pumpLists(tester);
      pumped.actions.writeHold = Completer<void>();

      await tester.tap(find.byTooltip('Add blocklist'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(urlField), 'https://lists.example/a.txt');
      await tester.tap(save);
      await tester.pump();
      await tester.tap(save, warnIfMissed: false);
      await tester.pump();

      expect(pumped.actions.calls, hasLength(1));
      expect(find.textContaining('Fetching the list'), findsOneWidget);
      pumped.actions.writeHold!.complete();
      await tester.pumpAndSettle();
      expect(find.text('New blocklist'), findsNothing);
    });

    testWidgets('delete asks first, then removes it',
        (WidgetTester tester) async {
      final Pumped pumped = await pumpLists(tester);

      await tester.tap(find.text('AdAway Default Blocklist'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete list'));
      await tester.pumpAndSettle();
      expect(find.text('Delete "AdAway Default Blocklist"?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(
        pumped.actions.calls,
        <String>['remove ${filtering.blocklists.last.url}'],
      );
      expect(find.text('Edit blocklist'), findsNothing);
      expect(find.text('List deleted'), findsOneWidget);
    });

    testWidgets('delete cancelled removes nothing', (WidgetTester tester) async {
      final Pumped pumped = await pumpLists(tester);

      await tester.tap(find.text('AdAway Default Blocklist'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete list'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(pumped.actions.calls, isEmpty);
      expect(find.text('Edit blocklist'), findsOneWidget);
    });

    testWidgets('leaving with a change asks first', (WidgetTester tester) async {
      await pumpLists(tester);

      await tester.tap(find.byTooltip('Add blocklist'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(nameField), 'Mine');
      await tester.pump();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
    });
  });

  testWidgets('a refused sign-in shows the refused view',
      (WidgetTester tester) async {
    await pumpAdguardHome(
      tester,
      const AdguardHomeFilterListsScreen(
        instance: adguardHomeTestInstance,
        allowlist: false,
      ),
      filteringError: const AdguardHomeSignInRefused(),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AdguardHomeRefusedView), findsOneWidget);
  });

  for (final double width in <double>[320, 360, 411]) {
    for (final double scale in <double>[1, 2]) {
      testWidgets('layout holds at $width wide and $scale text',
          (WidgetTester tester) async {
        await pumpLists(tester, size: Size(width, 2400), textScale: scale);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('AdAway Default Blocklist'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
