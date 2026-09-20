import 'package:flutter_test/flutter_test.dart';
import 'package:service_ombi/service_ombi.dart';

import 'support/ombi_fixtures.dart';

void main() {
  group('requests', () {
    test('a pending movie keeps its title, year, requester and poster', () {
      final OmbiRequest r =
          ombiRequestFromMovie(MovieRequests.fromJson(movieRequestJson()));

      expect(r.id, 11);
      expect(r.kind, OmbiMediaKind.movie);
      expect(r.title, 'Arrival');
      expect(r.year, 2016);
      expect(r.requestedBy, 'alice');
      expect(r.requestedAt, DateTime.parse('2026-09-18T10:15:00'));
      expect(r.status, OmbiRequestStatus.pending);
      expect(
        r.posterUrl,
        'https://image.tmdb.org/t/p/w185/x2FJsf1ElAgr63Y3PNPtJrcmpoe.jpg',
      );
    });

    test('status follows Ombi request list: available, denied, approved',
        () {
      OmbiRequestStatus of(Map<String, dynamic> json) =>
          ombiRequestFromMovie(MovieRequests.fromJson(json)).status;

      expect(of(movieRequestJson()), OmbiRequestStatus.pending);
      expect(
        of(movieRequestJson(approved: true)),
        OmbiRequestStatus.processing,
      );
      expect(
        of(movieRequestJson(approved: true, available: true)),
        OmbiRequestStatus.available,
      );
      expect(
        of(movieRequestJson(approved: true, denied: true)),
        OmbiRequestStatus.denied,
      );
      // Ombi's sync can find a title it had denied. Its request list then
      // says Available.
      expect(
        of(movieRequestJson(denied: true, available: true)),
        OmbiRequestStatus.available,
      );
    });

    test('the Recently Requested status puts a denial first', () {
      OmbiRecentStatus of(Map<String, dynamic> json) =>
          ombiRequestFromMovie(MovieRequests.fromJson(json)).recentStatus;

      expect(of(movieRequestJson()), OmbiRecentStatus.pending);
      expect(of(movieRequestJson(approved: true)), OmbiRecentStatus.approved);
      expect(
        of(movieRequestJson(approved: true, available: true)),
        OmbiRecentStatus.available,
      );
      expect(
        of(movieRequestJson(denied: true, available: true)),
        OmbiRecentStatus.denied,
      );
    });

    test('a show with some requested episodes in is partly available', () {
      OmbiRequest of(Map<String, dynamic> json) =>
          ombiRequestFromChild(ChildRequests.fromJson(json));

      final OmbiRequest partial =
          of(childRequestJson(approved: true, episodesIn: <bool>[true, false]));
      expect(partial.recentStatus, OmbiRecentStatus.partlyAvailable);
      // Ombi's request list has no partial state of its own.
      expect(partial.status, OmbiRequestStatus.processing);

      expect(
        of(childRequestJson(approved: true, episodesIn: <bool>[false, false]))
            .recentStatus,
        OmbiRecentStatus.approved,
      );
      expect(
        of(
          childRequestJson(
            approved: true,
            available: true,
            episodesIn: <bool>[true, true],
          ),
        ).recentStatus,
        OmbiRecentStatus.available,
      );
    });

    test('a movie with a 4K request says so, others do not', () {
      expect(
        ombiRequestFromMovie(
          MovieRequests.fromJson(movieRequestJson(has4KRequest: true)),
        ).has4K,
        isTrue,
      );
      expect(
        ombiRequestFromMovie(MovieRequests.fromJson(movieRequestJson()))
            .has4K,
        isFalse,
      );
    });

    test('a denial carries its reason', () {
      final OmbiRequest r = ombiRequestFromMovie(
        MovieRequests.fromJson(
          movieRequestJson(denied: true, deniedReason: 'Already on Plex'),
        ),
      );

      expect(r.deniedReason, 'Already on Plex');
    });

    test('a TV row is the child request, titled from its show', () {
      final OmbiRequest r =
          ombiRequestFromChild(ChildRequests.fromJson(childRequestJson()));

      // Approve, deny and delete act on the child, so its id is the one kept.
      expect(r.id, 21);
      expect(r.kind, OmbiMediaKind.tv);
      expect(r.title, 'Severance');
      expect(r.year, 2022);
      expect(
        r.posterUrl,
        'https://image.tmdb.org/t/p/w185/pPHpeI2X1qEd1CS1SeyrdhZ4qnT.jpg',
      );
    });

    test('an album names its artist and keeps a full cover URL', () {
      final OmbiRequest r =
          ombiRequestFromAlbum(AlbumRequest.fromJson(albumRequestJson()));

      expect(r.kind, OmbiMediaKind.music);
      expect(r.title, 'John Coltrane - Blue Train');
      expect(r.status, OmbiRequestStatus.processing);
      expect(
        r.posterUrl,
        'https://coverartarchive.org/release/abc/front-250.jpg',
      );
    });

    test('the requester falls back through alias to user name', () {
      final Map<String, dynamic> json = movieRequestJson()
        ..['requestedUser'] = <String, dynamic>{
          'userName': 'bob',
          'alias': null,
          'userAlias': null,
        };

      expect(
        ombiRequestFromMovie(MovieRequests.fromJson(json)).requestedBy,
        'bob',
      );
    });

    test('a request made on behalf of someone names them', () {
      final Map<String, dynamic> json = movieRequestJson()
        ..['requestedByAlias'] = 'Grandma';

      expect(
        ombiRequestFromMovie(MovieRequests.fromJson(json)).requestedBy,
        'Grandma',
      );
    });
  });

  test('counts add up to a total', () {
    final OmbiCounts c = ombiCountsFrom(RequestCountModel.fromJson(countsJson));

    expect(c.pending, 2);
    expect(c.total, 8);
    expect(ombiCountsFrom(null).total, 0);
  });

  test('search keeps movies and shows and drops people', () {
    final List<OmbiSearchHit> hits = <OmbiSearchHit>[
      for (final Map<String, dynamic> json in searchJson)
        if (ombiSearchHitFrom(MultiSearchResult.fromJson(json))
            case final OmbiSearchHit hit)
          hit,
    ];

    expect(hits.map((OmbiSearchHit h) => h.title), <String>[
      'Arrival',
      'Severance',
    ]);
    expect(hits.first.tmdbId, 329865);
    expect(hits.last.kind, OmbiMediaKind.tv);
  });

  test('a hit with no usable id is dropped', () {
    final MultiSearchResult r = MultiSearchResult.fromJson(<String, dynamic>{
      'id': 'not-a-number',
      'mediaType': 'movie',
      'title': 'Broken',
    });

    expect(ombiSearchHitFrom(r), isNull);
  });

  test('a fully available show reads as available, a partial one as partly',
      () {
    final OmbiTitleState full = ombiTitleStateFromTv(
      SearchFullInfoTvShowViewModel.fromJson(
        tvDetailJson(fullyAvailable: true),
      ),
    );
    final OmbiTitleState part = ombiTitleStateFromTv(
      SearchFullInfoTvShowViewModel.fromJson(
        tvDetailJson(partlyAvailable: true),
      ),
    );

    expect(full.available, isTrue);
    expect(full.canRequest, isFalse);
    expect(part.available, isFalse);
    expect(part.partlyAvailable, isTrue);
    expect(part.canRequest, isTrue);
  });

  test('a requested movie cannot be requested again', () {
    final OmbiTitleState s = ombiTitleStateFromMovie(
      MovieFullInfoViewModel.fromJson(movieDetailJson(requested: true)),
    );

    expect(s.requested, isTrue);
    expect(s.canRequest, isFalse);
  });

  test('a Discover movie is found by its TMDB id and keeps its state', () {
    final OmbiSearchHit hit = ombiSearchHitFromMovie(
      SearchMovieViewModel.fromJson(discoverMovieJson(requested: true)),
    )!;

    expect(hit.tmdbId, 969681);
    expect(hit.kind, OmbiMediaKind.movie);
    expect(hit.title, 'Spider-Man: Brand New Day');
    expect(hit.requested, isTrue);
    expect(hit.available, isFalse);
  });

  test('a Discover show takes its TMDB id from id, theMovieDbId being empty',
      () {
    final OmbiSearchHit hit = ombiSearchHitFromShow(
      SearchTvShowViewModel.fromJson(discoverShowJson()),
    )!;

    expect(hit.tmdbId, 275102);
    expect(hit.kind, OmbiMediaKind.tv);
    expect(
      hit.posterUrl,
      'https://image.tmdb.org/t/p/w185/pJsIzlTjmx07ilwEkl0cglrMVa1.jpg',
    );
  });

  test('poster paths become URLs, full URLs stay as they are', () {
    expect(ombiPosterUrl('/a.jpg'), 'https://image.tmdb.org/t/p/w185/a.jpg');
    expect(
      ombiPosterUrl('a.jpg', size: 'w500'),
      'https://image.tmdb.org/t/p/w500/a.jpg',
    );
    expect(ombiPosterUrl('https://x.test/a.jpg'), 'https://x.test/a.jpg');
    expect(ombiPosterUrl(''), isNull);
    expect(ombiPosterUrl(null), isNull);
  });
}
