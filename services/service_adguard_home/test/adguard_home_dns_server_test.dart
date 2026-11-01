import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

import 'support/adguard_home_settings_fixtures.dart';
import 'support/adguard_home_test_instance.dart';
import 'support/pump.dart';

void main() {
  final Finder save = find.widgetWithText(FilledButton, 'Save');
  Finder field(String key) => find.byKey(Key('adguard-dns-$key'));

  Future<Pumped> open(
    WidgetTester tester, {
    Size size = const Size(360, 3600),
    double textScale = 1,
  }) async {
    final Pumped pumped = await pumpAdguardHome(
      tester,
      Builder(
        builder: (BuildContext context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext _) => const AdguardHomeDnsServerScreen(
                instance: adguardHomeTestInstance,
              ),
            ),
          ),
          child: const Text('Open'),
        ),
      ),
      size: size,
      textScale: textScale,
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return pumped;
  }

  String text(WidgetTester tester, Finder finder) =>
      tester.widget<TextField>(finder).controller!.text;

  bool on(WidgetTester tester, String title) => tester
      .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, title))
      .value;

  testWidgets('opens as the server has it', (WidgetTester tester) async {
    await open(tester);

    expect(text(tester, field('ratelimit')), '20');
    expect(text(tester, field('subnet4')), '24');
    expect(text(tester, field('subnet6')), '56');
    expect(text(tester, field('ttl')), '10');
    expect(on(tester, 'DNSSEC'), isTrue);
    expect(on(tester, 'EDNS client subnet'), isFalse);
    expect(field('ipv4'), findsNothing);
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
  });

  testWidgets('saves only what was changed', (WidgetTester tester) async {
    final Pumped pumped = await open(tester);

    await tester.enterText(field('ratelimit'), '25');
    await tester.tap(find.text('DNSSEC'));
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(pumped.actions.savedDns.single, <String, dynamic>{
      'ratelimit': 25,
      'dnssec_enabled': false,
    });
    expect(find.text('DNS server settings saved'), findsOneWidget);
  });

  testWidgets('a number out of range says so and nothing is sent',
      (WidgetTester tester) async {
    final Pumped pumped = await open(tester);

    await tester.enterText(field('subnet4'), '33');
    await tester.pump();
    expect(find.text('From 0 to 32.'), findsOneWidget);

    await tester.enterText(field('ttl'), '');
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.text('Enter a number.'), findsOneWidget);
    expect(pumped.actions.calls, isEmpty);
  });

  testWidgets('the rate limit allowlist takes IP addresses, one a line',
      (WidgetTester tester) async {
    final Pumped pumped = await open(tester);
    final Finder allowlist =
        find.byKey(const Key('adguard-ratelimit-allowlist'));

    await tester.enterText(allowlist, '192.168.1.5\nnas.lan');
    await tester.pump();
    expect(find.text('"nas.lan" is not an IP address.'), findsOneWidget);

    await tester.enterText(allowlist, ' 192.168.1.5 \n\n::1');
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(pumped.actions.savedDns.single, <String, dynamic>{
      'ratelimit_whitelist': <String>['192.168.1.5', '::1'],
    });
  });

  testWidgets('a custom IP mode needs an address of each kind',
      (WidgetTester tester) async {
    final Pumped pumped = await open(tester);

    await tester.tap(find.text('Custom IP'));
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.text('An IPv4 address, such as 0.0.0.0.'), findsOneWidget);
    expect(find.text('An IPv6 address, such as ::.'), findsOneWidget);
    expect(pumped.actions.calls, isEmpty);

    await tester.enterText(field('ipv4'), '::1');
    await tester.pump();
    expect(find.text('An IPv4 address, such as 0.0.0.0.'), findsOneWidget);

    await tester.enterText(field('ipv4'), '10.0.0.1');
    await tester.enterText(field('ipv6'), 'fd00::1');
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(pumped.actions.savedDns.single, <String, dynamic>{
      'blocking_mode': 'custom_ip',
      'blocking_ipv4': '10.0.0.1',
      'blocking_ipv6': 'fd00::1',
    });
  });

  testWidgets('a custom EDNS address is asked for only with EDNS on',
      (WidgetTester tester) async {
    final Pumped pumped = await open(tester);

    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Use a custom IP for EDNS'),
          )
          .onChanged,
      isNull,
    );

    await tester.tap(find.text('EDNS client subnet'));
    await tester.pump();
    await tester.tap(find.text('Use a custom IP for EDNS'));
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('An IP address.'), findsOneWidget);

    await tester.enterText(field('ednsIp'), '203.0.113.0');
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(pumped.actions.savedDns.single, <String, dynamic>{
      'edns_cs_enabled': true,
      'edns_cs_use_custom': true,
      'edns_cs_custom_ip': '203.0.113.0',
    });
  });

  testWidgets('an address changed under Custom IP goes with the mode',
      (WidgetTester tester) async {
    final Pumped pumped = await pumpAdguardHome(
      tester,
      const AdguardHomeDnsServerScreen(instance: adguardHomeTestInstance),
      dnsConfig: AdguardHomeDnsConfig(<String, dynamic>{
        ...dnsInfoJson(),
        'blocking_mode': 'custom_ip',
        'blocking_ipv4': '10.0.0.1',
        'blocking_ipv6': 'fd00::1',
      }),
      size: const Size(360, 3600),
    );
    await tester.pumpAndSettle();

    await tester.enterText(field('ipv4'), '10.0.0.2');
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();

    // Sent alone, the server answers 200 and keeps the old address.
    expect(pumped.actions.savedDns.single, <String, dynamic>{
      'blocking_mode': 'custom_ip',
      'blocking_ipv4': '10.0.0.2',
      'blocking_ipv6': 'fd00::1',
    });
  });

  testWidgets('an address typed and then hidden is not sent',
      (WidgetTester tester) async {
    final Pumped pumped = await open(tester);

    await tester.tap(find.text('Custom IP'));
    await tester.pump();
    await tester.enterText(field('ipv4'), '1.2.3');
    await tester.pump();
    await tester.tap(find.text('Default'));
    await tester.pump();

    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tester.tap(find.text('DNSSEC'));
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(pumped.actions.savedDns.single, <String, dynamic>{
      'dnssec_enabled': false,
    });
  });

  for (final double width in <double>[320, 411]) {
    for (final double scale in <double>[1, 2]) {
      testWidgets('layout holds at $width wide and $scale text',
          (WidgetTester tester) async {
        await open(tester, size: Size(width, 5000), textScale: scale);
        await tester.tap(find.text('Custom IP'));
        await tester.pump();

        expect(tester.takeException(), isNull);
      });
    }
  }
}
