import 'package:flutter_test/flutter_test.dart';
import 'package:service_seerr/service_seerr.dart';

// Shape-faithful trims of Overseerr / Jellyseerr issue payloads. Extra keys
// the models do not know about are kept in to prove parsing ignores them.
const Map<String, dynamic> issueJson = <String, dynamic>{
  'id': 12,
  'issueType': 2,
  'status': 1,
  'problemSeason': 3,
  'problemEpisode': 0,
  'createdAt': '2026-06-01T10:00:00.000Z',
  'updatedAt': '2026-06-02T09:30:00.000Z',
  'media': <String, dynamic>{
    'id': 587,
    'mediaType': 'tv',
    'tmdbId': 1399,
    'tvdbId': 121361,
    'status': 5,
  },
  'createdBy': <String, dynamic>{
    'id': 2,
    'displayName': 'Alice',
    'username': 'alice',
    'email': 'alice@example.com',
  },
  'modifiedBy': null,
  'comments': <dynamic>[
    <String, dynamic>{
      'id': 31,
      'message': 'Audio drops out at 12:40.',
      'createdAt': '2026-06-01T10:00:00.000Z',
      'updatedAt': '2026-06-01T10:00:00.000Z',
      'user': <String, dynamic>{
        'id': 2,
        'displayName': 'Alice',
        'username': 'alice',
      },
    },
    <String, dynamic>{
      'id': 32,
      'message': 'Re-grabbed, please check again.',
      'user': null,
    },
  ],
};

const Map<String, dynamic> issuePageJson = <String, dynamic>{
  'pageInfo': <String, dynamic>{
    'pages': 1,
    'pageSize': 10,
    'results': 1,
    'page': 1,
  },
  'results': <dynamic>[issueJson],
};

void main() {
  group('SeerrIssue', () {
    test('parses a full issue with media + comments', () {
      final SeerrIssue issue = SeerrIssue.fromJson(issueJson);

      expect(issue.id, 12);
      expect(issue.issueType, 2);
      expect(issue.status, 1);
      expect(issue.problemSeason, 3);
      expect(issue.createdAt, '2026-06-01T10:00:00.000Z');

      expect(issue.media, isNotNull);
      expect(issue.media!.id, 587);
      expect(issue.media!.tmdbId, 1399);
      expect(issue.media!.mediaType, 'tv');
      expect(issue.media!.status, 5);

      expect(issue.createdBy, isNotNull);
      expect(issue.createdBy!.displayName, 'Alice');

      expect(issue.comments, hasLength(2));
      expect(issue.comments.first.id, 31);
      expect(issue.comments.first.message, 'Audio drops out at 12:40.');
      expect(issue.comments.first.user!.username, 'alice');
      expect(issue.comments.last.user, isNull);
    });

    test('parses tolerantly when optional fields are missing', () {
      final SeerrIssue issue =
          SeerrIssue.fromJson(const <String, dynamic>{'id': 7});

      expect(issue.id, 7);
      expect(issue.issueType, 4);
      expect(issue.status, 1);
      expect(issue.media, isNull);
      expect(issue.createdBy, isNull);
      expect(issue.problemSeason, isNull);
      expect(issue.comments, isEmpty);
      expect(issue.createdAt, isNull);
    });

    test('isOpen reflects status', () {
      // Default status is 1 (open).
      expect(const SeerrIssue(id: 1).isOpen, isTrue);
      expect(const SeerrIssue(id: 1, status: 2).isOpen, isFalse);
    });

    test('typeLabel maps the issue type', () {
      expect(const SeerrIssue(id: 1, issueType: 1).typeLabel, 'Video');
      expect(const SeerrIssue(id: 1, issueType: 2).typeLabel, 'Audio');
      expect(const SeerrIssue(id: 1, issueType: 3).typeLabel, 'Subtitles');
      // 4 (the default) and anything unknown both read as Other.
      expect(const SeerrIssue(id: 1).typeLabel, 'Other');
      expect(const SeerrIssue(id: 1, issueType: 99).typeLabel, 'Other');
    });
  });

  group('SeerrIssuePage', () {
    test('parses the results list', () {
      final SeerrIssuePage page = SeerrIssuePage.fromJson(issuePageJson);
      expect(page.results, hasLength(1));
      expect(page.results.single.id, 12);
      expect(page.results.single.comments, hasLength(2));
    });

    test('defaults to empty results', () {
      final SeerrIssuePage page =
          SeerrIssuePage.fromJson(const <String, dynamic>{});
      expect(page.results, isEmpty);
    });
  });

  group('SeerrMedia', () {
    test('picks up the internal media DB id', () {
      final SeerrMedia media = SeerrMedia.fromJson(const <String, dynamic>{
        'id': 587,
        'mediaType': 'movie',
        'tmdbId': 603,
        'status': 3,
      });
      expect(media.id, 587);
      expect(media.tmdbId, 603);
      expect(media.status, 3);
    });

    test('id stays null when absent', () {
      final SeerrMedia media = SeerrMedia.fromJson(const <String, dynamic>{
        'mediaType': 'movie',
        'tmdbId': 603,
      });
      expect(media.id, isNull);
    });
  });
}
