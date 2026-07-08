import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_plex/service_plex.dart';

/// Deterministic render tests for the Plex parity work: the now-playing
/// controller screen and the home-hub Now Streaming row. Same harness shape
/// as `new_services_render_test.dart` - leaf providers overridden with fixed
/// data, a fixed number of pumps instead of pumpAndSettle (which would hang
/// on spinners).
Instance makeInstance() => Instance(
      id: 'test-plex',
      name: 'Test Plex',
      kind: ServiceKind.plex,
      localUrl: 'http://localhost',
      externalUrl: '',
      urlMode: UrlMode.auto,
      // Auth is irrelevant to these render tests (plexApiProvider is always
      // overridden); apiKey matches the existing PlexHome render test.
      auth: const InstanceAuth.apiKey(apiKey: 'k'),
    );

Future<void> pumpBody(
  WidgetTester tester,
  List<Override> overrides,
  Widget body, {
  int pumps = 3,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AtriumTheme.light(null),
        // Scaffold gives non-Scaffold bodies (PlexHome) a Material ancestor
        // for chips and ink wells; a nested Scaffold screen is fine too.
        home: Scaffold(body: body),
      ),
    ),
  );
  // Overridden FutureProviders complete on the next microtask; each pump
  // surfaces one async stage.
  for (int i = 0; i < pumps; i++) {
    await tester.pump();
  }
}

void main() {
  testWidgets('PlexSessionDetailScreen shows a controllable session',
      (WidgetTester tester) async {
    final Instance instance = makeInstance();
    const PlexSession session = PlexSession(
      title: 'Blade Runner',
      thumb: '/t/1',
      viewOffset: 600000,
      duration: 6000000,
      user: PlexSessionUser(title: 'alice'),
      player: PlexSessionPlayer(
        title: 'Living Room',
        product: 'Plex for Apple TV',
        machineIdentifier: 'abc',
        state: 'playing',
        protocolCapabilities: 'timeline,playback,navigation',
      ),
      session: PlexSessionInfo(id: 'sess-1', bandwidth: 4200, location: 'lan'),
    );
    await pumpBody(
      tester,
      <Override>[
        plexApiProvider(instance)
            .overrideWith((Ref ref) async => PlexApi(Dio(), token: 'tok')),
        plexSessionsProvider(instance)
            .overrideWith((Ref ref) async => <PlexSession>[session]),
      ],
      PlexSessionDetailScreen(instance: instance, initialSession: session),
    );
    expect(find.text('Blade Runner'), findsOneWidget);
    expect(find.textContaining('Living Room'), findsOneWidget);
    expect(find.text('Direct Play'), findsOneWidget);
    // Controllable -> transport controls present.
    expect(find.byIcon(Icons.pause), findsOneWidget);
  });

  testWidgets('non-controllable session hides transport controls',
      (WidgetTester tester) async {
    final Instance instance = makeInstance();
    const PlexSession session = PlexSession(
      title: 'Ep',
      grandparentTitle: 'Some Show',
      player: PlexSessionPlayer(
        title: 'Web',
        machineIdentifier: 'web1',
        state: 'paused',
        protocolCapabilities: 'timeline',
      ),
      session: PlexSessionInfo(id: 'sess-2'),
    );
    await pumpBody(
      tester,
      <Override>[
        plexApiProvider(instance)
            .overrideWith((Ref ref) async => PlexApi(Dio(), token: 'tok')),
        plexSessionsProvider(instance)
            .overrideWith((Ref ref) async => <PlexSession>[session]),
      ],
      PlexSessionDetailScreen(instance: instance, initialSession: session),
    );
    expect(find.text('Some Show'), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsNothing);
    expect(find.byIcon(Icons.play_arrow), findsNothing);
    expect(find.textContaining("can't be controlled"), findsOneWidget);
  });

  testWidgets('PlexHome hub shows a Now Streaming row',
      (WidgetTester tester) async {
    final Instance instance = makeInstance();
    await pumpBody(
      tester,
      <Override>[
        plexApiProvider(instance)
            .overrideWith((Ref ref) async => PlexApi(Dio(), token: 'tok')),
        plexLibrariesProvider(instance).overrideWith(
          (Ref ref) async => const <PlexLibrary>[
            PlexLibrary(key: '1', title: 'Movies', type: 'movie'),
          ],
        ),
        plexSessionsProvider(instance).overrideWith(
          (Ref ref) async => const <PlexSession>[
            PlexSession(
              title: 'Dune',
              player: PlexSessionPlayer(
                title: 'TV',
                machineIdentifier: 'x',
                state: 'playing',
              ),
              session: PlexSessionInfo(id: 's1'),
            ),
          ],
        ),
        plexOnDeckProvider(instance)
            .overrideWith((Ref ref) async => const <PlexMetadata>[]),
        plexRecentlyAddedProvider(instance)
            .overrideWith((Ref ref) async => const <PlexMetadata>[]),
      ],
      PlexHome(instance: instance),
      pumps: 4,
    );
    expect(find.text('Now Streaming'), findsOneWidget);
    expect(find.text('Dune'), findsOneWidget);
  });
}
