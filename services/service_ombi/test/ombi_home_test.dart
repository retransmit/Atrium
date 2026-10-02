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

String _movies(String filter) =>
    '/api/v2/Requests/movie/${filter}25/0/requestedDate/desc';

final String _pendingMovies = _movies('pending/');
final String _allMovies = _movies('');

void main() {
  late FakeOmbi fake;

  setUp(() {
    fake = FakeOmbi()
      ..on('GET', '/api/v1/Lidarr/enabled', false)
      ..on('GET', '/api/v1/Request/count', countsJson)
      ..onCounts('movie', all: 4, pending: 1, processing: 2, available: 1)
      ..on(
        'GET',
        _pendingMovies,
        pageJson(<Map<String, dynamic>>[movieRequestJson()]),
      );
  });

  Future<void> open(WidgetTester tester) async {
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
  }

  bool chosen(WidgetTester tester, String chip) =>
      tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, chip)).selected;

  testWidgets('a pending movie shows who asked, and Approve and Deny',
      (WidgetTester tester) async {
    await open(tester);

    expect(find.textContaining('Arrival'), findsOneWidget);
    expect(find.textContaining('alice'), findsOneWidget);
    expect(find.text('Pending Approval'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Approve'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Deny'), findsOneWidget);
  });

  testWidgets('rows read like Ombi request list, 4K tag included',
      (WidgetTester tester) async {
    fake
      ..on(
        'GET',
        _pendingMovies,
        pageJson(<Map<String, dynamic>>[movieRequestJson(has4KRequest: true)]),
      )
      ..on(
        'GET',
        _movies('processing/'),
        pageJson(<Map<String, dynamic>>[movieRequestJson(approved: true)]),
      );
    await open(tester);

    expect(find.text('Pending Approval'), findsOneWidget);
    expect(find.text('4K'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Processing (2)'));
    await settle(tester);

    expect(find.text('Processing Request'), findsOneWidget);
    expect(find.text('4K'), findsNothing);
  });

  group('the filter chips', () {
    testWidgets('say how many requests each filter holds',
        (WidgetTester tester) async {
      await open(tester);

      for (final String chip in <String>[
        'All (4)',
        'Pending (1)',
        'Processing (2)',
        'Available (1)',
        'Denied (0)',
      ]) {
        expect(find.widgetWithText(ChoiceChip, chip), findsOneWidget);
      }
    });

    testWidgets('open on Pending when something is waiting',
        (WidgetTester tester) async {
      await open(tester);

      expect(chosen(tester, 'Pending (1)'), isTrue);
      expect(fake.to('GET', _pendingMovies), hasLength(1));
      expect(fake.to('GET', _allMovies), isEmpty);
    });

    testWidgets('open on All when nothing is waiting',
        (WidgetTester tester) async {
      // Pending is what you act on, but an empty list with everything else a
      // chip away reads as an empty server.
      fake
        ..onCounts('movie', all: 3, processing: 2, available: 1)
        ..on(
          'GET',
          _allMovies,
          pageJson(<Map<String, dynamic>>[movieRequestJson(approved: true)]),
        );
      await open(tester);

      expect(chosen(tester, 'All (3)'), isTrue);
      expect(find.text('Processing Request'), findsOneWidget);
      expect(fake.to('GET', _pendingMovies), isEmpty);
    });

    testWidgets('stay where they are when the last pending request is dealt with',
        (WidgetTester tester) async {
      fake.on('POST', '/api/v1/Request/movie/approve', engineOk());
      await open(tester);
      // What Ombi says once the request is approved.
      fake
        ..onCounts('movie', all: 4, processing: 3, available: 1)
        ..on('GET', _pendingMovies, pageJson(<Map<String, dynamic>>[]));

      await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
      await settle(tester, frames: 10);

      expect(chosen(tester, 'Pending (0)'), isTrue);
      expect(find.text('Nothing waiting for approval'), findsOneWidget);
      expect(fake.to('GET', _allMovies), isEmpty);
    });

    testWidgets('keep a picked filter when the kind changes',
        (WidgetTester tester) async {
      fake
        ..on(
          'GET',
          _movies('available/'),
          pageJson(<Map<String, dynamic>>[
            movieRequestJson(approved: true, available: true),
          ]),
        )
        ..onCounts('tv', all: 2, available: 2)
        ..on(
          'GET',
          '/api/v2/Requests/tv/available/25/0/requestedDate/desc',
          pageJson(<Map<String, dynamic>>[
            childRequestJson(approved: true, available: true),
          ]),
        );
      await open(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Available (1)'));
      await settle(tester);
      await tester.tap(find.text('TV'));
      await settle(tester, frames: 10);

      expect(chosen(tester, 'Available (2)'), isTrue);
      expect(find.textContaining('Severance'), findsOneWidget);
      expect(
        fake.to('GET', '/api/v2/Requests/tv/25/0/requestedDate/desc'),
        isEmpty,
      );
    });

    testWidgets('go plain and show everything when the counts cannot be read',
        (WidgetTester tester) async {
      for (final String filter in <String>[
        '',
        'pending/',
        'processing/',
        'available/',
        'denied/',
      ]) {
        fake.on(
          'GET',
          '/api/v2/Requests/movie/${filter}1/0/requestedDate/desc',
          <String, dynamic>{'error': 'boom'},
          status: 500,
        );
      }
      fake.on(
        'GET',
        _allMovies,
        pageJson(<Map<String, dynamic>>[movieRequestJson(approved: true)]),
      );
      await open(tester);

      expect(find.widgetWithText(ChoiceChip, 'Pending'), findsOneWidget);
      expect(chosen(tester, 'All'), isTrue);
      expect(find.text('Processing Request'), findsOneWidget);
    });
  });

  // Two tests rather than one re-pump: a second ProviderScope in the same
  // spot keeps the first one's container, and with it the cached answer.
  testWidgets('without Lidarr there is no Music segment',
      (WidgetTester tester) async {
    await open(tester);

    expect(find.text('Music'), findsNothing);
  });

  testWidgets('with Lidarr there is a Music segment',
      (WidgetTester tester) async {
    fake.on('GET', '/api/v1/Lidarr/enabled', true);
    await open(tester);

    expect(find.text('Music'), findsOneWidget);
  });

  testWidgets('Approve approves that request', (WidgetTester tester) async {
    fake.on('POST', '/api/v1/Request/movie/approve', engineOk());
    await open(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
    await settle(tester);

    expect(
      fake.to('POST', '/api/v1/Request/movie/approve').single.body,
      <String, dynamic>{'id': 11, 'is4K': false},
    );
    expect(find.text('Approved'), findsOneWidget);
  });

  testWidgets('Deny sends the reason typed into the dialog',
      (WidgetTester tester) async {
    fake.on('PUT', '/api/v1/Request/movie/deny', engineOk());
    await open(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Deny'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Already on Plex');
    await tester.tap(find.widgetWithText(FilledButton, 'Deny'));
    await settle(tester);

    expect(
      fake.to('PUT', '/api/v1/Request/movie/deny').single.body,
      <String, dynamic>{'id': 11, 'reason': 'Already on Plex', 'is4K': false},
    );
  });

  testWidgets('Delete asks first', (WidgetTester tester) async {
    fake.on('DELETE', '/api/v1/Request/movie/11', engineOk());
    await open(tester);

    await tester.tap(find.byTooltip('More'));
    await settle(tester);
    await tester.tap(find.text('Delete').last);
    await settle(tester);
    expect(fake.to('DELETE', '/api/v1/Request/movie/11'), isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await settle(tester);
    expect(fake.to('DELETE', '/api/v1/Request/movie/11'), hasLength(1));
  });

  testWidgets('a refusal from Ombi is shown in its own words',
      (WidgetTester tester) async {
    fake.on(
      'POST',
      '/api/v1/Request/movie/approve',
      engineError('Request not found'),
    );
    await open(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
    await settle(tester);

    expect(find.text('Request not found'), findsOneWidget);
  });

  testWidgets('the Denied chip asks for denied requests',
      (WidgetTester tester) async {
    fake.on(
      'GET',
      _movies('denied/'),
      pageJson(<Map<String, dynamic>>[]),
    );
    await open(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Denied (0)'));
    await settle(tester);

    expect(fake.to('GET', _movies('denied/')), hasLength(1));
    expect(find.text('Nothing denied'), findsOneWidget);
  });

  testWidgets('a refused key says where the key lives',
      (WidgetTester tester) async {
    fake.on(
      'GET',
      _pendingMovies,
      <String, dynamic>{'error': 'no'},
      status: 401,
    );
    await open(tester);

    expect(
      find.text('Ombi refused the API key. It is under Settings, Ombi.'),
      findsOneWidget,
    );
  });

  group('a request card', () {
    testWidgets('opens the title it is about', (WidgetTester tester) async {
      fake.on(
        'GET',
        '/api/v2/Search/movie/329865',
        movieDetailJson(requested: true),
      );
      await open(tester);

      await tester.tap(find.textContaining('Arrival'));
      await settle(tester);

      expect(fake.to('GET', '/api/v2/Search/movie/329865'), hasLength(1));
      // The title sheet, which says where the title stands.
      expect(find.text('Requested'), findsOneWidget);
    });

    testWidgets('for a show says which seasons and how many episodes are in',
        (WidgetTester tester) async {
      fake
        ..onCounts('tv', all: 1, processing: 1)
        ..on(
          'GET',
          '/api/v2/Requests/tv/25/0/requestedDate/desc',
          pageJson(<Map<String, dynamic>>[
            childRequestJson(
              approved: true,
              episodesIn: <bool>[true, false, false],
            ),
          ]),
        );
      await open(tester);

      await tester.tap(find.text('TV'));
      await settle(tester, frames: 10);

      expect(
        find.text('Season 1 · 1 of 3 episodes available'),
        findsOneWidget,
      );
    });

    testWidgets('says why a denied request was denied',
        (WidgetTester tester) async {
      fake
        ..onCounts('movie', all: 2, pending: 1, denied: 1)
        ..on(
          'GET',
          _movies('denied/'),
          pageJson(<Map<String, dynamic>>[
            movieRequestJson(denied: true, deniedReason: 'Already on Plex'),
          ]),
        );
      await open(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Denied (1)'));
      await settle(tester);

      expect(find.text('Denied'), findsOneWidget);
      expect(find.text('Already on Plex'), findsOneWidget);
    });

    // Ombi clears the denied flag when a denied request is approved after
    // all, and leaves the old reason on it.
    testWidgets('drops the reason of a denial that was later overturned',
        (WidgetTester tester) async {
      fake.on(
        'GET',
        _movies('processing/'),
        pageJson(<Map<String, dynamic>>[
          movieRequestJson(approved: true, deniedReason: 'Already on Plex'),
        ]),
      );
      await open(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Processing (2)'));
      await settle(tester);

      expect(find.text('Processing Request'), findsOneWidget);
      expect(find.text('Already on Plex'), findsNothing);
    });
  });

  group('the screen itself', () {
    void discover() {
      fake
        ..on('GET', '/api/v2/Search/movie/popular/0/20', <Object>[
          discoverMovieJson(),
        ])
        ..on('GET', '/api/v2/Search/movie/upcoming/0/20', <Object>[])
        ..on('GET', '/api/v2/Search/tv/popular/0/20', <Object>[])
        ..on('GET', '/api/v2/Search/tv/trending/0/20', <Object>[]);
    }

    int tab(WidgetTester tester) =>
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

    testWidgets('loads Discover only once its tab is opened',
        (WidgetTester tester) async {
      // Every Discover row is a round trip through TheMovieDB. Someone who
      // came to approve a request should not pay for four of them.
      discover();
      await open(tester);
      expect(fake.to('GET', '/api/v2/Search/movie/popular/0/20'), isEmpty);

      await tester.tap(find.text('Discover'));
      await settle(tester, frames: 10);

      expect(fake.to('GET', '/api/v2/Search/movie/popular/0/20'), hasLength(1));
      expect(find.text('Popular movies'), findsOneWidget);
      expect(tab(tester), 1);
    });

    testWidgets('goes back to Requests before it leaves',
        (WidgetTester tester) async {
      discover();
      await open(tester);
      await tester.tap(find.text('Discover'));
      await settle(tester, frames: 10);

      // The system back, as Android delivers it.
      await tester.binding.handlePopRoute();
      await settle(tester);

      expect(tab(tester), 0);
      expect(find.textContaining('Arrival'), findsOneWidget);
    });

    testWidgets('has a search button that opens search',
        (WidgetTester tester) async {
      await open(tester);

      await tester.tap(find.byTooltip('Search'));
      await settle(tester);

      expect(find.text('Search movies and shows'), findsOneWidget);
    });
  });
}
