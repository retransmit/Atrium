import 'dart:io';

import 'package:atrium/src/preferences.dart';
import 'package:atrium/src/screens/calendar_screen.dart';
import 'package:core_models/core_models.dart';
import 'package:core_profile/core_profile.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:service_radarr/service_radarr.dart';

class _TestPreferencesController extends PreferencesController {
  _TestPreferencesController([this._initial = const Preferences()]);
  final Preferences _initial;

  @override
  Preferences build() => _initial;

  @override
  Future<void> setCalendarListView(bool listView) async {
    state = state.copyWith(calendarListView: listView);
  }

  @override
  Future<void> setCalendarShowUnmonitored(bool show) async {
    state = state.copyWith(calendarShowUnmonitored: show);
  }
}

Instance _radarrInstance() => const Instance(
      id: 'test-radarr',
      name: 'Test Radarr',
      kind: ServiceKind.radarr,
      localUrl: 'http://localhost:7878',
      externalUrl: '',
      urlMode: UrlMode.auto,
      auth: InstanceAuth.apiKey(apiKey: 'k'),
    );

Future<void> _pumpCalendar(
  WidgetTester tester, {
  required Preferences initialPrefs,
  List<RadarrMovie> movies = const <RadarrMovie>[],
}) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final Instance radarr = _radarrInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        preferencesProvider.overrideWith(
          () => _TestPreferencesController(initialPrefs),
        ),
        activeInstancesProvider.overrideWith(
          (Ref ref) => <Instance>[radarr],
        ),
        radarrApiProvider(radarr).overrideWith(
          (Ref ref) async => RadarrApi(Dio(), apiKey: 'k'),
        ),
        radarrCalendarProvider.overrideWith(
          (Ref ref, (Instance, DateTime, bool) key) async => movies,
        ),
      ],
      child: MaterialApp(
        theme: AtriumTheme.light(null),
        home: const CalendarScreen(),
      ),
    ),
  );

  for (int i = 0; i < 3; i++) {
    await tester.pump();
  }
}

void main() {
  group('Preferences.calendarListView', () {
    test('defaults to false', () {
      const Preferences prefs = Preferences();
      expect(prefs.calendarListView, isFalse);
    });

    test('copyWith preserves or updates calendarListView', () {
      const Preferences prefs = Preferences();
      final Preferences updated = prefs.copyWith(calendarListView: true);
      expect(updated.calendarListView, isTrue);

      final Preferences unchanged = updated.copyWith();
      expect(unchanged.calendarListView, isTrue);

      final Preferences toggledBack = updated.copyWith(calendarListView: false);
      expect(toggledBack.calendarListView, isFalse);
    });
  });

  group('calendarListView in the settings box', () {
    late Directory tempDir;
    late Box<String> box;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('atrium_calendar');
      Hive.init(tempDir.path);
      box = await Hive.openBox<String>('settings');
    });

    tearDown(() async {
      await box.close();
      await Hive.deleteBoxFromDisk('settings');
      tempDir.deleteSync(recursive: true);
    });

    // A fresh container reads the box from scratch, the way a relaunch does.
    Preferences relaunch() {
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[settingsBoxProvider.overrideWithValue(box)],
      );
      addTearDown(container.dispose);
      return container.read(preferencesProvider);
    }

    test('the chosen view survives a relaunch', () async {
      final ProviderContainer first = ProviderContainer(
        overrides: <Override>[settingsBoxProvider.overrideWithValue(box)],
      );
      addTearDown(first.dispose);
      expect(first.read(preferencesProvider).calendarListView, isFalse);

      await first
          .read(preferencesProvider.notifier)
          .setCalendarListView(true);
      expect(relaunch().calendarListView, isTrue);

      await first
          .read(preferencesProvider.notifier)
          .setCalendarListView(false);
      expect(relaunch().calendarListView, isFalse);
    });
  });

  group('CalendarScreen view mode persistence', () {
    testWidgets('renders grid view by default and switches to list view on toggle',
        (WidgetTester tester) async {
      await _pumpCalendar(
        tester,
        initialPrefs: const Preferences(calendarListView: false),
      );

      // Initially in grid view: button tooltip indicates switching to list view
      expect(find.byTooltip('Switch to list view'), findsOneWidget);
      expect(find.byIcon(Icons.format_list_bulleted), findsOneWidget);
      expect(find.byTooltip('Switch to grid view'), findsNothing);

      // Tap the view switch button
      await tester.tap(find.byTooltip('Switch to list view'));
      await tester.pump();

      // State is updated and tooltip changes to 'Switch to grid view'
      expect(find.byTooltip('Switch to grid view'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_month), findsOneWidget);
      expect(find.byTooltip('Switch to list view'), findsNothing);
    });

    testWidgets('renders list view directly when calendarListView preference is true',
        (WidgetTester tester) async {
      final DateTime airDate = DateTime.now();
      await _pumpCalendar(
        tester,
        initialPrefs: const Preferences(calendarListView: true),
        movies: <RadarrMovie>[
          RadarrMovie(
            id: 1,
            title: 'Interstellar',
            year: 2014,
            inCinemas: airDate.toIso8601String(),
            monitored: true,
            hasFile: true,
          ),
        ],
      );

      // Directly renders list view mode upon launch
      expect(find.byTooltip('Switch to grid view'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_month), findsOneWidget);
      expect(find.byTooltip('Switch to list view'), findsNothing);
      expect(find.text('Interstellar'), findsOneWidget);

      // Tapping switches back to grid view
      await tester.tap(find.byTooltip('Switch to grid view'));
      await tester.pump();

      expect(find.byTooltip('Switch to list view'), findsOneWidget);
      expect(find.byIcon(Icons.format_list_bulleted), findsOneWidget);
    });
  });
}
