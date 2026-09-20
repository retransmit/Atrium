import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_radarr/service_radarr.dart';
import 'package:service_radarr/src/home/movies_tab.dart';

void main() {
  const instance = Instance(
    id: 'radarr-test-1',
    name: 'Radarr Test',
    kind: ServiceKind.radarr,
    localUrl: 'http://localhost:7878',
    externalUrl: '',
    urlMode: UrlMode.auto,
    auth: InstanceAuthApiKey(apiKey: 'test-key'),
  );

  group('Radarr Search Carry-Over', () {
    testWidgets('AddMovieScreen initializes with empty query by default',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            radarrMoviesProvider(instance).overrideWith((ref) => []),
            radarrLookupMovieProvider((instance, '')).overrideWith((ref) => []),
          ],
          child: const MaterialApp(
            home: AddMovieScreen(instance: instance),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final searchBarFinder = find.byType(SearchBar);
      expect(searchBarFinder, findsOneWidget);
      final searchBar = tester.widget<SearchBar>(searchBarFinder);
      expect(searchBar.controller?.text, isEmpty);
      expect(find.text('Search for a movie to add'), findsOneWidget);
    });

    testWidgets(
        'AddMovieScreen initializes with initialQuery and triggers lookup immediately',
        (tester) async {
      const query = 'Inception';
      const movie = RadarrMovie(
        id: 101,
        title: 'Inception',
        year: 2010,
        overview: 'A thief who steals corporate secrets through dream-sharing.',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            radarrMoviesProvider(instance).overrideWith((ref) => []),
            radarrLookupMovieProvider((instance, query))
                .overrideWith((ref) => [movie]),
          ],
          child: const MaterialApp(
            home: AddMovieScreen(
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
          matching: find.text('Inception'),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'MoviesTab shows empty state without online search action when search query is empty',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            radarrFilteredMoviesProvider(instance)
                .overrideWith((ref) => const AsyncValue.data([])),
            radarrSearchQueryProvider(instance).overrideWith((ref) => ''),
            radarrActiveTabBarIndexProvider(instance).overrideWith((ref) => 0),
          ],
          child: const MaterialApp(
            home: MoviesTab(instance: instance),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No movies found'), findsOneWidget);
      expect(find.textContaining('Search online for'), findsNothing);
    });

    testWidgets(
        'MoviesTab shows "Search online for <query>" button and navigates with initialQuery',
        (tester) async {
      const query = 'Interstellar';
      const movie = RadarrMovie(
        id: 102,
        title: 'Interstellar',
        year: 2014,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            radarrFilteredMoviesProvider(instance)
                .overrideWith((ref) => const AsyncValue.data([])),
            radarrSearchQueryProvider(instance).overrideWith((ref) => query),
            radarrActiveTabBarIndexProvider(instance).overrideWith((ref) => 0),
            radarrMoviesProvider(instance).overrideWith((ref) => []),
            radarrLookupMovieProvider((instance, query))
                .overrideWith((ref) => [movie]),
          ],
          child: const MaterialApp(
            home: MoviesTab(instance: instance),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final actionButtonFinder =
          find.text('Search online for "$query"');
      expect(actionButtonFinder, findsOneWidget);

      await tester.tap(actionButtonFinder);
      await tester.pumpAndSettle();

      expect(find.byType(AddMovieScreen), findsOneWidget);
      final searchBarFinder = find.byType(SearchBar);
      expect(searchBarFinder, findsOneWidget);
      final searchBar = tester.widget<SearchBar>(searchBarFinder);
      expect(searchBar.controller?.text, query);
      expect(
        find.descendant(
          of: find.byType(Card),
          matching: find.text('Interstellar'),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'MoviesTab Add Movie FAB carries over active query to AddMovieScreen',
        (tester) async {
      const query = 'The Dark Knight';
      const movie = RadarrMovie(
        id: 103,
        title: 'The Dark Knight',
        year: 2008,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            radarrFilteredMoviesProvider(instance)
                .overrideWith((ref) => const AsyncValue.data([])),
            radarrSearchQueryProvider(instance).overrideWith((ref) => query),
            radarrActiveTabBarIndexProvider(instance).overrideWith((ref) => 0),
            radarrMoviesProvider(instance).overrideWith((ref) => []),
            radarrLookupMovieProvider((instance, query))
                .overrideWith((ref) => [movie]),
          ],
          child: const MaterialApp(
            home: MoviesTab(instance: instance),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fabFinder = find.byType(FloatingActionButton);
      expect(fabFinder, findsWidgets);
      final addMovieFab = find.widgetWithText(FloatingActionButton, 'Add Movie');
      expect(addMovieFab, findsOneWidget);

      await tester.tap(addMovieFab);
      await tester.pumpAndSettle();

      expect(find.byType(AddMovieScreen), findsOneWidget);
      final searchBarFinder = find.byType(SearchBar);
      expect(searchBarFinder, findsOneWidget);
      final searchBar = tester.widget<SearchBar>(searchBarFinder);
      expect(searchBar.controller?.text, query);
    });
  });
}
