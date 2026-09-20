import 'package:flutter_test/flutter_test.dart';
import 'package:service_ombi/service_ombi.dart';

import 'support/fake_ombi.dart';
import 'support/ombi_fixtures.dart';

void main() {
  late FakeOmbi fake;
  late OmbiSearchService search;

  setUp(() {
    fake = FakeOmbi();
    search = OmbiClient.fromDio(fakeOmbiDio(fake)).searchService;
  });

  test('search asks for movies and shows only', () async {
    fake.on('POST', '/api/v2/Search/multi/arrival', searchJson);

    final List<OmbiSearchHit> hits = await search.search('arrival');

    expect(hits.map((OmbiSearchHit h) => h.title), <String>[
      'Arrival',
      'Severance',
    ]);
    expect(
      fake.to('POST', '/api/v2/Search/multi/arrival').single.body,
      <String, dynamic>{
        'movies': true,
        'tvShows': true,
        'music': false,
        'people': false,
      },
    );
  });

  test('a term with a space and a slash stays one path segment', () async {
    fake.on('POST', '/api/v2/Search/multi/the%20office%2Fuk', searchJson);

    await search.search('the office/uk');

    expect(
      fake.to('POST', '/api/v2/Search/multi/the%20office%2Fuk'),
      hasLength(1),
    );
  });

  test('an empty term asks nothing', () async {
    expect(await search.search('   '), isEmpty);
    expect(fake.seen, isEmpty);
  });

  test('a failed search carries its status for the message', () async {
    fake.on(
      'POST',
      '/api/v2/Search/multi/arrival',
      <String, dynamic>{
        'error': 'Unexpected character encountered while parsing value: <.',
      },
      status: 500,
    );

    await expectLater(
      search.search('arrival'),
      throwsA(
        isA<OmbiException>()
            .having((OmbiException e) => e.statusCode, 'status', 500),
      ),
    );
  });

  test('a movie reads its state from the movie detail', () async {
    fake.on(
      'GET',
      '/api/v2/Search/movie/329865',
      movieDetailJson(requested: true, approved: true),
    );

    final OmbiTitleState s =
        await search.titleState(OmbiMediaKind.movie, 329865);

    expect(s.requested, isTrue);
    expect(s.approved, isTrue);
  });

  test('a show reads its state from the TMDB detail route', () async {
    fake.on(
      'GET',
      '/api/v2/Search/tv/moviedb/95396',
      tvDetailJson(partlyAvailable: true),
    );

    final OmbiTitleState s = await search.titleState(OmbiMediaKind.tv, 95396);

    expect(s.partlyAvailable, isTrue);
  });

  test('each Discover row comes from its own route', () async {
    fake
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

    Future<List<String>> titles(OmbiDiscoverRow row) async =>
        (await search.discover(row)).map((OmbiSearchHit h) => h.title).toList();

    expect(
      await titles(OmbiDiscoverRow.popularMovies),
      <String>['Spider-Man: Brand New Day'],
    );
    expect(await titles(OmbiDiscoverRow.upcomingMovies), <String>['Soon']);
    expect(await titles(OmbiDiscoverRow.popularTv), <String>['The Scandal']);
    expect(await titles(OmbiDiscoverRow.trendingTv), <String>['Hot']);
  });
}
