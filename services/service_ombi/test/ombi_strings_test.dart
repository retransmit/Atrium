import 'package:flutter_test/flutter_test.dart';
import 'package:service_ombi/service_ombi.dart';

OmbiRequest _show({
  List<int> seasons = const <int>[],
  int episodes = 0,
  int episodesAvailable = 0,
}) =>
    OmbiRequest(
      id: 1,
      kind: OmbiMediaKind.tv,
      title: 'Severance',
      status: OmbiRequestStatus.processing,
      seasons: seasons,
      episodes: episodes,
      episodesAvailable: episodesAvailable,
    );

void main() {
  group('which seasons a request asks for', () {
    for (final (List<int> seasons, String? want) in <(List<int>, String?)>[
      (<int>[], null),
      (<int>[1], 'Season 1'),
      (<int>[4], 'Season 4'),
      (<int>[0], 'Specials'),
      (<int>[1, 2, 3], 'Seasons 1-3'),
      // A gap cannot be written as a range.
      (<int>[1, 3], '2 seasons'),
      // Specials are not season zero of a run.
      (<int>[0, 1], '2 seasons'),
    ]) {
      test('$seasons reads $want', () {
        expect(ombiSeasonsLabel(seasons), want);
      });
    }
  });

  group('the episodes line on a TV card', () {
    test('some episodes in says how many of how many', () {
      expect(
        ombiEpisodesLine(
          _show(seasons: <int>[1], episodes: 3, episodesAvailable: 1),
        ),
        'Season 1 · 1 of 3 episodes available',
      );
    });

    test('none in yet says only what was asked for', () {
      expect(
        ombiEpisodesLine(_show(seasons: <int>[1, 2], episodes: 5)),
        'Seasons 1-2 · 5 episodes',
      );
    });

    test('all in does not repeat what the status already says', () {
      expect(
        ombiEpisodesLine(
          _show(seasons: <int>[1], episodes: 10, episodesAvailable: 10),
        ),
        'Season 1 · 10 episodes',
      );
    });

    test('a single episode is not plural', () {
      expect(
        ombiEpisodesLine(_show(seasons: <int>[2], episodes: 1)),
        'Season 2 · 1 episode',
      );
    });

    test('a request with no episodes listed has no line', () {
      expect(ombiEpisodesLine(_show()), isNull);
    });
  });

  group('a runtime', () {
    for (final (int minutes, String want) in <(int, String)>[
      (50, '50m'),
      (60, '1h'),
      (116, '1h 56m'),
      (155, '2h 35m'),
    ]) {
      test('$minutes minutes reads $want', () {
        expect(ombiRuntime(minutes), want);
      });
    }
  });

  group('the facts under a title', () {
    test('a movie gives its kind, year, length and where it is in release',
        () {
      expect(
        ombiTitleFacts(
          kind: OmbiMediaKind.movie,
          year: 2016,
          runtimeMinutes: 116,
          releaseStatus: 'Released',
        ),
        <String>['Movie', '2016', '1h 56m', 'Released'],
      );
    });

    test('a show names its network too', () {
      expect(
        ombiTitleFacts(
          kind: OmbiMediaKind.tv,
          year: 2022,
          runtimeMinutes: 50,
          network: 'Apple TV+',
          releaseStatus: 'Returning Series',
        ),
        <String>['TV show', '2022', '50m', 'Apple TV+', 'Returning Series'],
      );
    });

    test('what is not known is left out, not shown empty', () {
      expect(
        ombiTitleFacts(kind: OmbiMediaKind.tv),
        <String>['TV show'],
      );
    });
  });
}
