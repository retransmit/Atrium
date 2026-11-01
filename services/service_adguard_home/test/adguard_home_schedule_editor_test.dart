import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

void main() {
  const AdguardHomeSchedule weekend = AdguardHomeSchedule(
    timeZone: 'Europe/Berlin',
    pauses: <AdguardHomeServicePause>[
      AdguardHomeServicePause(
        day: 'sat',
        start: Duration(hours: 9),
        end: Duration(hours: 17),
      ),
      AdguardHomeServicePause(
        day: 'sun',
        start: Duration.zero,
        end: Duration(hours: 24),
      ),
    ],
  );

  /// Times the next taps on From or To will choose, in order.
  final List<Duration> picks = <Duration>[];

  Future<Duration?> pick(BuildContext _, Duration __) async =>
      picks.isEmpty ? null : picks.removeAt(0);

  /// Pumps the editor and returns what it last reported.
  Future<AdguardHomeSchedule? Function()> pumpEditor(
    WidgetTester tester, {
    AdguardHomeSchedule schedule = weekend,
    bool enabled = true,
    Size size = const Size(360, 2000),
    double textScale = 1,
  }) async {
    picks.clear();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    AdguardHomeSchedule? reported;
    AdguardHomeSchedule shown = schedule;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (BuildContext _, StateSetter setState) =>
                  AdguardHomeScheduleEditor(
                schedule: shown,
                enabled: enabled,
                pickTime: pick,
                onChanged: (AdguardHomeSchedule next) => setState(() {
                  reported = next;
                  shown = next;
                }),
              ),
            ),
          ),
        ),
      ),
    );
    return () => reported;
  }

  Finder dayTile(String day) => find.ancestor(
        of: find.text(day),
        matching: find.byType(ListTile),
      );

  Future<void> openDay(WidgetTester tester, String day) async {
    await tester.tap(find.text(day));
    await tester.pumpAndSettle();
  }

  Finder inSheet(Finder finder) => find.descendant(
        of: find.byType(AdguardHomePauseSheet),
        matching: finder,
      );

  testWidgets('lists the week from Monday with what pauses when',
      (WidgetTester tester) async {
    await pumpEditor(tester);

    expect(find.text('Europe/Berlin'), findsOneWidget);
    double last = -1;
    for (final String day in <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ]) {
      final double y = tester.getTopLeft(find.text(day)).dy;
      expect(y, greaterThan(last), reason: day);
      last = y;
    }
    expect(find.text('Not paused'), findsNWidgets(5));
    expect(
      find.descendant(of: dayTile('Saturday'), matching: find.text('09:00 to 17:00')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dayTile('Sunday'), matching: find.text('All day')),
      findsOneWidget,
    );
  });

  testWidgets('a day opens with its own times', (WidgetTester tester) async {
    await pumpEditor(tester);

    await openDay(tester, 'Saturday');

    expect(inSheet(find.text('09:00')), findsOneWidget);
    expect(inSheet(find.text('17:00')), findsOneWidget);
    final SwitchListTile pause = tester.widget<SwitchListTile>(
      inSheet(find.widgetWithText(SwitchListTile, 'Pause blocking')),
    );
    expect(pause.value, isTrue);
  });

  testWidgets('new times for a day are saved, the other days kept',
      (WidgetTester tester) async {
    final AdguardHomeSchedule? Function() reported = await pumpEditor(tester);
    await openDay(tester, 'Saturday');
    picks.addAll(const <Duration>[
      Duration(hours: 10, minutes: 30),
      Duration(hours: 12),
    ]);

    await tester.tap(inSheet(find.text('09:00')));
    await tester.pumpAndSettle();
    await tester.tap(inSheet(find.text('17:00')));
    await tester.pumpAndSettle();
    await tester.tap(inSheet(find.text('Save')));
    await tester.pumpAndSettle();

    final AdguardHomeSchedule schedule = reported()!;
    expect(schedule.pauseOn('sat')!.start, const Duration(hours: 10, minutes: 30));
    expect(schedule.pauseOn('sat')!.end, const Duration(hours: 12));
    expect(schedule.pauseOn('sun')!.end, const Duration(hours: 24));
    expect(schedule.timeZone, 'Europe/Berlin');
    expect(find.text('10:30 to 12:00'), findsOneWidget);
  });

  testWidgets('a pause that is turned off leaves that day',
      (WidgetTester tester) async {
    final AdguardHomeSchedule? Function() reported = await pumpEditor(tester);
    await openDay(tester, 'Sunday');

    await tester.tap(inSheet(find.text('Pause blocking')));
    await tester.pumpAndSettle();
    await tester.tap(inSheet(find.text('Remove pause')));
    await tester.pumpAndSettle();

    expect(reported()!.pauseOn('sun'), isNull);
    expect(reported()!.pauseOn('sat'), isNotNull);
  });

  testWidgets('a new pause starts as working hours, and can run to the end '
      'of the day', (WidgetTester tester) async {
    final AdguardHomeSchedule? Function() reported = await pumpEditor(tester);
    await openDay(tester, 'Monday');

    expect(
      tester
          .widget<SwitchListTile>(
            inSheet(find.widgetWithText(SwitchListTile, 'Pause blocking')),
          )
          .value,
      isTrue,
    );
    await tester.tap(inSheet(find.text('Until the end of the day')));
    await tester.pumpAndSettle();
    await tester.tap(inSheet(find.text('Add pause')));
    await tester.pumpAndSettle();

    expect(reported()!.pauseOn('mon')!.start, const Duration(hours: 9));
    expect(reported()!.pauseOn('mon')!.end, const Duration(hours: 24));
  });

  testWidgets('the same pause can go to other days at once',
      (WidgetTester tester) async {
    final AdguardHomeSchedule? Function() reported = await pumpEditor(tester);
    await openDay(tester, 'Monday');

    await tester.tap(inSheet(find.widgetWithText(FilterChip, 'Tue')));
    await tester.pump();
    await tester.tap(inSheet(find.widgetWithText(FilterChip, 'Fri')));
    await tester.pump();
    await tester.tap(inSheet(find.text('Add pause')));
    await tester.pumpAndSettle();

    final AdguardHomeSchedule schedule = reported()!;
    expect(
      schedule.pauses.map((AdguardHomeServicePause pause) => pause.day),
      <String>['mon', 'tue', 'fri', 'sat', 'sun'],
    );
    expect(schedule.pauseOn('fri')!.start, schedule.pauseOn('mon')!.start);
  });

  testWidgets('the button says what it will do', (WidgetTester tester) async {
    await pumpEditor(tester);
    await openDay(tester, 'Monday');

    // Opened to add a pause, so it is on, and the button says so.
    expect(inSheet(find.widgetWithText(FilledButton, 'Add pause')), findsOneWidget);
    await tester.tap(inSheet(find.text('Pause blocking')));
    await tester.pumpAndSettle();
    expect(inSheet(find.widgetWithText(FilledButton, 'Save')), findsOneWidget);

    await tester.tap(inSheet(find.text('Cancel')));
    await tester.pumpAndSettle();
    await openDay(tester, 'Saturday');
    expect(inSheet(find.widgetWithText(FilledButton, 'Save')), findsOneWidget);
    await tester.tap(inSheet(find.text('Pause blocking')));
    await tester.pumpAndSettle();
    expect(
      inSheet(find.widgetWithText(FilledButton, 'Remove pause')),
      findsOneWidget,
    );
  });

  testWidgets('an end before the start says so and cannot be saved',
      (WidgetTester tester) async {
    final AdguardHomeSchedule? Function() reported = await pumpEditor(tester);
    await openDay(tester, 'Saturday');
    picks.add(const Duration(hours: 8));

    await tester.tap(inSheet(find.text('17:00')));
    await tester.pumpAndSettle();

    expect(
      inSheet(find.text('The end has to be after the start.')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(inSheet(find.widgetWithText(FilledButton, 'Save')))
          .onPressed,
      isNull,
    );
    expect(reported(), isNull);
  });

  testWidgets('a time not picked changes nothing', (WidgetTester tester) async {
    await pumpEditor(tester);
    await openDay(tester, 'Saturday');

    await tester.tap(inSheet(find.text('09:00')));
    await tester.pumpAndSettle();

    expect(inSheet(find.text('09:00')), findsOneWidget);
  });

  testWidgets('Cancel changes nothing', (WidgetTester tester) async {
    final AdguardHomeSchedule? Function() reported = await pumpEditor(tester);
    await openDay(tester, 'Saturday');

    await tester.tap(inSheet(find.text('Pause blocking')));
    await tester.pump();
    await tester.tap(inSheet(find.text('Cancel')));
    await tester.pumpAndSettle();

    expect(reported(), isNull);
    expect(find.text('09:00 to 17:00'), findsOneWidget);
  });

  testWidgets('switched off, nothing in it can be opened',
      (WidgetTester tester) async {
    await pumpEditor(tester, enabled: false);

    await tester.tap(find.text('Saturday'));
    await tester.pumpAndSettle();
    expect(find.byType(AdguardHomePauseSheet), findsNothing);

    await tester.tap(find.text('Europe/Berlin'));
    await tester.pumpAndSettle();
    expect(find.byType(AdguardHomeTimeZoneScreen), findsNothing);
  });

  group('the time zone', () {
    testWidgets('is picked from a list that can be searched',
        (WidgetTester tester) async {
      final AdguardHomeSchedule? Function() reported = await pumpEditor(tester);

      await tester.tap(find.text('Europe/Berlin'));
      await tester.pumpAndSettle();
      expect(find.byType(AdguardHomeTimeZoneScreen), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'tokyo');
      await tester.pump();
      expect(find.text('Asia/Tokyo'), findsOneWidget);
      expect(find.text('Europe/Berlin'), findsNothing);

      await tester.tap(find.text('Asia/Tokyo'));
      await tester.pumpAndSettle();

      expect(reported()!.timeZone, 'Asia/Tokyo');
      expect(reported()!.pauses, hasLength(2));
      expect(find.text('Asia/Tokyo'), findsOneWidget);
    });

    testWidgets('can be the server\'s own', (WidgetTester tester) async {
      final AdguardHomeSchedule? Function() reported = await pumpEditor(tester);

      await tester.tap(find.text('Europe/Berlin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text("The server's time zone"));
      await tester.pumpAndSettle();

      expect(reported()!.timeZone, 'Local');
    });

    testWidgets('going back keeps it', (WidgetTester tester) async {
      final AdguardHomeSchedule? Function() reported = await pumpEditor(tester);

      await tester.tap(find.text('Europe/Berlin'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(reported(), isNull);
    });
  });

  for (final double width in <double>[320, 360, 411]) {
    for (final double scale in <double>[1, 2]) {
      testWidgets('layout holds at $width wide and $scale text',
          (WidgetTester tester) async {
        await pumpEditor(
          tester,
          size: Size(width, 3000),
          textScale: scale,
        );
        expect(tester.takeException(), isNull);

        await openDay(tester, 'Saturday');
        picks.add(const Duration(hours: 18));
        await tester.tap(inSheet(find.text('09:00')));
        await tester.pumpAndSettle();
        expect(
          inSheet(find.text('The end has to be after the start.')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
