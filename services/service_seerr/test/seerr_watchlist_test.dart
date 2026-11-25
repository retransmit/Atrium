import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_seerr/service_seerr.dart';

/// A Seerr whose `/discover/watchlist` answers with [watchlist] and whose
/// `/movie/{id}` and `/tv/{id}` answer from [details]. A title missing from
/// [details] answers 500.
class _FakeSeerr implements HttpClientAdapter {
  _FakeSeerr(this.watchlist, this.details);

  final List<Map<String, dynamic>> watchlist;
  final Map<String, Map<String, dynamic>> details;
  final List<String> asked = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    asked.add(options.path);
    if (options.path.endsWith('/discover/watchlist')) {
      return _json(<String, dynamic>{
        'page': 1,
        'totalPages': 1,
        'totalResults': watchlist.length,
        'results': watchlist,
      });
    }
    final RegExpMatch? m =
        RegExp(r'/(movie|tv)/(\d+)$').firstMatch(options.path);
    final Map<String, dynamic>? body =
        m == null ? null : details['${m[1]}/${m[2]}'];
    return body == null ? _json(<String, dynamic>{}, 500) : _json(body);
  }

  ResponseBody _json(Map<String, dynamic> body, [int status = 200]) =>
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

SeerrApi _api(_FakeSeerr fake) => SeerrApi(
      Dio(BaseOptions(baseUrl: 'http://seerr.test/'))
        ..httpClientAdapter = fake,
    );

/// A row of Seerr's own watchlist table, as `/discover/watchlist` sends it
/// for a user with no Plex token: `id` is the row's own number.
Map<String, dynamic> _localRow(int row, String type, int tmdbId, String title) =>
    <String, dynamic>{
      'id': row,
      'ratingKey': '',
      'mediaType': type,
      'title': title,
      'tmdbId': tmdbId,
      'createdAt': '2026-11-20T10:00:00.000Z',
      'updatedAt': '2026-11-20T10:00:00.000Z',
    };

void main() {
  test('a local watchlist entry opens its TMDB title, not its row', () async {
    final _FakeSeerr fake = _FakeSeerr(
      <Map<String, dynamic>>[
        _localRow(1, 'tv', 95396, 'Severance'),
        _localRow(2, 'movie', 718930, 'Bullet Train'),
      ],
      <String, Map<String, dynamic>>{
        'tv/95396': <String, dynamic>{
          'id': 95396,
          'name': 'Severance',
          'posterPath': '/sev.jpg',
          'firstAirDate': '2022-02-17',
        },
        'movie/718930': <String, dynamic>{
          'id': 718930,
          'title': 'Bullet Train',
          'posterPath': '/bt.jpg',
          'releaseDate': '2022-08-03',
          'mediaInfo': <String, dynamic>{
            'id': 9,
            'mediaType': 'movie',
            'tmdbId': 718930,
            'status': 5,
          },
        },
      },
    );

    final List<SeerrDiscoverResult> list = await _api(fake).getWatchlist();

    expect(list.map((SeerrDiscoverResult r) => r.id), <int>[95396, 718930]);
    expect(
      list.map((SeerrDiscoverResult r) => r.mediaType),
      <String>['tv', 'movie'],
    );
    expect(fake.asked, isNot(contains(endsWith('/tv/1'))));
    expect(fake.asked, isNot(contains(endsWith('/movie/2'))));
  });

  test('watchlist entries carry their poster and status', () async {
    final _FakeSeerr fake = _FakeSeerr(
      <Map<String, dynamic>>[_localRow(2, 'movie', 718930, 'Bullet Train')],
      <String, Map<String, dynamic>>{
        'movie/718930': <String, dynamic>{
          'id': 718930,
          'title': 'Bullet Train',
          'posterPath': '/bt.jpg',
          'releaseDate': '2022-08-03',
          'mediaInfo': <String, dynamic>{
            'id': 9,
            'mediaType': 'movie',
            'tmdbId': 718930,
            'status': 5,
          },
        },
      },
    );

    final SeerrDiscoverResult item = (await _api(fake).getWatchlist()).single;

    expect(item.posterPath, '/bt.jpg');
    expect(item.year, '2022');
    expect(item.mediaInfo?.status, 5);
    expect(item.isMovie, isTrue);
  });

  test('a Plex watchlist entry keeps its TMDB id and gets a poster', () async {
    final _FakeSeerr fake = _FakeSeerr(
      <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 95396,
          'ratingKey': '5d9c086fe9d5a1001f4d5c6b',
          'title': 'Severance',
          'mediaType': 'tv',
          'tmdbId': 95396,
        },
      ],
      <String, Map<String, dynamic>>{
        'tv/95396': <String, dynamic>{
          'id': 95396,
          'name': 'Severance',
          'posterPath': '/sev.jpg',
        },
      },
    );

    final SeerrDiscoverResult item = (await _api(fake).getWatchlist()).single;

    expect(item.id, 95396);
    expect(item.mediaType, 'tv');
    expect(item.posterPath, '/sev.jpg');
  });

  test('an entry with only an id opens and dresses by that id', () async {
    final _FakeSeerr fake = _FakeSeerr(
      <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 95396,
          'ratingKey': '5d9c086fe9d5a1001f4d5c6b',
          'title': 'Severance',
          'mediaType': 'tv',
        },
      ],
      <String, Map<String, dynamic>>{
        'tv/95396': <String, dynamic>{
          'id': 95396,
          'name': 'Severance',
          'posterPath': '/sev.jpg',
        },
      },
    );

    final SeerrDiscoverResult item = (await _api(fake).getWatchlist()).single;

    expect(item.id, 95396);
    expect(fake.asked, contains(endsWith('/tv/95396')));
    expect(item.posterPath, '/sev.jpg');
  });

  test('a title whose details fail still shows, by its name', () async {
    final _FakeSeerr fake = _FakeSeerr(
      <Map<String, dynamic>>[
        _localRow(1, 'tv', 95396, 'Severance'),
        _localRow(2, 'movie', 718930, 'Bullet Train'),
      ],
      <String, Map<String, dynamic>>{
        'movie/718930': <String, dynamic>{
          'id': 718930,
          'title': 'Bullet Train',
          'posterPath': '/bt.jpg',
        },
      },
    );

    final List<SeerrDiscoverResult> list = await _api(fake).getWatchlist();

    expect(list, hasLength(2));
    expect(list.first.id, 95396);
    expect(list.first.displayTitle, 'Severance');
    expect(list.first.posterPath, isNull);
    expect(list.last.posterPath, '/bt.jpg');
  });

  test('an entry with no TMDB id is dropped', () async {
    final _FakeSeerr fake = _FakeSeerr(
      <Map<String, dynamic>>[
        <String, dynamic>{'ratingKey': 'abc', 'title': 'Home Video'},
      ],
      <String, Map<String, dynamic>>{},
    );

    expect(await _api(fake).getWatchlist(), isEmpty);
  });
}
