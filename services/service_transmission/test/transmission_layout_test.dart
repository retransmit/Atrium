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

/// The panel row carries the search box, the turtle, two caps and three
/// buttons; a phone held in portrait has very little room for that, and the
/// selection app bar replaces a title with a count and two actions. These
/// cases pin the narrow and large-text layouts, which the repo has broken
/// before.
void main() {
  for (final (double width, double scale) in <(double, double)>[
    (320, 1.0),
    (360, 1.3),
    (360, 2.0),
    (411, 1.0),
  ]) {
    testWidgets('torrents tab fits ${width}px at text scale $scale',
        (WidgetTester tester) async {
      tester.view.physicalSize = Size(width, 2400);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final FakeTransmission fake = FakeTransmission()
        ..on('session-get', sessionJson())
        ..on('session-stats', statsJson())
        ..on('torrent-get', <String, Object?>{
          'torrents': <Map<String, dynamic>>[
            torrentJson(
              hash: 'a',
              name: 'A rather long torrent name that has to wrap or '
                  'be ellipsised rather than overflow its row',
              labels: <String>['linux', 'iso'],
            ),
            torrentJson(id: 2, hash: 'b', name: 'Beta', status: 6),
          ],
        });

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

      expect(tester.takeException(), isNull);

      // The active-filter strip is another row that has to fit, and the
      // drawer it comes from is the tightest layout on the smallest phone.
      await tester.tap(find.byTooltip('Filter torrents'));
      await settle(tester);
      await tester.tap(find.text('Seeding (1)'));
      await settle(tester);
      await tester.tapAt(const Offset(10, 10));
      await settle(tester, frames: 12);
      expect(tester.takeException(), isNull);

      final Finder filterBar =
          find.byKey(const ValueKey<String>('active-filter-bar'));
      expect(filterBar, findsOneWidget);
      await tester.tap(
        find.descendant(of: filterBar, matching: find.text('Clear')),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);

      // Compact rows do not share the full row's layout.
      await tester.tap(find.byTooltip('More'));
      await settle(tester);
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<String>, 'Compact rows'),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);

      // The selection app bar is the other layout that has to fit.
      await tester.longPress(find.textContaining('ellipsised'));
      await settle(tester);
      expect(tester.takeException(), isNull);

      // And the filter drawer, whose rows carry counts beside long names.
      await tester.tap(find.byTooltip('Select all'));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  }
}
