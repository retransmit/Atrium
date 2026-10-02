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
      expect(r.requestedAt, DateTime.utc(2026, 9, 18, 10, 15));
      expect(r.status, OmbiRequestStatus.pending);
      expect(
        r.posterUrl,
        'https://image.tmdb.org/t/p/w342/x2FJsf1ElAgr63Y3PNPtJrcmpoe.jpg',
      );
    });

    test('a movie or TV request date with no zone on it is UTC', () {
      // Ombi stores these with DateTime.UtcNow and sends them bare. Read as
      // local time, a request made minutes ago shows as hours old anywhere
      // that is not on UTC.
      final OmbiRequest movie =
          ombiRequestFromMovie(MovieRequests.fromJson(movieRequestJson()));
      final OmbiRequest show =
          ombiRequestFromChild(ChildRequests.fromJson(childRequestJson()));

      expect(movie.requestedAt, DateTime.utc(2026, 9, 18, 10, 15));
      expect(show.requestedAt, DateTime.utc(2026, 9, 17, 8));
    });

    test('a request date that names its zone keeps it', () {
      final OmbiRequest r = ombiRequestFromMovie(
        MovieRequests.fromJson(
          movieRequestJson(requestedDate: '2026-09-18T12:15:00+02:00'),
        ),
      );

      expect(r.requestedAt, DateTime.utc(2026, 9, 18, 10, 15));
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
        'https://image.tmdb.org/t/p/w342/pPHpeI2X1qEd1CS1SeyrdhZ4qnT.jpg',
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
      'https://image.tmdb.org/t/p/w342/pJsIzlTjmx07ilwEkl0cglrMVa1.jpg',
    );
  });

  group('what a card and the title sheet need', () {
    test('a movie request carries its TMDB id, blurb and backdrop', () {
      final OmbiRequest r =
          ombiRequestFromMovie(MovieRequests.fromJson(movieRequestJson()));

      expect(r.tmdbId, 329865);
      expect(r.overview, 'A linguist is recruited to talk to visitors.');
      expect(
        r.backdropUrl,
        'https://image.tmdb.org/t/p/w780/yIZ1xendyqKvY3FGeeUYUd5X9Mm.jpg',
      );
    });

    test('a TV request carries the TMDB id of its show, not the TVDB one', () {
      final OmbiRequest r =
          ombiRequestFromChild(ChildRequests.fromJson(childRequestJson()));

      expect(r.tmdbId, 95396);
      expect(r.overview, 'Mark leads a team of office workers.');
    });

    test('a TV request counts the episodes asked for and the ones in', () {
      final OmbiRequest r = ombiRequestFromChild(
        ChildRequests.fromJson(
          childRequestJson(
            episodesIn: <bool>[true, false, false],
            moreSeasons: <int, List<bool>>{
              2: <bool>[true, true],
            },
          ),
        ),
      );

      expect(r.seasons, <int>[1, 2]);
      expect(r.episodes, 5);
      expect(r.episodesAvailable, 3);
    });

    test('a movie request has no episodes', () {
      final OmbiRequest r =
          ombiRequestFromMovie(MovieRequests.fromJson(movieRequestJson()));

      expect(r.seasons, isEmpty);
      expect(r.episodes, 0);
    });

    test('a movie request opens as the title it is about', () {
      final OmbiSearchHit hit = ombiRequestFromMovie(
        MovieRequests.fromJson(movieRequestJson()),
      ).asSearchHit!;

      expect(hit.tmdbId, 329865);
      expect(hit.kind, OmbiMediaKind.movie);
      expect(hit.title, 'Arrival');
      expect(hit.year, 2016);
      expect(hit.overview, 'A linguist is recruited to talk to visitors.');
    });

    test('an album has no title page to open', () {
      expect(
        ombiRequestFromAlbum(AlbumRequest.fromJson(albumRequestJson()))
            .asSearchHit,
        isNull,
      );
    });

    test('a Discover movie keeps its year, rating and backdrop', () {
      final OmbiSearchHit hit = ombiSearchHitFromMovie(
        SearchMovieViewModel.fromJson(discoverMovieJson()),
      )!;

      expect(hit.year, 2026);
      expect(hit.rating, 7.9);
      expect(
        hit.backdropUrl,
        'https://image.tmdb.org/t/p/w780/qeQJx07rK2xm8SD2sJxFKhE7gs0.jpg',
      );
    });

    test('a Discover show reads its rating from text and may have no year',
        () {
      final OmbiSearchHit undated = ombiSearchHitFromShow(
        SearchTvShowViewModel.fromJson(discoverShowJson()),
      )!;
      final OmbiSearchHit dated = ombiSearchHitFromShow(
        SearchTvShowViewModel.fromJson(
          discoverShowJson(firstAired: '2025-01-01T00:00:00'),
        ),
      )!;

      expect(undated.rating, 5.4);
      expect(undated.year, isNull);
      expect(dated.year, 2025);
    });

    test('a rating of zero is no rating', () {
      expect(
        ombiSearchHitFromShow(
          SearchTvShowViewModel.fromJson(discoverShowJson(rating: '0')),
        )!
            .rating,
        isNull,
      );
    });

    test('a movie page says what the film is', () {
      final OmbiTitleState s = ombiTitleStateFromMovie(
        MovieFullInfoViewModel.fromJson(movieDetailJson()),
      );

      expect(s.tagline, 'Why are they here?');
      expect(s.year, 2016);
      expect(s.runtimeMinutes, 116);
      expect(s.rating, 7.6);
      expect(s.genres, <String>['Drama', 'Science Fiction']);
      expect(s.releaseStatus, 'Released');
      expect(
        s.backdropUrl,
        'https://image.tmdb.org/t/p/w780/yIZ1xendyqKvY3FGeeUYUd5X9Mm.jpg',
      );
    });

    test('a show page reads its numbers from text and names its network', () {
      final OmbiTitleState s = ombiTitleStateFromTv(
        SearchFullInfoTvShowViewModel.fromJson(tvDetailJson()),
      );

      expect(s.year, 2022);
      expect(s.runtimeMinutes, 50);
      expect(s.rating, 8.4);
      expect(s.network, 'Apple TV+');
      expect(s.releaseStatus, 'Returning Series');
      expect(s.genres, <String>['Drama', 'Mystery']);
      // A show's backdrop is its banner.
      expect(
        s.backdropUrl,
        'https://image.tmdb.org/t/p/w780/npD65vPa4vvn1ZHpp3o05A5vdKT.jpg',
      );
    });

    test('a show with no runtime on record has none', () {
      final Map<String, dynamic> json = tvDetailJson()..['runtime'] = '0';

      expect(
        ombiTitleStateFromTv(SearchFullInfoTvShowViewModel.fromJson(json))
            .runtimeMinutes,
        isNull,
      );
    });
  });

  test('poster paths become URLs, full URLs stay as they are', () {
    expect(ombiPosterUrl('/a.jpg'), 'https://image.tmdb.org/t/p/w342/a.jpg');
    expect(
      ombiPosterUrl('a.jpg', size: 'w500'),
      'https://image.tmdb.org/t/p/w500/a.jpg',
    );
    expect(ombiPosterUrl('https://x.test/a.jpg'), 'https://x.test/a.jpg');
    expect(ombiPosterUrl(''), isNull);
    expect(ombiPosterUrl(null), isNull);
  });
}
