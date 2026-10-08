import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

import 'support/adguard_home_test_instance.dart';
import 'support/pump.dart';

void main() {
  final DateTime readAt = DateTime(2026, 10, 7, 18, 30);

  final AdguardHomeStatus status = AdguardHomeStatus(
    version: 'v0.107.79',
    running: true,
    protectionEnabled: true,
    pauseLeft: Duration.zero,
    readAt: readAt,
  );

  final AdguardHomeQueryLogState log = AdguardHomeQueryLogState(
    entries: <AdguardHomeQueryLogEntry>[
      AdguardHomeQueryLogEntry(
        domain: 'example.org',
        reason: 'NotFilteredNotFound',
        time: readAt.toUtc(),
        type: 'A',
        client: '172.17.0.1',
      ),
    ],
    reachedEnd: true,
  );

  Future<Pumped> pumpShell(WidgetTester tester, {Object? clientsError}) =>
      pumpAdguardHome(
        tester,
        const AdguardHomeShell(instance: adguardHomeTestInstance),
        status: status,
        log: log,
        clientsError: clientsError,
        size: const Size(360, 900),
      );

  /// The destination of the bottom bar named [label].
  Finder destination(String label) => find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      );

  int selected(WidgetTester tester) =>
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

  Future<void> openLog(WidgetTester tester) async {
    await tester.tap(destination('Query log'));
    await tester.pump();
    await tester.pump();
  }

  Future<void> openClients(WidgetTester tester) async {
    await tester.tap(destination('Clients'));
    await tester.pump();
    await tester.pump();
  }

  final Finder addClient =
      find.widgetWithText(FloatingActionButton, 'Add client');

  testWidgets('opens on Home, with Home, Query log and Clients in the bar',
      (WidgetTester tester) async {
    await pumpShell(tester);

    expect(destination('Home'), findsOneWidget);
    expect(destination('Query log'), findsOneWidget);
    expect(destination('Clients'), findsOneWidget);
    expect(selected(tester), 0);
    expect(find.text('Protection is on'), findsOneWidget);
  });

  group('the clients', () {
    testWidgets('are not asked for until their tab is opened',
        (WidgetTester tester) async {
      // Three requests nobody is waiting for, otherwise.
      final Pumped pumped = await pumpShell(tester);
      await openLog(tester);
      expect(pumped.clientReads, 0);

      await openClients(tester);

      expect(pumped.clientReads, 1);
      expect(selected(tester), 2);
      expect(find.text('Persistent (3)'), findsOneWidget);
    });

    testWidgets('keep their place while another tab is shown',
        (WidgetTester tester) async {
      final Pumped pumped = await pumpShell(tester);
      await openClients(tester);

      await tester.tap(destination('Home'));
      await tester.pump();
      await openClients(tester);

      expect(pumped.clientReads, 1);
      expect(
        find.byType(AdguardHomeClientsTab, skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('can be added to from their tab, and from no other',
        (WidgetTester tester) async {
      await pumpShell(tester);
      expect(addClient, findsNothing);
      await openLog(tester);
      expect(addClient, findsNothing);

      await openClients(tester);

      expect(addClient, findsOneWidget);
    });

    testWidgets('the add button opens the form for a new client, with the '
        'tags the server offers', (WidgetTester tester) async {
      await pumpShell(tester);
      await openClients(tester);
      // The button grows in, and cannot be tapped until it has.
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(addClient);
      await tester.pumpAndSettle();

      expect(find.text('New client'), findsOneWidget);
      expect(
        tester
            .widget<AdguardHomeClientScreen>(
              find.byType(AdguardHomeClientScreen),
            )
            .supportedTags,
        hasLength(21),
      );
    });

    testWidgets('cannot be added to while they cannot be read',
        (WidgetTester tester) async {
      // There would be no tags to offer, and after a refused sign-in
      // nothing could be saved.
      await pumpShell(tester, clientsError: const AdguardHomeSignInRefused());
      await openClients(tester);

      expect(find.byType(AdguardHomeRefusedView), findsOneWidget);
      expect(addClient, findsNothing);
    });

    testWidgets('back on their tab goes to Home before it leaves',
        (WidgetTester tester) async {
      await pumpShell(tester);
      await openClients(tester);

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(selected(tester), 0);
      expect(find.text('Protection is on'), findsOneWidget);
    });

    testWidgets('have no menu for the query log over them',
        (WidgetTester tester) async {
      await pumpShell(tester);
      await openClients(tester);

      expect(find.byTooltip('More'), findsNothing);
    });
  });

  testWidgets('the query log is not asked for until its tab is opened',
      (WidgetTester tester) async {
    // Opening the service must not cost a scan of the log nobody looks at.
    final Pumped pumped = await pumpShell(tester);
    expect(pumped.logWatched, isFalse);

    await openLog(tester);

    expect(pumped.logWatched, isTrue);
    expect(selected(tester), 1);
    expect(find.text('example.org'), findsOneWidget);
  });

  testWidgets('the query log keeps its place while Home is shown',
      (WidgetTester tester) async {
    await pumpShell(tester);
    await openLog(tester);

    await tester.tap(destination('Home'));
    await tester.pump();

    expect(selected(tester), 0);
    expect(
      find.byType(AdguardHomeQueryLogTab, skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('back on the query log goes to Home before it leaves',
      (WidgetTester tester) async {
    await pumpShell(tester);
    await openLog(tester);

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(selected(tester), 0);
    expect(find.text('Protection is on'), findsOneWidget);
  });

  group('clearing the log', () {
    testWidgets('is offered on the Query log tab only',
        (WidgetTester tester) async {
      await pumpShell(tester);
      expect(find.byTooltip('More'), findsNothing);

      await openLog(tester);

      expect(find.byTooltip('More'), findsOneWidget);
    });

    testWidgets('asks first, and Cancel clears nothing',
        (WidgetTester tester) async {
      final Pumped pumped = await pumpShell(tester);
      await openLog(tester);

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear query log'));
      await tester.pumpAndSettle();

      expect(find.text('Clear the query log?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(pumped.actions.calls, isEmpty);
      expect(pumped.log.calls, isEmpty);
    });

    testWidgets('once confirmed it clears, says so and reads the log again',
        (WidgetTester tester) async {
      final Pumped pumped = await pumpShell(tester);
      await openLog(tester);

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear query log'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
      await tester.pumpAndSettle();

      expect(pumped.actions.calls, <String>['clear log']);
      expect(pumped.log.calls, <String>['reload']);
      expect(find.text('Query log cleared'), findsOneWidget);
    });

    testWidgets('a clear the server turns down says why and reads nothing',
        (WidgetTester tester) async {
      final Pumped pumped = await pumpShell(tester);
      await openLog(tester);
      pumped.actions.writeFailure = const AdguardHomeRequestRefused('not now');

      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear query log'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
      await tester.pumpAndSettle();

      expect(find.text('not now'), findsOneWidget);
      expect(pumped.log.calls, isEmpty);
    });
  });
}
