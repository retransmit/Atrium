import 'package:atrium/src/preferences.dart';
import 'package:atrium/src/screens/calendar_screen.dart';
import 'package:clock/clock.dart';
import 'package:core_models/core_models.dart';
import 'package:core_profile/core_profile.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_sonarr/service_sonarr.dart';

class _Prefs extends PreferencesController {
  _Prefs(this._initial);
  final Preferences _initial;

  @override
  Preferences build() => _initial;
}

const Instance _sonarr = Instance(
  id: 'test-sonarr',
  name: 'Test Sonarr',
  kind: ServiceKind.sonarr,
  localUrl: 'http://localhost:8989',
  externalUrl: '',
  urlMode: UrlMode.auto,
  auth: InstanceAuth.apiKey(apiKey: 'k'),
);

const SonarrSeries _drop =
    SonarrSeries(id: 7, title: 'Blade Runner 2099', monitored: true);
const SonarrSeries _weekly = SonarrSeries(id: 8, title: 'Stick', monitored: true);

/// Ten episodes of one series at 07:30 on the 25th, and one of another at
/// 09:00 the next day. With [fifthAiredWithoutFile], episode 5 aired at 06:00
/// and has no file, so it is missing while the rest are still to air.
List<SonarrEpisode> _episodes({bool fifthAiredWithoutFile = false}) =>
    <SonarrEpisode>[
      for (int n = 1; n <= 10; n++)
        SonarrEpisode(
          id: n,
          seriesId: _drop.id,
          seasonNumber: 1,
          episodeNumber: n,
          title: 'Chapter $n',
          monitored: true,
          airDateUtc: (n == 5 && fifthAiredWithoutFile
                  ? DateTime(2026, 11, 25, 6)
                  : DateTime(2026, 11, 25, 7, 30))
              .toUtc()
              .toIso8601String(),
          series: _drop,
        ),
      SonarrEpisode(
        id: 99,
        seriesId: _weekly.id,
        seasonNumber: 2,
        episodeNumber: 5,
        title: 'Go Time!',
        monitored: true,
        airDateUtc: DateTime(2026, 11, 26, 9).toUtc().toIso8601String(),
        series: _weekly,
      ),
    ];

Future<void> _pump(
  WidgetTester tester, {
  bool listView = true,
  bool fifthAiredWithoutFile = false,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        preferencesProvider.overrideWith(
          () => _Prefs(Preferences(calendarListView: listView)),
        ),
        activeInstancesProvider.overrideWith((Ref ref) => <Instance>[_sonarr]),
        sonarrApiProvider(_sonarr).overrideWith(
          (Ref ref) async => SonarrApi(Dio(), apiKey: 'k'),
        ),
        sonarrCalendarProvider.overrideWith(
          (Ref ref, (Instance, DateTime, bool) key) async =>
              key.$2.month == 11
                  ? _episodes(fifthAiredWithoutFile: fifthAiredWithoutFile)
                  : <SonarrEpisode>[],
        ),
      ],
      child: MaterialApp(
        theme: AtriumTheme.light(null),
        home: const CalendarScreen(),
      ),
    ),
  );
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The morning of the 25th, before the drop airs.
final Clock _morning = Clock.fixed(DateTime(2026, 11, 25, 7));

void main() {
  testWidgets('a season drop is one card with +9 more',
      (WidgetTester tester) async {
    await withClock(_morning, () async {
      await _pump(tester);
      expect(find.text('Blade Runner 2099 - S01E01'), findsOneWidget);
      expect(find.text('Blade Runner 2099 - S01E02'), findsNothing);
      expect(find.text('+9 more'), findsOneWidget);
    });
  });

  testWidgets('a single episode gets no chip', (WidgetTester tester) async {
    await withClock(_morning, () async {
      await _pump(tester);
      expect(find.text('Stick - S02E05'), findsOneWidget);
      expect(find.textContaining('more'), findsOneWidget);
    });
  });

  testWidgets('the chip opens and closes the other episodes',
      (WidgetTester tester) async {
    await withClock(_morning, () async {
      await _pump(tester);
      expect(find.text('Chapter 2'), findsNothing);
      await tester.tap(find.text('+9 more'));
      await tester.pump();
      expect(find.text('S01E02'), findsOneWidget);
      expect(find.text('Chapter 2'), findsOneWidget);
      expect(find.text('Chapter 10'), findsOneWidget);
      // The first episode is the card itself, not listed again.
      expect(find.text('Chapter 1'), findsNothing);
      await tester.tap(find.text('+9 more'));
      await tester.pump();
      expect(find.text('Chapter 2'), findsNothing);
    });
  });

  testWidgets('a later episode aired without a file makes the card Missing',
      (WidgetTester tester) async {
    await withClock(_morning, () async {
      await _pump(tester, fifthAiredWithoutFile: true);
      final Finder card = find.ancestor(
        of: find.text('Blade Runner 2099 - S01E01'),
        matching: find.byType(Card),
      );
      expect(
        find.descendant(of: card, matching: find.text('Missing')),
        findsOneWidget,
      );
    });
  });

  testWidgets("the grid's day list is grouped too",
      (WidgetTester tester) async {
    await withClock(_morning, () async {
      await _pump(tester, listView: false);
      expect(find.text('Blade Runner 2099 - S01E01'), findsOneWidget);
      expect(find.text('Blade Runner 2099 - S01E02'), findsNothing);
      expect(find.text('+9 more'), findsOneWidget);
    });
  });
}
