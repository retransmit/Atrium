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
  Future<void> open(WidgetTester tester, FakeTransmission fake) async {
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
          home: TransmissionHome(instance: transmissionTestInstance),
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('the bottom bar switches between Torrents and Settings',
      (WidgetTester tester) async {
    final FakeTransmission fake = FakeTransmission()
      ..on('session-get', sessionJson())
      ..on('session-stats', statsJson())
      ..on('torrent-get', <String, Object?>{'torrents': <Object>[]});
    await open(tester, fake);

    expect(find.text('No torrents'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await settle(tester);
    expect(find.text('This session'), findsOneWidget);
  });

  testWidgets('back clears a selection, then returns to Torrents, before leaving',
      (WidgetTester tester) async {
    final FakeTransmission fake = FakeTransmission()
      ..on('session-get', sessionJson())
      ..on('session-stats', statsJson())
      ..on('torrent-get', <String, Object?>{
        'torrents': <Map<String, dynamic>>[
          torrentJson(hash: 'a', name: 'Alpha'),
        ],
      });
    await open(tester, fake);

    await tester.longPress(find.text('Alpha'));
    await settle(tester);
    expect(find.text('1 selected'), findsOneWidget);

    // The system back, as Android delivers it.
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('1 selected'), findsNothing);
    expect(find.text('Alpha'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await settle(tester);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );

    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
    expect(find.text('Alpha'), findsOneWidget);
  });
}
