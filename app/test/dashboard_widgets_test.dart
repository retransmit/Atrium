import 'package:atrium/src/dashboard/dashboard_board.dart';
import 'package:atrium/src/dashboard/dashboard_widget_card.dart';
import 'package:atrium/src/dashboard/dashboard_widget_kind.dart';
import 'package:atrium/src/dashboard/widgets/disk_widget.dart';
import 'package:atrium/src/dashboard/widgets/downloads_widget.dart';
import 'package:atrium/src/dashboard/widgets/health_widget.dart';
import 'package:atrium/src/dashboard/widgets/requests_widget.dart';
import 'package:atrium/src/dashboard/widgets/streams_widget.dart';
import 'package:atrium/src/dashboard/widgets/upcoming_widget.dart';
import 'package:atrium/src/health_providers.dart';
import 'package:atrium/src/screens/calendar_screen.dart';
import 'package:core_models/core_models.dart';
import 'package:core_profile/core_profile.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_jellyfin/service_jellyfin.dart' as jf;
import 'package:service_qbittorrent/service_qbittorrent.dart';
import 'package:service_seerr/service_seerr.dart';
import 'package:service_sabnzbd/service_sabnzbd.dart';
import 'package:service_sonarr/service_sonarr.dart';
import 'package:service_tautulli/service_tautulli.dart';

/// Render tests for the dashboard widget board: each widget pumped with its
/// leaf providers overridden to fixed data, mirroring
/// new_services_render_test.dart's approach.
Instance makeInstance(ServiceKind kind) => Instance(
      id: 'test-${kind.name}',
      name: 'Test ${kind.displayName}',
      kind: kind,
      localUrl: 'http://localhost',
      externalUrl: '',
      urlMode: UrlMode.auto,
      auth: const InstanceAuth.apiKey(apiKey: 'k'),
    );

Future<void> pumpBody(
  WidgetTester tester,
  List<Override> overrides,
  Widget body, {
  int pumps = 2,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AtriumTheme.light(null),
        home: Scaffold(body: body),
      ),
    ),
  );
  for (int i = 0; i < pumps; i++) {
    await tester.pump();
  }
}

void main() {
  testWidgets('DashboardWidgetCard renders header, trailing and child',
      (WidgetTester tester) async {
    await pumpBody(
      tester,
      const <Override>[],
      Builder(
        builder: (BuildContext context) => DashboardWidgetCard(
          kind: DashboardWidgetKind.downloads,
          accent: Theme.of(context).colorScheme.primary,
          trailing: const Text('9 active'),
          child: const Text('card body'),
        ),
      ),
    );
    expect(find.text('Active downloads'), findsOneWidget);
    expect(find.text('9 active'), findsOneWidget);
    expect(find.text('card body'), findsOneWidget);
    expect(find.byIcon(Icons.download_rounded), findsOneWidget);
  });

  testWidgets('DashboardDownloadsWidget shows combined qBit + SAB items',
      (WidgetTester tester) async {
    final Instance qbit = makeInstance(ServiceKind.qbittorrent);
    final Instance sab = makeInstance(ServiceKind.sabnzbd);
    await pumpBody(
      tester,
      <Override>[
        qbitRawTorrentsProvider(qbit).overrideWith(
          (Ref ref) async => const <QbitTorrent>[
            QbitTorrent(
              hash: 'h1',
              name: 'Ubuntu ISO',
              state: 'downloading',
              progress: 0.45,
              dlspeed: 1048576,
            ),
          ],
        ),
        qbitTransferProvider(qbit).overrideWith(
          (Ref ref) async => const QbitTransferInfo(dlSpeed: 1048576),
        ),
        sabQueueProvider(sab).overrideWith(
          (Ref ref) async => const SabQueue(
            status: 'Downloading',
            speed: '2.0 M',
            slots: <SabSlot>[
              SabSlot(
                nzoId: 'n1',
                filename: 'Show.S01E01.mkv',
                percentage: '80',
                status: 'Downloading',
              ),
            ],
          ),
        ),
      ],
      DashboardDownloadsWidget(
        qbitInstances: <Instance>[qbit],
        sabInstances: <Instance>[sab],
      ),
    );
    expect(find.text('Ubuntu ISO'), findsOneWidget);
    expect(find.text('Show.S01E01.mkv'), findsOneWidget);
    expect(find.text('Active downloads'), findsOneWidget);
  });

  test('parseSabSpeed handles K/M/G suffixes and bare bytes', () {
    expect(parseSabSpeed('2.0 M'), 2 * 1024 * 1024);
    expect(parseSabSpeed('512 K'), 512 * 1024);
    expect(parseSabSpeed('100'), 100);
    expect(parseSabSpeed(''), 0);
    expect(parseSabSpeed('junk'), 0);
  });

  testWidgets('DashboardStreamsWidget shows Tautulli and Jellyfin sessions',
      (WidgetTester tester) async {
    final Instance tau = makeInstance(ServiceKind.tautulli);
    final Instance jelly = makeInstance(ServiceKind.jellyfin);
    await pumpBody(
      tester,
      <Override>[
        tautulliActivityProvider(tau).overrideWith(
          (Ref ref) async => const TautulliActivity(
            streamCount: 1,
            sessions: <TautulliSession>[
              TautulliSession(
                friendlyName: 'Alice',
                fullTitle: 'The Matrix',
                progressPercent: 30,
                state: 'playing',
              ),
            ],
          ),
        ),
        jf.jellyfinSessionsProvider(jelly).overrideWith(
          (Ref ref) => Stream<List<jf.ActiveSession>>.value(<jf.ActiveSession>[
            const jf.ActiveSession(
              id: 's1',
              user: 'Bob',
              device: 'Web',
              status: 'Playing',
              showTitle: 'Breaking Bad',
              episodeName: 'Pilot',
              progressPercent: 55,
              timePosition: '0:10:00',
              timeDuration: '0:45:00',
              positionTicks: 0,
              durationTicks: 0,
            ),
          ]),
        ),
      ],
      DashboardStreamsWidget(
        tautulliInstances: <Instance>[tau],
        jellyfinInstances: <Instance>[jelly],
        embyInstances: const <Instance>[],
      ),
    );
    expect(find.text('Now streaming'), findsOneWidget);
    expect(find.textContaining('The Matrix'), findsOneWidget);
    expect(find.textContaining('Breaking Bad'), findsOneWidget);
  });

  testWidgets('DashboardUpcomingWidget lists events inside the 7-day window',
      (WidgetTester tester) async {
    final Instance sonarr = makeInstance(ServiceKind.sonarr);
    final DateTime tomorrow = DateTime.now().add(const Duration(days: 1));
    final List<CalendarEvent> events = <CalendarEvent>[
      SonarrCalendarEvent(
        SonarrCalendarEntry(
          id: 1,
          seriesId: 10,
          title: 'Pilot',
          seasonNumber: 1,
          episodeNumber: 1,
          airDateUtc: tomorrow.toUtc(),
          hasFile: false,
          monitored: true,
          series: const SonarrSeries(id: 10, title: 'Test Show'),
        ),
        sonarr,
      ),
    ];
    await pumpBody(
      tester,
      <Override>[
        for (final DateTime m in upcomingWindowMonths(DateTime.now()))
          globalCalendarProvider(m).overrideWith((Ref ref) async => events),
      ],
      const DashboardUpcomingWidget(),
    );
    expect(find.text('Upcoming releases'), findsOneWidget);
    expect(find.textContaining('Test Show'), findsOneWidget);
  });

  testWidgets('DashboardHealthWidget shows per-instance chips and counts',
      (WidgetTester tester) async {
    final Instance ok = makeInstance(ServiceKind.sonarr);
    final Instance down = makeInstance(ServiceKind.radarr);
    await pumpBody(
      tester,
      <Override>[
        instanceHealthProvider(ok).overrideWith((Ref ref) async => Health.ok),
        instanceHealthProvider(down)
            .overrideWith((Ref ref) async => Health.error),
      ],
      DashboardHealthWidget(instances: <Instance>[ok, down]),
    );
    expect(find.text('Service health'), findsOneWidget);
    expect(find.text('Test Sonarr'), findsOneWidget);
    expect(find.text('Test Radarr'), findsOneWidget);
    expect(find.text('1 issue'), findsOneWidget);
  });

  testWidgets('DashboardRequestsWidget shows pending count and newest title',
      (WidgetTester tester) async {
    final Instance seerr = makeInstance(ServiceKind.seerr);
    await pumpBody(
      tester,
      <Override>[
        seerrRequestCountsProvider(seerr).overrideWith(
          (Ref ref) async => const SeerrCounts(total: 3, pending: 2),
        ),
        seerrRequestsProvider(seerr).overrideWith(
          (Ref ref) async => const <SeerrRequest>[
            SeerrRequest(
              id: 1,
              status: 1,
              type: 'movie',
              media: SeerrMedia(mediaType: 'movie', tmdbId: 603),
              requestedBy: SeerrUser(displayName: 'Bob'),
              createdAt: '2026-07-01T00:00:00Z',
            ),
          ],
        ),
        seerrMediaDetailsProvider(
          (instance: seerr, mediaType: 'movie', tmdbId: 603),
        ).overrideWith(
          (Ref ref) async =>
              const SeerrDiscoverResult(id: 603, title: 'The Matrix'),
        ),
      ],
      DashboardRequestsWidget(instances: <Instance>[seerr]),
      pumps: 3,
    );
    expect(find.text('Pending requests'), findsOneWidget);
    expect(find.text('2 pending'), findsOneWidget);
    expect(find.textContaining('The Matrix'), findsOneWidget);
    expect(find.textContaining('Bob'), findsOneWidget);
  });

  testWidgets('DashboardDiskWidget shows SAB free space',
      (WidgetTester tester) async {
    final Instance sab = makeInstance(ServiceKind.sabnzbd);
    await pumpBody(
      tester,
      <Override>[
        sabQueueProvider(sab).overrideWith(
          (Ref ref) async => const SabQueue(
            diskspace1: '250.0',
            diskspacetotal1: '1000.0',
          ),
        ),
      ],
      DashboardDiskWidget(
        sabInstances: <Instance>[sab],
        glancesInstances: const <Instance>[],
      ),
    );
    expect(find.text('Disk space'), findsOneWidget);
    expect(find.textContaining('250'), findsOneWidget);
  });

  testWidgets('DashboardBoard renders configured widgets and hides others',
      (WidgetTester tester) async {
    final Instance qbit = makeInstance(ServiceKind.qbittorrent);
    final Instance tau = makeInstance(ServiceKind.tautulli);
    await pumpBody(
      tester,
      <Override>[
        activeInstancesProvider.overrideWithValue(<Instance>[qbit, tau]),
        qbitRawTorrentsProvider(qbit).overrideWith(
          (Ref ref) async => const <QbitTorrent>[
            QbitTorrent(
              hash: 'h1',
              name: 'Ubuntu ISO',
              state: 'downloading',
              progress: 0.45,
            ),
          ],
        ),
        qbitTransferProvider(qbit).overrideWith(
          (Ref ref) async => const QbitTransferInfo(dlSpeed: 0),
        ),
        tautulliActivityProvider(tau).overrideWith(
          (Ref ref) async => const TautulliActivity(streamCount: 0),
        ),
        instanceHealthProvider(qbit).overrideWith((Ref ref) async => Health.ok),
        instanceHealthProvider(tau).overrideWith((Ref ref) async => Health.ok),
      ],
      const DashboardBoard(),
      pumps: 3,
    );
    expect(find.text('Active downloads'), findsOneWidget);
    expect(find.text('Ubuntu ISO'), findsOneWidget);
    expect(find.text('Now streaming'), findsOneWidget);
    expect(find.text('Service health'), findsOneWidget);
    // No sonarr/radarr, seerr, sab or glances configured:
    expect(find.text('Upcoming releases'), findsNothing);
    expect(find.text('Pending requests'), findsNothing);
    expect(find.text('Disk space'), findsNothing);
  });

  testWidgets('DashboardBoard edit mode reorders and hides widgets',
      (WidgetTester tester) async {
    final Instance qbit = makeInstance(ServiceKind.qbittorrent);
    await pumpBody(
      tester,
      <Override>[
        activeInstancesProvider.overrideWithValue(<Instance>[qbit]),
        dashboardEditModeProvider.overrideWith((Ref ref) => true),
      ],
      const DashboardBoard(),
    );
    // All six widgets are arrangeable in edit mode, configured or not.
    expect(find.byIcon(Icons.drag_indicator), findsNWidgets(6));
    expect(find.text('Hidden'), findsNothing);
    // Hide the first widget -> it moves to the Hidden section.
    await tester.tap(find.byIcon(Icons.visibility_off_outlined).first);
    await tester.pump();
    expect(find.text('Hidden'), findsOneWidget);
    expect(find.byIcon(Icons.drag_indicator), findsNWidgets(5));
    expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
  });
}
