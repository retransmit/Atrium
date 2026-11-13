import 'dart:async';

import 'package:atrium/src/share_intake/atrium_link.dart';
import 'package:atrium/src/share_intake/atrium_link_flow.dart';
import 'package:atrium/src/share_intake/title_resolver.dart';
import 'package:atrium/src/share_intake/title_share_flow.dart';
import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
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
final Instance _sonarr = _instance('Sonarr Test', ServiceKind.sonarr);
final Instance _sonarr2 = _instance('Sonarr Two', ServiceKind.sonarr);

/// What the flow did, captured instead of routing or building real screens.
class _Outcome {
  final List<String> told = <String>[];
  final List<String> went = <String>[];
  TitleMatch? opened;
  Instance? openedOn;
  bool done = false;
}

Future<_Outcome> _run(
  WidgetTester tester,
  AtriumLink link, {
  required List<Instance> instances,
  MovieById? movieById,
  SeriesLookup? lookupSeries,
  OpenTitle? openExisting,
}) async {
  final _Outcome outcome = _Outcome();
  final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        activeInstancesProvider.overrideWithValue(instances),
        for (final Instance i in instances)
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
              onPressed: () async {
                await openAtriumLink(
                ref,
                link,
                presentContext: () => navigator.currentContext,
                tell: (String message) async => outcome.told.add(message),
                go: outcome.went.add,
                movieById: movieById ??
                    (Instance on, int id) async => throw StateError('unused'),
                seriesById: (Instance on, int id) async =>
                    throw StateError('unused'),
                lookupMovies: (Instance i, String term) async =>
                    <RadarrMovie>[],
                lookupSeries: lookupSeries ??
                    (Instance i, String term) async => <SonarrSeries>[],
                openExisting: openExisting ??
                    (BuildContext c, Instance on, TitleMatch m) async {
                      outcome
                        ..opened = m
                        ..openedOn = on;
                    },
                );
                outcome.done = true;
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return outcome;
}

void main() {
  testWidgets('a service link with one instance opens its screen',
      (WidgetTester tester) async {
    final _Outcome o = await _run(
      tester,
      const AtriumLink(service: ServiceKind.sonarr),
      instances: <Instance>[_radarr, _sonarr],
    );
    expect(o.went, <String>['/service/sonarr/Sonarr Test']);
    expect(o.told, isEmpty);
  });

  testWidgets('a service link with two instances asks which',
      (WidgetTester tester) async {
    final _Outcome o = await _run(
      tester,
      const AtriumLink(service: ServiceKind.sonarr),
      instances: <Instance>[_sonarr, _sonarr2],
    );
    expect(o.went, isEmpty);
    await tester.tap(find.text('Sonarr Two'));
    await tester.pumpAndSettle();
    expect(o.went, <String>['/service/sonarr/Sonarr Two']);
  });

  testWidgets('a named instance is matched ignoring case',
      (WidgetTester tester) async {
    final _Outcome o = await _run(
      tester,
      const AtriumLink(service: ServiceKind.sonarr, instanceName: 'sonarr two'),
      instances: <Instance>[_sonarr, _sonarr2],
    );
    expect(find.text('Add to'), findsNothing);
    expect(o.went, <String>['/service/sonarr/Sonarr Two']);
  });

  testWidgets('a named instance of another service is not used',
      (WidgetTester tester) async {
    final _Outcome o = await _run(
      tester,
      const AtriumLink(service: ServiceKind.radarr, instanceName: 'Sonarr Test'),
      instances: <Instance>[_radarr, _sonarr],
    );
    expect(o.told, <String>[
      'No Radarr with that name is set up in Atrium.',
    ]);
    expect(o.went, isEmpty);
  });

  testWidgets('a service with nothing set up says so',
      (WidgetTester tester) async {
    final _Outcome o = await _run(
      tester,
      const AtriumLink(service: ServiceKind.radarr),
      instances: <Instance>[_sonarr],
    );
    expect(o.told, <String>['No Radarr is set up in Atrium yet.']);
    expect(o.went, isEmpty);
  });

  testWidgets('a library ID opens that movie', (WidgetTester tester) async {
    final _Outcome o = await _run(
      tester,
      const AtriumLink(
        service: ServiceKind.radarr,
        item: LinkItem.movie,
        libraryId: 12,
      ),
      instances: <Instance>[_radarr],
      movieById: (Instance on, int id) async =>
          RadarrMovie(id: id, title: 'WarGames'),
    );
    expect(o.openedOn, _radarr);
    expect((o.opened! as MovieMatch).movie.id, 12);
  });

  testWidgets('a library ID the instance does not have says so',
      (WidgetTester tester) async {
    final _Outcome o = await _run(
      tester,
      const AtriumLink(
        service: ServiceKind.radarr,
        item: LinkItem.movie,
        libraryId: 12,
      ),
      instances: <Instance>[_radarr],
      movieById: (Instance on, int id) async =>
          throw const NetworkNotFoundException('x'),
    );
    expect(o.told, <String>['Radarr Test has no movie with ID 12.']);
    expect(o.opened, isNull);
  });

  testWidgets('a library ID on a server that is down says so',
      (WidgetTester tester) async {
    final _Outcome o = await _run(
      tester,
      const AtriumLink(
        service: ServiceKind.radarr,
        item: LinkItem.movie,
        libraryId: 12,
      ),
      instances: <Instance>[_radarr],
      movieById: (Instance on, int id) async =>
          throw const NetworkUnreachableException('x'),
    );
    expect(o.told, <String>['Could not reach Radarr Test.']);
    expect(o.opened, isNull);
  });

  testWidgets('a TVDB link looks the series up on the named Sonarr only',
      (WidgetTester tester) async {
    final List<String> asked = <String>[];
    await _run(
      tester,
      const AtriumLink(
        service: ServiceKind.sonarr,
        item: LinkItem.series,
        tvdbId: 81189,
        instanceName: 'Sonarr Two',
      ),
      instances: <Instance>[_sonarr, _sonarr2],
      lookupSeries: (Instance i, String term) async {
        asked.add('${i.name}|$term');
        return <SonarrSeries>[];
      },
    );
    expect(asked, <String>['Sonarr Two|tvdb:81189']);
  });

  testWidgets('a name from the link is never shown back',
      (WidgetTester tester) async {
    final _Outcome o = await _run(
      tester,
      const AtriumLink(
        service: ServiceKind.sonarr,
        instanceName: 'x".\n\nYour API key expired. Re-enter it at evil.example',
      ),
      instances: <Instance>[_sonarr],
    );
    expect(o.told, <String>['No Sonarr with that name is set up in Atrium.']);
  });

  testWidgets('a screen a link opened does not hold the next link back',
      (WidgetTester tester) async {
    final _Outcome o = await _run(
      tester,
      const AtriumLink(
        service: ServiceKind.radarr,
        item: LinkItem.movie,
        libraryId: 12,
      ),
      instances: <Instance>[_radarr],
      movieById: (Instance on, int id) async =>
          RadarrMovie(id: id, title: 'WarGames'),
      // A pushed screen's future ends only when the user leaves it.
      openExisting: (BuildContext c, Instance on, TitleMatch m) =>
          Completer<void>().future,
    );
    expect(o.done, isTrue);
  });
}
