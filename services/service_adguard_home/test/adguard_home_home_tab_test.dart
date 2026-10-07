import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:core_ui/core_ui.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

import 'support/adguard_home_fixtures.dart';
import 'support/adguard_home_test_instance.dart';
import 'support/pump.dart';

void main() {
  final DateTime readAt = DateTime(2026, 10, 7, 18, 30);

  AdguardHomeStatus statusWith({
    bool enabled = true,
    Duration pauseLeft = Duration.zero,
  }) =>
      AdguardHomeStatus(
        version: 'v0.107.79',
        running: true,
        protectionEnabled: enabled,
        pauseLeft: pauseLeft,
        readAt: readAt,
      );

  Widget tab({
    DateTime Function()? now,
    Instance instance = adguardHomeTestInstance,
  }) =>
      AdguardHomeHomeTab(
        instance: instance,
        now: now ?? () => readAt,
      );

  testWidgets('shows protection, the figures and the top lists',
      (WidgetTester tester) async {
    await pumpAdguardHome(
      tester,
      tab(),
      status: statusWith(),
      stats: AdguardHomeStats.fromJson(statsJson()),
      filtering: AdguardHomeFiltering.fromJson(filteringJson()),
    );

    expect(find.text('Protection is on'), findsOneWidget);
    expect(find.text('Last 24 hours'), findsOneWidget);

    expect(find.text('DNS queries'), findsOneWidget);
    expect(find.text('68'), findsWidgets);
    expect(find.text('Blocked by filters'), findsOneWidget);
    expect(find.text('24'), findsWidgets);
    expect(find.text('35.29%'), findsOneWidget);
    expect(find.text('Blocked malware and phishing'), findsOneWidget);
    expect(find.text('Blocked adult websites'), findsOneWidget);
    expect(find.text('Enforced safe search'), findsOneWidget);
    // The average processing time sits with the queries it is about.
    expect(find.text('avg 67 ms'), findsOneWidget);
    // Only the blocklist that is switched on counts.
    expect(find.text('Rules on blocklists'), findsOneWidget);
    expect(find.text('179,185'), findsOneWidget);

    expect(find.text('Top clients'), findsOneWidget);
    expect(find.text('127.0.0.1'), findsOneWidget);
    expect(find.text('Top queried domains'), findsOneWidget);
    expect(find.text('github.com'), findsOneWidget);
    expect(find.text('Top blocked domains'), findsOneWidget);
    expect(find.text('doubleclick.net'), findsOneWidget);
    expect(find.text('Top upstreams'), findsOneWidget);
    // The upstream's average response time, 0.189 s.
    expect(find.text('189 ms'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a server nobody has asked anything shows zeros, not errors',
      (WidgetTester tester) async {
    await pumpAdguardHome(tester, tab(), status: statusWith());

    expect(find.text('0%'), findsOneWidget);
    expect(find.text('avg 0 ms'), findsOneWidget);
    expect(find.text('Nothing yet'), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the charts of two tiles side by side line up',
      (WidgetTester tester) async {
    // One label takes more lines than its neighbour's, which used to leave
    // the two charts at different heights.
    await pumpAdguardHome(
      tester,
      tab(),
      status: statusWith(),
      stats: AdguardHomeStats.fromJson(statsJson()),
    );

    final Finder charts = find.byType(LineChart);
    expect(charts, findsNWidgets(4));
    // Queries and blocked come first, each on a card of its own. Malware
    // and adult websites share the row after them.
    expect(
      tester.getRect(charts.at(2)).bottom,
      tester.getRect(charts.at(3)).bottom,
    );
  });

  testWidgets('queries and blocked each get a chart across the tab',
      (WidgetTester tester) async {
    await pumpAdguardHome(
      tester,
      tab(),
      status: statusWith(),
      stats: AdguardHomeStats.fromJson(statsJson()),
    );

    final Finder charts = find.byType(LineChart);
    // 360 wide, less the page's padding and the card's.
    expect(tester.getSize(charts.at(0)), const Size(304, 120));
    expect(tester.getSize(charts.at(1)), const Size(304, 120));
    // One above the other, with the total and a second figure beside each
    // title.
    expect(
      tester.getRect(charts.at(1)).top,
      greaterThan(tester.getRect(charts.at(0)).bottom),
    );
    expect(find.text('avg 67 ms'), findsOneWidget);
    expect(find.text('35.29%'), findsOneWidget);
  });

  testWidgets('a long figure leaves no gap above its chart',
      (WidgetTester tester) async {
    // A nine-digit count at twice the text size is shrunk to fit one line.
    // The tile must be measured as that one line too, or the row grows as
    // if the figure had wrapped and the chart drifts away from it.
    await pumpAdguardHome(
      tester,
      tab(),
      status: statusWith(),
      stats: AdguardHomeStats.fromJson(
        statsJson()..['num_replaced_safebrowsing'] = 123456789,
      ),
      size: const Size(320, 6000),
      textScale: 2,
    );

    // The malware tile is the taller of its row, so its chart sits right
    // under the box its figure shrinks in.
    final double figureBottom = tester
        .getRect(
          find.ancestor(
            of: find.text('123,456,789'),
            matching: find.byType(FittedBox),
          ),
        )
        .bottom;
    final double chartTop = tester.getRect(find.byType(LineChart).at(2)).top;
    expect(chartTop - figureBottom, closeTo(Insets.sm, 0.01));
  });

  testWidgets('the layout holds on a narrow screen at large text',
      (WidgetTester tester) async {
    await pumpAdguardHome(
      tester,
      tab(),
      status: statusWith(
        enabled: false,
        pauseLeft: const Duration(hours: 23, minutes: 59),
      ),
      stats: AdguardHomeStats.fromJson(
        statsJson()
          ..['num_dns_queries'] = 123456789
          ..['num_blocked_filtering'] = 98765432
          ..['top_queried_domains'] = <dynamic>[
            <String, dynamic>{
              'a-very-long-subdomain.of.another-long-subdomain.example.com':
                  123456789,
            },
          ],
      ),
      // Tall enough that every row is laid out at twice the text size.
      size: const Size(320, 6000),
      textScale: 2,
    );

    // An overflow would have been thrown as a layout error.
    expect(tester.takeException(), isNull);
    expect(find.text('Protection is paused'), findsOneWidget);
  });

  testWidgets('the switch and the pause chips ask for the right change',
      (WidgetTester tester) async {
    final Pumped pumped =
        await pumpAdguardHome(tester, tab(), status: statusWith());

    for (final String label in <String>[
      '30 seconds',
      '1 minute',
      '10 minutes',
      '1 hour',
      'Until tomorrow',
    ]) {
      expect(find.widgetWithText(ActionChip, label), findsOneWidget);
    }

    await tester.tap(find.widgetWithText(ActionChip, '10 minutes'));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.pump();

    expect(pumped.actions.calls, <String>[
      'protection enabled=false pause=600',
      'protection enabled=false pause=null',
    ]);
  });

  testWidgets('turning the switch on resumes a paused server',
      (WidgetTester tester) async {
    final Pumped pumped = await pumpAdguardHome(
      tester,
      tab(),
      status: statusWith(
        enabled: false,
        pauseLeft: const Duration(minutes: 5),
      ),
    );

    expect(find.text('Protection is paused'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.pump();

    expect(pumped.actions.calls, <String>['protection enabled=true pause=null']);
  });

  testWidgets('a change the server turns down says why',
      (WidgetTester tester) async {
    final Pumped pumped =
        await pumpAdguardHome(tester, tab(), status: statusWith());
    pumped.actions.failure =
        const AdguardHomeRequestRefused('protection: not now');

    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.pump();

    expect(find.text('protection: not now'), findsOneWidget);
    // And the controls come back.
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNotNull);
  });

  testWidgets('a pause counts down, stops at zero and reads the server again',
      (WidgetTester tester) async {
    DateTime clock = readAt;
    final Pumped pumped = await pumpAdguardHome(
      tester,
      tab(now: () => clock),
      status: statusWith(
        enabled: false,
        pauseLeft: const Duration(seconds: 30),
      ),
    );

    expect(find.text('Protection is paused'), findsOneWidget);
    expect(find.text('0:30'), findsOneWidget);
    expect(pumped.statusReads, 1);

    clock = readAt.add(const Duration(seconds: 12));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('0:18'), findsOneWidget);

    // Past the end: the time must not go negative, and the status is read
    // again at once instead of at the next poll.
    clock = readAt.add(const Duration(seconds: 45));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('0:00'), findsOneWidget);
    expect(pumped.statusReads, 2);

    // Once, not on every tick after it.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(pumped.statusReads, 2);
  });

  testWidgets('off with no timer says so and shows no countdown',
      (WidgetTester tester) async {
    await pumpAdguardHome(tester, tab(), status: statusWith(enabled: false));

    expect(find.text('Protection is off'), findsOneWidget);
    expect(find.byType(AdguardHomeCountdown), findsNothing);
  });

  testWidgets('a refused sign-in shows why, and only tries again when asked',
      (WidgetTester tester) async {
    final Pumped pumped = await pumpAdguardHome(
      tester,
      tab(),
      statusError: const AdguardHomeSignInRefused(),
      statsError: const AdguardHomeSignInRefused(),
    );

    expect(find.text('AdGuard Home refused the sign-in'), findsOneWidget);
    expect(find.text(AdguardHomeRefusedView.explanation), findsOneWidget);
    expect(find.textContaining('15 minutes'), findsOneWidget);
    expect(find.text('Protection is on'), findsNothing);
    expect(pumped.actions.calls, isEmpty);

    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(pumped.actions.calls, <String>['retry']);
  });

  testWidgets('with no sign-in entered it asks for one, not for a better one',
      (WidgetTester tester) async {
    // A server that has a user answers an instance with no username or
    // password with the same 401. Nothing was sent that it counts as a wrong
    // try, so the talk of a lockout would only mislead.
    final Instance blank = adguardHomeTestInstance.copyWith(
      auth: const InstanceAuth.userPass(username: '', password: ''),
    );
    await pumpAdguardHome(
      tester,
      tab(instance: blank),
      instance: blank,
      statusError: const AdguardHomeSignInRefused(),
    );

    expect(find.text('AdGuard Home asks for a sign-in'), findsOneWidget);
    expect(find.text(AdguardHomeRefusedView.noCredentials), findsOneWidget);
    expect(find.textContaining('15 minutes'), findsNothing);
    expect(find.text('Edit instance'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('any other failure shows its message and a retry',
      (WidgetTester tester) async {
    final Pumped pumped = await pumpAdguardHome(
      tester,
      tab(),
      statusError: const NetworkUnreachableException('No route to host'),
    );

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('No route to host'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(pumped.actions.calls, <String>['refresh']);
  });

  testWidgets('statistics that fail leave the protection card usable',
      (WidgetTester tester) async {
    await pumpAdguardHome(
      tester,
      tab(),
      status: statusWith(),
      statsError: const NetworkTimeoutException('Server took too long.'),
    );

    expect(find.text('Protection is on'), findsOneWidget);
    expect(find.text('Server took too long.'), findsOneWidget);
    expect(find.text('DNS queries'), findsNothing);
  });

  testWidgets('a queried domain can be blocked and a blocked one unblocked',
      (WidgetTester tester) async {
    final Pumped pumped = await pumpAdguardHome(
      tester,
      tab(),
      status: statusWith(),
      stats: AdguardHomeStats.fromJson(statsJson()),
    );

    await tester.ensureVisible(find.byTooltip('Block github.com'));
    await tester.tap(find.byTooltip('Block github.com'));
    await tester.pump();
    await tester.pump();
    expect(
      find.text(r'Added ||github.com^$important to the custom rules'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.byTooltip('Unblock doubleclick.net'));
    await tester.tap(find.byTooltip('Unblock doubleclick.net'));
    await tester.pump();
    await tester.pump();

    expect(pumped.actions.calls, <String>[
      'block github.com',
      'unblock doubleclick.net',
    ]);
    // Clients and upstreams are not domains: nothing to block there.
    expect(find.byTooltip('Block 127.0.0.1'), findsNothing);
  });

  testWidgets('removing the opposite rule is reported as a removal',
      (WidgetTester tester) async {
    final Pumped pumped = await pumpAdguardHome(
      tester,
      tab(),
      status: statusWith(),
      stats: AdguardHomeStats.fromJson(statsJson()),
    );
    pumped.actions.change = AdguardHomeRuleChange.removed;

    await tester.ensureVisible(find.byTooltip('Block github.com'));
    await tester.tap(find.byTooltip('Block github.com'));
    await tester.pump();
    await tester.pump();

    expect(
      find.text(r'Removed ||github.com^$important from the custom rules'),
      findsOneWidget,
    );
  });

  testWidgets('View all opens the whole list, where a domain can be blocked',
      (WidgetTester tester) async {
    final Pumped pumped = await pumpAdguardHome(
      tester,
      tab(),
      status: statusWith(),
      stats: AdguardHomeStats.fromJson(statsJson()),
    );

    // Seven queried domains: five on the tab, two added up as Others.
    expect(find.text('f-droid.org'), findsNothing);
    expect(find.text('Others'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);

    await tester.ensureVisible(find.text('View all'));
    await tester.tap(find.text('View all'));
    await tester.pumpAndSettle();

    expect(find.text('Top queried domains'), findsOneWidget);
    expect(find.text('f-droid.org'), findsOneWidget);
    expect(find.text('sonarr.tv'), findsOneWidget);
    expect(find.text('Others'), findsNothing);

    await tester.tap(find.byTooltip('Block f-droid.org'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));

    expect(pumped.actions.calls, <String>['block f-droid.org']);
    expect(
      find.text(r'Added ||f-droid.org^$important to the custom rules'),
      findsOneWidget,
    );
  });

  testWidgets('a block can be taken back from its message',
      (WidgetTester tester) async {
    // The lists re-read themselves every half minute and can reorder under a
    // finger, and a block reaches everything that uses the server.
    final Pumped pumped = await pumpAdguardHome(
      tester,
      tab(),
      status: statusWith(),
      stats: AdguardHomeStats.fromJson(statsJson()),
    );

    await tester.ensureVisible(find.byTooltip('Block github.com'));
    await tester.tap(find.byTooltip('Block github.com'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));

    expect(pumped.actions.calls, <String>[
      'block github.com',
      'unblock github.com',
    ]);
    // Taking it back is itself said, and is not offered to be taken back.
    expect(find.textContaining('@@||github.com'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets('a rule that was already there offers nothing to take back',
      (WidgetTester tester) async {
    // Nothing was changed, so undoing would remove a rule this tap never
    // added.
    final Pumped pumped = await pumpAdguardHome(
      tester,
      tab(),
      status: statusWith(),
      stats: AdguardHomeStats.fromJson(statsJson()),
    );
    pumped.actions.change = AdguardHomeRuleChange.alreadyThere;

    await tester.ensureVisible(find.byTooltip('Block github.com'));
    await tester.tap(find.byTooltip('Block github.com'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));

    expect(find.textContaining('is already in the custom rules'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets('the shell names the instance and marks it beta',
      (WidgetTester tester) async {
    await pumpAdguardHome(
      tester,
      const AdguardHomeShell(instance: adguardHomeTestInstance),
      status: statusWith(),
    );

    expect(find.text('AdGuard Home'), findsOneWidget);
    expect(find.byType(BetaBadge), findsOneWidget);
    expect(find.text('Protection is on'), findsOneWidget);
  });
}
