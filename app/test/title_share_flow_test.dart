import 'package:atrium/src/share_intake/title_resolver.dart';
import 'package:atrium/src/share_intake/title_share.dart';
import 'package:atrium/src/share_intake/title_share_flow.dart';
import 'package:core_models/core_models.dart';
import 'package:core_profile/core_profile.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_radarr/service_radarr.dart';
import 'package:service_sonarr/service_sonarr.dart';

Instance _instance(String name, ServiceKind kind) => Instance(
      id: name,
      name: name,
      kind: kind,
      localUrl: 'http://localhost',
      externalUrl: '',
      urlMode: UrlMode.auto,
      auth: const InstanceAuth.apiKey(apiKey: 'k'),
    );

final Instance _radarr = _instance('Radarr Test', ServiceKind.radarr);
final Instance _radarr2 = _instance('Radarr Two', ServiceKind.radarr);
final Instance _sonarr = _instance('Sonarr Test', ServiceKind.sonarr);
final Instance _sonarr2 = _instance('Sonarr Two', ServiceKind.sonarr);

/// What the flow did at the end, captured instead of building the real
/// detail screen or add sheet, which need a live server's providers.
class _Outcome {
  final List<String> told = <String>[];
  TitleMatch? opened;
  Instance? openedOn;
  TitleMatch? adding;
  Instance? addingOn;
}

Future<_Outcome> _run(
  WidgetTester tester,
  TitleShare share, {
  List<Instance>? instances,
  MovieLookup? lookupMovies,
  SeriesLookup? lookupSeries,
  List<Instance>? within,
  bool settle = true,
}) async {
  final _Outcome outcome = _Outcome();
  final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();
  final List<Instance> active = instances ?? <Instance>[_radarr, _sonarr];
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        activeInstancesProvider.overrideWithValue(active),
        for (final Instance i in active)
          if (i.kind == ServiceKind.radarr)
            radarrApiProvider(i).overrideWith((Ref ref) => RadarrApi(Dio()))
          else if (i.kind == ServiceKind.sonarr)
            sonarrApiProvider(i).overrideWith((Ref ref) => SonarrApi(Dio())),
      ],
      child: MaterialApp(
        navigatorKey: navigator,
        home: Consumer(
          builder: (BuildContext context, WidgetRef ref, _) => Scaffold(
            body: ElevatedButton(
              onPressed: () => runTitleShare(
                ref,
                share,
                presentContext: () => navigator.currentContext,
                tell: (String message) async => outcome.told.add(message),
                lookupMovies: lookupMovies ??
                    (Instance i, String term) async => <RadarrMovie>[],
                lookupSeries: lookupSeries ??
                    (Instance i, String term) async => <SonarrSeries>[],
                readLetterboxd: (Uri _) async => null,
                within: within,
                openExisting: (BuildContext c, Instance on, TitleMatch m) async {
                  outcome
                    ..opened = m
                    ..openedOn = on;
                },
                openAdd: (BuildContext c, Instance on, TitleMatch m) async {
                  outcome
                    ..adding = m
                    ..addingOn = on;
                },
              ),
              child: const Text('Share'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Share'));
  if (settle) {
    await tester.pumpAndSettle();
  }
  return outcome;
}

void main() {
  testWidgets('a title already in the library opens it',
      (WidgetTester tester) async {
    final _Outcome o = await _run(
      tester,
      const TitleShare(kind: TitleKind.movie, imdbId: 'tt0086567'),
      lookupMovies: (Instance i, String term) async => <RadarrMovie>[
        const RadarrMovie(id: 7, title: 'WarGames', tmdbId: 860),
      ],
    );
    expect((o.opened! as MovieMatch).movie.id, 7);
    expect(o.openedOn, _radarr);
    expect(o.adding, isNull);
  });

  testWidgets('a new title opens the add sheet', (WidgetTester tester) async {
    final _Outcome o = await _run(
      tester,
      const TitleShare(kind: TitleKind.movie, imdbId: 'tt0086567'),
      lookupMovies: (Instance i, String term) async => <RadarrMovie>[
        const RadarrMovie(title: 'WarGames', tmdbId: 860),
      ],
    );
    expect((o.adding! as MovieMatch).movie.title, 'WarGames');
    expect(o.opened, isNull);
  });

  testWidgets('nothing found says so', (WidgetTester tester) async {
    final _Outcome o = await _run(
      tester,
      const TitleShare(kind: TitleKind.unknown, title: 'Nope'),
    );
    expect(o.told.single, contains('Could not find that title'));
    expect(o.adding, isNull);
  });

  testWidgets('an unreachable server is named', (WidgetTester tester) async {
    final _Outcome o = await _run(
      tester,
      const TitleShare(kind: TitleKind.movie, title: 'WarGames'),
      lookupMovies: (Instance i, String term) async =>
          throw Exception('down'),
    );
    expect(o.told.single, contains('Could not reach Radarr Test'));
  });

  testWidgets('a movie with no Radarr set up says so',
      (WidgetTester tester) async {
    final _Outcome o = await _run(
      tester,
      const TitleShare(kind: TitleKind.movie, title: 'WarGames'),
      instances: <Instance>[_sonarr],
    );
    expect(o.told.single, contains('No Radarr is set up'));
  });

  testWidgets('a title search shows the picker', (WidgetTester tester) async {
    final _Outcome o = await _run(
      tester,
      const TitleShare(kind: TitleKind.unknown, title: 'Dune'),
      lookupMovies: (Instance i, String term) async => <RadarrMovie>[
        const RadarrMovie(title: 'Dune', year: 1984, tmdbId: 841),
        const RadarrMovie(title: 'Dune', year: 2021, tmdbId: 438631),
      ],
    );
    expect(find.text('Pick the title'), findsOneWidget);
    await tester.tap(find.text('Dune (2021)'));
    await tester.pumpAndSettle();
    expect((o.adding! as MovieMatch).movie.tmdbId, 438631);
  });

  testWidgets(
      'a title in the first Radarr but not found on the chosen one opens the '
      'add sheet, not the first library entry',
      (WidgetTester tester) async {
    final _Outcome o = await _run(
      tester,
      const TitleShare(kind: TitleKind.movie, imdbId: 'tt0086567'),
      instances: <Instance>[_radarr, _radarr2],
      lookupMovies: (Instance i, String term) async => i == _radarr
          ? <RadarrMovie>[
              const RadarrMovie(id: 7, title: 'WarGames', tmdbId: 860),
            ]
          : <RadarrMovie>[],
    );
    await tester.tap(find.text('Radarr Two'));
    await tester.pumpAndSettle();
    expect(o.opened, isNull);
    expect(o.addingOn, _radarr2);
    expect((o.adding! as MovieMatch).movie.id, 0);
  });

  testWidgets('two Radarrs ask which, and the chosen one is checked again',
      (WidgetTester tester) async {
    final List<String> asked = <String>[];
    final _Outcome o = await _run(
      tester,
      const TitleShare(kind: TitleKind.movie, imdbId: 'tt0086567'),
      instances: <Instance>[_radarr, _radarr2],
      lookupMovies: (Instance i, String term) async {
        asked.add('${i.name}|$term');
        // Only the second Radarr already has it.
        return <RadarrMovie>[
          RadarrMovie(
            id: i == _radarr2 ? 12 : 0,
            title: 'WarGames',
            tmdbId: 860,
          ),
        ];
      },
    );
    expect(find.text('Add to'), findsOneWidget);
    await tester.tap(find.text('Radarr Two'));
    await tester.pumpAndSettle();
    expect(asked, <String>[
      'Radarr Test|imdb:tt0086567',
      'Radarr Two|tmdb:860',
    ]);
    expect(o.openedOn, _radarr2);
    expect((o.opened! as MovieMatch).movie.id, 12);
  });

  testWidgets('two Sonarrs ask which, and the chosen one is checked by TVDB',
      (WidgetTester tester) async {
    final List<String> asked = <String>[];
    final _Outcome o = await _run(
      tester,
      const TitleShare(kind: TitleKind.show, imdbId: 'tt7366338'),
      instances: <Instance>[_radarr, _sonarr, _sonarr2],
      lookupSeries: (Instance i, String term) async {
        asked.add('${i.name}|$term');
        // Only the second Sonarr already has it.
        return <SonarrSeries>[
          SonarrSeries(
            id: i == _sonarr2 ? 21 : 0,
            title: 'Chernobyl',
            tvdbId: 360893,
          ),
        ];
      },
    );
    expect(find.text('Add to'), findsOneWidget);
    expect(find.text('Radarr Test'), findsNothing);
    await tester.tap(find.text('Sonarr Two'));
    await tester.pumpAndSettle();
    expect(asked, <String>[
      'Sonarr Test|imdb:tt7366338',
      'Sonarr Two|tvdb:360893',
    ]);
    expect(o.openedOn, _sonarr2);
    expect((o.opened! as SeriesMatch).series.id, 21);
    expect(o.adding, isNull);
  });

  testWidgets(
      'a show in the first Sonarr but not found on the chosen one opens the '
      'add sheet, not the first library entry',
      (WidgetTester tester) async {
    final _Outcome o = await _run(
      tester,
      const TitleShare(kind: TitleKind.show, imdbId: 'tt7366338'),
      instances: <Instance>[_sonarr, _sonarr2],
      lookupSeries: (Instance i, String term) async => i == _sonarr
          ? <SonarrSeries>[
              const SonarrSeries(id: 9, title: 'Chernobyl', tvdbId: 360893),
            ]
          : <SonarrSeries>[],
    );
    await tester.tap(find.text('Sonarr Two'));
    await tester.pumpAndSettle();
    expect(o.opened, isNull);
    expect(o.addingOn, _sonarr2);
    expect((o.adding! as SeriesMatch).series.id, 0);
    expect((o.adding! as SeriesMatch).series.tvdbId, 360893);
  });

  testWidgets('the chosen Sonarr being down says so and adds nothing',
      (WidgetTester tester) async {
    final _Outcome o = await _run(
      tester,
      const TitleShare(kind: TitleKind.show, imdbId: 'tt7366338'),
      instances: <Instance>[_sonarr, _sonarr2],
      lookupSeries: (Instance i, String term) async {
        if (i == _sonarr2) throw Exception('down');
        return <SonarrSeries>[
          const SonarrSeries(title: 'Chernobyl', tvdbId: 360893),
        ];
      },
    );
    await tester.tap(find.text('Sonarr Two'));
    await tester.pumpAndSettle();
    expect(o.told.single, contains('Could not reach Sonarr Two'));
    expect(o.adding, isNull);
    expect(o.opened, isNull);
  });

  testWidgets('within limits the lookup to the named instance and skips the '
      'picker', (WidgetTester tester) async {
    final List<String> asked = <String>[];
    final _Outcome o = await _run(
      tester,
      const TitleShare(kind: TitleKind.movie, tmdbId: 860),
      instances: <Instance>[_radarr, _radarr2, _sonarr],
      within: <Instance>[_radarr2],
      lookupMovies: (Instance i, String term) async {
        asked.add('${i.name}|$term');
        return <RadarrMovie>[const RadarrMovie(title: 'WarGames', tmdbId: 860)];
      },
    );
    expect(asked, <String>['Radarr Two|tmdb:860']);
    expect(find.text('Add to'), findsNothing);
    expect(o.addingOn, _radarr2);
  });
}
