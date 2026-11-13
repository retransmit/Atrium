import 'package:atrium/src/share_intake/atrium_link.dart';
import 'package:atrium/src/share_intake/torrent_share.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('service links', () {
    test('a service name opens that service', () {
      expect(
        parseAtriumLink('atrium://sonarr'),
        const AtriumLink(service: ServiceKind.sonarr),
      );
    });

    test('case and a trailing slash do not matter', () {
      expect(
        parseAtriumLink('atrium://Sonarr/'),
        const AtriumLink(service: ServiceKind.sonarr),
      );
      expect(
        parseAtriumLink('atrium://adguardhome'),
        const AtriumLink(service: ServiceKind.adguardHome),
      );
    });

    test('an unknown service says so', () {
      expect(
        parseAtriumLink('atrium://nope'),
        const TorrentShareProblem(
          'Atrium does not know a service called "nope", so that link went '
          'nowhere.',
        ),
      );
    });
  });

  group('item links', () {
    test('a movie by TMDB ID', () {
      expect(
        parseAtriumLink('atrium://radarr/movie?tmdb=550'),
        const AtriumLink(
          service: ServiceKind.radarr,
          item: LinkItem.movie,
          tmdbId: 550,
        ),
      );
    });

    test('a library ID wins, and an encoded instance name is read', () {
      expect(
        parseAtriumLink(
          'atrium://radarr/movie?id=12&tmdb=550&instance=Home%20Radarr',
        ),
        const AtriumLink(
          service: ServiceKind.radarr,
          item: LinkItem.movie,
          libraryId: 12,
          instanceName: 'Home Radarr',
        ),
      );
    });

    test('a series keeps its TVDB ID over IMDb', () {
      expect(
        parseAtriumLink('atrium://sonarr/series?tvdb=81189&imdb=tt0903747'),
        const AtriumLink(
          service: ServiceKind.sonarr,
          item: LinkItem.series,
          tvdbId: 81189,
        ),
      );
    });

    test('a series by IMDb ID', () {
      expect(
        parseAtriumLink('atrium://sonarr/series?imdb=tt0903747'),
        const AtriumLink(
          service: ServiceKind.sonarr,
          item: LinkItem.series,
          imdbId: 'tt0903747',
        ),
      );
    });

    for (final String bad in <String>[
      'atrium://sonarr/movie?tmdb=1',
      'atrium://radarr/movie',
      'atrium://radarr/movie?tmdb=abc',
      'atrium://radarr/movie?tvdb=5',
      'atrium://radarr/movie?imdb=tt12',
      'atrium://lidarr/artist?id=1',
      'https://sonarr.example.com',
      'atrium://sonarr?instance=%FF',
      'atrium://radarr/movie?tmdb=550&instance=%E0%A4',
    ]) {
      test('$bad cannot be read', () {
        expect(
          parseAtriumLink(bad),
          const TorrentShareProblem(
            'That Atrium link could not be read, so it went nowhere.',
          ),
        );
      });
    }
  });
}
