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
}
