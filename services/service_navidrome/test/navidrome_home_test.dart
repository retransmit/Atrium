import 'package:core_networking/core_networking.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_navidrome/service_navidrome.dart';

import 'support/fake_navidrome.dart';

void main() {
  late FakeNavidrome fake;

  setUp(() => fake = FakeNavidrome());

  Future<void> open(
    WidgetTester tester,
    String tab, {
    Size size = const Size(411, 890),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      ProviderScope(
        retry: (int _, Object __) => null,
        overrides: <Override>[
          instanceDioProvider(navidromeTestInstance)
              .overrideWith((Ref ref) async => fakeNavidromeDio(fake)),
        ],
        child: MaterialApp(
          theme: AtriumTheme.light(null),
          home: const NavidromeHome(instance: navidromeTestInstance),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text(tab));
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('the artists tab', () {
    // Navidrome names its own groups, and out of the box two of them are
    // longer than a letter: X-Z holds three letters, and [Unknown] the
    // names that open with a bracket.
    testWidgets('heads each section with the name Navidrome gives the group',
        (WidgetTester tester) async {
      fake.on(
        'getArtists',
        artistsJson(<String, List<String>>{
          '#': <String>['2Pac'],
          'P': <String>['Pink Floyd'],
          'X-Z': <String>['X Japan', 'Yes', 'ZZ Top'],
          '[Unknown]': <String>['[Unknown Artist]'],
        }),
      );
      await open(tester, 'Artists');

      expect(find.text('ZZ Top'), findsOneWidget);
      expect(find.text('P'), findsOneWidget);
      expect(find.text('X-Z'), findsOneWidget);
      expect(find.text('[Unknown]'), findsOneWidget);
      // One, for the group Navidrome calls that. Not a second one standing
      // in for a name that did not fit.
      expect(find.text('#'), findsOneWidget);
    });

    testWidgets('keeps a long group name on one line',
        (WidgetTester tester) async {
      fake.on(
        'getArtists',
        artistsJson(<String, List<String>>{
          'P': <String>['Pink Floyd'],
          '[Unknown]': <String>['[Unknown Artist]'],
        }),
      );
      await open(tester, 'Artists');

      expect(tester.takeException(), isNull);
      // As tall as the single letter beside it, so not wrapped.
      expect(
        tester.getSize(find.text('[Unknown]')).height,
        tester.getSize(find.text('P')).height,
      );
    });

    // Index groups are the server owner's to set, and nothing says they
    // are Latin letters.
    testWidgets('keeps a group named in another script',
        (WidgetTester tester) async {
      fake.on(
        'getArtists',
        artistsJson(<String, List<String>>{
          'К': <String>['Кино'],
          'Å': <String>['Åse Kleveland'],
          'The': <String>['The The'],
        }),
      );
      await open(tester, 'Artists');

      expect(find.text('К'), findsOneWidget);
      expect(find.text('Å'), findsOneWidget);
      expect(find.text('The'), findsOneWidget);
      expect(find.text('#'), findsNothing);
    });
  });

  group('the playlists tab', () {
    testWidgets('counts one song as one song', (WidgetTester tester) async {
      fake.on(
        'getPlaylists',
        playlistsJson(<Map<String, dynamic>>[
          playlistJson(name: 'One Song', songCount: 1),
          playlistJson(name: 'Morning Coffee'),
        ]),
      );
      await open(tester, 'Playlists');

      expect(find.text('1 song'), findsOneWidget);
      expect(find.text('24 songs'), findsOneWidget);
    });

    // A cell is as tall as its cover and its two lines of text, at whatever
    // size the text is set to. A fixed shape runs out of room below.
    testWidgets('fits its cells at the largest text size',
        (WidgetTester tester) async {
      fake.on(
        'getPlaylists',
        playlistsJson(<Map<String, dynamic>>[
          playlistJson(name: 'Morning Coffee'),
          playlistJson(name: 'Road Trip', songCount: 112),
        ]),
      );
      await open(
        tester,
        'Playlists',
        size: const Size(360, 800),
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('112 songs'), findsOneWidget);
    });

    // The add button floats over the bottom right corner, which is where
    // the last playlist of an even count sits once the grid is scrolled to
    // its end.
    testWidgets('leaves the last row clear of the add button',
        (WidgetTester tester) async {
      const String last = 'Workout Mix 2026 - High Energy Running and Lifting';
      fake.on(
        'getPlaylists',
        playlistsJson(<Map<String, dynamic>>[
          for (int i = 1; i <= 7; i++) playlistJson(name: 'Playlist $i'),
          playlistJson(name: last),
        ]),
      );
      await open(tester, 'Playlists');

      await tester.dragUntilVisible(
        find.text(last),
        find.byType(GridView),
        const Offset(0, -300),
      );
      await tester.drag(find.byType(GridView), const Offset(0, -3000));
      // Past the bounce at the end of the list.
      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final Rect name = tester.getRect(find.text(last));
      final Rect button = tester.getRect(find.byType(FloatingActionButton));
      expect(
        name.overlaps(button),
        isFalse,
        reason: 'the name at $name is under the button at $button',
      );
    });
  });
}
