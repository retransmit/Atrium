import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

import 'support/adguard_home_fixtures.dart';
import 'support/adguard_home_settings_fixtures.dart';
import 'support/adguard_home_test_instance.dart';
import 'support/pump.dart';

void main() {
  final AdguardHomeStatus status =
      AdguardHomeStatus.fromJson(statusJson(), readAt: DateTime(2026, 10, 20));

  Future<Pumped> pump(
    WidgetTester tester,
    Widget screen, {
    AdguardHomeTlsStatus? tls,
    AdguardHomeDhcpStatus? dhcp,
    Object? settingsError,
    Size size = const Size(360, 2000),
    double textScale = 1,
  }) async {
    final Pumped pumped = await pumpAdguardHome(
      tester,
      screen,
      status: status,
      tls: tls,
      dhcp: dhcp,
      settingsError: settingsError,
      size: size,
      textScale: textScale,
    );
    await tester.pumpAndSettle();
    return pumped;
  }

  const AdguardHomeEncryptionScreen encryption =
      AdguardHomeEncryptionScreen(instance: adguardHomeTestInstance);
  const AdguardHomeDhcpScreen dhcpScreen =
      AdguardHomeDhcpScreen(instance: adguardHomeTestInstance);
  const AdguardHomeAboutScreen about =
      AdguardHomeAboutScreen(instance: adguardHomeTestInstance);

  group('encryption', () {
    testWidgets('off, says so and where it is set up',
        (WidgetTester tester) async {
      await pump(tester, encryption);

      expect(find.text('Encryption is off'), findsOneWidget);
      expect(find.text('Certificate'), findsNothing);
    });

    testWidgets('on, shows the ports and the certificate, never its text',
        (WidgetTester tester) async {
      await pump(
        tester,
        encryption,
        tls: AdguardHomeTlsStatus.fromJson(tlsOnJson()),
      );

      expect(find.text('Encryption is on'), findsOneWidget);
      expect(find.text('dns.home.example'), findsWidgets);
      expect(find.text('853'), findsNWidgets(2));
      expect(find.text('DNSCrypt port'), findsNothing);
      expect(find.text('Valid, ECDSA'), findsOneWidget);
      expect(find.textContaining('LS0t'), findsNothing);
    });

    testWidgets('an expired certificate says so', (WidgetTester tester) async {
      await pump(
        tester,
        encryption,
        tls: AdguardHomeTlsStatus.fromJson(<String, dynamic>{
          ...tlsOnJson(),
          'not_after': '2020-01-01T00:00:00Z',
        }),
      );

      expect(find.textContaining('expired'), findsOneWidget);
    });
  });

  group('DHCP', () {
    testWidgets('off, says so', (WidgetTester tester) async {
      await pump(tester, dhcpScreen);

      expect(find.text('DHCP is off on this server'), findsOneWidget);
      expect(find.text('IPv4'), findsNothing);
    });

    testWidgets('on, shows the range and both kinds of lease',
        (WidgetTester tester) async {
      await pump(
        tester,
        dhcpScreen,
        dhcp: AdguardHomeDhcpStatus.fromJson(dhcpOnJson()),
      );

      expect(find.text('Handing out addresses'), findsOneWidget);
      expect(find.text('192.168.1.100 to 192.168.1.200'), findsOneWidget);
      expect(find.text('24 hours'), findsOneWidget);
      expect(find.text('Leases (1)'), findsOneWidget);
      expect(find.text('kitchen-speaker'), findsOneWidget);
      expect(find.text('Static leases (1)'), findsOneWidget);
      expect(find.text('nas'), findsOneWidget);
    });
  });

  testWidgets('a lease time of no whole hours shows in minutes',
      (WidgetTester tester) async {
    await pump(
      tester,
      dhcpScreen,
      dhcp: AdguardHomeDhcpStatus.fromJson(<String, dynamic>{
        ...dhcpOnJson(),
        'v4': <String, dynamic>{
          ...(dhcpOnJson()['v4'] as Map<String, dynamic>),
          'lease_duration': 5400,
        },
      }),
    );

    expect(find.text('90 minutes'), findsOneWidget);
  });

  testWidgets('where DHCP cannot run, says so and does not ask about it',
      (WidgetTester tester) async {
    final Pumped pumped = await pumpAdguardHome(
      tester,
      dhcpScreen,
      status: AdguardHomeStatus.fromJson(
        <String, dynamic>{...statusJson(), 'dhcp_available': false},
        readAt: DateTime(2026, 10, 20),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DHCP is not available on this server'), findsOneWidget);
    expect(pumped.settingsReads, 0);
  });

  test('a status that says nothing of DHCP takes it as available', () {
    expect(
      AdguardHomeStatus.fromJson(
        <String, dynamic>{...statusJson()}..remove('dhcp_available'),
        readAt: DateTime(2026),
      ).dhcpAvailable,
      isTrue,
    );
    expect(status.dhcpAvailable, isTrue);
  });

  group('about', () {
    testWidgets('shows the version and the addresses, and checks nothing '
        'unasked', (WidgetTester tester) async {
      final Pumped pumped = await pump(tester, about);

      expect(find.text('v0.107.79'), findsOneWidget);
      expect(find.textContaining('172.17.0.4'), findsOneWidget);
      expect(pumped.actions.calls, isEmpty);
    });

    testWidgets('a check with the server\'s checks off says so',
        (WidgetTester tester) async {
      final Pumped pumped = await pump(tester, about);

      await tester.tap(find.text('Check for updates'));
      await tester.pumpAndSettle();

      expect(pumped.actions.calls, <String>['version now']);
      expect(
        find.text('Update checks are off on this server.'),
        findsOneWidget,
      );
    });

    testWidgets('a newer version is named, with where to read of it',
        (WidgetTester tester) async {
      final Pumped pumped = await pump(tester, about);
      pumped.actions.versionCheck =
          AdguardHomeVersionCheck.fromJson(versionNewJson());

      await tester.tap(find.text('Check for updates'));
      await tester.pumpAndSettle();

      expect(find.text('AdGuard Home v0.107.80 is out.'), findsOneWidget);
      expect(find.text("What's new"), findsOneWidget);
    });

    testWidgets('the same version is the latest', (WidgetTester tester) async {
      final Pumped pumped = await pump(tester, about);
      pumped.actions.versionCheck =
          const AdguardHomeVersionCheck(newVersion: 'v0.107.79');

      await tester.tap(find.text('Check for updates'));
      await tester.pumpAndSettle();

      expect(find.text('This is the latest version.'), findsOneWidget);
    });

    testWidgets('a check refused for the sign-in is tried again on the '
        'button', (WidgetTester tester) async {
      final Pumped pumped = await pump(tester, about);
      pumped.actions.lookupFailure = const AdguardHomeSignInRefused();

      await tester.tap(find.text('Check for updates'));
      await tester.pumpAndSettle();
      expect(find.text('AdGuard Home refused the sign-in.'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(
        pumped.actions.calls,
        <String>['version now', 'retry', 'version now'],
      );
      expect(
        find.text('Update checks are off on this server.'),
        findsOneWidget,
      );
    });

    testWidgets('a check that fails says why', (WidgetTester tester) async {
      final Pumped pumped = await pump(tester, about);
      pumped.actions.lookupFailure = const AdguardHomeRequestRefused('nope');

      await tester.tap(find.text('Check for updates'));
      await tester.pumpAndSettle();

      expect(find.text('nope'), findsOneWidget);
    });
  });

  testWidgets('a refused sign-in shows Try again on a status page',
      (WidgetTester tester) async {
    await pump(
      tester,
      encryption,
      settingsError: const AdguardHomeSignInRefused(),
    );

    expect(find.text('Try again'), findsOneWidget);
  });

  for (final double width in <double>[320, 411]) {
    testWidgets('layout holds at $width wide and twice the text',
        (WidgetTester tester) async {
      await pump(
        tester,
        encryption,
        tls: AdguardHomeTlsStatus.fromJson(tlsOnJson()),
        size: Size(width, 3000),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
