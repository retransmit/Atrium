import 'package:atrium/src/share_intake/title_share.dart';
import 'package:atrium/src/share_intake/torrent_share.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('extractTitleShare', () {
    test('Showly movie: ID from IMDb, kind from Trakt', () {
      expect(
        extractTitleShare(
          'WarGames:\nhttps://www.imdb.com/title/tt0086567\n'
          'https://trakt.tv/movies/wargames-1983',
        ),
        const TitleShare(
          kind: TitleKind.movie,
          imdbId: 'tt0086567',
          title: 'wargames',
        ),
      );
    });

    test('Showly show', () {
      expect(
        extractTitleShare(
          'Breaking Bad:\nhttps://www.imdb.com/title/tt0903747\n'
          'https://trakt.tv/shows/breaking-bad',
        ),
        const TitleShare(
          kind: TitleKind.show,
          imdbId: 'tt0903747',
          title: 'breaking bad',
        ),
      );
    });

    test('IMDb app link with tracking and m. host', () {
      expect(
        extractTitleShare(
          'https://m.imdb.com/title/tt0086567/?ref_=ext_shr_lnk',
        ),
        const TitleShare(kind: TitleKind.unknown, imdbId: 'tt0086567'),
      );
    });

    test('TMDB tv link with slug', () {
      expect(
        extractTitleShare('https://www.themoviedb.org/tv/1396-breaking-bad'),
        const TitleShare(kind: TitleKind.show, tmdbId: 1396),
      );
    });

    test('TMDB movie link', () {
      expect(
        extractTitleShare('https://www.themoviedb.org/movie/860'),
        const TitleShare(kind: TitleKind.movie, tmdbId: 860),
      );
    });

    test('Letterboxd short link with a title line', () {
      expect(
        extractTitleShare('WarGames (1983) https://boxd.it/29qU'),
        TitleShare(
          kind: TitleKind.unknown,
          letterboxdUrl: Uri.parse('https://boxd.it/29qU'),
          title: 'WarGames (1983)',
        ),
      );
    });

    test('a Letterboxd film page link', () {
      expect(
        extractTitleShare('https://letterboxd.com/film/wargames/'),
        TitleShare(
          kind: TitleKind.unknown,
          letterboxdUrl: Uri.parse('https://letterboxd.com/film/wargames/'),
        ),
      );
    });

    test('Trakt alone is a titled search', () {
      expect(
        extractTitleShare('https://trakt.tv/shows/severance'),
        const TitleShare(kind: TitleKind.show, title: 'severance'),
      );
    });

    test('plain text is a title search', () {
      expect(
        extractTitleShare('Dune Part Two'),
        const TitleShare(kind: TitleKind.unknown, title: 'Dune Part Two'),
      );
    });

    test('an unknown web link alone is not a title', () {
      expect(extractTitleShare('https://example.com/x'), isNull);
    });

    test('empty text is null', () {
      expect(extractTitleShare('   '), isNull);
    });
  });

  group('decodeTorrentShare text', () {
    test('a torrent beats an IMDb link in the same share', () {
      expect(
        decodeTorrentShare(<Object?, Object?>{
          'kind': 'text',
          'value':
              'magnet:?xt=urn:btih:z https://www.imdb.com/title/tt0086567',
        }),
        const TorrentShareLink('magnet:?xt=urn:btih:z'),
      );
    });

    test('a movie link becomes a title share', () {
      expect(
        decodeTorrentShare(<Object?, Object?>{
          'kind': 'text',
          'value': 'https://www.imdb.com/title/tt0086567/',
        }),
        const TitleShare(kind: TitleKind.unknown, imdbId: 'tt0086567'),
      );
    });

    test('an unknown link alone is a problem', () {
      expect(
        decodeTorrentShare(<Object?, Object?>{
          'kind': 'text',
          'value': 'https://example.com/x',
        }),
        isA<TorrentShareProblem>(),
      );
    });
  });
}
