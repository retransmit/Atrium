import 'package:core_networking/core_networking.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(1080, 2400),
  }) async {
    tester.view.physicalSize = size;
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

  testWidgets('the list says a filter is on and can drop it',
      (WidgetTester tester) async {
    await open(tester);
    final Finder bar = find.byKey(
      const ValueKey<String>('active-filter-bar'),
    );
    expect(bar, findsNothing);

    await openFilters(tester);
    await tester.tap(find.text('Seeding (1)'));
    await settle(tester);
    await tester.tapAt(const Offset(10, 10));
    // The scrim is hit-testable until the close animation finishes.
    await settle(tester, frames: 12);

    // The drawer is closed now, so only the strip can say the list is
    // narrowed, and only it can undo it without opening the drawer again.
    expect(bar, findsOneWidget);
    expect(
      find.descendant(of: bar, matching: find.text('Filtered:')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: bar, matching: find.text('Seeding')),
      findsOneWidget,
    );

    await tester.tap(find.descendant(of: bar, matching: find.text('Clear')));
    await settle(tester);
    expect(bar, findsNothing);
    expect(find.text('Alpha'), findsOneWidget);
  });

  testWidgets('an empty list under a filter offers to clear it',
      (WidgetTester tester) async {
    await open(tester);
    await openFilters(tester);
    await tester.tap(find.text('Error (0)'));
    await settle(tester);
    await tester.tapAt(const Offset(10, 10));
    await settle(tester, frames: 12);

    // "No torrents, add one" would be a lie while a filter hides both.
    expect(find.text('No torrents match'), findsOneWidget);
    expect(find.text('Clear filters'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await settle(tester);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('No torrents match'), findsNothing);
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

  testWidgets('rows render clean card without peer clutter',
      (WidgetTester tester) async {
    fake.on('torrent-get', <String, Object?>{
      'torrents': <Map<String, dynamic>>[
        torrentJson(hash: 'm', name: 'Magnet', metadataPercentComplete: 0.4),
      ],
    });
    await open(tester);

    expect(find.text('Magnet'), findsOneWidget);
    expect(
      find.textContaining('Downloading from 8 of 12 peers'),
      findsNothing,
    );
    final Finder row = find.byType(TransmissionTorrentRow);
    expect(
      find.descendant(of: row, matching: find.byIcon(Icons.south)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.byIcon(Icons.north)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.byIcon(Icons.swap_vert)),
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

  testWidgets('unlimited caps show no pills until a cap is in force',
      (WidgetTester tester) async {
    // The fixture leaves download unlimited and upload capped at 1000 kB/s,
    // which is exactly the pair that used to read "Unlimited" / "1000 KB/s"
    // and crowd the bulk controls.
    await open(tester);

    // One pill, for the cap that is actually on. Addressed by key: the Down
    // figure happens to read the same rate as the upload cap.
    expect(find.text('Unlimited'), findsNothing);
    expect(find.byKey(const ValueKey<String>('limit-down-pill')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('limit-up-pill')),
        matching: find.text('1000 KB/s'),
      ),
      findsOneWidget,
    );

    // The menu still offers both caps, naming what each is set to, so the
    // unlimited one is not a dead end.
    await tester.tap(find.byTooltip('More'));
    await settle(tester);
    expect(find.textContaining('Download limit: Unlimited'), findsOneWidget);
    expect(find.textContaining('Upload limit: 1000 KB/s'), findsOneWidget);

    await tester.tap(find.textContaining('Download limit: Unlimited'));
    await settle(tester);
    expect(find.text('Download limit'), findsOneWidget);
  });

  testWidgets('compact rows drop the bottom badges row',
      (WidgetTester tester) async {
    await open(tester);
    expect(find.byIcon(Icons.swap_vert), findsNWidgets(2));

    await tester.tap(find.byTooltip('More'));
    await settle(tester);
    // The checked item's tile ignores pointers; the item itself takes the tap.
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<String>, 'Compact rows'),
    );
    await settle(tester);

    expect(find.byIcon(Icons.swap_vert), findsNothing);
    expect(find.textContaining('↓'), findsWidgets);
  });

  testWidgets('compact rows are shorter and say the state once',
      (WidgetTester tester) async {
    fake.on('torrent-get', <String, Object?>{
      'torrents': <Map<String, dynamic>>[
        torrentJson(hash: 'p', name: 'Paused one', status: 0),
      ],
    });
    await open(tester);

    final Finder row = find.byType(TransmissionTorrentRow);
    final double full = tester.getSize(row).height;
    expect(find.text('Paused'), findsOneWidget);

    await tester.tap(find.byTooltip('More'));
    await settle(tester);
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<String>, 'Compact rows'),
    );
    await settle(tester);

    // The pill used to sit above a summary that repeated it, and dropping
    // only the pill row left the row nearly as tall as the full one.
    expect(tester.getSize(row).height, lessThan(full - 32));
    expect(find.text('Paused'), findsOneWidget);
  });

  testWidgets('the row menu opens Set location', (WidgetTester tester) async {
    await open(tester);

    await tester.tap(find.byTooltip('Torrent actions').first);
    await settle(tester);
    await tester.tap(find.text('Set location'));
    await settle(tester);

    expect(find.text('Set torrent location'), findsOneWidget);
  });

  testWidgets('the top transfer panel elements are evenly spaced',
      (WidgetTester tester) async {
    await open(tester);

    // Badges in Row 1 have Insets.sm (8 px) horizontal spacing between them.
    final Finder torrentsBadge = find.ancestor(
      of: find.text('Torrents'),
      matching: find.byType(TransmissionStatBadge),
    );
    final Finder downBadge = find.ancestor(
      of: find.text('Down'),
      matching: find.byType(TransmissionStatBadge),
    );
    final Finder upBadge = find.ancestor(
      of: find.text('Up'),
      matching: find.byType(TransmissionStatBadge),
    );

    expect(
      tester.getTopLeft(downBadge).dx - tester.getTopRight(torrentsBadge).dx,
      equals(8.0),
    );
    expect(
      tester.getTopLeft(upBadge).dx - tester.getTopRight(downBadge).dx,
      equals(8.0),
    );

    // Row 4 bulk buttons also have Insets.sm (8 px) spacing between them.
    final Finder resumeBtn = find.ancestor(
      of: find.byTooltip('Resume all'),
      matching: find.byType(IconButton),
    );
    final Finder pauseBtn = find.ancestor(
      of: find.byTooltip('Pause all'),
      matching: find.byType(IconButton),
    );
    expect(
      tester.getTopLeft(pauseBtn).dx - tester.getTopRight(resumeBtn).dx,
      equals(8.0),
    );

    // Vertical spacing between panel rows is consistently Insets.sm (8 px).
    final Finder badgeRow = find.ancestor(
      of: torrentsBadge,
      matching: find.byType(Row),
    ).first;
    final Finder searchRow = find.ancestor(
      of: find.text('Search torrents...'),
      matching: find.byType(Row),
    ).first;
    final Finder limitWrap = find.ancestor(
      of: find.byKey(const ValueKey<String>('limit-up-pill')),
      matching: find.byType(Wrap),
    );
    final Finder buttonRow = find.ancestor(
      of: resumeBtn,
      matching: find.byType(Row),
    );

    expect(
      tester.getTopLeft(searchRow).dy - tester.getBottomLeft(badgeRow).dy,
      equals(8.0),
    );
    expect(
      tester.getTopLeft(limitWrap).dy - tester.getBottomLeft(searchRow).dy,
      equals(8.0),
    );
    expect(
      tester.getTopLeft(buttonRow).dy - tester.getBottomLeft(limitWrap).dy,
      equals(8.0),
    );
  });

  testWidgets(
      'the top transfer panel rows are evenly spaced when caps are unlimited',
      (WidgetTester tester) async {
    fake.on(
      'session-get',
      sessionJson()
        ..['speed-limit-down-enabled'] = false
        ..['speed-limit-up-enabled'] = false,
    );
    await open(tester);

    expect(find.byKey(const ValueKey<String>('limit-down-pill')), findsNothing);
    expect(find.byKey(const ValueKey<String>('limit-up-pill')), findsNothing);

    final Finder torrentsBadge = find.ancestor(
      of: find.text('Torrents'),
      matching: find.byType(TransmissionStatBadge),
    );
    final Finder badgeRow = find.ancestor(
      of: torrentsBadge,
      matching: find.byType(Row),
    ).first;
    final Finder searchRow = find.ancestor(
      of: find.text('Search torrents...'),
      matching: find.byType(Row),
    ).first;
    final Finder buttonRow = find.ancestor(
      of: find.byTooltip('Resume all'),
      matching: find.byType(Row),
    );

    // Row 1 to Row 2
    expect(
      tester.getTopLeft(searchRow).dy - tester.getBottomLeft(badgeRow).dy,
      equals(8.0),
    );
    // Row 2 to Row 3 (buttonRow), without any doubled SizedBox gap
    expect(
      tester.getTopLeft(buttonRow).dy - tester.getBottomLeft(searchRow).dy,
      equals(8.0),
    );
  });

  testWidgets(
      'torrent card badges for down speed, up speed, and ratio are evenly spaced',
      (WidgetTester tester) async {
    await open(tester);

    final Finder firstTile = find.byType(TransmissionTorrentRow).first;
    final Finder downBadge = find.descendant(
      of: firstTile,
      matching: find.byWidgetPredicate(
        (Widget w) => w is TransmissionSpeedPill && w.icon == Icons.south,
      ),
    );
    final Finder upBadge = find.descendant(
      of: firstTile,
      matching: find.byWidgetPredicate(
        (Widget w) => w is TransmissionSpeedPill && w.icon == Icons.north,
      ),
    );
    final Finder ratioBadge = find.descendant(
      of: firstTile,
      matching: find.byType(TransmissionRatioPill),
    );

    expect(downBadge, findsOneWidget);
    expect(upBadge, findsOneWidget);
    expect(ratioBadge, findsOneWidget);

    final double downWidth = tester.getSize(downBadge).width;
    final double upWidth = tester.getSize(upBadge).width;
    final double ratioWidth = tester.getSize(ratioBadge).width;

    // All 3 badges have identical widths
    expect(downWidth, equals(upWidth));
    expect(upWidth, equals(ratioWidth));

    // Evenly spaced by Insets.sm (8 px)
    expect(
      tester.getTopLeft(upBadge).dx - tester.getTopRight(downBadge).dx,
      equals(8.0),
    );
    expect(
      tester.getTopLeft(ratioBadge).dx - tester.getTopRight(upBadge).dx,
      equals(8.0),
    );
  });

  testWidgets('a full row says a torrent failed, and why',
      (WidgetTester tester) async {
    // The reason used to ride on the status line under the bar. With that
    // line gone, a full row showed a red "Paused" pill and nothing else.
    fake.on('torrent-get', <String, Object?>{
      'torrents': <Map<String, dynamic>>[
        torrentJson(
          hash: 'e',
          name: 'Broken',
          status: 0,
          error: 3,
          errorString: 'No data found!',
        ),
      ],
    });
    await open(tester);

    final Finder row = find.byType(TransmissionTorrentRow);
    expect(
      find.descendant(of: row, matching: find.text('No data found!')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.text('Error')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.text('Paused')),
      findsNothing,
    );
  });

  testWidgets('Back clears the search box along with the search',
      (WidgetTester tester) async {
    await open(tester);
    await openSearch(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Search torrents...'),
      'lin',
    );
    await settle(tester);
    expect(find.text('Beta'), findsNothing);

    // Back is handled by the home screen, which clears the query but cannot
    // reach the field that shows it.
    await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
    await settle(tester);

    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('lin'), findsNothing);
    expect(find.text('Search torrents...'), findsOneWidget);
  });

  testWidgets('the turtle button looks different on and off',
      (WidgetTester tester) async {
    // The button's own surface is the nearest Material above its icon.
    Color background() => tester
        .widget<Material>(
          find
              .ancestor(
                of: find.byIcon(Icons.slow_motion_video),
                matching: find.byType(Material),
              )
              .first,
        )
        .color!;

    await open(tester);
    final ColorScheme cs = Theme.of(
      tester.element(find.byType(TransmissionTorrentsTab)),
    ).colorScheme;
    expect(find.byTooltip('Turtle off'), findsOneWidget);
    final Color off = background();

    fake.on('session-get', sessionJson()..['alt-speed-enabled'] = true);
    await tester.pumpWidget(const SizedBox.shrink());
    await open(tester);
    expect(find.byTooltip('Turtle on: 500/100 KB/s'), findsOneWidget);
    final Color on = background();

    expect(on, cs.primaryContainer);
    expect(on, isNot(off));
  });

  testWidgets('speeds stack rather than cut short on a narrow phone',
      (WidgetTester tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester, size: const Size(320, 2400));

    final Finder firstTile = find.byType(TransmissionTorrentRow).first;
    final Finder down = find.descendant(
      of: firstTile,
      matching: find.byWidgetPredicate(
        (Widget w) => w is TransmissionSpeedPill && w.icon == Icons.south,
      ),
    );
    final Finder up = find.descendant(
      of: firstTile,
      matching: find.byWidgetPredicate(
        (Widget w) => w is TransmissionSpeedPill && w.icon == Icons.north,
      ),
    );

    // One under the other, and each value whole.
    expect(tester.getTopLeft(up).dy, greaterThan(tester.getBottomLeft(down).dy));
    for (final Finder pill in <Finder>[down, up]) {
      // The icon is drawn as text too; the value comes after it.
      final RenderParagraph text = tester.renderObject<RenderParagraph>(
        find.descendant(of: pill, matching: find.byType(RichText)).last,
      );
      expect(text.didExceedMaxLines, isFalse);
    }
  });
}
