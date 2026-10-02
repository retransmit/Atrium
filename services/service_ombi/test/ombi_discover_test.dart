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
    fake = FakeOmbi()
      ..on('GET', '/api/v1/Lidarr/enabled', false)
      ..onCounts('movie')
      ..on(
        'GET',
        '/api/v2/Requests/movie/25/0/requestedDate/desc',
        pageJson(<Map<String, dynamic>>[]),
      )
      ..on('GET', '/api/v2/Search/movie/popular/0/20', <Object>[
        discoverMovieJson(),
      ])
      ..on('GET', '/api/v2/Search/movie/upcoming/0/20', <Object>[
        discoverMovieJson(id: 1, title: 'Soon'),
      ])
      ..on('GET', '/api/v2/Search/tv/popular/0/20', <Object>[
        discoverShowJson(),
      ])
      ..on('GET', '/api/v2/Search/tv/trending/0/20', <Object>[
        discoverShowJson(id: 2, title: 'Hot'),
      ]);
  });

  Future<void> openDiscover(WidgetTester tester) async {
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
        child: const MaterialApp(home: OmbiHome(instance: ombiTestInstance)),
      ),
    );
    await settle(tester, frames: 10);
    await tester.tap(find.text('Discover'));
    await settle(tester, frames: 12);
  }

  testWidgets('Discover shows a row for each list',
      (WidgetTester tester) async {
    await openDiscover(tester);

    expect(find.text('Popular movies'), findsOneWidget);
    expect(find.text('Spider-Man: Brand New Day'), findsOneWidget);
    expect(find.text('Upcoming movies'), findsOneWidget);
    expect(find.text('Soon'), findsOneWidget);
    expect(find.text('Popular TV'), findsOneWidget);
    expect(find.text('The Scandal'), findsOneWidget);
    expect(find.text('Trending TV'), findsOneWidget);
    expect(find.text('Hot'), findsOneWidget);
  });

  testWidgets('a card shows the year and the score',
      (WidgetTester tester) async {
    fake
      ..on('GET', '/api/v2/Search/movie/upcoming/0/20', <Object>[])
      ..on('GET', '/api/v2/Search/tv/popular/0/20', <Object>[])
      ..on('GET', '/api/v2/Search/tv/trending/0/20', <Object>[]);
    await openDiscover(tester);

    // Released 2026-07-31 and scored 7.9 on TheMovieDB.
    expect(find.text('2026'), findsOneWidget);
    expect(find.text('7.9'), findsOneWidget);
  });

  testWidgets('a title with no score yet shows none',
      (WidgetTester tester) async {
    fake
      ..on('GET', '/api/v2/Search/movie/popular/0/20', <Object>[])
      ..on('GET', '/api/v2/Search/movie/upcoming/0/20', <Object>[])
      ..on('GET', '/api/v2/Search/tv/popular/0/20', <Object>[
        discoverShowJson(rating: '0'),
      ])
      ..on('GET', '/api/v2/Search/tv/trending/0/20', <Object>[]);
    await openDiscover(tester);

    expect(find.text('The Scandal'), findsOneWidget);
    expect(find.text('0.0'), findsNothing);
  });

  testWidgets('a card says in words when a title is requested or available',
      (WidgetTester tester) async {
    fake
      ..on('GET', '/api/v2/Search/movie/popular/0/20', <Object>[
        discoverMovieJson(requested: true),
      ])
      ..on('GET', '/api/v2/Search/movie/upcoming/0/20', <Object>[
        discoverMovieJson(id: 1, title: 'Soon', available: true),
      ]);
    await openDiscover(tester);

    expect(find.text('Requested'), findsOneWidget);
    expect(find.text('Available'), findsOneWidget);
  });

  testWidgets('a poster opens the request sheet', (WidgetTester tester) async {
    fake.on('GET', '/api/v2/Search/movie/969681', movieDetailJson());
    await openDiscover(tester);

    await tester.tap(find.text('Spider-Man: Brand New Day'));
    await settle(tester);

    expect(find.widgetWithText(FilledButton, 'Request'), findsOneWidget);
  });

  testWidgets('a title Ombi cannot look up says why, with a retry',
      (WidgetTester tester) async {
    fake.on(
      'GET',
      '/api/v2/Search/movie/969681',
      <String, dynamic>{'error': 'parse error'},
      status: 500,
    );
    await openDiscover(tester);

    await tester.tap(find.text('Spider-Man: Brand New Day'));
    await settle(tester);
    // Past the two quick retries.
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);

    expect(
      find.text(
        'Ombi could not look this title up right now. It could not reach '
        'its movie database.',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Request'), findsNothing);
  });

  testWidgets('a list that fails keeps to its own row',
      (WidgetTester tester) async {
    fake.on(
      'GET',
      '/api/v2/Search/tv/trending/0/20',
      <String, dynamic>{'error': 'parse error'},
      status: 500,
    );
    await openDiscover(tester);
    // Past the two quick retries.
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);

    expect(
      find.text(
        'Ombi could not load this list right now. It could not reach its '
        'movie database.',
      ),
      findsOneWidget,
    );
    expect(find.text('Spider-Man: Brand New Day'), findsOneWidget);
    expect(find.text('The Scandal'), findsOneWidget);
  });
}
