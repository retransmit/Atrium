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
import 'package:service_radarr/service_radarr.dart';

class _Prefs extends PreferencesController {
  _Prefs(this._initial);
  final Preferences _initial;

  @override
  Preferences build() => _initial;

  @override
  Future<void> setCalendarListView(bool listView) async {
    state = state.copyWith(calendarListView: listView);
  }
}

const Instance _radarr = Instance(
  id: 'test-radarr',
  name: 'Test Radarr',
  kind: ServiceKind.radarr,
  localUrl: 'http://localhost:7878',
  externalUrl: '',
  urlMode: UrlMode.auto,
  auth: InstanceAuth.apiKey(apiKey: 'k'),
);

/// [perDay] movies in cinemas on each of [days] of [month]. The first of a
/// day is titled `M<month>-<day>`, any others `M<month>-<day>-<n>`.
List<RadarrMovie> _movies(
  DateTime month,
  Iterable<int> days, {
  int perDay = 1,
}) =>
    <RadarrMovie>[
      for (final int day in days)
        for (int n = 0; n < perDay; n++)
        RadarrMovie(
          id: month.month * 10000 + day * 100 + n,
          title: n == 0 ? 'M${month.month}-$day' : 'M${month.month}-$day-$n',
          year: month.year,
          inCinemas: DateTime(month.year, month.month, day, 12)
              .toIso8601String(),
          monitored: true,
          hasFile: false,
        ),
    ];

Iterable<int> _range(int from, int to) =>
    <int>[for (int d = from; d <= to; d++) d];

Future<void> _pump(
  WidgetTester tester, {
  required Iterable<int> Function(DateTime month) days,
  bool listView = true,
  int perDay = 1,
}) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        preferencesProvider.overrideWith(
          () => _Prefs(Preferences(calendarListView: listView)),
        ),
        activeInstancesProvider.overrideWith((Ref ref) => <Instance>[_radarr]),
        radarrApiProvider(_radarr).overrideWith(
          (Ref ref) async => RadarrApi(Dio(), apiKey: 'k'),
        ),
        radarrCalendarProvider.overrideWith(
          (Ref ref, (Instance, DateTime, bool) key) async =>
              _movies(key.$2, days(key.$2), perDay: perDay),
        ),
      ],
      child: MaterialApp(
        theme: AtriumTheme.light(null),
        home: const CalendarScreen(),
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Whether [title] is on screen, in the top third of it.
bool _nearTop(WidgetTester tester, String title) {
  final Finder f = find.text(title).hitTestable();
  return f.evaluate().isNotEmpty && tester.getTopLeft(f).dy < 400;
}

bool _visible(String title) =>
    find.text(title).hitTestable().evaluate().isNotEmpty;

void main() {
  final Clock nov21 = Clock.fixed(DateTime(2026, 11, 21, 9));

  testWidgets('the list opens at today', (WidgetTester tester) async {
    await withClock(nov21, () async {
      await _pump(tester, days: (_) => _range(1, 30));
      expect(_nearTop(tester, 'M11-21'), isTrue);
      expect(_visible('M11-1'), isFalse);
    });
  });

  testWidgets('with nothing today it opens at the next day with releases',
      (WidgetTester tester) async {
    await withClock(nov21, () async {
      await _pump(
        tester,
        days: (_) => _range(1, 30).where((int d) => d != 21),
      );
      expect(_nearTop(tester, 'M11-22'), isTrue);
      expect(_visible('M11-1'), isFalse);
    });
  });

  testWidgets('with everything past it opens at the latest release',
      (WidgetTester tester) async {
    await withClock(Clock.fixed(DateTime(2026, 11, 28, 9)), () async {
      await _pump(tester, days: (_) => _range(1, 25));
      expect(_visible('M11-25'), isTrue);
      expect(_visible('M11-1'), isFalse);
    });
  });

  testWidgets('Today scrolls back to today', (WidgetTester tester) async {
    await withClock(nov21, () async {
      await _pump(tester, days: (_) => _range(1, 30));
      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 4000),
        3000,
      );
      await _settle(tester);
      expect(_visible('M11-1'), isTrue);
      await tester.tap(find.widgetWithText(TextButton, 'Today'));
      await _settle(tester);
      expect(_nearTop(tester, 'M11-21'), isTrue);
    });
  });

  testWidgets('another month opens at its start', (WidgetTester tester) async {
    await withClock(nov21, () async {
      await _pump(tester, days: (_) => _range(1, 30));
      await tester.tap(find.byIcon(Icons.chevron_right));
      await _settle(tester);
      expect(_nearTop(tester, 'M12-1'), isTrue);
    });
  });

  testWidgets('switching from grid to list opens at today',
      (WidgetTester tester) async {
    await withClock(nov21, () async {
      await _pump(tester, days: (_) => _range(1, 30), listView: false);
      await tester.tap(find.byTooltip('Switch to list view'));
      await _settle(tester);
      expect(_nearTop(tester, 'M11-21'), isTrue);
    });
  });

  testWidgets('rows far from the screen are not built',
      (WidgetTester tester) async {
    await withClock(nov21, () async {
      await _pump(tester, days: (_) => _range(1, 30), perDay: 10);
      expect(_nearTop(tester, 'M11-21'), isTrue);
      // 300 releases; only those around what is on screen should exist,
      // since each row loads a poster.
      expect(
        find.textContaining('M11-', skipOffstage: false).evaluate().length,
        lessThan(60),
      );
    });
  });
}
