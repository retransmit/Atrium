import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

import 'support/adguard_home_test_instance.dart';
import 'support/pump.dart';

void main() {
  // Times here are built in the test machine's own zone and handed over in
  // UTC, as the server sends them, so the screen reads the same anywhere.
  final DateTime now = DateTime(2026, 10, 7, 23);
  final DateTime asked = DateTime(2026, 10, 7, 20, 29, 32, 377);

  AdguardHomeQueryLogEntry entry({
    String domain = 'example.org',
    String unicodeName = '',
    String reason = 'NotFilteredNotFound',
    DateTime? at,
    String type = 'A',
    String client = '172.17.0.1',
    String clientName = 'Laptop',
    bool clientDisallowed = false,
    String clientDisallowedRule = '172.17.0.1',
    bool cached = false,
    String serviceName = '',
    List<AdguardHomeMatchedRule> rules = const <AdguardHomeMatchedRule>[],
    Duration elapsed = const Duration(microseconds: 365871),
  }) =>
      AdguardHomeQueryLogEntry(
        domain: domain,
        unicodeName: unicodeName,
        reason: reason,
        time: (at ?? asked).toUtc(),
        type: type,
        status: 'NOERROR',
        answers: const <AdguardHomeDnsAnswer>[
          AdguardHomeDnsAnswer(type: 'A', value: '172.66.157.237', ttl: 262),
        ],
        rules: rules,
        serviceName: serviceName,
        client: client,
        clientName: clientName,
        clientDisallowed: clientDisallowed,
        clientDisallowedRule: clientDisallowedRule,
        upstream: 'https://dns10.quad9.net:443/dns-query',
        cached: cached,
        elapsed: elapsed,
      );

  final AdguardHomeQueryLogEntry blocked = entry(
    domain: 'adservice.google.com',
    reason: 'FilteredBlackList',
    rules: const <AdguardHomeMatchedRule>[
      AdguardHomeMatchedRule(listId: 1, text: '||adservice.google.'),
    ],
    elapsed: const Duration(microseconds: 104),
  );

  const AdguardHomeFiltering lists = AdguardHomeFiltering(
    blocklists: <AdguardHomeFilterList>[
      AdguardHomeFilterList(
        id: 1,
        name: 'AdGuard DNS filter',
        url: 'https://lists.example/1.txt',
        enabled: true,
        rulesCount: 179185,
      ),
    ],
  );

  /// A whole log that has been read to its end.
  AdguardHomeQueryLogState all(List<AdguardHomeQueryLogEntry> entries) =>
      AdguardHomeQueryLogState(entries: entries, reachedEnd: true);

  Future<Pumped> pumpTab(
    WidgetTester tester,
    AdguardHomeQueryLogState log, {
    AdguardHomeQueryLogConfig config = const AdguardHomeQueryLogConfig(),
    Size size = const Size(360, 800),
    double textScale = 1,
    Instance instance = adguardHomeTestInstance,
  }) =>
      pumpAdguardHome(
        tester,
        AdguardHomeQueryLogTab(instance: instance, now: () => now),
        log: log,
        logConfig: config,
        filtering: lists,
        size: size,
        textScale: textScale,
        instance: instance,
      );

  group('the list', () {
    testWidgets(
        'a row says what was asked, when, what came of it, by whom and how '
        'long it took', (WidgetTester tester) async {
      await pumpTab(tester, all(<AdguardHomeQueryLogEntry>[entry()]));

      expect(find.text('example.org'), findsOneWidget);
      expect(find.text('20:29:32'), findsOneWidget);
      expect(find.text('Processed'), findsWidgets);
      expect(find.text('A · Laptop'), findsOneWidget);
      expect(find.text('365 ms'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a query from another day has its date in front',
        (WidgetTester tester) async {
      await pumpTab(
        tester,
        all(<AdguardHomeQueryLogEntry>[entry(at: DateTime(2026, 10, 5, 9, 4, 7))]),
      );

      expect(find.text('5 Oct 09:04:07'), findsOneWidget);
    });

    testWidgets('a client with no name goes by its address',
        (WidgetTester tester) async {
      await pumpTab(
        tester,
        all(<AdguardHomeQueryLogEntry>[entry(clientName: '')]),
      );

      expect(find.text('A · 172.17.0.1'), findsOneWidget);
    });

    testWidgets('a query with no client at all shows its type alone',
        (WidgetTester tester) async {
      await pumpTab(
        tester,
        all(<AdguardHomeQueryLogEntry>[entry(client: '', clientName: '')]),
      );

      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('a name in another script is shown in it',
        (WidgetTester tester) async {
      await pumpTab(
        tester,
        all(<AdguardHomeQueryLogEntry>[
          entry(
            domain: 'xn--mnchen-3ya.example',
            unicodeName: 'münchen.example',
          ),
        ]),
      );

      expect(find.text('münchen.example'), findsOneWidget);
    });

    testWidgets('a client that is shut out is marked',
        (WidgetTester tester) async {
      await pumpTab(
        tester,
        all(<AdguardHomeQueryLogEntry>[entry(clientDisallowed: true)]),
      );

      final Icon mark = tester.widget(find.byIcon(Icons.block));
      expect(mark.semanticLabel, 'Disallowed client');
    });

    testWidgets('a client that is let in has no mark',
        (WidgetTester tester) async {
      await pumpTab(tester, all(<AdguardHomeQueryLogEntry>[entry()]));

      expect(find.byIcon(Icons.block), findsNothing);
    });

    testWidgets('each result is named as the web UI names it',
        (WidgetTester tester) async {
      await pumpTab(
        tester,
        all(<AdguardHomeQueryLogEntry>[
          blocked,
          entry(domain: 'en.wikipedia.org', reason: 'NotFilteredWhiteList'),
          entry(domain: 'nas.home.example', reason: 'Rewrite'),
          entry(domain: 'www.youtube.com', reason: 'FilteredSafeSearch'),
          entry(domain: 'adult.example', reason: 'FilteredParental'),
          entry(domain: 'new.example', reason: 'FilteredSomethingNew'),
        ]),
      );

      AdguardHomeResultChip chip(String domain) => tester.widget(
            find.descendant(
              of: find.ancestor(
                of: find.text(domain),
                matching: find.byType(AdguardHomeQueryLogRow),
              ),
              matching: find.byType(AdguardHomeResultChip),
            ),
          );

      expect(chip('adservice.google.com').label, 'Blocked');
      expect(chip('adservice.google.com').tone, AdguardHomeResultTone.blocked);
      expect(chip('en.wikipedia.org').label, 'Allowed');
      expect(chip('en.wikipedia.org').tone, AdguardHomeResultTone.allowed);
      expect(chip('nas.home.example').tone, AdguardHomeResultTone.rewritten);
      expect(chip('www.youtube.com').tone, AdguardHomeResultTone.restricted);
      // Shortened, so it is not cut off beside the client.
      expect(chip('adult.example').label, 'Parental control');
      // One this app has no name for reads as the server wrote it.
      expect(chip('new.example').label, 'FilteredSomethingNew');
      expect(chip('new.example').tone, AdguardHomeResultTone.plain);
    });

    testWidgets('the end of the log is said', (WidgetTester tester) async {
      await pumpTab(tester, all(<AdguardHomeQueryLogEntry>[entry()]));

      expect(find.text('End of the query log'), findsOneWidget);
    });

    testWidgets('older entries are asked for when the end comes into view, '
        'and once', (WidgetTester tester) async {
      final Pumped pumped = await pumpTab(
        tester,
        AdguardHomeQueryLogState(
          entries: <AdguardHomeQueryLogEntry>[entry()],
          searchedBackTo: 'c1',
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(pumped.log.calls, <String>['more']);
      expect(find.text('End of the query log'), findsNothing);
    });

    testWidgets('a read that ran out of requests waits to be asked on',
        (WidgetTester tester) async {
      final Pumped pumped = await pumpTab(
        tester,
        AdguardHomeQueryLogState(
          entries: <AdguardHomeQueryLogEntry>[entry()],
          filter: AdguardHomeLogFilter.blockedThreats,
          stalled: true,
          searchedBackTo:
              DateTime(2026, 10, 5, 14, 20, 11).toUtc().toIso8601String(),
        ),
      );
      await tester.pump();

      expect(find.text('Searched back to 5 Oct 14:20:11'), findsOneWidget);
      expect(pumped.log.calls, isEmpty);

      await tester.tap(find.text('Keep searching'));
      await tester.pump();

      expect(pumped.log.calls, <String>['more']);
    });

    testWidgets('older entries that could not be read can be asked for again',
        (WidgetTester tester) async {
      final Pumped pumped = await pumpTab(
        tester,
        AdguardHomeQueryLogState(
          entries: <AdguardHomeQueryLogEntry>[entry()],
          searchedBackTo: 'c1',
          error: const AdguardHomeUnexpectedAnswer(),
        ),
      );
      await tester.pump();

      // The entries stay, and nothing is asked for by itself.
      expect(find.text('example.org'), findsOneWidget);
      expect(
        find.text('This address answered, but not as AdGuard Home.'),
        findsOneWidget,
      );
      expect(pumped.log.calls, isEmpty);

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(pumped.log.calls, <String>['more']);
    });

    testWidgets('pulling down reads the log again',
        (WidgetTester tester) async {
      final Pumped pumped =
          await pumpTab(tester, all(<AdguardHomeQueryLogEntry>[entry()]));

      await tester.drag(find.text('example.org'), const Offset(0, 320));
      await tester.pumpAndSettle();

      expect(pumped.log.calls, <String>['reload']);
    });
  });

  group('with nothing to list', () {
    testWidgets('a first read shows that it is under way',
        (WidgetTester tester) async {
      await pumpTab(tester, const AdguardHomeQueryLogState(loading: true));

      expect(find.byType(ExpressiveProgressIndicator), findsOneWidget);
    });

    testWidgets('a read that failed says why and can be tried again',
        (WidgetTester tester) async {
      final Pumped pumped = await pumpTab(
        tester,
        const AdguardHomeQueryLogState(
          error: AdguardHomeRequestRefused('parsing params: invalid value'),
        ),
      );

      expect(find.text('parsing params: invalid value'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(pumped.log.calls, <String>['reload']);
    });

    testWidgets('an empty log says so', (WidgetTester tester) async {
      await pumpTab(tester, all(const <AdguardHomeQueryLogEntry>[]));

      expect(find.text('Nothing in the query log yet'), findsOneWidget);
    });

    testWidgets('a server that keeps no log says that instead',
        (WidgetTester tester) async {
      await pumpTab(
        tester,
        all(const <AdguardHomeQueryLogEntry>[]),
        config: const AdguardHomeQueryLogConfig(enabled: false),
      );

      expect(find.text('The query log is off'), findsOneWidget);
      expect(find.text('Nothing in the query log yet'), findsNothing);
    });

    testWidgets('nothing under a search offers to clear it',
        (WidgetTester tester) async {
      final Pumped pumped = await pumpTab(
        tester,
        const AdguardHomeQueryLogState(
          search: 'zzz',
          filter: AdguardHomeLogFilter.blocked,
          reachedEnd: true,
        ),
      );

      expect(find.text('Nothing found'), findsOneWidget);
      await tester.tap(find.text('Clear search and filter'));
      await tester.pump();

      expect(pumped.log.calls, <String>['search ', 'filter all']);
    });

    testWidgets('a search that has not reached the end yet says how far '
        'it got', (WidgetTester tester) async {
      final Pumped pumped = await pumpTab(
        tester,
        AdguardHomeQueryLogState(
          search: 'rare.example',
          stalled: true,
          searchedBackTo:
              DateTime(2026, 10, 5, 14, 20, 11).toUtc().toIso8601String(),
        ),
      );

      expect(find.text('Nothing found yet'), findsOneWidget);
      expect(find.text('Searched back to 5 Oct 14:20:11'), findsOneWidget);
      await tester.tap(find.text('Keep searching'));
      await tester.pump();

      expect(pumped.log.calls, <String>['more']);
    });
  });

  group('narrowing down', () {
    testWidgets('offers the ten filters of the web UI',
        (WidgetTester tester) async {
      await pumpTab(tester, all(<AdguardHomeQueryLogEntry>[entry()]));

      for (final AdguardHomeLogFilter filter in AdguardHomeLogFilter.values) {
        expect(
          find.widgetWithText(ChoiceChip, filter.label),
          findsOneWidget,
          reason: filter.label,
        );
      }
    });

    testWidgets('a filter is asked for when its chip is tapped',
        (WidgetTester tester) async {
      final Pumped pumped =
          await pumpTab(tester, all(<AdguardHomeQueryLogEntry>[entry()]));

      // The ten do not fit side by side: this one is scrolled to.
      final Finder chip = find.widgetWithText(ChoiceChip, 'Blocked');
      await tester.ensureVisible(chip);
      await tester.pump();
      await tester.tap(chip);
      await tester.pump();

      expect(pumped.log.calls, <String>['filter blocked']);
    });

    testWidgets('the chip of the filter in force is the selected one',
        (WidgetTester tester) async {
      await pumpTab(
        tester,
        const AdguardHomeQueryLogState(
          filter: AdguardHomeLogFilter.rewritten,
          reachedEnd: true,
        ),
      );

      bool selected(String label) => tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label))
          .selected;

      expect(selected('Rewritten'), isTrue);
      expect(selected('All queries'), isFalse);
    });

    testWidgets('a search is sent once the typing has paused',
        (WidgetTester tester) async {
      final Pumped pumped =
          await pumpTab(tester, all(<AdguardHomeQueryLogEntry>[entry()]));

      await tester.enterText(find.byType(TextField), 'Lap');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(find.byType(TextField), 'Laptop');
      await tester.pump(const Duration(milliseconds: 399));
      expect(pumped.log.calls, isEmpty);

      await tester.pump(const Duration(milliseconds: 1));

      expect(pumped.log.calls, <String>['search Laptop']);
    });

    testWidgets('submitting sends it at once, and only once',
        (WidgetTester tester) async {
      final Pumped pumped =
          await pumpTab(tester, all(<AdguardHomeQueryLogEntry>[entry()]));

      await tester.enterText(find.byType(TextField), 'tiktok');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(pumped.log.calls, <String>['search tiktok']);

      await tester.pump(const Duration(seconds: 1));
      expect(pumped.log.calls, <String>['search tiktok']);
    });

    testWidgets('the cross empties the search', (WidgetTester tester) async {
      final Pumped pumped =
          await pumpTab(tester, all(<AdguardHomeQueryLogEntry>[entry()]));
      expect(find.byTooltip('Clear search'), findsNothing);

      await tester.enterText(find.byType(TextField), 'tiktok');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump();

      expect(pumped.log.calls, <String>['search tiktok', 'search ']);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    });
  });

  group('a refused sign-in', () {
    testWidgets('takes the place of the list and the search',
        (WidgetTester tester) async {
      await pumpTab(
        tester,
        const AdguardHomeQueryLogState(error: AdguardHomeSignInRefused()),
      );

      expect(find.text('AdGuard Home refused the sign-in'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
    });

    testWidgets('trying again lets one request out and reads the log',
        (WidgetTester tester) async {
      final Pumped pumped = await pumpTab(
        tester,
        const AdguardHomeQueryLogState(error: AdguardHomeSignInRefused()),
      );

      await tester.tap(find.text('Try again'));
      await tester.pump();

      expect(pumped.actions.calls, <String>['retry']);
      expect(pumped.log.calls, <String>['reload']);
    });

    testWidgets('with no sign-in entered it asks for one',
        (WidgetTester tester) async {
      await pumpTab(
        tester,
        const AdguardHomeQueryLogState(error: AdguardHomeSignInRefused()),
        instance: adguardHomeTestInstance.copyWith(
          auth: const InstanceAuth.userPass(username: '', password: ''),
        ),
      );

      expect(find.text('AdGuard Home asks for a sign-in'), findsOneWidget);
    });
  });

  group('the detail of an entry', () {
    Future<Pumped> open(
      WidgetTester tester,
      AdguardHomeQueryLogEntry which, {
      Size size = const Size(360, 1600),
      double textScale = 1,
    }) async {
      final Pumped pumped = await pumpTab(
        tester,
        all(<AdguardHomeQueryLogEntry>[which]),
        size: size,
        textScale: textScale,
      );
      await tester.tap(find.byType(AdguardHomeQueryLogRow));
      await tester.pumpAndSettle();
      return pumped;
    }

    testWidgets('shows what the entry carries', (WidgetTester tester) async {
      await open(tester, entry());

      final Finder sheet = find.byType(AdguardHomeQueryDetail);
      Finder inSheet(String text) =>
          find.descendant(of: sheet, matching: find.text(text));

      expect(inSheet('example.org'), findsOneWidget);
      expect(inSheet('Processed'), findsOneWidget);
      expect(inSheet('7 Oct 2026, 20:29:32.377'), findsOneWidget);
      expect(inSheet('Type'), findsOneWidget);
      expect(inSheet('A'), findsOneWidget);
      expect(inSheet('Plain DNS'), findsOneWidget);
      expect(inSheet('NOERROR'), findsOneWidget);
      expect(
        inSheet('https://dns10.quad9.net:443/dns-query'),
        findsOneWidget,
      );
      expect(inSheet('365 ms'), findsOneWidget);
      expect(inSheet('A: 172.66.157.237 (ttl=262)'), findsOneWidget);
      expect(inSheet('172.17.0.1'), findsOneWidget);
      expect(inSheet('Laptop'), findsOneWidget);
      // Nothing came from the cache, so that line is left out.
      expect(inSheet('Served from cache'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('starts at the left edge of the sheet, whatever its width',
        (WidgetTester tester) async {
      // An entry with nothing wide in it is as far left as any other:
      // nothing is centred.
      await open(
        tester,
        const AdguardHomeQueryLogEntry(
          domain: 'a.io',
          reason: 'NotFilteredNotFound',
          type: 'A',
          status: 'OK',
        ),
      );

      final Finder sheet = find.byType(AdguardHomeQueryDetail);
      double left(String text) => tester
          .getTopLeft(find.descendant(of: sheet, matching: find.text(text)))
          .dx;

      expect(left('a.io'), 16);
      expect(left('Request'), 16);
      expect(left('OK'), 16);
    });

    testWidgets('names the rule that matched and the list it is on',
        (WidgetTester tester) async {
      await open(tester, blocked);

      expect(find.text('||adservice.google.'), findsOneWidget);
      expect(find.text('AdGuard DNS filter'), findsOneWidget);
    });

    testWidgets('says when the answer came from the cache',
        (WidgetTester tester) async {
      await open(tester, entry(cached: true));

      expect(find.text('Served from cache'), findsOneWidget);
    });

    testWidgets('names the blocked service', (WidgetTester tester) async {
      await open(
        tester,
        entry(
          domain: 'www.tiktok.com',
          reason: 'FilteredBlockedService',
          serviceName: 'tiktok',
        ),
      );

      expect(find.text('Blocked service'), findsWidgets);
      expect(find.text('tiktok'), findsOneWidget);
    });

    testWidgets('says what shuts a shut-out client out',
        (WidgetTester tester) async {
      await open(
        tester,
        entry(clientDisallowed: true, clientDisallowedRule: '172.17.0.0/16'),
      );

      expect(
        find.text('Disallowed by 172.17.0.0/16'),
        findsOneWidget,
      );
    });

    testWidgets('holds on a narrow screen at twice the text size',
        (WidgetTester tester) async {
      await open(
        tester,
        entry(
          domain: 'a-very-long-subdomain.of-a-long-name.example-tracker.com',
          reason: 'FilteredParental',
          clientName: 'Living room television',
          rules: const <AdguardHomeMatchedRule>[
            AdguardHomeMatchedRule(
              listId: -3,
              text: 'parental CATEGORY_BLACKLISTED',
            ),
          ],
        ),
        size: const Size(320, 900),
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(AdguardHomeQueryDetail), findsOneWidget);
    });
  });

  group('acting on an entry', () {
    Future<Pumped> open(
      WidgetTester tester,
      AdguardHomeQueryLogEntry which,
    ) async {
      final Pumped pumped = await pumpTab(
        tester,
        all(<AdguardHomeQueryLogEntry>[which]),
        size: const Size(360, 1600),
      );
      await tester.tap(find.byType(AdguardHomeQueryLogRow));
      await tester.pumpAndSettle();
      return pumped;
    }

    /// Opens the menu beside the main action and picks [item] from it.
    Future<void> more(WidgetTester tester, String item) async {
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(item));
      await tester.pumpAndSettle();
    }

    testWidgets('the main action stays in reach however long the entry is',
        (WidgetTester tester) async {
      await pumpTab(
        tester,
        all(<AdguardHomeQueryLogEntry>[
          entry(
            rules: <AdguardHomeMatchedRule>[
              for (int i = 0; i < 20; i++)
                AdguardHomeMatchedRule(listId: 1, text: '||rule$i.example^'),
            ],
          ),
        ]),
        size: const Size(360, 640),
      );
      await tester.tap(find.byType(AdguardHomeQueryLogRow));
      await tester.pumpAndSettle();

      // Not at the end of a scroll: on the screen as the sheet opens.
      final Rect button =
          tester.getRect(find.widgetWithText(FilledButton, 'Block'));
      expect(button.bottom, lessThanOrEqualTo(640));
      expect(button.top, greaterThan(0));
      // And the last rule is there to scroll to.
      expect(
        find.text('||rule19.example^', skipOffstage: false),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('an answered query can be blocked, and the sheet closes',
        (WidgetTester tester) async {
      final Pumped pumped = await open(tester, entry());

      await tester.tap(find.widgetWithText(FilledButton, 'Block'));
      await tester.pumpAndSettle();

      expect(pumped.actions.calls, <String>['block example.org']);
      expect(find.byType(AdguardHomeQueryDetail), findsNothing);
      expect(
        find.text(r'Added ||example.org^$important to the custom rules'),
        findsOneWidget,
      );
    });

    testWidgets('a filtered one can be unblocked', (WidgetTester tester) async {
      final Pumped pumped = await open(tester, blocked);

      expect(find.widgetWithText(FilledButton, 'Block'), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Unblock'));
      await tester.pumpAndSettle();

      expect(pumped.actions.calls, <String>['unblock adservice.google.com']);
    });

    testWidgets('a name in another script is blocked by its ASCII form',
        (WidgetTester tester) async {
      final Pumped pumped = await open(
        tester,
        entry(domain: 'xn--mnchen-3ya.example', unicodeName: 'münchen.example'),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Block'));
      await tester.pumpAndSettle();

      expect(pumped.actions.calls, <String>['block xn--mnchen-3ya.example']);
    });

    testWidgets('blocking for this client only passes the client\'s address',
        (WidgetTester tester) async {
      final Pumped pumped = await open(tester, entry());

      await more(tester, 'Block for this client only');

      expect(
        pumped.actions.calls,
        <String>['block example.org for 172.17.0.1'],
      );
    });

    testWidgets('a filtered one is unblocked for this client only',
        (WidgetTester tester) async {
      final Pumped pumped = await open(tester, blocked);

      await more(tester, 'Unblock for this client only');

      expect(
        pumped.actions.calls,
        <String>['unblock adservice.google.com for 172.17.0.1'],
      );
    });

    testWidgets('shutting the client out asks first, and No changes nothing',
        (WidgetTester tester) async {
      final Pumped pumped = await open(tester, entry());

      await more(tester, 'Disallow this client');

      expect(find.text('Disallow this client?'), findsOneWidget);
      expect(
        find.textContaining('drop every DNS query from 172.17.0.1'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(pumped.actions.calls, <String>['read access']);
      expect(pumped.log.calls, isEmpty);
      // Still on the entry.
      expect(find.byType(AdguardHomeQueryDetail), findsOneWidget);
    });

    testWidgets('confirming shuts it out and reads the log again',
        (WidgetTester tester) async {
      final Pumped pumped = await open(tester, entry());

      await more(tester, 'Disallow this client');
      await tester.tap(find.widgetWithText(FilledButton, 'Disallow'));
      await tester.pumpAndSettle();

      // No rule is named for a client that is not shut out: what the server
      // sends in that property means nothing then.
      expect(
        pumped.actions.calls,
        <String>['read access', 'disallow 172.17.0.1 rule='],
      );
      expect(pumped.log.calls, <String>['reload']);
      expect(find.byType(AdguardHomeQueryDetail), findsNothing);
      expect(find.text('172.17.0.1 is now disallowed'), findsOneWidget);
    });

    testWidgets('a shut-out client can be let back in by the entry that '
        'shuts it out', (WidgetTester tester) async {
      final Pumped pumped = await open(
        tester,
        entry(clientDisallowed: true, clientDisallowedRule: '172.17.0.0/16'),
      );

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      expect(find.text('Disallow this client'), findsNothing);
      await tester.tap(find.text('Allow this client'));
      await tester.pumpAndSettle();

      expect(find.text('Allow this client?'), findsOneWidget);
      expect(
        find.textContaining('172.17.0.0/16 from the disallowed clients'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Allow'));
      await tester.pumpAndSettle();

      expect(
        pumped.actions.calls,
        <String>['read access', 'allow 172.17.0.1 rule=172.17.0.0/16'],
      );
      expect(pumped.log.calls, <String>['reload']);
    });

    testWidgets('with the allowed clients in use it says what that does',
        (WidgetTester tester) async {
      final Pumped pumped = await pumpTab(
        tester,
        all(<AdguardHomeQueryLogEntry>[entry()]),
        size: const Size(360, 1600),
      );
      pumped.actions.accessList = const AdguardHomeAccessList(
        allowedClients: <String>['127.0.0.1', '172.17.0.1'],
      );
      await tester.tap(find.byType(AdguardHomeQueryLogRow));
      await tester.pumpAndSettle();

      await more(tester, 'Disallow this client');

      expect(
        find.textContaining('takes 172.17.0.1 off the allowed clients'),
        findsOneWidget,
      );
    });

    testWidgets('the only allowed client is not offered a way out',
        (WidgetTester tester) async {
      final Pumped pumped = await pumpTab(
        tester,
        all(<AdguardHomeQueryLogEntry>[entry()]),
        size: const Size(360, 1600),
      );
      pumped.actions.accessList = const AdguardHomeAccessList(
        allowedClients: <String>['172.17.0.1'],
      );
      await tester.tap(find.byType(AdguardHomeQueryLogRow));
      await tester.pumpAndSettle();

      await more(tester, 'Disallow this client');

      expect(find.text('Disallow this client?'), findsNothing);
      expect(find.text(AdguardHomeLastAllowedClient.message), findsOneWidget);
      expect(pumped.actions.calls, <String>['read access']);
    });

    testWidgets('a write the server turns down is said in its words',
        (WidgetTester tester) async {
      final Pumped pumped = await pumpTab(
        tester,
        all(<AdguardHomeQueryLogEntry>[entry()]),
        size: const Size(360, 1600),
      );
      pumped.actions.writeFailure =
          const AdguardHomeRequestRefused('bad ip, cidr, or clientid');
      await tester.tap(find.byType(AdguardHomeQueryLogRow));
      await tester.pumpAndSettle();

      await more(tester, 'Disallow this client');
      await tester.tap(find.widgetWithText(FilledButton, 'Disallow'));
      await tester.pumpAndSettle();

      expect(find.text('bad ip, cidr, or clientid'), findsOneWidget);
      // Nothing changed, so the log is not read again.
      expect(pumped.log.calls, isEmpty);
    });

    testWidgets('an entry with no client has nothing to do to a client',
        (WidgetTester tester) async {
      await open(tester, entry(client: '', clientName: ''));

      expect(find.widgetWithText(FilledButton, 'Block'), findsOneWidget);
      expect(find.byTooltip('More actions'), findsNothing);
    });
  });

  group('layout', () {
    final List<AdguardHomeQueryLogEntry> awkward = <AdguardHomeQueryLogEntry>[
      entry(
        domain: 'a-very-long-subdomain.of-a-long-name.example-tracker.com',
        reason: 'FilteredParental',
        clientName: 'Living room television',
        elapsed: const Duration(seconds: 12),
        at: DateTime(2025, 12, 31, 23, 59, 59),
      ),
      entry(type: 'HTTPS', clientName: '', client: '2001:db8:85a3::8a2e:370:7334'),
    ];

    for (final double width in <double>[320, 360, 411]) {
      for (final double scale in <double>[1, 1.3, 2]) {
        testWidgets('holds at $width wide and $scale text',
            (WidgetTester tester) async {
          await pumpTab(
            tester,
            all(awkward),
            size: Size(width, 900),
            textScale: scale,
          );

          expect(tester.takeException(), isNull);
          expect(find.byType(AdguardHomeQueryLogRow), findsNWidgets(2));
        });
      }
    }
  });
}
