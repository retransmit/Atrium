import 'dart:convert';

import 'package:core_models/core_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_radarr/service_radarr.dart';
import 'package:service_radarr/src/home/movies_tab.dart';
import 'package:service_radarr/src/radarr_custom_filter_evaluator.dart';

/// Answers each request with the JSON [handler] gives for its path.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Object? Function(String path) handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(handler(options.path)),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }
}

/// One rule, in the shape Radarr's filter builder saves it.
Map<String, Object?> _rule(String key, Object? value, [String? type]) =>
    <String, Object?>{
      'key': key,
      'value': value,
      if (type != null) 'type': type,
    };

/// A custom filter as `GET /api/v3/customfilter` sends one.
Map<String, Object?> _filterJson(
  String label,
  List<Map<String, Object?>> rules, {
  int id = 1,
  String type = 'movieIndex',
}) =>
    <String, Object?>{
      'id': id,
      'type': type,
      'label': label,
      'filters': rules,
    };

RadarrCustomFilter _filter(List<Map<String, Object?>> rules) =>
    RadarrCustomFilter.fromJson(
      _filterJson('Test', rules).cast<String, dynamic>(),
    );

/// The moment the relative date rules are measured from.
final DateTime _now = DateTime(2026, 10, 7, 18, 30);

/// Whether [movie] passes a filter of the one rule given.
bool _passes(RadarrMovie movie, String key, Object? value, [String? type]) =>
    matchesRadarrCustomFilter(
      movie,
      _filter(<Map<String, Object?>>[_rule(key, value, type)]),
      now: _now,
    );

/// A date as the server sends it, for a moment in this device's time zone.
String _utc(DateTime local) => local.toUtc().toIso8601String();

void main() {
  const RadarrMovie matrix = RadarrMovie(
    id: 1,
    title: 'The Matrix',
    originalTitle: 'The Matrix',
    year: 1999,
    status: 'released',
    studio: 'Warner Bros.',
    runtime: 136,
    monitored: true,
    hasFile: true,
    sizeOnDisk: 8000000000,
    isAvailable: true,
    minimumAvailability: 'released',
    qualityProfileId: 1,
    genres: <String>['Action', 'Science Fiction'],
    keywords: <String>['hacker'],
    popularity: 42.5,
    certification: 'R',
    tags: <int>[2, 5],
    path: '/movies/The Matrix (1999)',
    collection: RadarrCollection(title: 'The Matrix Collection', tmdbId: 2344),
    originalLanguage: RadarrLanguage(id: 1, name: 'English'),
    ratings: RadarrRatings(
      imdb: RadarrRatingValue(value: 8.7, votes: 2000000),
      tmdb: RadarrRatingValue(value: 8.2, votes: 25000),
      rottenTomatoes: RadarrRatingValue(value: 83),
      trakt: RadarrRatingValue(value: 8.6, votes: 90000),
    ),
    statistics: RadarrMovieStatistics(
      movieFileCount: 1,
      sizeOnDisk: 8000000000,
      releaseGroups: <String>['FLUX'],
      movieFileQualities: <RadarrMovieFileQuality>[
        RadarrMovieFileQuality(id: 7, name: 'Bluray-1080p'),
      ],
    ),
  );

  // Nothing downloaded, and several properties the server sends only where
  // it has a value: no certification, no collection, no ratings yet.
  const RadarrMovie avatar = RadarrMovie(
    id: 2,
    title: 'Avatar: Fire and Ash',
    originalTitle: 'Avatar: Fire and Ash',
    year: 2025,
    status: 'announced',
    studio: '20th Century Studios',
    runtime: 0,
    isAvailable: false,
    minimumAvailability: 'released',
    qualityProfileId: 4,
    genres: <String>['Science Fiction'],
    keywords: <String>[],
    popularity: 3,
    path: '/movies/Avatar Fire and Ash (2025)',
    originalLanguage: RadarrLanguage(id: 1, name: 'English'),
    ratings: RadarrRatings(),
    statistics: RadarrMovieStatistics(),
  );

  group('radarrMovieCustomFilters', () {
    test('keeps the movie list filters, by label, and no other screen\'s', () {
      final List<RadarrCustomFilter> all = <Map<String, Object?>>[
        _filterJson('Has files', <Map<String, Object?>>[]),
        // Saved from interactive search on a real server.
        _filterJson(
          'eng',
          <Map<String, Object?>>[
            _rule('languages', <String>['English'], 'contains'),
          ],
          id: 2,
          type: 'releases',
        ),
        _filterJson('4K', <Map<String, Object?>>[], id: 3),
        _filterJson(
          'Discover one',
          <Map<String, Object?>>[],
          id: 4,
          type: 'discoverMovie',
        ),
        _filterJson(
          'by section',
          <Map<String, Object?>>[],
          id: 5,
          type: 'movies',
        ),
        _filterJson('', <Map<String, Object?>>[], id: 6),
        _filterJson('Top 10', <Map<String, Object?>>[], id: 7),
        _filterJson('Top 2', <Map<String, Object?>>[], id: 8),
      ]
          .map(
            (Map<String, Object?> json) =>
                RadarrCustomFilter.fromJson(json.cast<String, dynamic>()),
          )
          .toList();

      expect(
        radarrMovieCustomFilters(all).map((RadarrCustomFilter f) => f.label),
        <String>['4K', 'by section', 'Has files', 'Top 2', 'Top 10'],
      );
    });
  });

  group('matchesRadarrCustomFilter', () {
    test('reads a number from the list the builder saves it in', () {
      expect(_passes(matrix, 'year', <int>[1990], 'greaterThan'), isTrue);
      expect(_passes(matrix, 'year', <int>[1999], 'greaterThan'), isFalse);
      expect(
        _passes(matrix, 'year', <int>[1999], 'greaterThanOrEqual'),
        isTrue,
      );
      expect(_passes(matrix, 'year', <int>[1999], 'lessThan'), isFalse);
      expect(_passes(matrix, 'year', <int>[1999], 'lessThanOrEqual'), isTrue);
      expect(_passes(matrix, 'year', <int>[1999], 'equal'), isTrue);
      expect(_passes(matrix, 'year', <int>[1999], 'notEqual'), isFalse);
      expect(_passes(matrix, 'runtime', <int>[120], 'greaterThan'), isTrue);
      expect(_passes(matrix, 'popularity', <int>[42], 'greaterThan'), isTrue);
    });

    test('tells a movie with a file from one with none', () {
      expect(_passes(matrix, 'sizeOnDisk', <int>[0], 'greaterThan'), isTrue);
      expect(_passes(avatar, 'sizeOnDisk', <int>[0], 'greaterThan'), isFalse);
      expect(_passes(matrix, 'sizeOnDisk', <int>[0], 'equal'), isFalse);
      expect(_passes(avatar, 'sizeOnDisk', <int>[0], 'equal'), isTrue);
      // A server that sends no statistics still sends the size itself.
      expect(
        _passes(
          const RadarrMovie(title: 'Old server', sizeOnDisk: 700000000),
          'sizeOnDisk',
          <int>[0],
          'greaterThan',
        ),
        isTrue,
      );
    });

    test('takes any of the values, and none of them under the two nots', () {
      const List<String> either = <String>['announced', 'inCinemas'];
      expect(_passes(avatar, 'status', either, 'equal'), isTrue);
      expect(_passes(matrix, 'status', either, 'equal'), isFalse);
      expect(_passes(avatar, 'status', either, 'notEqual'), isFalse);
      expect(_passes(matrix, 'status', either, 'notEqual'), isTrue);

      const List<String> genres = <String>['Action', 'Horror'];
      expect(_passes(matrix, 'genres', genres, 'contains'), isTrue);
      expect(_passes(matrix, 'genres', genres, 'notContains'), isFalse);
      expect(_passes(avatar, 'genres', genres, 'notContains'), isTrue);
    });

    test('takes a value on its own, and equal where no type is given', () {
      expect(_passes(matrix, 'hasFile', true), isTrue);
      expect(_passes(avatar, 'hasFile', true), isFalse);
      expect(_passes(avatar, 'monitored', false, 'equal'), isTrue);
    });

    test('matches equal exactly and contains without regard to case', () {
      expect(_passes(matrix, 'title', <String>['The Matrix'], 'equal'), isTrue);
      expect(
        _passes(matrix, 'title', <String>['the matrix'], 'equal'),
        isFalse,
      );
      expect(_passes(matrix, 'title', <String>['MATRIX'], 'contains'), isTrue);
      expect(
        _passes(matrix, 'title', <String>['MATRIX'], 'notContains'),
        isFalse,
      );
      expect(_passes(matrix, 'title', <String>['the'], 'startsWith'), isTrue);
      expect(
        _passes(matrix, 'title', <String>['the'], 'notStartsWith'),
        isFalse,
      );
      expect(_passes(matrix, 'title', <String>['RIX'], 'endsWith'), isTrue);
      expect(_passes(matrix, 'title', <String>['RIX'], 'notEndsWith'), isFalse);
      expect(
        _passes(matrix, 'studio', <String>['Warner Bros.'], 'equal'),
        isTrue,
      );
      expect(
        _passes(matrix, 'studio', <String>['warner bros.'], 'equal'),
        isFalse,
      );
    });

    test('looks for the exact entry in a list', () {
      expect(_passes(matrix, 'genres', <String>['Action'], 'contains'), isTrue);
      expect(
        _passes(matrix, 'genres', <String>['action'], 'contains'),
        isFalse,
      );
      expect(
        _passes(matrix, 'genres', <String>['Science'], 'contains'),
        isFalse,
      );
      expect(
        _passes(matrix, 'keywords', <String>['hacker'], 'contains'),
        isTrue,
      );
      expect(
        _passes(avatar, 'keywords', <String>['hacker'], 'notContains'),
        isTrue,
      );
      expect(_passes(matrix, 'tags', <int>[5], 'contains'), isTrue);
      expect(_passes(matrix, 'tags', <int>[3], 'contains'), isFalse);
      expect(_passes(avatar, 'tags', <int>[5], 'notContains'), isTrue);
      expect(
        _passes(matrix, 'releaseGroups', <String>['FLUX'], 'contains'),
        isTrue,
      );
      expect(
        _passes(avatar, 'releaseGroups', <String>['FLUX'], 'contains'),
        isFalse,
      );
      // The qualities of a movie's files, by quality id.
      expect(
        _passes(matrix, 'movieFileQualities', <int>[7], 'contains'),
        isTrue,
      );
      expect(
        _passes(matrix, 'movieFileQualities', <int>[19], 'contains'),
        isFalse,
      );
      expect(
        _passes(avatar, 'movieFileQualities', <int>[7], 'notContains'),
        isTrue,
      );
    });

    test('works the values out that Radarr works out', () {
      // The collection by any part of its name, and no collection as an
      // empty one.
      expect(
        _passes(matrix, 'collection', <String>['matrix'], 'contains'),
        isTrue,
      );
      expect(
        _passes(avatar, 'collection', <String>['matrix'], 'contains'),
        isFalse,
      );
      expect(
        _passes(avatar, 'collection', <String>['matrix'], 'notContains'),
        isTrue,
      );
      expect(
        _passes(matrix, 'originalLanguage', <String>['English'], 'equal'),
        isTrue,
      );
      expect(
        _passes(matrix, 'originalLanguage', <String>['French'], 'notEqual'),
        isTrue,
      );
      // TMDb and Trakt are filtered as the percentage they are shown as,
      // IMDb and Rotten Tomatoes as they come.
      expect(_passes(matrix, 'tmdbRating', <int>[82], 'equal'), isTrue);
      expect(_passes(matrix, 'traktRating', <int>[86], 'equal'), isTrue);
      expect(_passes(matrix, 'imdbRating', <int>[8], 'greaterThan'), isTrue);
      expect(_passes(matrix, 'imdbRating', <int>[9], 'greaterThan'), isFalse);
      expect(
        _passes(matrix, 'rottenTomatoesRating', <int>[83], 'equal'),
        isTrue,
      );
      expect(_passes(matrix, 'tmdbVotes', <int>[10000], 'greaterThan'), isTrue);
      expect(
        _passes(matrix, 'imdbVotes', <int>[1000000], 'greaterThan'),
        isTrue,
      );
      expect(_passes(matrix, 'traktVotes', <int>[100000], 'lessThan'), isTrue);
      // A movie with no rating of a kind counts as zero there.
      expect(_passes(avatar, 'tmdbRating', <int>[0], 'equal'), isTrue);
      expect(_passes(avatar, 'imdbVotes', <int>[0], 'equal'), isTrue);
    });

    test('rejects a movie that lacks the property, whatever the rule', () {
      expect(_passes(avatar, 'certification', <String>['R'], 'equal'), isFalse);
      expect(
        _passes(avatar, 'certification', <String>['R'], 'notEqual'),
        isFalse,
      );
      expect(
        _passes(matrix, 'certification', <String>['PG'], 'notEqual'),
        isTrue,
      );
      expect(
        _passes(
          const RadarrMovie(title: 'No keywords sent'),
          'keywords',
          <String>['hacker'],
          'notContains',
        ),
        isFalse,
      );
    });

    test('rejects on a rule it cannot test', () {
      expect(_passes(matrix, 'episodeCount', <int>[0], 'greaterThan'), isFalse);
      expect(_passes(matrix, 'title', <String>['The'], 'resembles'), isFalse);
      expect(_passes(matrix, 'year', <int>[19], 'startsWith'), isFalse);
      expect(_passes(matrix, 'year', <int>[19], 'notStartsWith'), isFalse);
      // The builder saves a row that was added and never filled in.
      expect(
        matchesRadarrCustomFilter(
          matrix,
          _filter(<Map<String, Object?>>[
            _rule('monitored', <bool>[true], 'equal'),
            <String, Object?>{},
          ]),
        ),
        isFalse,
      );
    });

    test('passes everything on a filter with no rules', () {
      expect(
        matchesRadarrCustomFilter(avatar, _filter(<Map<String, Object?>>[])),
        isTrue,
      );
    });

    test('needs every rule to pass', () {
      final RadarrCustomFilter filter = _filter(<Map<String, Object?>>[
        _rule('monitored', <bool>[true], 'equal'),
        _rule('isAvailable', <bool>[true], 'equal'),
        _rule('year', <int>[2010], 'lessThan'),
      ]);
      expect(matchesRadarrCustomFilter(matrix, filter), isTrue);
      expect(
        matchesRadarrCustomFilter(matrix.copyWith(year: 2015), filter),
        isFalse,
      );
      expect(
        matchesRadarrCustomFilter(matrix.copyWith(isAvailable: false), filter),
        isFalse,
      );
    });

    group('on a date', () {
      RadarrMovie added(DateTime local) => matrix.copyWith(added: _utc(local));

      test('compares with a day as midnight in this time zone', () {
        final RadarrMovie late = added(DateTime(2024, 4, 30, 23, 30));
        final RadarrMovie early = added(DateTime(2024, 5, 1, 0, 30));
        expect(_passes(late, 'added', '2024-05-01', 'lessThan'), isTrue);
        expect(_passes(early, 'added', '2024-05-01', 'lessThan'), isFalse);
        expect(_passes(late, 'added', '2024-05-01', 'greaterThan'), isFalse);
        expect(_passes(early, 'added', '2024-05-01', 'greaterThan'), isTrue);
        // A date field left empty.
        expect(_passes(early, 'added', '', 'greaterThan'), isFalse);
      });

      test('measures the last and the next from now', () {
        const Map<String, Object?> week = <String, Object?>{
          'time': 'days',
          'value': 7,
        };
        final RadarrMovie recent = added(DateTime(2026, 10, 3, 9));
        final RadarrMovie old = added(DateTime(2026, 9, 20, 9));
        expect(_passes(recent, 'added', week, 'inLast'), isTrue);
        expect(_passes(old, 'added', week, 'inLast'), isFalse);
        expect(_passes(old, 'added', week, 'notInLast'), isTrue);
        expect(_passes(recent, 'added', week, 'notInLast'), isFalse);

        RadarrMovie digital(DateTime local) =>
            avatar.copyWith(digitalRelease: _utc(local));
        final RadarrMovie soon = digital(DateTime(2026, 10, 10, 9));
        final RadarrMovie far = digital(DateTime(2026, 11, 20, 9));
        expect(_passes(soon, 'digitalRelease', week, 'inNext'), isTrue);
        expect(_passes(far, 'digitalRelease', week, 'inNext'), isFalse);
        expect(_passes(far, 'digitalRelease', week, 'notInNext'), isTrue);
        expect(_passes(soon, 'digitalRelease', week, 'notInNext'), isFalse);
      });

      test('counts in every unit the builder offers', () {
        final RadarrMovie justNow =
            added(_now.subtract(const Duration(seconds: 40)));
        for (final String unit in <String>[
          'minutes',
          'hours',
          'days',
          'weeks',
          'months',
        ]) {
          final Map<String, Object?> one = <String, Object?>{
            'time': unit,
            'value': 1,
          };
          expect(
            _passes(justNow, 'added', one, 'inLast'),
            isTrue,
            reason: unit,
          );
        }
        expect(
          _passes(
            justNow,
            'added',
            <String, Object?>{'time': 'seconds', 'value': 30},
            'inLast',
          ),
          isFalse,
        );
      });

      test('counts a month back to the last day of a shorter month', () {
        const Map<String, Object?> month = <String, Object?>{
          'time': 'months',
          'value': 1,
        };
        final RadarrCustomFilter filter = _filter(<Map<String, Object?>>[
          _rule('added', month, 'inLast'),
        ]);
        // A month before 31 March is 28 February, at the same time of day.
        final DateTime endOfMarch = DateTime(2026, 3, 31, 9, 15);
        expect(
          matchesRadarrCustomFilter(
            added(DateTime(2026, 2, 28, 10)),
            filter,
            now: endOfMarch,
          ),
          isTrue,
        );
        expect(
          matchesRadarrCustomFilter(
            added(DateTime(2026, 2, 28, 8)),
            filter,
            now: endOfMarch,
          ),
          isFalse,
        );
      });

      test('passes nothing without a date, or on another type', () {
        const Map<String, Object?> week = <String, Object?>{
          'time': 'days',
          'value': 7,
        };
        expect(_passes(avatar, 'digitalRelease', week, 'notInNext'), isFalse);
        expect(_passes(avatar, 'inCinemas', '2024-05-01', 'lessThan'), isFalse);
        expect(
          _passes(
            added(DateTime(2024, 5)),
            'added',
            <String>['2024-05-01'],
            'equal',
          ),
          isFalse,
        );
      });
    });
  });

  group('the movies tab', () {
    const Instance instance = Instance(
      id: 'test-radarr',
      name: 'Radarr',
      kind: ServiceKind.radarr,
      localUrl: 'http://localhost:7878',
      externalUrl: '',
      urlMode: UrlMode.auto,
      auth: InstanceAuthApiKey(apiKey: 'dummy'),
    );

    // What a server with three saved filters answers, one of them made on
    // another screen.
    final List<Map<String, Object?>> saved = <Map<String, Object?>>[
      _filterJson(
        'No file',
        <Map<String, Object?>>[
          _rule('sizeOnDisk', <int>[0], 'equal'),
        ],
        id: 7,
      ),
      _filterJson(
        'Has a file',
        <Map<String, Object?>>[
          _rule('sizeOnDisk', <int>[0], 'greaterThan'),
        ],
        id: 3,
      ),
      _filterJson(
        'eng',
        <Map<String, Object?>>[
          _rule('languages', <String>['English'], 'contains'),
        ],
        id: 5,
        type: 'releases',
      ),
    ];

    RadarrApi fakeApi() => RadarrApi(
          Dio(BaseOptions(baseUrl: 'http://localhost:7878/'))
            ..httpClientAdapter = _FakeAdapter(
              (String path) => path.endsWith('customfilter')
                  ? saved
                  : <Object?>[],
            ),
        );

    List<String> shown(ProviderContainer container) => container
        .read(radarrFilteredMoviesProvider(instance))
        .value!
        .map((RadarrMovie m) => m.title)
        .toList();

    test('filters the list by the active custom filter', () {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          radarrMoviesProvider(instance).overrideWith(
            (ref) => <RadarrMovie>[matrix, avatar],
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(shown(container), <String>['Avatar: Fire and Ash', 'The Matrix']);

      container.read(radarrActiveCustomFilterProvider(instance).notifier).state =
          RadarrCustomFilter.fromJson(saved[1].cast<String, dynamic>());
      expect(shown(container), <String>['The Matrix']);

      // The search still narrows what the filter lets through.
      container.read(radarrSearchQueryProvider(instance).notifier).state =
          'avatar';
      expect(shown(container), isEmpty);
    });

    testWidgets('offers the saved filters and filters by the one picked',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            radarrApiProvider(instance).overrideWith((ref) => fakeApi()),
            radarrMoviesProvider(instance).overrideWith(
              (ref) => <RadarrMovie>[matrix, avatar],
            ),
            radarrActiveTabBarIndexProvider(instance).overrideWith((ref) => 0),
          ],
          child: const MaterialApp(home: MoviesTab(instance: instance)),
        ),
      );
      await tester.pumpAndSettle();
      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(MoviesTab)),
      );

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      // The two for this list, by label, after the built-in ones. The one
      // saved from interactive search is not offered.
      final List<String> chips = tester
          .widgetList<ChoiceChip>(find.byType(ChoiceChip))
          .map((ChoiceChip chip) => (chip.label as Text).data!)
          .toList();
      expect(
        chips.sublist(chips.indexOf('Unmonitored Only') + 1).take(2),
        <String>['Has a file', 'No file'],
      );
      expect(find.text('eng'), findsNothing);

      bool selected(String label) => tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label))
          .selected;

      await tester.tap(find.widgetWithText(ChoiceChip, 'No file'));
      await tester.pumpAndSettle();
      expect(selected('No file'), isTrue);
      expect(selected('All Status'), isFalse);
      expect(shown(container), <String>['Avatar: Fire and Ash']);

      // A built-in filter takes over from the custom one.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Monitored Only'));
      await tester.pumpAndSettle();
      expect(selected('No file'), isFalse);
      expect(selected('Monitored Only'), isTrue);
      expect(shown(container), <String>['The Matrix']);

      // Tapping the active custom filter again goes back to everything.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Has a file'));
      await tester.pumpAndSettle();
      expect(shown(container), <String>['The Matrix']);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Has a file'));
      await tester.pumpAndSettle();
      expect(selected('All Status'), isTrue);
      expect(shown(container), <String>['Avatar: Fire and Ash', 'The Matrix']);
    });
  });
}
