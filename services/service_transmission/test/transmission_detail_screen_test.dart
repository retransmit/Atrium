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
      ..onCall('torrent-get', (Map<String, dynamic> args) {
        // The list asks for many fields, the detail asks for `files`.
        final List<dynamic> fields = args['fields'] as List<dynamic>;
        return <String, Object?>{
          'torrents': <Map<String, dynamic>>[
            // The fixture's hash is the one this screen opens.
            if (fields.contains('files')) detailJson() else torrentJson(),
          ],
        };
      });
  });

  Future<void> open(WidgetTester tester, {String tab = 'Info'}) async {
    tester.view.physicalSize = const Size(1080, 2400);
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
          home: TransmissionDetailScreen(
            instance: transmissionTestInstance,
            hashString: 'aaaa',
            initialName: 'Debian netinst',
          ),
        ),
      ),
    );
    await settle(tester);
    if (tab != 'Info') {
      await tester.tap(find.text(tab));
      // The tab slides over for 300 ms.
      await settle(tester, frames: 12);
    }
  }

  testWidgets('Info shows the inspector lines', (WidgetTester tester) async {
    await open(tester);

    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    expect(find.textContaining('Unverified'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Public torrent'), findsOneWidget);
    expect(find.textContaining('Created by mktorrent 1.1 on'), findsOneWidget);
    expect(find.textContaining('1000 pieces @'), findsOneWidget);
    expect(find.byTooltip('Copy magnet link'), findsOneWidget);
  });

  testWidgets('Files groups by folder and writes wanted and priority',
      (WidgetTester tester) async {
    await open(tester, tab: 'Files');

    expect(find.text('debian'), findsOneWidget);
    expect(find.text('iso'), findsOneWidget);
    expect(find.text('README.txt'), findsOneWidget);

    // The folder's checkbox covers every file under it.
    await tester.tap(find.byType(Checkbox).first);
    await settle(tester);
    expect(fake.to('torrent-set').last.arguments, <String, dynamic>{
      'ids': <String>['aaaa'],
      'files-unwanted': <int>[0, 1],
    });

    await tester.tap(find.byTooltip('Priority').last);
    await settle(tester);
    await tester.tap(find.text('Low'));
    await settle(tester);
    expect(fake.to('torrent-set').last.arguments['priority-low'], <int>[1]);

    await tester.tap(find.text('Select none'));
    await settle(tester);
    expect(
      fake.to('torrent-set').last.arguments['files-unwanted'],
      <int>[0, 1],
    );
  });

  testWidgets('Peers shows flags, a legend and web seeds',
      (WidgetTester tester) async {
    await open(tester, tab: 'Peers');

    expect(find.text('10.0.0.5:51413'), findsOneWidget);
    expect(find.text('DEI'), findsOneWidget);
    expect(find.text('Web seeds'), findsOneWidget);
    expect(find.text('https://cdimage.debian.org/'), findsOneWidget);

    await tester.tap(find.byTooltip('Peer flags'));
    await settle(tester);
    expect(find.text('Encrypted connection'), findsOneWidget);
  });

  testWidgets('Trackers shows the tier, state, announce and scrape',
      (WidgetTester tester) async {
    await open(tester, tab: 'Trackers');

    expect(find.text('Tier 1'), findsOneWidget);
    expect(find.text('debian'), findsOneWidget);
    expect(find.textContaining('Next announce in'), findsOneWidget);
    expect(find.textContaining('got 40 peers'), findsOneWidget);
    expect(find.textContaining('Last scrape:'), findsOneWidget);
    expect(find.text('300 seeders'), findsOneWidget);
    expect(find.text('20 leechers'), findsOneWidget);
    expect(find.text('5000 downloads'), findsOneWidget);
  });

  testWidgets('the app bar menu carries the actions',
      (WidgetTester tester) async {
    await open(tester);

    await tester.tap(find.byTooltip('Torrent actions'));
    await settle(tester);
    await tester.tap(find.text('Verify local data'));
    await settle(tester);

    expect(fake.single('torrent-verify').arguments['ids'], <String>['aaaa']);
  });
}
