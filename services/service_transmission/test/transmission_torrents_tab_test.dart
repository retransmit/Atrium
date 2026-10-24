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
      ..on('session-stats', statsJson())
      ..on('torrent-get', <String, Object?>{
        'torrents': <Map<String, dynamic>>[
          torrentJson(hash: 'a', name: 'Alpha', labels: <String>['linux']),
          torrentJson(
            id: 2,
            hash: 'b',
            name: 'Beta',
            status: 6,
            leftUntilDone: 0,
          ),
        ],
      });
  });

  Future<void> open(WidgetTester tester) async {
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

  /// The filters live in the end drawer now, so a test that wants one opens it
  /// the way the filter button does.
  Future<void> openFilters(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Filter torrents'));
    await settle(tester);
  }

  /// Opens the search box, which is collapsed to a tap target until wanted.
  Future<void> openSearch(WidgetTester tester) async {
    await tester.tap(find.text('Search torrents...'));
    await settle(tester);
  }

  testWidgets('the filter drawer counts and narrows the list',
      (WidgetTester tester) async {
    await open(tester);

    await openFilters(tester);
    expect(find.text('All (2)'), findsOneWidget);
    expect(find.text('Downloading (1)'), findsOneWidget);
    expect(find.text('Seeding (1)'), findsOneWidget);
    // Every torrent is public, so those two say nothing and stay hidden.
    expect(find.textContaining('Private'), findsNothing);

    await tester.tap(find.text('Seeding (1)'));
    await settle(tester);
    // Picking a filter leaves the drawer open so a second facet can follow;
    // closing it is the user's own move.
    await tester.tapAt(const Offset(10, 10));
    await settle(tester);

    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Alpha'), findsNothing);
  });

  testWidgets('search narrows by name and label', (WidgetTester tester) async {
    await open(tester);
    await openSearch(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Search torrents...'),
      'lin',
    );
    await settle(tester);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsNothing);

    // The drawer's counts follow the search, as the chips' did.
    await openFilters(tester);
    expect(find.text('All (1)'), findsOneWidget);
  });

  testWidgets('tapping outside the search box drops its focus',
      (WidgetTester tester) async {
    // Otherwise the keyboard comes back every time a menu closes, since focus
    // returns to the field.
    await open(tester);
    await openSearch(tester);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );

    // Anywhere outside the field: a header figure's label will do. (Not
    // "Torrents", which the bottom bar also says.)
    await tester.tap(find.text('Down'));
    await settle(tester);

    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isFalse,
    );
  });

  testWidgets('rows read like the web UI', (WidgetTester tester) async {
    fake.on('torrent-get', <String, Object?>{
      'torrents': <Map<String, dynamic>>[
        torrentJson(hash: 'm', name: 'Magnet', metadataPercentComplete: 0.4),
      ],
    });
    await open(tester);

    expect(
      find.text('Magnetized transfer - retrieving metadata (40.0%)'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Downloading from 8 of 12 peers'),
      findsOneWidget,
    );
  });

  testWidgets('long-press selects, Select all widens, the bar pauses them all',
      (WidgetTester tester) async {
    await open(tester);

    await tester.longPress(find.text('Alpha'));
    await settle(tester);
    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(find.byTooltip('Select all'));
    await settle(tester);
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.byTooltip('Selection actions'));
    await settle(tester);
    await tester.tap(find.text('Pause'));
    await settle(tester);

    expect(fake.single('torrent-stop').arguments['ids'], <String>['a', 'b']);
    // The selection is dropped once the action ran.
    expect(find.textContaining('selected'), findsNothing);
  });

  testWidgets('Pause all and Start all send no ids',
      (WidgetTester tester) async {
    await open(tester);

    await tester.tap(find.byTooltip('Pause all'));
    await settle(tester);
    await tester.tap(find.byTooltip('Resume all'));
    await settle(tester);

    expect(fake.single('torrent-stop').arguments.containsKey('ids'), isFalse);
    expect(fake.single('torrent-start').arguments.containsKey('ids'), isFalse);
  });

  testWidgets('compact rows drop the progress line',
      (WidgetTester tester) async {
    await open(tester);
    expect(find.textContaining('remaining'), findsOneWidget);

    await tester.tap(find.byTooltip('More'));
    await settle(tester);
    // The checked item's tile ignores pointers; the item itself takes the tap.
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<String>, 'Compact rows'),
    );
    await settle(tester);

    expect(find.textContaining('remaining'), findsNothing);
    expect(find.textContaining('↓'), findsWidgets);
  });

  testWidgets('the row menu opens Set location', (WidgetTester tester) async {
    await open(tester);

    await tester.tap(find.byTooltip('Torrent actions').first);
    await settle(tester);
    await tester.tap(find.text('Set location'));
    await settle(tester);

    expect(find.text('Set torrent location'), findsOneWidget);
  });
}
