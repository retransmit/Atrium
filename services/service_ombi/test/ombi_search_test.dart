import 'package:core_networking/core_networking.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_ombi/service_ombi.dart';

import 'support/fake_ombi.dart';
import 'support/ombi_fixtures.dart';
import 'support/ombi_test_instance.dart';
import 'support/pump.dart';

void main() {
  late FakeOmbi fake;

  setUp(() {
    fake = FakeOmbi()..on('POST', '/api/v2/Search/multi/arrival', searchJson);
  });

  Future<void> search(WidgetTester tester, String term) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (int _, Object __) => null,
        overrides: <Override>[
          instanceDioProvider(ombiTestInstance)
              .overrideWith((Ref ref) async => fakeOmbiDio(fake)),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showSearch<void>(
                    context: context,
                    useRootNavigator: true,
                    delegate: OmbiSearchDelegate(instance: ombiTestInstance),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), term);
    // Build the results first: that is what starts the provider's 350 ms
    // debounce. pump(duration) moves the clock before it builds a frame, so
    // without this the timer would only start at the end of the wait.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await settle(tester);
  }

  testWidgets('movies and shows come back, people do not',
      (WidgetTester tester) async {
    await search(tester, 'arrival');

    expect(find.text('Arrival'), findsOneWidget);
    expect(find.text('Severance'), findsOneWidget);
    expect(find.text('Amy Adams'), findsNothing);
  });

  testWidgets('a movie nobody asked for can be requested',
      (WidgetTester tester) async {
    fake
      ..on('GET', '/api/v2/Search/movie/329865', movieDetailJson())
      ..on('POST', '/api/v1/Request/movie', engineOk());
    await search(tester, 'arrival');

    await tester.tap(find.text('Arrival'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Request'));
    await settle(tester);

    expect(
      fake.to('POST', '/api/v1/Request/movie').single.body,
      <String, dynamic>{'theMovieDbId': 329865, 'is4kRequest': false},
    );
    expect(find.text('Requested Arrival'), findsOneWidget);
  });

  testWidgets('an already requested title says so instead',
      (WidgetTester tester) async {
    fake.on(
      'GET',
      '/api/v2/Search/movie/329865',
      movieDetailJson(requested: true),
    );
    await search(tester, 'arrival');

    await tester.tap(find.text('Arrival'));
    await settle(tester);

    // Ombi's own title page says Requested, approved or not.
    expect(find.text('Requested'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Request'), findsNothing);
  });

  testWidgets('an available title says Available', (WidgetTester tester) async {
    fake.on(
      'GET',
      '/api/v2/Search/movie/329865',
      movieDetailJson(available: true),
    );
    await search(tester, 'arrival');

    await tester.tap(find.text('Arrival'));
    await settle(tester);

    expect(find.text('Available'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Request'), findsNothing);
  });

  testWidgets('a show partly in says so and can still be requested',
      (WidgetTester tester) async {
    fake.on(
      'GET',
      '/api/v2/Search/tv/moviedb/95396',
      tvDetailJson(partlyAvailable: true),
    );
    await search(tester, 'arrival');

    await tester.tap(find.text('Severance'));
    await settle(tester);

    expect(find.text('Partially Available'), findsOneWidget);
    expect(find.text('All seasons'), findsOneWidget);
  });

  testWidgets('a show offers all, first or latest season',
      (WidgetTester tester) async {
    fake
      ..on('GET', '/api/v2/Search/tv/moviedb/95396', tvDetailJson())
      ..on('POST', '/api/v2/Requests/tv', engineOk());
    await search(tester, 'arrival');

    await tester.tap(find.text('Severance'));
    await settle(tester);
    expect(find.text('All seasons'), findsOneWidget);
    expect(find.text('First season'), findsOneWidget);
    await tester.tap(find.text('Latest season'));
    await settle(tester);

    expect(
      fake.to('POST', '/api/v2/Requests/tv').single.body,
      <String, dynamic>{
        'theMovieDbId': 95396,
        'requestAll': false,
        'firstSeason': false,
        'latestSeason': true,
      },
    );
  });

  testWidgets('a search that fails once is quietly tried again',
      (WidgetTester tester) async {
    // TMDB behind Ombi flakes often enough that one retry saves a tap.
    fake.failNext('POST', '/api/v2/Search/multi/arrival', 1);
    await search(tester, 'arrival');
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);

    expect(find.text('Arrival'), findsOneWidget);
    expect(fake.to('POST', '/api/v2/Search/multi/arrival'), hasLength(2));
  });

  testWidgets('a search that keeps failing gives up within seconds',
      (WidgetTester tester) async {
    fake.on(
      'POST',
      '/api/v2/Search/multi/arrival',
      <String, dynamic>{'error': 'parse error'},
      status: 500,
    );
    await search(tester, 'arrival');
    // Two retries, half a second apart, then the error. Riverpod's own
    // default would keep a spinner up for about half a minute.
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);

    expect(fake.to('POST', '/api/v2/Search/multi/arrival'), hasLength(3));
    expect(
      find.text(
        'Ombi could not search right now. It could not reach its movie '
        'database. Try again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });
}
