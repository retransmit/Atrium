import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_sonarr/service_sonarr.dart';
import 'package:service_sonarr/src/home/series_tab.dart';

void main() {
  const instance = Instance(
    id: 'sonarr-test-1',
    name: 'Sonarr Test',
    kind: ServiceKind.sonarr,
    localUrl: 'http://localhost:8989',
    externalUrl: '',
    urlMode: UrlMode.auto,
    auth: InstanceAuthApiKey(apiKey: 'test-key'),
  );

  group('Sonarr Search Carry-Over', () {
    testWidgets('SonarrAddSeriesSearchScreen initializes with empty query by default',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sonarrSeriesProvider(instance).overrideWith((ref) => []),
            sonarrLookupSeriesProvider((instance, ''))
                .overrideWith((ref) => []),
          ],
          child: const MaterialApp(
            home: SonarrAddSeriesSearchScreen(instance: instance),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final searchBarFinder = find.byType(SearchBar);
      expect(searchBarFinder, findsOneWidget);
      final searchBar = tester.widget<SearchBar>(searchBarFinder);
      expect(searchBar.controller?.text, isEmpty);
      expect(find.text('Search for a TV show to add'), findsOneWidget);
    });

    testWidgets(
        'SonarrAddSeriesSearchScreen initializes with initialQuery and triggers lookup immediately',
        (tester) async {
      const query = 'Breaking Bad';
      const series = SonarrSeries(
        id: 201,
        title: 'Breaking Bad',
        overview: 'A chemistry teacher diagnosed with lung cancer turns to manufacturing meth.',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sonarrSeriesProvider(instance).overrideWith((ref) => []),
            sonarrLookupSeriesProvider((instance, query))
                .overrideWith((ref) => [series]),
          ],
          child: const MaterialApp(
            home: SonarrAddSeriesSearchScreen(
              instance: instance,
              initialQuery: query,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final searchBarFinder = find.byType(SearchBar);
      expect(searchBarFinder, findsOneWidget);
      final searchBar = tester.widget<SearchBar>(searchBarFinder);
      expect(searchBar.controller?.text, query);
      expect(searchBar.controller?.selection.baseOffset, query.length);
      expect(
        find.descendant(
          of: find.byType(Card),
          matching: find.text('Breaking Bad'),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'SeriesTab shows empty state without online search action when search query is empty',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sonarrFilteredSeriesProvider(instance)
                .overrideWith((ref) => const AsyncValue.data([])),
            sonarrSearchQueryProvider(instance).overrideWith((ref) => ''),
            sonarrActiveTabBarIndexProvider(instance).overrideWith((ref) => 0),
          ],
          child: const MaterialApp(
            home: SeriesTab(instance: instance),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No series found'), findsOneWidget);
      expect(find.textContaining('Search online for'), findsNothing);
    });

    testWidgets(
        'SeriesTab shows "Search online for <query>" button and navigates with initialQuery',
        (tester) async {
      const query = 'Severance';
      const series = SonarrSeries(
        id: 202,
        title: 'Severance',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sonarrFilteredSeriesProvider(instance)
                .overrideWith((ref) => const AsyncValue.data([])),
            sonarrSearchQueryProvider(instance).overrideWith((ref) => query),
            sonarrActiveTabBarIndexProvider(instance).overrideWith((ref) => 0),
            sonarrSeriesProvider(instance).overrideWith((ref) => []),
            sonarrLookupSeriesProvider((instance, query))
                .overrideWith((ref) => [series]),
          ],
          child: const MaterialApp(
            home: SeriesTab(instance: instance),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final actionButtonFinder =
          find.text('Search online for "$query"');
      expect(actionButtonFinder, findsOneWidget);

      await tester.tap(actionButtonFinder);
      await tester.pumpAndSettle();

      expect(find.byType(SonarrAddSeriesSearchScreen), findsOneWidget);
      final searchBarFinder = find.byType(SearchBar);
      expect(searchBarFinder, findsOneWidget);
      final searchBar = tester.widget<SearchBar>(searchBarFinder);
      expect(searchBar.controller?.text, query);
      expect(
        find.descendant(
          of: find.byType(Card),
          matching: find.text('Severance'),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'SeriesTab Add Series FAB carries over active query to SonarrAddSeriesSearchScreen',
        (tester) async {
      const query = 'Better Call Saul';
      const series = SonarrSeries(
        id: 203,
        title: 'Better Call Saul',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sonarrFilteredSeriesProvider(instance)
                .overrideWith((ref) => const AsyncValue.data([])),
            sonarrSearchQueryProvider(instance).overrideWith((ref) => query),
            sonarrActiveTabBarIndexProvider(instance).overrideWith((ref) => 0),
            sonarrSeriesProvider(instance).overrideWith((ref) => []),
            sonarrLookupSeriesProvider((instance, query))
                .overrideWith((ref) => [series]),
          ],
          child: const MaterialApp(
            home: SeriesTab(instance: instance),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final addSeriesFab = find.widgetWithText(FloatingActionButton, 'Add Series');
      expect(addSeriesFab, findsOneWidget);

      await tester.tap(addSeriesFab);
      await tester.pumpAndSettle();

      expect(find.byType(SonarrAddSeriesSearchScreen), findsOneWidget);
      final searchBarFinder = find.byType(SearchBar);
      expect(searchBarFinder, findsOneWidget);
      final searchBar = tester.widget<SearchBar>(searchBarFinder);
      expect(searchBar.controller?.text, query);
    });
  });
}
