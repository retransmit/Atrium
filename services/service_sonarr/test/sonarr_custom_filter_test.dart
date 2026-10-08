import 'dart:convert';

import 'package:core_models/core_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_sonarr/service_sonarr.dart';
import 'package:service_sonarr/src/home/series_tab.dart';
import 'package:service_sonarr/src/sonarr_custom_filter_evaluator.dart';

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

/// One rule, in the shape Sonarr's filter builder saves it.
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
  String type = 'series',
}) =>
    <String, Object?>{
      'id': id,
      'type': type,
      'label': label,
      'filters': rules,
    };

CustomFilterResource _filter(List<Map<String, Object?>> rules) =>
    CustomFilterResource.fromJson(
      _filterJson('Test', rules).cast<String, dynamic>(),
    );

/// The moment the relative date rules are measured from.
final DateTime _now = DateTime(2026, 10, 7, 18, 30);

/// Whether [series] passes a filter of the one rule given.
bool _passes(SonarrSeries series, String key, Object? value, [String? type]) =>
    matchesSonarrCustomFilter(
      series,
      _filter(<Map<String, Object?>>[_rule(key, value, type)]),
      now: _now,
    );

/// A date as the server sends it, for a moment in this device's time zone.
String _utc(DateTime local) => local.toUtc().toIso8601String();

void main() {
  const SonarrSeries office = SonarrSeries(
    id: 1,
    title: 'The Office',
    status: 'ended',
    seriesType: 'standard',
    network: 'NBC',
    year: 2005,
    monitored: true,
    genres: <String>['Comedy'],
    path: '/tv/The Office',
    rootFolderPath: '/tv',
    certification: 'TV-14',
    qualityProfileId: 1,
    tags: <int>[2, 5],
    useSceneNumbering: false,
    ratings: SonarrRatings(votes: 2500, value: 8.6),
    originalLanguage: SonarrLanguage(id: 1, name: 'English'),
    seasons: <SonarrSeason>[
      SonarrSeason(
        monitored: true,
        statistics: SonarrSeasonStatistics(totalEpisodeCount: 4),
      ),
      SonarrSeason(
        seasonNumber: 1,
        monitored: true,
        statistics: SonarrSeasonStatistics(
          episodeFileCount: 6,
          episodeCount: 6,
          totalEpisodeCount: 6,
        ),
      ),
      SonarrSeason(
        seasonNumber: 2,
        monitored: true,
        statistics: SonarrSeasonStatistics(
          episodeFileCount: 3,
          episodeCount: 6,
          totalEpisodeCount: 6,
        ),
      ),
    ],
    statistics: SonarrSeriesStatistics(
      seasonCount: 2,
      episodeFileCount: 9,
      episodeCount: 12,
      totalEpisodeCount: 16,
      sizeOnDisk: 9000000000,
      releaseGroups: <String>['NTb'],
    ),
  );

  // Nothing downloaded, and several properties the server sends only where
  // it has a value: no network, no certification, no language.
  const SonarrSeries severance = SonarrSeries(
    id: 2,
    title: 'Severance',
    status: 'continuing',
    seriesType: 'standard',
    year: 2022,
    genres: <String>['Drama', 'Sci-Fi'],
    path: '/tv/Severance',
    rootFolderPath: '/tv',
    qualityProfileId: 4,
    useSceneNumbering: false,
    ratings: SonarrRatings(),
    seasons: <SonarrSeason>[
      SonarrSeason(
        seasonNumber: 1,
        statistics: SonarrSeasonStatistics(
          episodeCount: 9,
          totalEpisodeCount: 9,
        ),
      ),
      SonarrSeason(
        seasonNumber: 2,
        monitored: true,
        statistics: SonarrSeasonStatistics(totalEpisodeCount: 10),
      ),
    ],
    statistics: SonarrSeriesStatistics(
      seasonCount: 2,
      episodeCount: 9,
      totalEpisodeCount: 19,
    ),
  );

  group('sonarrSeriesCustomFilters', () {
    test('keeps the series list filters, by label, and no other screen\'s',
        () {
      final List<CustomFilterResource> all = <Map<String, Object?>>[
        _filterJson('Has downloads', <Map<String, Object?>>[]),
        // Saved from interactive search on a real server.
        _filterJson(
          '24',
          <Map<String, Object?>>[
            _rule('episodeRequested', <bool>[true], 'equal'),
          ],
          id: 2,
          type: 'releases',
        ),
        _filterJson('anime', <Map<String, Object?>>[], id: 3),
        _filterJson(
          'Calendar one',
          <Map<String, Object?>>[],
          id: 4,
          type: 'calendar',
        ),
        _filterJson(
          'Old section name',
          <Map<String, Object?>>[],
          id: 5,
          type: 'seriesIndex',
        ),
        _filterJson('', <Map<String, Object?>>[], id: 6),
        _filterJson('Top 10', <Map<String, Object?>>[], id: 7),
        _filterJson('Top 2', <Map<String, Object?>>[], id: 8),
      ]
          .map(
            (Map<String, Object?> json) =>
                CustomFilterResource.fromJson(json.cast<String, dynamic>()),
          )
          .toList();

      expect(
        sonarrSeriesCustomFilters(all)
            .map((CustomFilterResource f) => f.label),
        <String>[
          'anime',
          'Has downloads',
          'Old section name',
          'Top 2',
          'Top 10',
        ],
      );
    });
  });

  group('matchesSonarrCustomFilter', () {
    test('reads a number from the list the builder saves it in', () {
      expect(_passes(office, 'year', <int>[2000], 'greaterThan'), isTrue);
      expect(_passes(office, 'year', <int>[2005], 'greaterThan'), isFalse);
      expect(
        _passes(office, 'year', <int>[2005], 'greaterThanOrEqual'),
        isTrue,
      );
      expect(_passes(office, 'year', <int>[2005], 'lessThan'), isFalse);
      expect(_passes(office, 'year', <int>[2005], 'lessThanOrEqual'), isTrue);
      expect(_passes(office, 'year', <int>[2005], 'equal'), isTrue);
      expect(_passes(office, 'year', <int>[2005], 'notEqual'), isFalse);
    });

    test('tells a series with downloads from one with none', () {
      expect(_passes(office, 'sizeOnDisk', <int>[0], 'greaterThan'), isTrue);
      expect(
        _passes(severance, 'sizeOnDisk', <int>[0], 'greaterThan'),
        isFalse,
      );
      expect(_passes(office, 'sizeOnDisk', <int>[0], 'equal'), isFalse);
      expect(_passes(severance, 'sizeOnDisk', <int>[0], 'equal'), isTrue);
    });

    test('takes any of the values, and none of them under the two nots', () {
      const List<String> either = <String>['continuing', 'upcoming'];
      expect(_passes(severance, 'status', either, 'equal'), isTrue);
      expect(_passes(office, 'status', either, 'equal'), isFalse);
      expect(_passes(severance, 'status', either, 'notEqual'), isFalse);
      expect(_passes(office, 'status', either, 'notEqual'), isTrue);

      const List<String> genres = <String>['Comedy', 'Horror'];
      expect(_passes(office, 'genres', genres, 'contains'), isTrue);
      expect(_passes(office, 'genres', genres, 'notContains'), isFalse);
      expect(_passes(severance, 'genres', genres, 'notContains'), isTrue);
    });

    test('takes a value on its own, and equal where no type is given', () {
      expect(_passes(office, 'monitored', true), isTrue);
      expect(_passes(severance, 'monitored', true), isFalse);
      expect(_passes(severance, 'status', 'continuing', 'equal'), isTrue);
    });

    test('matches equal exactly and contains without regard to case', () {
      expect(_passes(office, 'title', <String>['The Office'], 'equal'), isTrue);
      expect(
        _passes(office, 'title', <String>['the office'], 'equal'),
        isFalse,
      );
      expect(_passes(office, 'title', <String>['OFFICE'], 'contains'), isTrue);
      expect(
        _passes(office, 'title', <String>['OFFICE'], 'notContains'),
        isFalse,
      );
      expect(_passes(office, 'title', <String>['the'], 'startsWith'), isTrue);
      expect(
        _passes(office, 'title', <String>['the'], 'notStartsWith'),
        isFalse,
      );
      expect(_passes(office, 'title', <String>['ICE'], 'endsWith'), isTrue);
      expect(_passes(office, 'title', <String>['ICE'], 'notEndsWith'), isFalse);
      // The builder offers Network as a list, but a series has one name.
      expect(_passes(office, 'network', <String>['nb'], 'contains'), isTrue);
    });

    test('looks for the exact entry in a list', () {
      expect(_passes(office, 'genres', <String>['Comedy'], 'contains'), isTrue);
      expect(
        _passes(office, 'genres', <String>['comedy'], 'contains'),
        isFalse,
      );
      expect(_passes(office, 'genres', <String>['Com'], 'contains'), isFalse);
      expect(_passes(office, 'tags', <int>[5], 'contains'), isTrue);
      expect(_passes(office, 'tags', <int>[3], 'contains'), isFalse);
      expect(_passes(severance, 'tags', <int>[5], 'notContains'), isTrue);
      expect(
        _passes(office, 'releaseGroups', <String>['NTb'], 'contains'),
        isTrue,
      );
      expect(
        _passes(severance, 'releaseGroups', <String>['NTb'], 'contains'),
        isFalse,
      );
    });

    test('works the values out that Sonarr works out', () {
      // 9 of 12 aired episodes.
      expect(_passes(office, 'episodeProgress', <int>[75], 'equal'), isTrue);
      expect(
        _passes(office, 'episodeProgress', <int>[100], 'lessThan'),
        isTrue,
      );
      expect(_passes(severance, 'episodeProgress', <int>[0], 'equal'), isTrue);
      // A series with nothing aired counts as complete.
      expect(
        _passes(
          const SonarrSeries(title: 'Unaired'),
          'episodeProgress',
          <int>[100],
          'equal',
        ),
        isTrue,
      );
      expect(_passes(office, 'seasonCount', <int>[2], 'equal'), isTrue);
      // A rating is filtered as the percentage it is shown as.
      expect(_passes(office, 'ratings', <int>[86], 'equal'), isTrue);
      expect(_passes(office, 'ratings', <int>[80], 'greaterThan'), isTrue);
      expect(_passes(severance, 'ratings', <int>[0], 'equal'), isTrue);
      expect(
        _passes(office, 'ratingVotes', <int>[1000], 'greaterThan'),
        isTrue,
      );
      expect(
        _passes(office, 'originalLanguage', <String>['English'], 'equal'),
        isTrue,
      );
      expect(
        _passes(severance, 'originalLanguage', <String>['English'], 'notEqual'),
        isTrue,
      );
    });

    test('judges seasons without the specials', () {
      // The Office: both seasons monitored, each with files.
      expect(
        _passes(office, 'seasonsMonitoredStatus', <String>['all'], 'equal'),
        isTrue,
      );
      expect(
        _passes(office, 'hasMissingSeason', <bool>[false], 'equal'),
        isTrue,
      );
      // Severance: season 1 aired in full with no file, season 2 not aired.
      expect(
        _passes(
          severance,
          'seasonsMonitoredStatus',
          <String>['partial'],
          'equal',
        ),
        isTrue,
      );
      expect(
        _passes(severance, 'hasMissingSeason', <bool>[true], 'equal'),
        isTrue,
      );
      expect(
        _passes(
          const SonarrSeries(
            title: 'Specials only',
            seasons: <SonarrSeason>[SonarrSeason(monitored: true)],
          ),
          'seasonsMonitoredStatus',
          <String>['none'],
          'equal',
        ),
        isTrue,
      );
    });

    test('passes a series with missing episodes on the missing key', () {
      expect(_passes(office, 'missing', true, 'equal'), isTrue);
      expect(
        _passes(
          office.copyWith(
            statistics: const SonarrSeriesStatistics(
              episodeFileCount: 12,
              episodeCount: 12,
            ),
          ),
          'missing',
          true,
          'equal',
        ),
        isFalse,
      );
    });

    test('rejects a series that lacks the property, whatever the rule', () {
      expect(
        _passes(severance, 'certification', <String>['TV-MA'], 'equal'),
        isFalse,
      );
      expect(
        _passes(severance, 'certification', <String>['TV-MA'], 'notEqual'),
        isFalse,
      );
      expect(
        _passes(severance, 'network', <String>['NBC'], 'notContains'),
        isFalse,
      );
      expect(
        _passes(office, 'certification', <String>['TV-MA'], 'notEqual'),
        isTrue,
      );
    });

    test('rejects on a rule it cannot test', () {
      expect(
        _passes(office, 'episodeFileCount', <int>[0], 'greaterThan'),
        isFalse,
      );
      expect(_passes(office, 'title', <String>['The'], 'resembles'), isFalse);
      expect(_passes(office, 'year', <int>[20], 'startsWith'), isFalse);
      expect(_passes(office, 'year', <int>[20], 'notStartsWith'), isFalse);
      // The builder saves a row that was added and never filled in.
      expect(
        matchesSonarrCustomFilter(
          office,
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
        matchesSonarrCustomFilter(severance, _filter(<Map<String, Object?>>[])),
        isTrue,
      );
    });

    test('needs every rule to pass', () {
      final CustomFilterResource filter = _filter(<Map<String, Object?>>[
        _rule('monitored', <bool>[true], 'equal'),
        _rule('year', <int>[2010], 'lessThan'),
      ]);
      expect(matchesSonarrCustomFilter(office, filter), isTrue);
      expect(
        matchesSonarrCustomFilter(office.copyWith(year: 2015), filter),
        isFalse,
      );
      expect(
        matchesSonarrCustomFilter(office.copyWith(monitored: false), filter),
        isFalse,
      );
    });

    group('on a date', () {
      SonarrSeries added(DateTime local) => office.copyWith(added: _utc(local));

      test('compares with a day as midnight in this time zone', () {
        final SonarrSeries late = added(DateTime(2024, 4, 30, 23, 30));
        final SonarrSeries early = added(DateTime(2024, 5, 1, 0, 30));
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
        final SonarrSeries recent = added(DateTime(2026, 10, 3, 9));
        final SonarrSeries old = added(DateTime(2026, 9, 20, 9));
        final SonarrSeries soon = added(DateTime(2026, 10, 10, 9));
        final SonarrSeries far = added(DateTime(2026, 11, 20, 9));

        expect(_passes(recent, 'added', week, 'inLast'), isTrue);
        expect(_passes(old, 'added', week, 'inLast'), isFalse);
        expect(_passes(soon, 'added', week, 'inLast'), isFalse);
        expect(_passes(old, 'added', week, 'notInLast'), isTrue);
        expect(_passes(recent, 'added', week, 'notInLast'), isFalse);

        expect(_passes(soon, 'added', week, 'inNext'), isTrue);
        expect(_passes(far, 'added', week, 'inNext'), isFalse);
        expect(_passes(recent, 'added', week, 'inNext'), isFalse);
        expect(_passes(far, 'added', week, 'notInNext'), isTrue);
        expect(_passes(soon, 'added', week, 'notInNext'), isFalse);
      });

      test('counts in every unit the builder offers', () {
        final SonarrSeries justNow =
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
        final CustomFilterResource filter = _filter(<Map<String, Object?>>[
          _rule('added', month, 'inLast'),
        ]);
        // A month before 31 March is 28 February, at the same time of day.
        final DateTime endOfMarch = DateTime(2026, 3, 31, 9, 15);
        expect(
          matchesSonarrCustomFilter(
            added(DateTime(2026, 2, 28, 10)),
            filter,
            now: endOfMarch,
          ),
          isTrue,
        );
        expect(
          matchesSonarrCustomFilter(
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
        expect(_passes(severance, 'nextAiring', week, 'notInNext'), isFalse);
        expect(
          _passes(severance, 'nextAiring', '2024-05-01', 'lessThan'),
          isFalse,
        );
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

  group('the series tab', () {
    const Instance instance = Instance(
      id: 'test-sonarr',
      name: 'Sonarr',
      kind: ServiceKind.sonarr,
      localUrl: 'http://localhost:8989',
      externalUrl: '',
      urlMode: UrlMode.auto,
      auth: InstanceAuthApiKey(apiKey: 'dummy'),
    );

    // What a server with three saved filters answers, one of them made on
    // another screen.
    final List<Map<String, Object?>> saved = <Map<String, Object?>>[
      _filterJson(
        'No downloads',
        <Map<String, Object?>>[
          _rule('sizeOnDisk', <int>[0], 'equal'),
        ],
        id: 7,
      ),
      _filterJson(
        'Has downloads',
        <Map<String, Object?>>[
          _rule('sizeOnDisk', <int>[0], 'greaterThan'),
        ],
        id: 3,
      ),
      _filterJson(
        'Requested',
        <Map<String, Object?>>[
          _rule('episodeRequested', <bool>[true], 'equal'),
        ],
        id: 5,
        type: 'releases',
      ),
    ];

    SonarrApi fakeApi() => SonarrApi(
          Dio(BaseOptions(baseUrl: 'http://localhost:8989/'))
            ..httpClientAdapter = _FakeAdapter(
              (String path) => path.endsWith('customfilter')
                  ? saved
                  : <Object?>[],
            ),
        );

    List<String> shown(ProviderContainer container) => container
        .read(sonarrFilteredSeriesProvider(instance))
        .value!
        .map((SonarrSeries s) => s.title)
        .toList();

    test('filters the list by the active custom filter', () {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          sonarrSeriesProvider(instance).overrideWith(
            (ref) => <SonarrSeries>[office, severance],
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(shown(container), <String>['Severance', 'The Office']);

      container.read(sonarrActiveCustomFilterProvider(instance).notifier).state =
          CustomFilterResource.fromJson(saved[1].cast<String, dynamic>());
      expect(shown(container), <String>['The Office']);

      // The search still narrows what the filter lets through.
      container.read(sonarrSearchQueryProvider(instance).notifier).state =
          'sever';
      expect(shown(container), isEmpty);
    });

    testWidgets('offers the saved filters and filters by the one picked',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sonarrApiProvider(instance).overrideWith((ref) => fakeApi()),
            sonarrSeriesProvider(instance).overrideWith(
              (ref) => <SonarrSeries>[office, severance],
            ),
            sonarrActiveTabBarIndexProvider(instance).overrideWith((ref) => 0),
          ],
          child: const MaterialApp(home: SeriesTab(instance: instance)),
        ),
      );
      await tester.pumpAndSettle();
      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(SeriesTab)),
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
        chips.sublist(chips.indexOf('Missing Episodes') + 1).take(2),
        <String>['Has downloads', 'No downloads'],
      );
      expect(find.text('Requested'), findsNothing);

      bool selected(String label) => tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label))
          .selected;

      await tester.tap(find.widgetWithText(ChoiceChip, 'No downloads'));
      await tester.pumpAndSettle();
      expect(selected('No downloads'), isTrue);
      expect(selected('All'), isFalse);
      expect(shown(container), <String>['Severance']);

      // A built-in filter takes over from the custom one.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Monitored Only'));
      await tester.pumpAndSettle();
      expect(selected('No downloads'), isFalse);
      expect(selected('Monitored Only'), isTrue);
      expect(shown(container), <String>['The Office']);

      // Tapping the active custom filter again goes back to everything.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Has downloads'));
      await tester.pumpAndSettle();
      expect(shown(container), <String>['The Office']);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Has downloads'));
      await tester.pumpAndSettle();
      expect(selected('All'), isTrue);
      expect(shown(container), <String>['Severance', 'The Office']);
    });
  });
}
