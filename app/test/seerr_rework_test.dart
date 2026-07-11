import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_seerr/service_seerr.dart';

/// Render tests for the reworked Seerr item-detail screen: the screen is
/// pumped with its data providers overridden to fixed results, proving the
/// hero/metadata/cast sections are wired and build without a live server.
Instance _instance() => Instance(
      id: 'test-seerr',
      name: 'Test Seerr',
      kind: ServiceKind.seerr,
      localUrl: 'http://localhost',
      externalUrl: '',
      urlMode: UrlMode.auto,
      auth: const InstanceAuth.apiKey(apiKey: 'k'),
    );

void main() {
  testWidgets('SeerrItemDetailScreen renders title, metadata, and cast',
      (WidgetTester tester) async {
    final Instance instance = _instance();
    // No poster/backdrop/profile paths: keeps the test free of network-image
    // loads (and of palette sampling, which is keyed off the poster URL).
    const SeerrDiscoverResult movie = SeerrDiscoverResult(
      id: 603,
      mediaType: 'movie',
      title: 'The Matrix',
      voteAverage: 8.2,
      releaseDate: '1999-03-30',
      runtime: 136,
      status: 'Released',
      overview: 'A computer hacker learns the truth about reality.',
      genres: <SeerrGenre>[SeerrGenre(id: 28, name: 'Action')],
      credits: SeerrCredits(
        cast: <SeerrCastMember>[
          SeerrCastMember(id: 6384, name: 'Keanu Reeves', character: 'Neo'),
        ],
      ),
    );
    final SeerrMediaDetailsArgs args =
        (instance: instance, mediaType: 'movie', tmdbId: 603);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          seerrMediaDetailsProvider(args).overrideWith(
            (Ref ref) async => movie,
          ),
          seerrRecommendationsProvider(args).overrideWith(
            (Ref ref) async => const <SeerrDiscoverResult>[],
          ),
          seerrSimilarProvider(args).overrideWith(
            (Ref ref) async => const <SeerrDiscoverResult>[],
          ),
        ],
        child: MaterialApp(
          theme: AtriumTheme.light(null),
          home: SeerrItemDetailScreen(instance: instance, item: movie),
        ),
      ),
    );
    // Each pump surfaces one async stage of the overridden FutureProviders.
    for (int i = 0; i < 4; i++) {
      await tester.pump();
    }

    expect(find.text('The Matrix'), findsOneWidget);
    expect(find.text('Keanu Reeves'), findsOneWidget);
    expect(find.text('Neo'), findsOneWidget);
    expect(find.text('Action'), findsOneWidget);
    expect(find.text('8.2'), findsOneWidget);
  });

  testWidgets('SeerrIssuesScreen renders an open issue with type and status',
      (WidgetTester tester) async {
    final Instance instance = _instance();
    const SeerrIssue issue = SeerrIssue(
      id: 1,
      issueType: 2, // Audio
      status: 1, // open
      media: SeerrMedia(id: 10, mediaType: 'movie', tmdbId: 603),
      createdBy: SeerrUser(displayName: 'lennox'),
      createdAt: '2026-07-01T10:00:00.000Z',
    );
    // No posterPath: keeps the card free of network-image loads.
    const SeerrDiscoverResult movie = SeerrDiscoverResult(
      id: 603,
      mediaType: 'movie',
      title: 'The Matrix',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          seerrIssuesProvider((instance: instance, filter: 'all')).overrideWith(
            (Ref ref) async => const <SeerrIssue>[issue],
          ),
          seerrMediaDetailsProvider(
            (instance: instance, mediaType: 'movie', tmdbId: 603),
          ).overrideWith((Ref ref) async => movie),
        ],
        child: MaterialApp(
          theme: AtriumTheme.light(null),
          home: Scaffold(body: SeerrIssuesScreen(instance: instance)),
        ),
      ),
    );
    for (int i = 0; i < 4; i++) {
      await tester.pump();
    }

    expect(find.text('The Matrix'), findsOneWidget);
    expect(find.text('Audio'), findsOneWidget);
    expect(find.text('lennox'), findsOneWidget);
    // 'Open' also labels a filter chip, so scope the pill assertion.
    expect(
      find.descendant(
        of: find.byType(SeerrIssueStatusPill),
        matching: find.text('Open'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('SeerrIssueDetailScreen renders the comment thread',
      (WidgetTester tester) async {
    final Instance instance = _instance();
    const SeerrIssue issue = SeerrIssue(
      id: 7,
      issueType: 3, // Subtitles
      status: 2, // resolved
      createdBy: SeerrUser(displayName: 'lennox'),
      comments: <SeerrIssueComment>[
        SeerrIssueComment(
          id: 1,
          message: 'Subtitles are out of sync.',
          user: SeerrUser(displayName: 'morpheus'),
          createdAt: '2026-07-02T09:30:00.000Z',
        ),
      ],
      createdAt: '2026-07-01T10:00:00.000Z',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          seerrIssueDetailProvider((instance: instance, id: 7)).overrideWith(
            (Ref ref) async => issue,
          ),
        ],
        child: MaterialApp(
          theme: AtriumTheme.light(null),
          home: SeerrIssueDetailScreen(instance: instance, issue: issue),
        ),
      ),
    );
    for (int i = 0; i < 4; i++) {
      await tester.pump();
    }

    expect(find.text('Subtitles'), findsOneWidget);
    expect(find.text('Subtitles are out of sync.'), findsOneWidget);
    expect(find.text('morpheus'), findsOneWidget);
    // A resolved issue offers the Reopen action.
    expect(find.text('Reopen'), findsOneWidget);
  });

  testWidgets('SeerrMediaCard shows the Available pill from mediaInfo.status',
      (WidgetTester tester) async {
    // No posterPath: keeps the card free of network-image loads.
    const SeerrDiscoverResult item = SeerrDiscoverResult(
      id: 603,
      mediaType: 'movie',
      title: 'The Matrix',
      releaseDate: '1999-03-30',
      voteAverage: 8.2,
      mediaInfo: SeerrMedia(mediaType: 'movie', tmdbId: 603, status: 5),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AtriumTheme.light(null),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              height: 250,
              child: SeerrMediaCard(item: item),
            ),
          ),
        ),
      ),
    );

    expect(find.text('The Matrix'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SeerrStatusBadge),
        matching: find.text('Available'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Request tile renders color-coded status pills and inline actions',
      (WidgetTester tester) async {
    final Instance instance = _instance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          seerrRequestsProvider(instance).overrideWith(
            (Ref ref) async => const <SeerrRequest>[
              SeerrRequest(
                id: 1,
                status: 1, // pending approval
                type: 'movie',
                media: SeerrMedia(mediaType: 'movie', tmdbId: 603, status: 3),
                requestedBy: SeerrUser(displayName: 'Bob'),
              ),
            ],
          ),
          // The request tile resolves the title from Seerr's media details.
          seerrMediaDetailsProvider(
            (instance: instance, mediaType: 'movie', tmdbId: 603),
          ).overrideWith(
            (Ref ref) async => const SeerrDiscoverResult(
              id: 603,
              mediaType: 'movie',
              title: 'The Matrix',
            ),
          ),
        ],
        child: MaterialApp(
          theme: AtriumTheme.light(null),
          home: Scaffold(body: SeerrHome(instance: instance)),
        ),
      ),
    );
    for (int i = 0; i < 4; i++) {
      await tester.pump();
    }

    expect(find.text('The Matrix'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    // Media status 3 -> Processing pill; request status 1 -> Pending pill.
    expect(
      find.descendant(
        of: find.byType(SeerrStatusPill),
        matching: find.text('Processing'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(SeerrStatusPill),
        matching: find.text('Pending'),
      ),
      findsOneWidget,
    );
    // Pending requests get inline approve / decline alongside delete.
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
    expect(find.byTooltip('Delete request'), findsOneWidget);
  });

  testWidgets('SeerrDiscoverScreen renders the Watchlist row',
      (WidgetTester tester) async {
    // Tall viewport so the lazy vertical list builds the first few rows
    // (Watchlist, Trending, Popular Movies) in one frame.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final Instance instance = _instance();
    // No posterPath: keeps the row free of network-image loads.
    const List<SeerrDiscoverResult> watchlist = <SeerrDiscoverResult>[
      SeerrDiscoverResult(id: 603, mediaType: 'movie', title: 'The Matrix'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          seerrWatchlistProvider(instance).overrideWith(
            (Ref ref) async => watchlist,
          ),
          seerrTrendingProvider(instance).overrideWith(
            (Ref ref) async => const <SeerrDiscoverResult>[],
          ),
          seerrDiscoverMoviesProvider(instance).overrideWith(
            (Ref ref) async => const <SeerrDiscoverResult>[],
          ),
          seerrDiscoverTvProvider(instance).overrideWith(
            (Ref ref) async => const <SeerrDiscoverResult>[],
          ),
          seerrUpcomingMoviesProvider(instance).overrideWith(
            (Ref ref) async => const <SeerrDiscoverResult>[],
          ),
          seerrUpcomingTvProvider(instance).overrideWith(
            (Ref ref) async => const <SeerrDiscoverResult>[],
          ),
          seerrMovieGenresProvider(instance).overrideWith(
            (Ref ref) async => const <SeerrGenre>[],
          ),
          seerrTvGenresProvider(instance).overrideWith(
            (Ref ref) async => const <SeerrGenre>[],
          ),
        ],
        child: MaterialApp(
          theme: AtriumTheme.light(null),
          home: Scaffold(body: SeerrDiscoverScreen(instance: instance)),
        ),
      ),
    );
    for (int i = 0; i < 4; i++) {
      await tester.pump();
    }

    expect(find.text('Watchlist'), findsOneWidget);
    expect(find.text('The Matrix'), findsOneWidget);
    // The Popular rows are wired with the same bold-header sections.
    expect(find.text('Popular Movies'), findsOneWidget);
  });
}
