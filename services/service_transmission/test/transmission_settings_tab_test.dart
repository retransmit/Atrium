import 'package:core_networking/core_networking.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_transmission/service_transmission.dart';

import 'support/fake_transmission.dart';
import 'support/pump.dart';
import 'support/transmission_fixtures.dart';
import 'support/transmission_test_instance.dart';

void main() {
  late FakeTransmission fake;

  setUp(() {
    fake = FakeTransmission()
      ..on('session-get', sessionJson())
      ..on('session-stats', statsJson());
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          instanceDioProvider(transmissionTestInstance)
              .overrideWith((Ref ref) async => fakeTransmissionDio(fake)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: TransmissionSettingsTab(instance: transmissionTestInstance),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester);
  }

  testWidgets('the statistics card shows both columns',
      (WidgetTester tester) async {
    await open(tester);

    expect(find.text('This session'), findsOneWidget);
    expect(find.text('All time'), findsOneWidget);
    expect(find.text('Started 57 times'), findsOneWidget);
    expect(find.text(trTimeInterval(3600)), findsOneWidget);
    expect(find.text(trFmtBytes(391807173959)), findsOneWidget);
  });

  testWidgets('a switch writes its key alone', (WidgetTester tester) async {
    await open(tester);
    await scrollTo(tester, find.text('Start when added'));

    await tester.tap(find.text('Start when added'));
    await settle(tester);

    expect(fake.single('session-set').arguments, <String, dynamic>{
      'start-added-torrents': false,
    });
    expect(find.text('Setting saved'), findsOneWidget);
  });

  testWidgets('a number opens a dialog and writes on Save',
      (WidgetTester tester) async {
    await open(tester);
    await scrollTo(tester, find.text('Max peers overall'));

    await tester.tap(find.text('Max peers overall'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '250');
    await tester.tap(find.text('Save'));
    await settle(tester);

    expect(fake.single('session-set').arguments, <String, dynamic>{
      'peer-limit-global': 250,
    });
  });

  testWidgets('day chips write the bitmask', (WidgetTester tester) async {
    // The daemon reads back what was written, so the fake keeps the day
    // mask the tab writes; the next toggle then builds on it.
    int day = trEveryDay;
    fake
      ..onCall(
        'session-get',
        (Map<String, dynamic> _) => sessionJson(altSpeedTimeDay: day),
      )
      ..onCall('session-set', (Map<String, dynamic> args) {
        day = (args['alt-speed-time-day'] as int?) ?? day;
        return <String, Object?>{};
      });
    await open(tester);
    await scrollTo(tester, find.text('Weekdays'));

    await tester.tap(find.text('Weekdays'));
    await settle(tester);
    expect(fake.to('session-set').last.arguments, <String, dynamic>{
      'alt-speed-time-day': trWeekdays,
    });

    await tester.tap(find.text('Sat'));
    await settle(tester);
    expect(fake.to('session-set').last.arguments, <String, dynamic>{
      'alt-speed-time-day': trWeekdays | 64,
    });
  });

  testWidgets('encryption offers the three modes and writes allowed',
      (WidgetTester tester) async {
    await open(tester);
    await scrollTo(tester, find.text('Encryption'));

    await tester.tap(find.text('Encryption'));
    await settle(tester);
    await tester.tap(find.text('Allow encryption'));
    await settle(tester);

    expect(fake.single('session-set').arguments, <String, dynamic>{
      'encryption': 'allowed',
    });
  });

  testWidgets('Update blocklist calls the daemon and shows the count',
      (WidgetTester tester) async {
    fake.on('blocklist-update', <String, Object?>{'blocklist-size': 4242});
    await open(tester);
    await scrollTo(tester, find.text('Update blocklist'));

    await tester.tap(find.text('Update blocklist'));
    await settle(tester);

    expect(fake.to('blocklist-update'), hasLength(1));
    expect(find.text('Blocklist updated: 4242 rules'), findsOneWidget);
  });

  testWidgets('Test port reports both protocols on 4.1',
      (WidgetTester tester) async {
    fake.onCall(
      'port-test',
      (Map<String, dynamic> args) => <String, Object?>{
        'port-is-open': args['ipProtocol'] == 'ipv4',
      },
    );
    await open(tester);
    await scrollTo(tester, find.text('Test port'));

    await tester.tap(find.text('Test port'));
    await settle(tester);

    expect(find.text('IPv4 port is Open'), findsOneWidget);
    expect(find.text('IPv6 port is Closed'), findsOneWidget);
  });

  testWidgets('an old daemon gets one port test and no default trackers',
      (WidgetTester tester) async {
    fake
      ..on('session-get', sessionJson(rpcVersion: 16))
      ..on('port-test', <String, Object?>{'port-is-open': false});
    await open(tester);

    expect(find.text('Default public trackers'), findsNothing);
    await scrollTo(tester, find.text('Test port'));
    await tester.tap(find.text('Test port'));
    await settle(tester);

    expect(find.text('Port is Closed'), findsOneWidget);
    expect(
      fake.single('port-test').arguments.containsKey('ipProtocol'),
      isFalse,
    );
  });

  testWidgets('the version line names the daemon', (WidgetTester tester) async {
    await open(tester);
    await scrollTo(tester, find.textContaining('RPC 19'));

    expect(
      find.text('Transmission 4.1.3 (838877323f), RPC 19'),
      findsOneWidget,
    );
  });
}
