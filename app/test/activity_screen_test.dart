import 'package:atrium/src/screens/activity_screen.dart';
import 'package:core_models/core_models.dart';
import 'package:core_profile/core_profile.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_jellyfin/service_jellyfin.dart' as jf;
import 'package:service_plex/service_plex.dart';
import 'package:service_qbittorrent/service_qbittorrent.dart';
import 'package:service_sonarr/service_sonarr.dart';

/// Deterministic render tests for the cross-service Activity feed. Each test
/// pumps the real [ActivityScreen] with `activeInstancesProvider` plus every
/// watched source provider overridden to fixed data, proving the aggregation
/// providers and the screen render together (streams section, downloads
/// section, per-source error chips, and the empty state).
Instance _instance(ServiceKind kind) => Instance(
      id: 'test-${kind.name}',
      name: 'Test ${kind.displayName}',
      kind: kind,
      localUrl: 'http://localhost',
      externalUrl: '',
      urlMode: UrlMode.auto,
      auth: const InstanceAuth.apiKey(apiKey: 'k'),
    );

Future<void> _pump(
  WidgetTester tester,
  List<Override> overrides, {
  int pumps = 3,
}) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AtriumTheme.light(null),
        home: const ActivityScreen(),
      ),
    ),
  );
  // Overridden FutureProviders complete on the next microtask; each pump
  // surfaces one async stage (pumpAndSettle would hang on the loading
  // spinner, so a fixed number of frames is pumped instead).
  for (int i = 0; i < pumps; i++) {
    await tester.pump();
  }
}

void main() {
  testWidgets('renders Plex and Jellyfin streams with service chips',
      (WidgetTester tester) async {
    final Instance plex = _instance(ServiceKind.plex);
    final Instance jellyfin = _instance(ServiceKind.jellyfin);
    await _pump(
      tester,
      <Override>[
        activeInstancesProvider.overrideWith(
          (Ref ref) => <Instance>[plex, jellyfin],
        ),
        // A throwaway PlexApi so the stream mapper can call imageUrl()
        // without a live connection; the test asserts on titles, not art.
        plexApiProvider(plex).overrideWith(
          (Ref ref) async => PlexApi(Dio(), token: 'tok'),
        ),
        plexSessionsProvider(plex).overrideWith(
          (Ref ref) async => const <PlexSession>[
            PlexSession(
              title: 'Dune',
              viewOffset: 3000,
              duration: 6000,
              user: PlexSessionUser(title: 'alice'),
              player: PlexSessionPlayer(state: 'playing'),
            ),
          ],
        ),
        jf.jellyfinFastSessionsProvider(jellyfin).overrideWith(
          (Ref ref) => Stream<List<jf.ActiveSession>>.value(
            const <jf.ActiveSession>[
              jf.ActiveSession(
                id: 's1',
                user: 'bob',
                device: 'Jellyfin Web',
                status: 'Playing',
                showTitle: 'The Wire',
                progressPercent: 40,
                timePosition: '0:10:00',
                timeDuration: '1:00:00',
                positionTicks: 0,
                durationTicks: 0,
                volumeLevel: 100,
                isMuted: false,
              ),
            ],
          ),
        ),
      ],
    );
    expect(find.text('Now Streaming'), findsOneWidget);
    expect(find.text('Dune'), findsOneWidget);
    expect(find.text('The Wire'), findsOneWidget);
    expect(find.text('Plex'), findsOneWidget);
    expect(find.text('Jellyfin'), findsOneWidget);
  });

  testWidgets('renders qBittorrent and Sonarr downloads',
      (WidgetTester tester) async {
    final Instance qbit = _instance(ServiceKind.qbittorrent);
    final Instance sonarr = _instance(ServiceKind.sonarr);
    await _pump(
      tester,
      <Override>[
        activeInstancesProvider.overrideWith(
          (Ref ref) => <Instance>[qbit, sonarr],
        ),
        qbitRawTorrentsProvider(qbit).overrideWith(
          (Ref ref) async => const <QbitTorrent>[
            QbitTorrent(
              hash: 'h1',
              name: 'Ubuntu.iso',
              state: 'downloading',
              progress: 0.45,
              dlspeed: 1048576,
              size: 100000,
            ),
          ],
        ),
        sonarrQueueProvider(sonarr).overrideWith(
          (Ref ref) async => const <SonarrQueueItem>[
            SonarrQueueItem(
              id: 1,
              title: 'Severance.S01E01.1080p',
              status: 'downloading',
              size: 100,
              sizeleft: 55,
              timeleft: '00:10:00',
            ),
          ],
        ),
      ],
    );
    // 'Downloads' appears in the summary bar tile and the section header.
    expect(find.text('Downloads'), findsWidgets);
    expect(find.text('Ubuntu.iso'), findsOneWidget);
    expect(find.text('Severance.S01E01.1080p'), findsOneWidget);
  });

  testWidgets('an unreachable source shows a chip without hiding the rest',
      (WidgetTester tester) async {
    final Instance qbit = _instance(ServiceKind.qbittorrent);
    final Instance sonarr = _instance(ServiceKind.sonarr);
    await _pump(
      tester,
      <Override>[
        activeInstancesProvider.overrideWith(
          (Ref ref) => <Instance>[qbit, sonarr],
        ),
        qbitRawTorrentsProvider(qbit).overrideWith(
          (Ref ref) async => const <QbitTorrent>[
            QbitTorrent(
              hash: 'h1',
              name: 'Ubuntu.iso',
              state: 'downloading',
              progress: 0.45,
              dlspeed: 1048576,
              size: 100000,
            ),
          ],
        ),
        sonarrQueueProvider(sonarr).overrideWith(
          (Ref ref) async => throw StateError('server down'),
        ),
      ],
    );
    expect(find.text('Test Sonarr unreachable'), findsOneWidget);
    expect(find.text('Ubuntu.iso'), findsOneWidget);
  });

  testWidgets('all sources empty shows the empty state',
      (WidgetTester tester) async {
    final Instance plex = _instance(ServiceKind.plex);
    await _pump(
      tester,
      <Override>[
        activeInstancesProvider.overrideWith((Ref ref) => <Instance>[plex]),
        plexApiProvider(plex).overrideWith(
          (Ref ref) async => PlexApi(Dio(), token: 'tok'),
        ),
        plexSessionsProvider(plex).overrideWith(
          (Ref ref) async => const <PlexSession>[],
        ),
      ],
    );
    expect(find.text('Nothing happening right now'), findsOneWidget);
  });
}
