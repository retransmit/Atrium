import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

import 'support/adguard_home_settings_fixtures.dart';
import 'support/adguard_home_test_instance.dart';
import 'support/pump.dart';

void main() {
  final Finder save = find.widgetWithText(FilledButton, 'Save');
  final Finder upstreams = find.byKey(const Key('adguard-upstreams'));
  final Finder bootstrap = find.byKey(const Key('adguard-bootstrap'));
  final Finder timeout = find.byKey(const Key('adguard-upstream-timeout'));

  Future<Pumped> open(
    WidgetTester tester, {
    AdguardHomeDnsConfig? dns,
    Size size = const Size(360, 2600),
    double textScale = 1,
  }) async {
    final Pumped pumped = await pumpAdguardHome(
      tester,
      Builder(
        builder: (BuildContext context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext _) => const AdguardHomeDnsUpstreamsScreen(
                instance: adguardHomeTestInstance,
              ),
            ),
          ),
          child: const Text('Open'),
        ),
      ),
      dnsConfig: dns,
      size: size,
      textScale: textScale,
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return pumped;
  }

  String text(WidgetTester tester, Finder field) =>
      tester.widget<TextField>(field).controller!.text;

  testWidgets('opens with the servers as the server has them',
      (WidgetTester tester) async {
    await open(tester);

    expect(text(tester, upstreams), 'https://dns10.quad9.net/dns-query');
    expect(text(tester, bootstrap).split('\n'), hasLength(4));
    expect(text(tester, timeout), '10');
    expect(
      tester
          .widget<RadioGroup<AdguardHomeUpstreamMode>>(
            find.byType(RadioGroup<AdguardHomeUpstreamMode>),
          )
          .groupValue,
      AdguardHomeUpstreamMode.loadBalance,
    );
    expect(find.textContaining('192.168.65.7:53'), findsOneWidget);
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
  });

  testWidgets('saves only what was changed, and closes',
      (WidgetTester tester) async {
    final Pumped pumped = await open(tester);

    await tester.enterText(bootstrap, '9.9.9.10\n\n 1.1.1.1 \n');
    await tester.tap(find.text('Parallel requests'));
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(pumped.actions.savedDns.single, <String, dynamic>{
      'upstream_mode': 'parallel',
      'bootstrap_dns': <String>['9.9.9.10', '1.1.1.1'],
    });
    expect(find.byType(AdguardHomeDnsUpstreamsScreen), findsNothing);
    expect(find.text('Upstream settings saved'), findsOneWidget);
  });

  testWidgets('blank lines and spaces around a server are no change',
      (WidgetTester tester) async {
    await open(tester);

    await tester.enterText(
      upstreams,
      '  https://dns10.quad9.net/dns-query  \n\n',
    );
    await tester.pump();

    expect(tester.widget<FilledButton>(save).onPressed, isNull);
  });

  testWidgets('a timeout of nothing or 0 says so and is not sent',
      (WidgetTester tester) async {
    final Pumped pumped = await open(tester);

    await tester.enterText(timeout, '0');
    await tester.pump();
    expect(find.text('At least 1 second.'), findsOneWidget);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(pumped.actions.calls, isEmpty);

    await tester.enterText(timeout, '5');
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(pumped.actions.savedDns.single, <String, dynamic>{
      'upstream_timeout': 5,
    });
  });

  test('a draft of upstreams kept in a file has no list to send', () {
    final AdguardHomeUpstreamDraft draft = AdguardHomeUpstreamDraft.of(
      AdguardHomeDnsConfig(<String, dynamic>{
        ...dnsInfoJson(),
        'upstream_dns_file': '/opt/adguardhome/upstreams.txt',
      }),
    );

    expect(draft.toJson().containsKey('upstream_dns'), isFalse);
    expect(
      AdguardHomeUpstreamDraft.of(AdguardHomeDnsConfig(dnsInfoJson()))
          .toJson()['upstream_dns'],
      <String>['https://dns10.quad9.net/dns-query'],
    );
  });

  testWidgets('upstreams kept in a file are said, and never sent',
      (WidgetTester tester) async {
    final Pumped pumped = await open(
      tester,
      dns: AdguardHomeDnsConfig(<String, dynamic>{
        ...dnsInfoJson(),
        'upstream_dns_file': '/opt/adguardhome/upstreams.txt',
      }),
    );

    expect(find.textContaining('/opt/adguardhome/upstreams.txt'), findsOneWidget);
    expect(upstreams, findsNothing);

    await tester.tap(find.text('Fastest IP address'));
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(pumped.actions.savedDns.single, <String, dynamic>{
      'upstream_mode': 'fastest_addr',
    });
  });

  testWidgets('Test upstreams tries what is typed, unsaved, and lists '
      'each answer', (WidgetTester tester) async {
    final Pumped pumped = await open(tester);
    pumped.actions.upstreamResults = const <AdguardHomeUpstreamResult>[
      AdguardHomeUpstreamResult('1.1.1.1:53', 'OK'),
      AdguardHomeUpstreamResult('10.255.255.1:53', 'i/o timeout'),
    ];

    await tester.enterText(upstreams, '1.1.1.1\n10.255.255.1');
    await tester.tap(find.text('Test upstreams'));
    await tester.pumpAndSettle();

    expect(pumped.actions.calls, <String>['test 1.1.1.1 10.255.255.1']);
    expect(find.text('1 server did not answer'), findsOneWidget);
    expect(find.text('10.255.255.1:53'), findsOneWidget);
    expect(find.text('i/o timeout'), findsOneWidget);
    expect(pumped.actions.savedDns, isEmpty);
  });

  testWidgets('upstreams kept in a file are not tested, and the sheet '
      'says why', (WidgetTester tester) async {
    final Pumped pumped = await open(
      tester,
      dns: AdguardHomeDnsConfig(<String, dynamic>{
        ...dnsInfoJson(),
        'upstream_dns_file': '/opt/adguardhome/upstreams.txt',
      }),
    );
    pumped.actions.upstreamResults = const <AdguardHomeUpstreamResult>[];

    await tester.tap(find.text('Test upstreams'));
    await tester.pumpAndSettle();

    expect(pumped.actions.calls, <String>['test ']);
    expect(find.textContaining('cannot be tested from here'), findsOneWidget);
  });

  testWidgets('a server with no timeout opens unchanged, and keeps none',
      (WidgetTester tester) async {
    final Pumped pumped = await open(
      tester,
      dns: AdguardHomeDnsConfig(
        <String, dynamic>{...dnsInfoJson()}..remove('upstream_timeout'),
      ),
    );

    expect(text(tester, timeout), isEmpty);
    expect(find.text('At least 1 second.'), findsNothing);
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tester.tap(find.text('Parallel requests'));
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(pumped.actions.savedDns.single, <String, dynamic>{
      'upstream_mode': 'parallel',
    });
  });

  testWidgets('a timeout past 32 bits says so', (WidgetTester tester) async {
    await open(tester);

    await tester.enterText(timeout, '4294967296');
    await tester.pump();

    expect(find.text('At most 4294967295 seconds.'), findsOneWidget);
  });

  testWidgets('a test refused for the sign-in is tried again from the sheet',
      (WidgetTester tester) async {
    final Pumped pumped = await open(tester);
    pumped.actions.lookupFailure = const AdguardHomeSignInRefused();

    await tester.tap(find.text('Test upstreams'));
    await tester.pumpAndSettle();
    expect(find.text('Not tested'), findsOneWidget);

    pumped.actions.lookupFailure = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(pumped.actions.calls, <String>[
      'test https://dns10.quad9.net/dns-query',
      'retry',
      'test https://dns10.quad9.net/dns-query',
    ]);
    expect(find.text('Every server answered'), findsOneWidget);
  });

  testWidgets('a test that fails says why', (WidgetTester tester) async {
    final Pumped pumped = await open(tester);
    pumped.actions.lookupFailure = const AdguardHomeRequestRefused('nope');

    await tester.tap(find.text('Test upstreams'));
    await tester.pumpAndSettle();

    expect(find.text('Not tested'), findsOneWidget);
    expect(find.text('nope'), findsOneWidget);
  });

  for (final double width in <double>[320, 411]) {
    for (final double scale in <double>[1, 2]) {
      testWidgets('layout holds at $width wide and $scale text',
          (WidgetTester tester) async {
        await open(tester, size: Size(width, 4000), textScale: scale);

        expect(tester.takeException(), isNull);
      });
    }
  }
}
