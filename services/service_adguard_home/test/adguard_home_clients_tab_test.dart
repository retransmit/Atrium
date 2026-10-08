import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

import 'support/adguard_home_clients_fixtures.dart';
import 'support/adguard_home_test_instance.dart';
import 'support/pump.dart';

void main() {
  const Widget tab = AdguardHomeClientsTab(instance: adguardHomeTestInstance);

  Future<void> showRuntime(WidgetTester tester) async {
    await tester.tap(find.textContaining('Runtime'));
    await tester.pumpAndSettle();
  }

  /// The row of the list that shows [text].
  Finder rowOf(String text, Type row) =>
      find.ancestor(of: find.text(text), matching: find.byType(row));

  bool inRow(String rowText, Type row, String text) => find
      .descendant(of: rowOf(rowText, row), matching: find.text(text))
      .evaluate()
      .isNotEmpty;

  group('persistent clients', () {
    testWidgets('are listed with the most queries first',
        (WidgetTester tester) async {
      await pumpAdguardHome(tester, tab);

      final double laptop = tester.getTopLeft(find.text('Laptop')).dy;
      final double work = tester.getTopLeft(find.text('Work phone')).dy;
      final double kids = tester.getTopLeft(find.text('Kids tablet')).dy;
      expect(laptop, lessThan(work));
      expect(work, lessThan(kids));
    });

    testWidgets('show what they go by and how much they asked',
        (WidgetTester tester) async {
      await pumpAdguardHome(tester, tab);

      const Type row = AdguardHomePersistentClientRow;
      expect(inRow('Laptop', row, '172.17.0.1'), isTrue);
      expect(inRow('Laptop', row, '150'), isTrue);
      expect(
        inRow('Kids tablet', row, '192.168.50.0/28, aa:bb:cc:dd:ee:01'),
        isTrue,
      );
      expect(inRow('Work phone', row, '7'), isTrue);
      // The statistics say nothing of this one.
      expect(
        find.descendant(
          of: rowOf('Kids tablet', row),
          matching: find.text('queries'),
        ),
        findsNothing,
      );
    });

    testWidgets('are marked with their tags and with what is their own',
        (WidgetTester tester) async {
      await pumpAdguardHome(tester, tab);

      const Type row = AdguardHomePersistentClientRow;
      expect(inRow('Kids tablet', row, 'device_tablet'), isTrue);
      expect(inRow('Kids tablet', row, 'user_child'), isTrue);
      expect(inRow('Kids tablet', row, 'Own settings'), isTrue);
      expect(inRow('Kids tablet', row, '3 services blocked'), isTrue);
      expect(inRow('Kids tablet', row, 'Own upstreams'), isFalse);

      expect(inRow('Work phone', row, 'Own upstreams'), isTrue);
      expect(inRow('Work phone', row, 'Not in the query log'), isTrue);
      expect(inRow('Work phone', row, 'Own settings'), isFalse);

      expect(inRow('Laptop', row, 'device_laptop'), isTrue);
      expect(inRow('Laptop', row, 'Own settings'), isFalse);
      expect(inRow('Laptop', row, 'No services blocked'), isFalse);
    });

    testWidgets('a client with its own, empty list of services says so',
        (WidgetTester tester) async {
      // It is exempt from the services the server blocks for everyone.
      await pumpAdguardHome(
        tester,
        tab,
        clients: AdguardHomeClientsView.build(
          list: AdguardHomeClientList.fromJson(<String, dynamic>{
            'clients': <dynamic>[
              <String, dynamic>{
                'name': 'Exempt',
                'ids': <dynamic>['10.0.0.9'],
                'use_global_settings': true,
                'use_global_blocked_services': false,
                'ignore_statistics': true,
              },
            ],
          }),
        ),
      );

      const Type row = AdguardHomePersistentClientRow;
      expect(inRow('Exempt', row, 'No services blocked'), isTrue);
      expect(inRow('Exempt', row, 'Not in statistics'), isTrue);
    });

    testWidgets('a row opens the form for its client',
        (WidgetTester tester) async {
      await pumpAdguardHome(tester, tab);

      await tester.tap(find.text('Work phone'));
      await tester.pumpAndSettle();

      expect(find.text('Edit client'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('adguard-client-name')))
            .controller!
            .text,
        'Work phone',
      );
      // With the tags the server offers.
      expect(find.byType(FilterChip), findsNWidgets(21));
    });

    testWidgets('when there are none, says so', (WidgetTester tester) async {
      await pumpAdguardHome(
        tester,
        tab,
        clients: const AdguardHomeClientsView(),
      );

      expect(find.text('No persistent clients'), findsOneWidget);
    });
  });

  testWidgets('the two lists say how many each holds',
      (WidgetTester tester) async {
    await pumpAdguardHome(tester, tab);

    expect(find.text('Persistent (3)'), findsOneWidget);
    expect(find.text('Runtime (9)'), findsOneWidget);
  });

  group('runtime clients', () {
    const Type row = AdguardHomeRuntimeClientRow;

    testWidgets('are shown when asked for, the busiest first',
        (WidgetTester tester) async {
      await pumpAdguardHome(tester, tab);
      expect(find.byType(AdguardHomeRuntimeClientRow), findsNothing);

      await showRuntime(tester);

      expect(find.byType(AdguardHomeRuntimeClientRow), findsNWidgets(9));
      expect(find.byType(AdguardHomePersistentClientRow), findsNothing);
      expect(
        tester.getTopLeft(find.text('172.17.0.1')).dy,
        lessThan(tester.getTopLeft(find.text('127.0.0.1')).dy),
      );
    });

    testWidgets('show a name where the server has one, the address, and '
        'where it was learned', (WidgetTester tester) async {
      await pumpAdguardHome(tester, tab);
      await showRuntime(tester);

      // Two addresses are called localhost.
      expect(find.text('localhost'), findsNWidgets(2));
      expect(find.text('127.0.0.1'), findsOneWidget);
      expect(inRow('127.0.0.1', row, 'Hosts file'), isTrue);
      expect(inRow('127.0.0.1', row, '122'), isTrue);
      // With no name, the address is what it is called.
      expect(inRow('172.17.0.1', row, 'ARP table'), isTrue);
      expect(inRow('172.17.0.1', row, '150'), isTrue);
    });

    testWidgets('one that belongs to a persistent client says whose it is',
        (WidgetTester tester) async {
      await pumpAdguardHome(tester, tab);
      await showRuntime(tester);

      expect(inRow('172.17.0.1', row, 'Laptop'), isTrue);
      expect(inRow('127.0.0.1', row, 'Laptop'), isFalse);
    });

    testWidgets('one with WHOIS says who the address belongs to',
        (WidgetTester tester) async {
      await pumpAdguardHome(tester, tab);
      await showRuntime(tester);

      expect(
        inRow('203.0.113.9', row, 'Example Networks, DE, Berlin'),
        isTrue,
      );
    });

    testWidgets('when there are none, says so', (WidgetTester tester) async {
      await pumpAdguardHome(
        tester,
        tab,
        clients: const AdguardHomeClientsView(),
      );
      await showRuntime(tester);

      expect(find.text('No runtime clients'), findsOneWidget);
    });

    testWidgets('a row opens what the server knows of it, without asking '
        'again', (WidgetTester tester) async {
      final Pumped pumped = await pumpAdguardHome(tester, tab);
      await showRuntime(tester);

      await tester.tap(find.text('127.0.0.1'));
      await tester.pumpAndSettle();

      expect(find.byType(AdguardHomeClientSheet), findsOneWidget);
      expect(find.text('Add as persistent client'), findsOneWidget);
      // Everything it shows was in the list already.
      expect(pumped.actions.calls, isEmpty);
    });

    testWidgets('a row of a persistent client\'s address offers to edit that '
        'client', (WidgetTester tester) async {
      await pumpAdguardHome(tester, tab);
      await showRuntime(tester);

      await tester.tap(find.text('172.17.0.1'));
      await tester.pumpAndSettle();

      expect(find.text('Add as persistent client'), findsNothing);
      await tester.tap(find.text('Edit client'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(find.byKey(const Key('adguard-client-name')))
            .controller!
            .text,
        'Laptop',
      );
    });
  });

  group('when the clients cannot be read', () {
    testWidgets('a refused sign-in is said as on every tab, and Try again '
        'asks once', (WidgetTester tester) async {
      final Pumped pumped = await pumpAdguardHome(
        tester,
        tab,
        clientsError: const AdguardHomeSignInRefused(),
      );

      expect(find.byType(AdguardHomeRefusedView), findsOneWidget);
      expect(find.textContaining('Persistent'), findsNothing);

      await tester.tap(find.text('Try again'));
      await tester.pump();

      expect(pumped.actions.calls, <String>['retry']);
    });

    testWidgets('says how many times in a row the sign-in was refused',
        (WidgetTester tester) async {
      await pumpAdguardHome(
        tester,
        tab,
        clientsError: const AdguardHomeSignInRefused(),
        session: RefusedSession(3),
      );

      expect(
        find.text('Refused 3 times in a row from this app.'),
        findsOneWidget,
      );
    });

    testWidgets('another failure says what went wrong, and Retry reads again',
        (WidgetTester tester) async {
      final Pumped pumped = await pumpAdguardHome(
        tester,
        tab,
        clientsError: const AdguardHomeUnexpectedAnswer(),
      );

      expect(
        find.text('This address answered, but not as AdGuard Home.'),
        findsOneWidget,
      );
      expect(pumped.clientReads, 1);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();

      expect(pumped.clientReads, 2);
    });
  });

  for (final double width in <double>[320, 360, 411]) {
    for (final double scale in <double>[1, 1.3, 2]) {
      testWidgets('layout holds at $width wide and $scale text',
          (WidgetTester tester) async {
        await pumpAdguardHome(
          tester,
          tab,
          size: Size(width, 4000),
          textScale: scale,
        );
        expect(tester.takeException(), isNull);

        await showRuntime(tester);
        expect(tester.takeException(), isNull);
        expect(find.byType(AdguardHomeRuntimeClientRow), findsNWidgets(9));
      });
    }
  }

  group('the sheet of one client', () {
    final AdguardHomeClientList list =
        AdguardHomeClientList.fromJson(clientListJson());

    /// Opens the sheet for [address] from a screen with a button.
    Future<Pumped> openSheet(
      WidgetTester tester,
      String address, {
      AdguardHomeClientLookup? lookup,
      AdguardHomeClientLookup? found,
      Object? failure,
      Completer<void>? hold,
      int? queries,
      Size size = const Size(360, 2400),
      double textScale = 1,
    }) async {
      final Pumped pumped = await pumpAdguardHome(
        tester,
        Builder(
          builder: (BuildContext context) => Center(
            child: TextButton(
              onPressed: () => showAdguardHomeClientSheet(
                context,
                instance: adguardHomeTestInstance,
                address: address,
                lookup: lookup,
                queries: queries,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
        size: size,
        textScale: textScale,
      );
      pumped.actions
        ..lookup = found
        ..lookupFailure = failure
        ..lookupHold = hold;
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      return pumped;
    }

    AdguardHomeClientLookup lookupOf(String address, {int? queries}) =>
        AdguardHomeClientLookup.of(
          address: address,
          list: list,
          queries: queries,
        );

    testWidgets('looks the address up when it is opened for one',
        (WidgetTester tester) async {
      final Completer<void> hold = Completer<void>();
      final Pumped pumped = await openSheet(
        tester,
        '127.0.0.1',
        found: lookupOf('127.0.0.1', queries: 122),
        hold: hold,
        queries: 122,
      );

      // Something to look at while the server answers.
      expect(find.byType(ExpressiveProgressIndicator), findsOneWidget);
      expect(find.text('127.0.0.1'), findsOneWidget);
      expect(pumped.actions.calls, <String>['find 127.0.0.1']);

      hold.complete();
      await tester.pumpAndSettle();

      expect(find.byType(ExpressiveProgressIndicator), findsNothing);
      expect(find.text('localhost'), findsWidgets);
      expect(find.text('Hosts file'), findsOneWidget);
      expect(find.text('122'), findsOneWidget);
      expect(find.text('Add as persistent client'), findsOneWidget);
    });

    testWidgets('says why when the lookup fails, and asks again on Retry',
        (WidgetTester tester) async {
      final Pumped pumped = await openSheet(
        tester,
        '127.0.0.1',
        failure: const AdguardHomeUnexpectedAnswer(),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('This address answered, but not as AdGuard Home.'),
        findsOneWidget,
      );
      expect(find.text('Add as persistent client'), findsNothing);

      pumped.actions
        ..lookupFailure = null
        ..lookup = lookupOf('127.0.0.1');
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(pumped.actions.calls, <String>['find 127.0.0.1', 'find 127.0.0.1']);
      expect(find.text('Add as persistent client'), findsOneWidget);
    });

    testWidgets('of a persistent client shows its settings in short',
        (WidgetTester tester) async {
      await openSheet(
        tester,
        '192.168.50.3',
        lookup: AdguardHomeClientLookup.of(
          address: '192.168.50.3',
          list: list,
          found: AdguardHomeFoundClient.mapFromJson(clientSearchJson())
              ['192.168.50.3'],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kids tablet'), findsOneWidget);
      expect(find.text('192.168.50.3'), findsOneWidget);
      expect(find.text('192.168.50.0/28\naa:bb:cc:dd:ee:01'), findsOneWidget);
      expect(find.text('device_tablet, user_child'), findsOneWidget);
      expect(find.text('Its own'), findsOneWidget);
      expect(find.text('3 services blocked'), findsOneWidget);
      expect(find.text('Edit client'), findsOneWidget);
    });

    testWidgets('of an address nobody knows says so and offers to add it',
        (WidgetTester tester) async {
      await openSheet(tester, '10.9.9.9', lookup: lookupOf('10.9.9.9'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('AdGuard Home has no settings for it'),
        findsOneWidget,
      );

      await tester.tap(find.text('Add as persistent client'));
      await tester.pumpAndSettle();

      expect(find.text('New client'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('adguard-client-id-0')))
            .controller!
            .text,
        '10.9.9.9',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('adguard-client-name')))
            .controller!
            .text,
        isEmpty,
      );
    });

    testWidgets('of a runtime client fills the form with its name and '
        'address', (WidgetTester tester) async {
      await openSheet(tester, '127.0.0.1', lookup: lookupOf('127.0.0.1'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add as persistent client'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(find.byKey(const Key('adguard-client-name')))
            .controller!
            .text,
        'localhost',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('adguard-client-id-0')))
            .controller!
            .text,
        '127.0.0.1',
      );
    });

    testWidgets('closes once the client was saved: what it said is no longer '
        'so', (WidgetTester tester) async {
      final Pumped pumped =
          await openSheet(tester, '127.0.0.1', lookup: lookupOf('127.0.0.1'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add as persistent client'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(pumped.actions.saved, hasLength(1));
      expect(find.byType(AdguardHomeClientSheet), findsNothing);
      expect(find.text('Open'), findsOneWidget);
    });

    testWidgets('stays when the form was left without saving',
        (WidgetTester tester) async {
      await openSheet(tester, '127.0.0.1', lookup: lookupOf('127.0.0.1'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add as persistent client'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(AdguardHomeClientSheet), findsOneWidget);
    });

    for (final double width in <double>[320, 360, 411]) {
      for (final double scale in <double>[1, 2]) {
        testWidgets('layout holds at $width wide and $scale text',
            (WidgetTester tester) async {
          await openSheet(
            tester,
            '192.168.50.3',
            lookup: AdguardHomeClientLookup(
              address: '192.168.50.3',
              persistent: list.persistent.first,
              runtime: const AdguardHomeRuntimeClient(
                address: '192.168.50.3',
                name: 'a-rather-long-host-name.lan.example',
                source: 'DHCP',
                whois: <String, String>{'orgname': 'Example Networks'},
              ),
              queries: 123456,
            ),
            size: Size(width, 900),
            textScale: scale,
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('Edit client'), findsOneWidget);
        });
      }
    }
  });
}
