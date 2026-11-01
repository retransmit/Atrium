import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

import 'support/adguard_home_filters_fixtures.dart';
import 'support/adguard_home_fixtures.dart';
import 'support/adguard_home_test_instance.dart';
import 'support/pump.dart';

void main() {
  const Widget tab = AdguardHomeSettingsTab(instance: adguardHomeTestInstance);

  Future<Pumped> pumpTab(
    WidgetTester tester, {
    bool filteringOn = true,
    Size size = const Size(360, 2000),
    double textScale = 1,
  }) async {
    final Pumped pumped = await pumpAdguardHome(
      tester,
      tab,
      status:
          AdguardHomeStatus.fromJson(statusJson(), readAt: DateTime(2026)),
      filtering: AdguardHomeFiltering.fromJson(
        <String, dynamic>{...filterStatusJson(), 'enabled': filteringOn},
      ),
      size: size,
      textScale: textScale,
    );
    await tester.pumpAndSettle();
    return pumped;
  }

  testWidgets('lists every section under its heading, reading nothing',
      (WidgetTester tester) async {
    final Pumped pumped = await pumpTab(tester);

    for (final String title in <String>[
      'Protection',
      'General',
      'Logs',
      'Query log',
      'Statistics',
      'DNS',
      'Upstreams',
      'DNS server',
      'DNS cache',
      'Access',
      'Server',
      'Encryption',
      'DHCP',
      'About',
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
    expect(find.text('Version v0.107.79'), findsOneWidget);
    expect(pumped.settingsReads, 0);
  });

  testWidgets('says when filtering is off', (WidgetTester tester) async {
    await pumpTab(tester, filteringOn: false);

    expect(find.text('Filtering off'), findsOneWidget);
  });

  testWidgets('each section opens its screen', (WidgetTester tester) async {
    await pumpTab(tester);
    final Map<String, Type> screens = <String, Type>{
      'General': AdguardHomeGeneralSettingsScreen,
      'Query log': AdguardHomeRetentionScreen,
      'Statistics': AdguardHomeRetentionScreen,
      'Upstreams': AdguardHomeDnsUpstreamsScreen,
      'DNS server': AdguardHomeDnsServerScreen,
      'DNS cache': AdguardHomeDnsCacheScreen,
      'Access': AdguardHomeAccessScreen,
      'Encryption': AdguardHomeEncryptionScreen,
      'DHCP': AdguardHomeDhcpScreen,
      'About': AdguardHomeAboutScreen,
    };
    for (final MapEntry<String, Type> section in screens.entries) {
      await tester.tap(
        find.ancestor(
          of: find.text(section.key),
          matching: find.byType(ListTile),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(section.value), findsOneWidget, reason: section.key);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  for (final double width in <double>[320, 411]) {
    for (final double scale in <double>[1, 2]) {
      testWidgets('layout holds at $width wide and $scale text',
          (WidgetTester tester) async {
        await pumpTab(tester, size: Size(width, 3000), textScale: scale);

        expect(tester.takeException(), isNull);
      });
    }
  }
}
