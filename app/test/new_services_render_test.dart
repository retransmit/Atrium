import 'package:core_models/core_models.dart';
import 'package:core_profile/core_profile.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_bazarr/service_bazarr.dart';
import 'package:service_seerr/service_seerr.dart';
import 'package:service_plex/service_plex.dart';
import 'package:service_radarr/service_radarr.dart';
import 'package:service_sabnzbd/service_sabnzbd.dart';
import 'package:service_tautulli/service_tautulli.dart';
import 'package:atrium/src/screens/calendar_screen.dart';

/// Deterministic render tests for the service modules added in the final pass.
///
/// Emulator UI-automation of the Add-service dropdown proved flaky, so instead
/// of driving taps we pump each `*Home` widget directly with its leaf data
/// provider overridden to fixed data. This exercises the real widget tree of
/// each new module and asserts it renders the expected content - proving the
/// screens are wired and build, not just that they compile.
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
  List<Override> overrides,
  Widget home, {
  int pumps = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AtriumTheme.light(null),
        home: Scaffold(body: home),
      ),
    ),
  );
  // Overridden FutureProviders complete on the next microtask; each pump
  // surfaces one async stage. Screens with nested providers (e.g. Plex:
  // libraries → items grid) need more than one. pumpAndSettle would hang on
  // the loading spinner, so we pump a fixed number of frames instead.
  for (int i = 0; i < pumps; i++) {
    await tester.pump();
  }
}

void main() {
  testWidgets('SabnzbdHome renders queue slots', (WidgetTester tester) async {
    final Instance instance = _instance(ServiceKind.sabnzbd);
    await _pump(
      tester,
      <Override>[
        sabQueueProvider(instance).overrideWith(
          (Ref ref) async => const SabQueue(
            status: 'Downloading',
            speed: '1.2 M',
            slots: <SabSlot>[
              SabSlot(
                nzoId: '1',
                filename: 'Ubuntu.24.04.iso',
                percentage: '45',
                status: 'Downloading',
                timeleft: '0:05:00',
              ),
            ],
          ),
        ),
      ],
      SabnzbdHome(instance: instance),
    );
    expect(find.text('Ubuntu.24.04.iso'), findsOneWidget);
  });

  testWidgets('TautulliHome renders active streams', (WidgetTester tester) async {
    final Instance instance = _instance(ServiceKind.tautulli);
    await _pump(
      tester,
      <Override>[
        tautulliActivityProvider(instance).overrideWith(
          (Ref ref) async => const TautulliActivity(
            streamCount: 1,
            sessions: <TautulliSession>[
              TautulliSession(
                friendlyName: 'Alice',
                fullTitle: 'The Matrix',
                progressPercent: 30,
                state: 'playing',
                player: 'Living Room TV',
              ),
            ],
          ),
        ),
      ],
      TautulliHome(instance: instance),
    );
    expect(find.text('The Matrix'), findsOneWidget);
  });

  testWidgets('SeerrHome renders a request with its media details',
      (WidgetTester tester) async {
    final Instance instance = _instance(ServiceKind.seerr);
    await _pump(
      tester,
      <Override>[
        seerrRequestsProvider(instance).overrideWith(
          (Ref ref) async => const <SeerrRequest>[
            SeerrRequest(
              id: 1,
              status: 1,
              type: 'movie',
              media: SeerrMedia(mediaType: 'movie', tmdbId: 603, status: 5),
              requestedBy: SeerrUser(displayName: 'Bob'),
            ),
          ],
        ),
        // The request tile resolves the title from Seerr's media details.
        seerrMediaDetailsProvider(
          (instance: instance, mediaType: 'movie', tmdbId: 603),
        ).overrideWith(
          (Ref ref) async => const SeerrDiscoverResult(
            id: 603,
            mediaType: 'movie',
            title: 'The Matrix',
          ),
        ),
      ],
      SeerrHome(instance: instance),
      pumps: 4,
    );
    expect(find.text('The Matrix'), findsOneWidget);
    // The redesigned SeerrRequestCard shows the requester name next to an
    // avatar (no "Requested by:" prefix).
    expect(find.text('Bob'), findsOneWidget);
  });

  testWidgets('BazarrHome renders wanted-subtitles rows', (WidgetTester tester) async {
    final Instance instance = _instance(ServiceKind.bazarr);
    await _pump(
      tester,
      <Override>[
        bazarrBadgesProvider(instance).overrideWith(
          (Ref ref) async =>
              const BazarrBadges(episodes: 3, movies: 1, providers: 5),
        ),
        bazarrWantedProvider(instance).overrideWith(
          (Ref ref) async => const <BazarrWantedRow>[
            BazarrWantedRow(
              title: 'Breaking Bad',
              subtitle: 'S01E01 · Pilot',
              missing: <BazarrSubtitle>[BazarrSubtitle(name: 'English', code2: 'en')],
              isMovie: false,
            ),
          ],
        ),
        bazarrSeriesProvider(instance).overrideWith(
          (Ref ref) async => const <BazarrSeries>[],
        ),
        bazarrMoviesProvider(instance).overrideWith(
          (Ref ref) async => const <BazarrMovie>[],
        ),
      ],
      BazarrHome(instance: instance),
    );
    // Wanted is the third tab now; switch to it before asserting.
    await tester.tap(find.text('Wanted'));
    await tester.pump(); // register the tap, start the tab animation
    await tester.pump(const Duration(milliseconds: 400)); // finish animation
    await tester.pump(); // let the wanted provider resolve and render
    expect(find.text('Breaking Bad'), findsOneWidget);
  });

  testWidgets('PlexHome renders hub sections', (WidgetTester tester) async {
    final Instance instance = _instance(ServiceKind.plex);
    await _pump(
      tester,
      <Override>[
        // A throwaway PlexApi so the poster card can call imageUrl() without a
        // live connection; the test asserts on the title, not the poster.
        plexApiProvider(instance).overrideWith(
          (Ref ref) async => PlexApi(Dio(), token: 'tok'),
        ),
        plexLibrariesProvider(instance).overrideWith(
          (Ref ref) async => const <PlexLibrary>[
            PlexLibrary(key: '1', title: 'Movies', type: 'movie'),
          ],
        ),
        // No active streams: the Now Streaming row renders nothing (and the
        // real sessions poller must not run in tests).
        plexSessionsProvider(instance).overrideWith(
          (Ref ref) async => const <PlexSession>[],
        ),
        // The Home tab is the default view, so it renders the on-deck and
        // recently-added rows rather than a library grid.
        plexOnDeckProvider(instance).overrideWith(
          (Ref ref) async => const <PlexMetadata>[
            PlexMetadata(
              ratingKey: '10',
              title: 'Blade Runner',
              year: 1982,
              type: 'movie',
              viewOffset: 600000,
              duration: 6000000,
            ),
          ],
        ),
        plexRecentlyAddedProvider(instance).overrideWith(
          (Ref ref) async => const <PlexMetadata>[],
        ),
        // The hub renders a row per library, so its items provider must be
        // overridden too (a real fetch would leave a pending timer).
        plexItemsProvider((instance, '1')).overrideWith(
          (Ref ref) async => const <PlexMetadata>[],
        ),
      ],
      PlexHome(instance: instance),
      pumps: 4,
    );
    expect(find.text('Continue Watching'), findsOneWidget);
    // Once in the featured hero, once in the Continue Watching row.
    expect(find.text('Blade Runner'), findsNWidgets(2));
    expect(find.text('Movies'), findsOneWidget);
  });

  testWidgets('CalendarScreen renders Radarr aggregated entries', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final Instance radarr = _instance(ServiceKind.radarr);
    final DateTime airDate = DateTime.now();

    await _pump(
      tester,
      <Override>[
        activeInstancesProvider.overrideWith(
          (Ref ref) => <Instance>[radarr],
        ),
        radarrApiProvider(radarr).overrideWith(
          (Ref ref) async => RadarrApi(Dio(), apiKey: 'k'),
        ),
        radarrCalendarProvider.overrideWith(
          (Ref ref, (Instance, DateTime) key) async => <RadarrMovie>[
            RadarrMovie(
              id: 1,
              title: 'Inception',
              year: 2010,
              inCinemas: airDate.toIso8601String(),
              monitored: true,
              hasFile: false,
            ),
          ],
        ),
      ],
      const CalendarScreen(),
      pumps: 3,
    );

    expect(find.text('Inception'), findsOneWidget);
    expect(find.text('Missing'), findsOneWidget);
  });

}
