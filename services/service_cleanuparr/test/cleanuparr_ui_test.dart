import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_cleanuparr/service_cleanuparr.dart';

const Instance testInstance = Instance(
  id: 'cleanuparr-1',
  name: 'Home Cleanuparr',
  kind: ServiceKind.cleanuparr,
  localUrl: 'http://cleanuparr.local:11011/',
  externalUrl: '',
  urlMode: UrlMode.auto,
  auth: InstanceAuthApiKey(apiKey: 'cleanuparr-secret-key'),
);

void main() {
  const CleanuparrStatus testStatus = CleanuparrStatus(
    version: '2.4.0',
    appName: 'Cleanuparr',
    memoryUsageMB: 128.0,
    mediaManagers: <CleanuparrManagerStatus>[
      CleanuparrManagerStatus(name: 'Sonarr', type: 'Sonarr'),
      CleanuparrManagerStatus(name: 'Radarr', type: 'Radarr'),
    ],
    downloadClients: <CleanuparrClientStatus>[
      CleanuparrClientStatus(name: 'qBittorrent', type: 'qBittorrent'),
    ],
  );

  const CleanuparrStats testStats = CleanuparrStats(
    hours: 168,
    totalEvents: 35,
    eventsWarning: 5,
    eventsError: 2,
    strikesIssued: 12,
    strikesRecovered: 4,
    activeStrikes: 2,
    malwareBlocked: 3,
    totalRemovals: 6,
    totalCleaned: 10,
    seekerTriggers: 8,
    seekerGrabbed: 3,
  );

  const List<CleanuparrJob> testJobs = <CleanuparrJob>[
    CleanuparrJob(
      jobType: 'MalwareBlocker',
      displayName: 'Malware Blocker',
      intervalDescription: 'Every 5m',
    ),
    CleanuparrJob(
      jobType: 'QueueCleaner',
      displayName: 'Queue Cleaner',
      intervalDescription: 'Every 15m',
    ),
  ];

  const List<CleanuparrStrikeItem> testStrikes = <CleanuparrStrikeItem>[
    CleanuparrStrikeItem(
      id: 'item-1',
      title: 'Severance.S02E01.1080p.WEB-DL',
      hash: '4a5b6c7d8e9f',
      strikeCount: 2,
      strikes: <CleanuparrStrikeDetail>[
        CleanuparrStrikeDetail(
          type: 'StalledStrike',
          reason: 'Download stalled with 0 B/s',
        ),
      ],
    ),
  ];

  final List<CleanuparrEvent> testEvents = <CleanuparrEvent>[
    CleanuparrEvent(
      id: 'ev-1',
      timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
      eventType: 'MalwareBlocked',
      severity: 'Error',
      message: 'Blocked download matching malicious pattern: crack.exe',
      downloadItemTitle: 'Sample.Release.Malware.exe',
      downloadClientName: 'qBittorrent',
      hash: 'abc12345',
    ),
  ];

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        cleanuparrStatusProvider(testInstance).overrideWith((ref) => testStatus),
        cleanuparrStatsProvider(testInstance).overrideWith((ref) => testStats),
        cleanuparrJobsProvider(testInstance).overrideWith((ref) => testJobs),
        cleanuparrStrikesProvider(testInstance).overrideWith((ref) => testStrikes),
        cleanuparrStrikesCountProvider(testInstance).overrideWith((ref) => 1),
        cleanuparrEventsProvider(testInstance).overrideWith((ref) => testEvents),
      ],
      child: const MaterialApp(
        home: CleanuparrHome(instance: testInstance),
      ),
    );
  }

  testWidgets(
    'CleanuparrHome renders 3 tabs, enables pull-to-refresh, and switches between Overview, Strikes, and Events',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Verify Tab 0: Overview
      expect(find.text('Overview'), findsWidgets);
      expect(find.text('Strikes'), findsWidgets);
      expect(find.text('Events'), findsWidgets);
      expect(find.byType(EasyRefresh), findsOneWidget);

      // System Status & Metrics
      expect(find.text('Cleanuparr'), findsOneWidget);
      expect(find.text('v2.4.0'), findsOneWidget);
      expect(find.text('Sonarr'), findsOneWidget);
      expect(find.text('Radarr'), findsOneWidget);
      expect(find.text('qBittorrent'), findsOneWidget);

      expect(find.text('Malware Blocked'), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // malware count
      expect(find.text('Active Strikes'), findsOneWidget);
      expect(find.text('Cleaned Torrents'), findsOneWidget);
      expect(find.text('Seeker Searches'), findsOneWidget);

      // Background Tasks
      expect(find.text('Background Tasks'), findsOneWidget);
      expect(find.text('Malware Blocker'), findsOneWidget);
      expect(find.text('Queue Cleaner'), findsOneWidget);

      // Switch to Tab 1: Strikes
      await tester.tap(find.text('Strikes').last);
      await tester.pumpAndSettle();

      expect(find.byType(EasyRefresh), findsOneWidget);
      expect(find.text('Strikes Ledger'), findsOneWidget);
      expect(find.text('Severance.S02E01.1080p.WEB-DL'), findsOneWidget);
      expect(find.text('2 strikes'), findsOneWidget);
      expect(find.text('4A5B6C7D'), findsOneWidget);
      expect(find.text('StalledStrike'), findsOneWidget);

      // Switch to Tab 2: Events
      await tester.tap(find.text('Events').last);
      await tester.pumpAndSettle();

      expect(find.byType(EasyRefresh), findsOneWidget);
      expect(find.text('Audit Events'), findsOneWidget);
      expect(find.text('MalwareBlocked'), findsOneWidget);
      expect(find.text('Sample.Release.Malware.exe'), findsOneWidget);

      // Tap event card to open bottom sheet
      await tester.tap(find.text('MalwareBlocked'));
      await tester.pumpAndSettle();

      expect(find.text('Release Title'), findsOneWidget);
      expect(find.text('abc12345'), findsOneWidget); // Hash
    },
  );

  testWidgets('the Strikes tab tells a pending removal from a done one', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cleanuparrStatusProvider(testInstance).overrideWith((ref) => testStatus),
          cleanuparrStatsProvider(testInstance).overrideWith((ref) => testStats),
          cleanuparrJobsProvider(testInstance).overrideWith((ref) => testJobs),
          cleanuparrStrikesProvider(testInstance).overrideWith(
            (ref) => const <CleanuparrStrikeItem>[
              CleanuparrStrikeItem(id: 'a', title: 'Still.Stalled'),
              CleanuparrStrikeItem(
                id: 'b',
                title: 'About.To.Go',
                strikeCount: 3,
                isMarkedForRemoval: true,
              ),
              CleanuparrStrikeItem(
                id: 'c',
                title: 'Already.Gone',
                strikeCount: 3,
                isRemoved: true,
              ),
            ],
          ),
          cleanuparrStrikesCountProvider(testInstance).overrideWith((ref) => 2),
          cleanuparrEventsProvider(testInstance).overrideWith((ref) => testEvents),
        ],
        child: const MaterialApp(home: CleanuparrHome(instance: testInstance)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Strikes').last);
    await tester.pumpAndSettle();

    expect(find.text('1 strike'), findsOneWidget);
    expect(find.text('3 strikes • Removal Pending'), findsOneWidget);
    expect(find.text('3 strikes • Removed'), findsOneWidget);
  });

  testWidgets('a server that is down reads as a message, not a stack of Dio text', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const NetworkException down =
        NetworkUnreachableException('Could not reach the server.');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cleanuparrStatusProvider(testInstance).overrideWith((ref) => throw down),
          cleanuparrStatsProvider(testInstance).overrideWith((ref) => throw down),
          cleanuparrJobsProvider(testInstance).overrideWith((ref) => throw down),
          cleanuparrStrikesProvider(testInstance).overrideWith((ref) => throw down),
          cleanuparrStrikesCountProvider(testInstance).overrideWith((ref) => throw down),
          cleanuparrEventsProvider(testInstance).overrideWith((ref) => throw down),
        ],
        child: const MaterialApp(home: CleanuparrHome(instance: testInstance)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Unable to load metrics: Could not reach the server.'),
      findsOneWidget,
    );
    expect(
      find.text('Could not load tasks: Could not reach the server.'),
      findsOneWidget,
    );
    expect(find.textContaining('Exception'), findsNothing);
  });
}
