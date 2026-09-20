import 'package:flutter_test/flutter_test.dart';
import 'package:service_ombi/service_ombi.dart';

import 'support/fake_ombi.dart';
import 'support/ombi_fixtures.dart';

void main() {
  late FakeOmbi fake;
  late OmbiRequestService requests;

  setUp(() {
    fake = FakeOmbi();
    requests = OmbiClient.fromDio(fakeOmbiDio(fake)).requestService;
  });

  group('list', () {
    test('pending movies come from the pending route, newest first', () async {
      fake.on(
        'GET',
        '/api/v2/Requests/movie/pending/25/0/requestedDate/desc',
        pageJson(<Map<String, dynamic>>[movieRequestJson()], total: 1),
      );

      final OmbiRequestPage page =
          await requests.list(OmbiMediaKind.movie, OmbiRequestFilter.pending);

      expect(page.total, 1);
      expect(page.items.single.title, 'Arrival');
    });

    test('All uses the unfiltered route and later pages move on', () async {
      fake.on(
        'GET',
        '/api/v2/Requests/tv/25/50/requestedDate/desc',
        pageJson(<Map<String, dynamic>>[childRequestJson()], total: 51),
      );

      final OmbiRequestPage page = await requests
          .list(OmbiMediaKind.tv, OmbiRequestFilter.all, page: 2);

      expect(page.items.single.kind, OmbiMediaKind.tv);
      expect(page.total, 51);
    });

    test('albums come from the album routes', () async {
      fake.on(
        'GET',
        '/api/v2/Requests/album/processing/25/0/requestedDate/desc',
        pageJson(<Map<String, dynamic>>[albumRequestJson()]),
      );

      final OmbiRequestPage page = await requests
          .list(OmbiMediaKind.music, OmbiRequestFilter.processing);

      expect(page.items.single.title, 'John Coltrane - Blue Train');
    });

    test('a refused key surfaces as a 401', () async {
      fake.on(
        'GET',
        '/api/v2/Requests/movie/pending/25/0/requestedDate/desc',
        <String, dynamic>{'error': 'unauthorized'},
        status: 401,
      );

      await expectLater(
        requests.list(OmbiMediaKind.movie, OmbiRequestFilter.pending),
        throwsA(
          isA<OmbiException>()
              .having((OmbiException e) => e.statusCode, 'status', 401),
        ),
      );
    });
  });

  test('recent mixes movies and TV, newest first', () async {
    fake
      ..on(
        'GET',
        '/api/v2/Requests/movie/25/0/requestedDate/desc',
        pageJson(<Map<String, dynamic>>[
          movieRequestJson(requestedDate: '2026-09-10T00:00:00'),
        ]),
      )
      ..on(
        'GET',
        '/api/v2/Requests/tv/25/0/requestedDate/desc',
        pageJson(<Map<String, dynamic>>[
          childRequestJson(requestedDate: '2026-09-12T00:00:00'),
        ]),
      );

    final List<OmbiRequest> recent = await requests.recent();

    expect(recent.map((OmbiRequest r) => r.title), <String>[
      'Severance',
      'Arrival',
    ]);
  });

  group('actions', () {
    test('approving a show approves the child request', () async {
      fake.on('POST', '/api/v1/Request/tv/approve', engineOk());

      await requests.approve(OmbiMediaKind.tv, 21);

      expect(
        fake.to('POST', '/api/v1/Request/tv/approve').single.body,
        <String, dynamic>{'id': 21},
      );
    });

    test('approving a movie leaves 4K alone', () async {
      fake.on('POST', '/api/v1/Request/movie/approve', engineOk());

      await requests.approve(OmbiMediaKind.movie, 11);

      expect(
        fake.to('POST', '/api/v1/Request/movie/approve').single.body,
        <String, dynamic>{'id': 11, 'is4K': false},
      );
    });

    test('denying sends the reason', () async {
      fake.on('PUT', '/api/v1/Request/movie/deny', engineOk());

      await requests.deny(OmbiMediaKind.movie, 11, reason: 'Already on Plex');

      expect(
        fake.to('PUT', '/api/v1/Request/movie/deny').single.body,
        <String, dynamic>{
          'id': 11,
          'reason': 'Already on Plex',
          'is4K': false,
        },
      );
    });

    test('deleting a show deletes the child request', () async {
      fake.on('DELETE', '/api/v1/Request/tv/child/21', engineOk());

      await requests.delete(OmbiMediaKind.tv, 21);

      expect(fake.to('DELETE', '/api/v1/Request/tv/child/21'), hasLength(1));
    });

    test('music uses the music routes', () async {
      fake
        ..on('POST', '/api/v1/request/music/approve', engineOk())
        ..on('PUT', '/api/v1/request/music/deny', engineOk())
        ..on('DELETE', '/api/v1/request/music/31', engineOk());

      await requests.approve(OmbiMediaKind.music, 31);
      await requests.deny(OmbiMediaKind.music, 31);
      await requests.delete(OmbiMediaKind.music, 31);

      expect(
        fake.to('PUT', '/api/v1/request/music/deny').single.body,
        <String, dynamic>{'id': 31, 'reason': ''},
      );
      expect(fake.to('DELETE', '/api/v1/request/music/31'), hasLength(1));
    });

    test('Ombi refusing inside a 200 is a failure', () async {
      fake.on(
        'POST',
        '/api/v1/Request/movie/approve',
        engineError('Request not found'),
      );

      await expectLater(
        requests.approve(OmbiMediaKind.movie, 11),
        throwsA(
          isA<OmbiException>().having(
            (OmbiException e) => e.message,
            'message',
            'Request not found',
          ),
        ),
      );
    });
  });

  group('creating requests', () {
    test('a movie is requested by its TMDB id', () async {
      fake.on('POST', '/api/v1/Request/movie', engineOk());

      await requests.requestMovie(329865);

      expect(
        fake.to('POST', '/api/v1/Request/movie').single.body,
        <String, dynamic>{'theMovieDbId': 329865, 'is4kRequest': false},
      );
    });

    test('a show goes to the v2 route, which takes a TMDB id', () async {
      // v1 wants a TVDB id, which search does not give us.
      fake.on('POST', '/api/v2/Requests/tv', engineOk());

      await requests.requestTv(95396, OmbiTvSeasons.latest);

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
  });

  test('counts and the music switch', () async {
    fake
      ..on('GET', '/api/v1/Request/count', countsJson)
      ..on('GET', '/api/v1/Lidarr/enabled', true);

    expect((await requests.counts()).total, 8);
    expect(await requests.musicEnabled(), isTrue);
  });
}
