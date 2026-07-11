import 'package:flutter_test/flutter_test.dart';
import 'package:service_seerr/service_seerr.dart';

// Shape-faithful trim of GET /api/v1/movie/{id}: credits.cast is inline and
// carries TMDB extras (castId, order, crew, ...) the models should ignore.
const Map<String, dynamic> movieDetailJson = <String, dynamic>{
  'id': 550,
  'mediaType': 'movie',
  'title': 'Fight Club',
  'overview': 'An insomniac office worker...',
  'releaseDate': '1999-10-15',
  'posterPath': '/poster.jpg',
  'backdropPath': '/backdrop.jpg',
  'runtime': 139,
  'status': 'Released',
  'genres': <dynamic>[
    <String, dynamic>{'id': 18, 'name': 'Drama'},
  ],
  'mediaInfo': <String, dynamic>{
    'id': 42,
    'mediaType': 'movie',
    'tmdbId': 550,
    'status': 5,
  },
  'credits': <String, dynamic>{
    'cast': <dynamic>[
      <String, dynamic>{
        'castId': 4,
        'character': 'The Narrator',
        'creditId': '52fe4250c3a36847f80149f3',
        'gender': 2,
        'id': 819,
        'name': 'Edward Norton',
        'order': 0,
        'profilePath': '/profile.jpg',
      },
      <String, dynamic>{
        'id': 287,
        'name': 'Brad Pitt',
        'character': null,
        'profilePath': null,
      },
    ],
    'crew': <dynamic>[
      <String, dynamic>{'id': 7467, 'name': 'David Fincher', 'job': 'Director'},
    ],
  },
};

void main() {
  group('SeerrDiscoverResult credits', () {
    test('parses inline credits.cast on a media detail', () {
      final SeerrDiscoverResult result =
          SeerrDiscoverResult.fromJson(movieDetailJson);

      expect(result.id, 550);
      expect(result.displayTitle, 'Fight Club');
      expect(result.mediaInfo!.id, 42);

      expect(result.credits, isNotNull);
      final List<SeerrCastMember> cast = result.credits!.cast;
      expect(cast, hasLength(2));
      expect(cast.first.id, 819);
      expect(cast.first.name, 'Edward Norton');
      expect(cast.first.character, 'The Narrator');
      expect(cast.first.profilePath, '/profile.jpg');
      expect(cast.last.character, isNull);
      expect(cast.last.profilePath, isNull);
    });

    test('credits stays null on list-shaped results', () {
      final SeerrDiscoverResult result =
          SeerrDiscoverResult.fromJson(const <String, dynamic>{
        'id': 550,
        'mediaType': 'movie',
        'title': 'Fight Club',
      });
      expect(result.credits, isNull);
    });

    test('cast defaults to empty when credits has no cast key', () {
      final SeerrDiscoverResult result =
          SeerrDiscoverResult.fromJson(const <String, dynamic>{
        'id': 550,
        'mediaType': 'movie',
        'credits': <String, dynamic>{},
      });
      expect(result.credits, isNotNull);
      expect(result.credits!.cast, isEmpty);
    });

    test('cast member name defaults when absent', () {
      final SeerrCastMember member =
          SeerrCastMember.fromJson(const <String, dynamic>{'id': 1});
      expect(member.id, 1);
      expect(member.name, '');
      expect(member.character, isNull);
      expect(member.profilePath, isNull);
    });
  });
}
