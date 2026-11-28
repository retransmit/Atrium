import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_tracearr/src/models/tracearr_models.dart';
import 'package:service_tracearr/src/providers/tracearr_providers.dart';
import 'package:service_tracearr/src/security/widgets/security_incident_ledger_section.dart';
import 'package:service_tracearr/src/tracearr_home.dart';

void main() {
  const testInstance = Instance(
    id: 'inst_tracearr_1',
    name: 'Main Tracearr',
    kind: ServiceKind.tracearr,
    localUrl: 'https://tr.example.com',
    externalUrl: '',
    urlMode: UrlMode.auto,
    auth: InstanceAuthApiKey(apiKey: 'dummy'),
  );

  Widget createOverviewWidget({
    TracearrHealthResponse? health,
    Object? healthError,
    List<TracearrStream>? streams,
    Object? streamsError,
    TracearrTodayStats? todayStats,
    Object? todayStatsError,
    List<TracearrViolationItem>? violations,
    Object? violationsError,
    TracearrActivityTrend? activity,
    Object? activityError,
  }) {
    return ProviderScope(
      overrides: [
        if (healthError != null)
          tracearrHealthProvider(testInstance)
              .overrideWith((ref) async => throw healthError)
        else if (health != null)
          tracearrHealthProvider(testInstance)
              .overrideWith((ref) async => health),
        if (streamsError != null)
          tracearrStreamsProvider(testInstance)
              .overrideWith((ref) async => throw streamsError)
        else if (streams != null)
          tracearrStreamsProvider(testInstance)
              .overrideWith((ref) async => streams),
        if (todayStatsError != null)
          tracearrTodayStatsProvider((testInstance, null, null))
              .overrideWith((ref) async => throw todayStatsError)
        else if (todayStats != null)
          tracearrTodayStatsProvider((testInstance, null, null))
              .overrideWith((ref) async => todayStats),
        if (violationsError != null)
          tracearrViolationsProvider(testInstance)
              .overrideWith((ref) async => throw violationsError)
        else if (violations != null)
          tracearrViolationsProvider(testInstance)
              .overrideWith((ref) async => violations),
        if (activityError != null)
          tracearrActivityProvider((testInstance, 'week', null, null))
              .overrideWith((ref) async => throw activityError)
        else if (activity != null)
          tracearrActivityProvider((testInstance, 'week', null, null))
              .overrideWith((ref) async => activity),
      ],
      child: const MaterialApp(
        home: TracearrHomeScreen(
          instance: testInstance,
        ),
      ),
    );
  }

  group('OverviewTab Destination', () {
    testWidgets('renders healthy fleet status, version, and server count',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const health = TracearrHealthResponse(
        status: 'ok',
        version: '2.4.1',
        servers: [
          TracearrServerStatus(
            id: 's1',
            name: 'Plex Server',
            type: 'plex',
            online: true,
          ),
          TracearrServerStatus(
            id: 's2',
            name: 'Jellyfin',
            type: 'jellyfin',
            online: true,
          ),
        ],
      );

      await tester.pumpWidget(
        createOverviewWidget(
          health: health,
          streams: const [],
          todayStats: const TracearrTodayStats(),
          violations: const [],
          activity: const TracearrActivityTrend(period: 'week'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('All Systems Operational'), findsOneWidget);
      expect(find.text('2 of 2 media servers reachable'), findsOneWidget);
      expect(find.text('v2.4.1'), findsOneWidget);
      expect(find.text('CONNECTED MEDIA SERVERS (2)'), findsOneWidget);
      expect(find.text('Plex Server'), findsOneWidget);
      expect(find.text('Jellyfin'), findsOneWidget);
    });

    testWidgets('renders degraded status when a server is offline',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const health = TracearrHealthResponse(
        status: 'degraded',
        servers: [
          TracearrServerStatus(
            id: 's1',
            name: 'Plex Server',
            type: 'plex',
            online: true,
          ),
          TracearrServerStatus(
            id: 's2',
            name: 'Jellyfin Backup',
            type: 'jellyfin',
            online: false,
          ),
        ],
      );

      await tester.pumpWidget(
        createOverviewWidget(
          health: health,
          streams: const [],
          todayStats: const TracearrTodayStats(),
          violations: const [],
          activity: const TracearrActivityTrend(period: 'week'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Degraded Performance'), findsOneWidget);
      expect(find.text('1 of 2 media servers reachable'), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);
    });

    testWidgets(
        'derives and renders active streams, direct play, and HW/SW transcodes',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const streams = [
        TracearrStream(
          id: 'st_1',
          serverId: 's1',
          serverName: 'Plex',
          serverType: 'plex',
          mediaTitle: 'Movie Direct',
          userUsername: 'User1',
          bitrate: 15000,
        ),
        TracearrStream(
          id: 'st_2',
          serverId: 's1',
          serverName: 'Plex',
          serverType: 'plex',
          mediaTitle: 'Movie HW',
          userUsername: 'User2',
          isTranscode: true,
          isHwTranscode: true,
          bitrate: 8000,
        ),
        TracearrStream(
          id: 'st_3',
          serverId: 's1',
          serverName: 'Plex',
          serverType: 'plex',
          mediaTitle: 'Movie SW',
          userUsername: 'User3',
          isTranscode: true,
          bitrate: 4000,
        ),
      ];

      await tester.pumpWidget(
        createOverviewWidget(
          health: const TracearrHealthResponse(status: 'ok'),
          streams: streams,
          todayStats: const TracearrTodayStats(),
          violations: const [],
          activity: const TracearrActivityTrend(period: 'week'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3'), findsWidgets);
      expect(find.text('Active Streams'), findsOneWidget);
      expect(find.text('Direct Play: 1'), findsOneWidget);
      expect(find.text('HW Transcode: 1'), findsOneWidget);
      expect(find.text('CPU Transcode: 1'), findsOneWidget);
      expect(find.text('27.0 Mbps'), findsOneWidget);
    });

    testWidgets('renders idle pulse card when active stream count is zero',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        createOverviewWidget(
          health: const TracearrHealthResponse(status: 'ok'),
          streams: const [],
          todayStats: const TracearrTodayStats(),
          violations: const [],
          activity: const TracearrActivityTrend(period: 'week'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0'), findsWidgets);
      expect(
        find.text('All connected media servers are currently idle.'),
        findsOneWidget,
      );
    });

    testWidgets('renders security alert callout and switches tab to Security',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const violations = [
        TracearrViolationItem(
          id: 'v_1',
          serverId: 's1',
          serverName: 'Plex',
          severity: 'critical',
          rule: 'Concurrent Stream Limit',
          username: 'BadActor',
        ),
      ];

      await tester.pumpWidget(
        createOverviewWidget(
          health: const TracearrHealthResponse(status: 'ok'),
          streams: const [],
          todayStats: const TracearrTodayStats(),
          violations: violations,
          activity: const TracearrActivityTrend(period: 'week'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 Unacknowledged Alert'), findsOneWidget);
      expect(
        find.text('Latest: Concurrent Stream Limit • @BadActor'),
        findsOneWidget,
      );

      // Tap alert callout
      await tester.tap(find.text('1 Unacknowledged Alert'));
      await tester.pumpAndSettle();

      // Should now be on Security destination
      expect(
        find.byType(SecurityIncidentLedgerSection),
        findsOneWidget,
      );
      expect(find.text('Concurrent Stream Limit'), findsOneWidget);
    });

    testWidgets('renders 24h fleet summary tiles accurately', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const today = TracearrTodayStats(
        todayPlays: 34,
        watchTimeHours: 14.8,
        activeUsersToday: 9,
        alertsLast24h: 2,
      );

      await tester.pumpWidget(
        createOverviewWidget(
          health: const TracearrHealthResponse(status: 'ok'),
          streams: const [],
          todayStats: today,
          violations: const [],
          activity: const TracearrActivityTrend(period: 'week'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('34'), findsOneWidget);
      expect(find.text('Plays Today'), findsOneWidget);
      expect(find.text('14.8h'), findsOneWidget);
      expect(find.text('Watch Time'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(find.text('Active Users'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('24h Alerts'), findsOneWidget);
    });

    testWidgets('renders 7-day activity trend histogram with buckets',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final activity = TracearrActivityTrend(
        period: 'week',
        rangeEnd: DateTime(2026, 8, 12, 10),
        plays: [
          TracearrActivityBucket(
            date: DateTime(2026, 8, 10),
            count: 12,
          ),
          TracearrActivityBucket(
            date: DateTime(2026, 8, 11),
            count: 25,
          ),
        ],
      );

      await tester.pumpWidget(
        createOverviewWidget(
          health: const TracearrHealthResponse(status: 'ok'),
          streams: const [],
          todayStats: const TracearrTodayStats(),
          violations: const [],
          activity: activity,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('7-DAY PLAYBACK ACTIVITY'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('25'), findsOneWidget);
    });

    testWidgets('shows one bar per day, adding up 6-hour buckets',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 6 to 12 August 2026 runs Thursday to Wednesday.
      final activity = TracearrActivityTrend(
        period: 'week',
        rangeEnd: DateTime(2026, 8, 12, 10),
        plays: [
          TracearrActivityBucket(date: DateTime(2026, 8, 10), count: 2),
          TracearrActivityBucket(date: DateTime(2026, 8, 10, 6), count: 3),
          TracearrActivityBucket(date: DateTime(2026, 8, 10, 18), count: 4),
          TracearrActivityBucket(date: DateTime(2026, 8, 12), count: 1),
        ],
      );

      await tester.pumpWidget(
        createOverviewWidget(
          health: const TracearrHealthResponse(status: 'ok'),
          streams: const [],
          todayStats: const TracearrTodayStats(),
          violations: const [],
          activity: activity,
        ),
      );
      await tester.pumpAndSettle();

      for (final day in ['Thu', 'Fri', 'Sat', 'Sun', 'Mon', 'Tue', 'Wed']) {
        expect(find.text(day), findsOneWidget, reason: day);
      }
      expect(find.text('9'), findsOneWidget);
      expect(find.text('2'), findsNothing);
    });

    testWidgets('a week with no plays says so', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        createOverviewWidget(
          health: const TracearrHealthResponse(status: 'ok'),
          streams: const [],
          todayStats: const TracearrTodayStats(),
          violations: const [],
          activity: TracearrActivityTrend(
            period: 'week',
            rangeEnd: DateTime(2026, 8, 12, 10),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('No playback activity recorded in the past 7 days.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'handles individual provider errors gracefully without blanking',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        createOverviewWidget(
          healthError: Exception('Health timeout'),
          streams: const [],
          todayStatsError: Exception('Stats unavailable'),
          violations: const [],
          activity: const TracearrActivityTrend(period: 'week'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Could not fetch server health status'),
        findsOneWidget,
      );
      expect(
        find.text('Failed to load 24h summary metrics'),
        findsOneWidget,
      );
      // Other sections still render
      expect(find.text('LIVE OPERATIONS'), findsOneWidget);
      expect(find.text('7-DAY PLAYBACK ACTIVITY'), findsOneWidget);
    });
  });
}
