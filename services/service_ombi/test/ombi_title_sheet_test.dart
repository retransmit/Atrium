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

const OmbiSearchHit _arrival = OmbiSearchHit(
  tmdbId: 329865,
  kind: OmbiMediaKind.movie,
  title: 'Arrival',
);

const OmbiSearchHit _severance = OmbiSearchHit(
  tmdbId: 95396,
  kind: OmbiMediaKind.tv,
  title: 'Severance',
);

void main() {
  late FakeOmbi fake;

  setUp(() => fake = FakeOmbi());

  Future<void> openSheet(WidgetTester tester, OmbiSearchHit hit) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
                  onPressed: () => showOmbiRequestSheet(
                    context: context,
                    instance: ombiTestInstance,
                    hit: hit,
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
    await settle(tester, frames: 10);
  }

  testWidgets('a film is described: when, how long, its score and genres',
      (WidgetTester tester) async {
    fake.on('GET', '/api/v2/Search/movie/329865', movieDetailJson());
    await openSheet(tester, _arrival);

    expect(find.text('Movie · 2016 · 1h 56m · Released'), findsOneWidget);
    expect(find.text('Why are they here?'), findsOneWidget);
    expect(find.text('7.6'), findsOneWidget);
    expect(find.text('Drama'), findsOneWidget);
    expect(find.text('Science Fiction'), findsOneWidget);
    // The overview box keeps a collapsed and an open copy of its text.
    expect(
      find.text('A linguist is recruited to talk to visitors.'),
      findsWidgets,
    );
  });

  testWidgets('a show names its network and whether it is still running',
      (WidgetTester tester) async {
    fake.on('GET', '/api/v2/Search/tv/moviedb/95396', tvDetailJson());
    await openSheet(tester, _severance);

    expect(
      find.text('TV show · 2022 · 50m · Apple TV+ · Returning Series'),
      findsOneWidget,
    );
    expect(find.text('8.4'), findsOneWidget);
    expect(find.text('Mystery'), findsOneWidget);
  });

  testWidgets('a title Ombi cannot look up still shows what the list knew',
      (WidgetTester tester) async {
    fake.on(
      'GET',
      '/api/v2/Search/movie/969681',
      <String, dynamic>{'error': 'parse error'},
      status: 500,
    );
    await openSheet(
      tester,
      const OmbiSearchHit(
        tmdbId: 969681,
        kind: OmbiMediaKind.movie,
        title: 'Spider-Man: Brand New Day',
        year: 2026,
        rating: 7.9,
        overview: 'Peter Parker starts over.',
      ),
    );
    // Past the two quick retries a lookup gets before it gives up.
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);

    expect(find.text('Movie · 2026'), findsOneWidget);
    expect(find.text('7.9'), findsOneWidget);
    expect(find.text('Peter Parker starts over.'), findsWidgets);
    expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
  });
}
