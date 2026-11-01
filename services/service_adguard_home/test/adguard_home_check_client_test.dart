import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

import 'support/adguard_home_test_instance.dart';
import 'support/pump.dart';

AdguardHomeClient client(List<String> ids) =>
    AdguardHomeClient(<String, dynamic>{'name': 'A', 'ids': ids});

void main() {
  group('the address a client is checked as', () {
    test('is the first address it lists', () {
      expect(
        adguardHomeCheckAddressOf(
          client(<String>['aa:bb:cc:dd:ee:01', '10.0.0.0/8', '192.168.1.5']),
        ),
        '192.168.1.5',
      );
      expect(adguardHomeCheckAddressOf(client(<String>['fd00::5'])), 'fd00::5');
    });

    test('else the first in its range, past the network address', () {
      expect(
        adguardHomeCheckAddressOf(client(<String>['192.168.50.0/28'])),
        '192.168.50.1',
      );
      // Written with host bits set, as the server allows.
      expect(
        adguardHomeCheckAddressOf(client(<String>['192.168.50.7/24'])),
        '192.168.50.1',
      );
      expect(
        adguardHomeCheckAddressOf(client(<String>['10.1.2.3/32'])),
        '10.1.2.3',
      );
      expect(
        adguardHomeCheckAddressOf(client(<String>['0.0.0.0/0'])),
        '0.0.0.1',
      );
    });

    test('is none for a client known only otherwise', () {
      expect(
        adguardHomeCheckAddressOf(
          client(<String>['aa:bb:cc:dd:ee:01', 'work-phone', 'fd00::/64']),
        ),
        isNull,
      );
    });
  });

  group('Check a host', () {
    Future<Pumped> open(WidgetTester tester) async {
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
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      return pumped;
    }

    Future<void> pick(WidgetTester tester, String label) async {
      await tester.tap(find.text('Checked for'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    testWidgets('checks for any client at first', (WidgetTester tester) async {
      final Pumped pumped = await open(tester);

      expect(find.text('Any client'), findsOneWidget);
      expect(pumped.actions.calls, <String>['check a.example']);
    });

    testWidgets('checks again for a client picked by its address',
        (WidgetTester tester) async {
      final Pumped pumped = await open(tester);

      await pick(tester, 'Kids tablet');

      expect(find.text('Kids tablet (192.168.50.1)'), findsOneWidget);
      expect(pumped.actions.calls, <String>[
        'check a.example',
        'check a.example for 192.168.50.1',
      ]);

      await pick(tester, 'Any client');
      expect(pumped.actions.calls.last, 'check a.example');
    });

    testWidgets('lists runtime clients, and cannot pick one with no address',
        (WidgetTester tester) async {
      final Pumped pumped = await open(tester);

      await tester.tap(find.text('Checked for'));
      await tester.pumpAndSettle();

      final ListTile phone = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('Work phone'),
          matching: find.byType(ListTile),
        ),
      );
      expect(phone.enabled, isFalse);
      expect(find.text('203.0.113.9'), findsOneWidget);

      await tester.tap(find.text('Work phone'));
      await tester.pumpAndSettle();
      expect(pumped.actions.calls, <String>['check a.example']);
    });

    testWidgets('checks for a typed address, and not for something else',
        (WidgetTester tester) async {
      final Pumped pumped = await open(tester);
      await tester.tap(find.text('Checked for'));
      await tester.pumpAndSettle();
      final Finder field = find.byKey(const Key('adguard-check-address'));

      await tester.enterText(field, 'not an address');
      await tester.tap(find.byTooltip('Check for this address'));
      await tester.pumpAndSettle();
      expect(find.text('An IP address, such as 192.168.1.20.'), findsOneWidget);
      expect(pumped.actions.calls, <String>['check a.example']);

      await tester.enterText(field, ' 10.0.0.42 ');
      await tester.tap(find.byTooltip('Check for this address'));
      await tester.pumpAndSettle();

      expect(find.text('10.0.0.42'), findsOneWidget);
      expect(pumped.actions.calls.last, 'check a.example for 10.0.0.42');
    });
  });
}
