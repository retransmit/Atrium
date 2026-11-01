import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_cleanuparr/service_cleanuparr.dart';

void main() {
  group('CleanuparrStatus.fromJson', () {
    test('parses real backend dictionary mediaManagers and download-client list', () {
      final status = CleanuparrStatus.fromJson(<String, dynamic>{
        'application': <String, dynamic>{
          'version': '2.4.0',
          'appName': 'Cleanuparr',
          'branch': 'master',
          'memoryUsageMB': 142.5,
          'startTime': '2026-10-23T10:00:00Z',
        },
        'mediaManagers': <String, dynamic>{
          'Sonarr': <String, dynamic>{'instanceCount': 1},
          'Radarr': <String, dynamic>{'instanceCount': 2},
        },
        'downloadClients': <dynamic>[
          <String, dynamic>{
            'name': 'qBittorrent',
            'type': 'qBittorrent',
            'enabled': true,
            'isConnected': true,
          },
        ],
      });

      expect(status.version, '2.4.0');
      expect(status.appName, 'Cleanuparr');
      expect(status.branch, 'master');
      expect(status.memoryUsageMB, 142.5);
      expect(status.mediaManagers.length, 2);
      expect(status.mediaManagers.first.name, 'Sonarr');
      expect(status.downloadClients.length, 1);
      expect(status.downloadClients.first.name, 'qBittorrent');
    });

    test('handles empty or fallback payloads safely', () {
      final status = CleanuparrStatus.fromJson(<String, dynamic>{});
      expect(status.version, 'Unknown');
      expect(status.appName, 'Cleanuparr');
      expect(status.mediaManagers, isEmpty);
      expect(status.downloadClients, isEmpty);
    });
  });

  group('CleanuparrStats.fromJson', () {
    test('parses real StatsV2Response payload correctly', () {
      final stats = CleanuparrStats.fromJson(<String, dynamic>{
        'events': <String, dynamic>{
          'total': 42,
          'warning': 8,
          'error': 4,
        },
        'strikes': <String, dynamic>{
          'total': 15,
          'recovered': 6,
          'byType': <String, dynamic>{
            'StalledStrike': 8,
            'FailedImportStrike': 7,
          },
        },
        'removals': <String, dynamic>{
          'total': 7,
          'byReason': <String, dynamic>{
            'AllFilesBlocked': 2,
            'AtLeastOneFileBlocked': 1,
            'MaxStrikesReached': 4,
          },
        },
        'cleaned': <String, dynamic>{
          'total': 12,
        },
        'searches': <String, dynamic>{
          'total': 9,
          'grabbed': 4,
        },
      },
      hours: 72,
    );

      expect(stats.hours, 72);
      expect(stats.totalEvents, 42);
      expect(stats.eventsWarning, 8);
      expect(stats.eventsError, 4);
      expect(stats.strikesIssued, 15);
      expect(stats.strikesRecovered, 6);
      // No derivation from (issued - recovered): the real StatsV2Response has
      // no active field, so it stays 0 here. Exact counts come from
      // CleanuparrApi.getActiveStrikesCount instead.
      expect(stats.activeStrikes, 0);
      expect(stats.malwareBlocked, 3); // 2 + 1
      expect(stats.totalCleaned, 12);
      expect(stats.seekerTriggers, 9);
      expect(stats.seekerGrabbed, 4);
      expect(stats.strikesByType['StalledStrike'], 8);
    });
  });

  group('CleanuparrStrikeItem.fromJson', () {
    test('parses real DownloadItemStrikesDto payload', () {
      final item = CleanuparrStrikeItem.fromJson(<String, dynamic>{
        'downloadItemId': '4b5a31a9-38b8-4c12-8700-60b731057f92',
        'downloadId': 'fedcba98765432100123456789abcdef01234567',
        'title': 'Test.Movie.2026.1080p',
        'totalStrikes': 2,
        'isMarkedForRemoval': true,
        'strikes': <dynamic>[
          <String, dynamic>{
            'id': 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d',
            'type': 'StalledStrike',
            'createdAt': '2026-10-23T10:15:00Z',
            'isDryRun': false,
          },
        ],
      });

      expect(item.id, '4b5a31a9-38b8-4c12-8700-60b731057f92');
      expect(item.hash, 'fedcba98765432100123456789abcdef01234567');
      expect(item.title, 'Test.Movie.2026.1080p');
      expect(item.strikeCount, 2);
      expect(item.isMarkedForRemoval, isTrue);
      expect(item.strikes.length, 1);
      expect(item.strikes.first.type, 'StalledStrike');
    });
  });

  group('CleanuparrEvent.fromJson', () {
    test('parses real EventListItem payload with itemTitle and itemHash', () {
      final event = CleanuparrEvent.fromJson(<String, dynamic>{
        'id': 'ev-1',
        'timestamp': '2026-10-23T10:14:00Z',
        'eventType': 'QueueItemDeleted',
        'severity': 'Warning',
        'message': 'Deleted queue item due to malware rule match',
        'itemTitle': 'Bad.File.exe',
        'itemHash': 'abcdef0123456789',
        'deleteReason': 'AllFilesBlocked',
      });

      expect(event.id, 'ev-1');
      expect(event.eventType, 'QueueItemDeleted');
      expect(event.severity, 'Warning');
      expect(event.downloadItemTitle, 'Bad.File.exe');
      expect(event.hash, 'abcdef0123456789');
      expect(event.deleteReason, 'AllFilesBlocked');
      expect(event.isMalware, isTrue);
      expect(event.isStrike, isFalse);
      expect(event.isDeletion, isTrue);
      expect(event.isCleaned, isFalse);
      expect(event.isRemoval, isTrue);
    });

    test('classifies cleaning events without mixing into deletions', () {
      final cleaned = CleanuparrEvent.fromJson(<String, dynamic>{
        'id': 'ev-2',
        'timestamp': '2026-10-23T10:30:00Z',
        'eventType': 'DownloadCleaned',
        'severity': 'Information',
        'message': 'Seeding completed',
        'cleanReason': 'SeedingCompleted',
      });
      expect(cleaned.isCleaned, isTrue);
      expect(cleaned.isDeletion, isFalse);
      expect(cleaned.isRemoval, isTrue);
      expect(cleaned.isStrike, isFalse);
      expect(cleaned.isMalware, isFalse);
    });

    test('strike event types are matched exactly, not by substring', () {
      final strike = CleanuparrEvent.fromJson(<String, dynamic>{
        'id': 'ev-3',
        'timestamp': '2026-10-23T10:40:00Z',
        'eventType': 'StalledStrike',
        'severity': 'Warning',
        'message': 'Stalled download',
      });
      expect(strike.isStrike, isTrue);
      expect(strike.isDeletion, isFalse);
      expect(strike.isCleaned, isFalse);
    });
  });

  group('CleanuparrJob.fromJson', () {
    test('parses real JobInfo and handles previousRunTime', () {
      final job = CleanuparrJob.fromJson(<String, dynamic>{
        'jobType': 'MalwareBlocker',
        'name': 'MalwareBlocker',
        'status': 'Idle',
        'schedule': '0 */5 * * * ?',
        'previousRunTime': '2026-10-23T10:00:00Z',
        'nextRunTime': '2026-10-23T10:05:00Z',
      });

      expect(job.jobType, 'MalwareBlocker');
      expect(job.displayName, 'Malware Blocker');
      expect(job.status, 'Idle');
      expect(job.isRunning, isFalse);
      expect(job.lastRunTime, isNotNull);
      expect(job.nextRunTime, isNotNull);
    });
  });

  group('CleanuparrApi Client', () {
    test('getStatus calls api/status and api/status/download-client in parallel', () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter(
        handler: (options) {
          if (options.path == 'api/status') {
            return ResponseBody.fromString(
              '{"application": {"version": "2.4.0", "appName": "Cleanuparr"}, "mediaManagers": {"Sonarr": {"instanceCount": 1}}}',
              200,
              headers: <String, List<String>>{
                Headers.contentTypeHeader: <String>[Headers.jsonContentType],
              },
            );
          }
          if (options.path == 'api/status/download-client') {
            return ResponseBody.fromString(
              '{"clients": [{"name": "qBittorrent", "type": "qBittorrent", "enabled": true}]}',
              200,
              headers: <String, List<String>>{
                Headers.contentTypeHeader: <String>[Headers.jsonContentType],
              },
            );
          }
          return ResponseBody.fromString('', 404);
        },
      );

      final api = CleanuparrApi(dio);
      final status = await api.getStatus();
      expect(status.version, '2.4.0');
      expect(status.mediaManagers.length, 1);
      expect(status.downloadClients.length, 1);
    });

    test('getStats calls api/v2/stats with hours query param', () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter(
        handler: (options) {
          expect(options.path, 'api/v2/stats');
          expect(options.queryParameters['hours'], 72);
          return ResponseBody.fromString(
            '{"events": {"total": 10}, "strikes": {"total": 5, "recovered": 2}}',
            200,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>[Headers.jsonContentType],
            },
          );
        },
      );

      final api = CleanuparrApi(dio);
      final stats = await api.getStats(hours: 72);
      expect(stats.totalEvents, 10);
      expect(stats.activeStrikes, 0);
    });

    test('getActiveStrikesCount leaves out items Cleanuparr already removed', () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter(
        handler: (RequestOptions options) {
          expect(options.path, 'api/strikes');
          expect(options.queryParameters['page'], 1);
          expect(options.queryParameters['pageSize'], 500);
          return ResponseBody.fromString(
            '{"items": ['
            '{"downloadItemId": "a", "title": "Stalled", "totalStrikes": 2, "isRemoved": false},'
            '{"downloadItemId": "b", "title": "Pending", "totalStrikes": 3, "isMarkedForRemoval": true, "isRemoved": false},'
            '{"downloadItemId": "c", "title": "Gone", "totalStrikes": 3, "isRemoved": true}'
            '], "page": 1, "pageSize": 500, "totalCount": 3, "totalPages": 1}',
            200,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>[Headers.jsonContentType],
            },
          );
        },
      );

      final api = CleanuparrApi(dio);
      expect(await api.getActiveStrikesCount(), 2);
    });

    test('getActiveStrikesCount counts items past the first page as active', () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter(
        handler: (RequestOptions options) => ResponseBody.fromString(
          '{"items": [{"downloadItemId": "a", "title": "Gone", "isRemoved": true}],'
          ' "page": 1, "pageSize": 500, "totalCount": 4, "totalPages": 1}',
          200,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        ),
      );

      final api = CleanuparrApi(dio);
      expect(await api.getActiveStrikesCount(), 3);
    });

    test('getEventsPage carries pagination metadata from the envelope', () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter(
        handler: (RequestOptions options) {
          expect(options.path, 'api/events');
          expect(options.queryParameters['page'], 2);
          return ResponseBody.fromString(
            '{"items": [{"id": "e1", "timestamp": "2026-10-23T10:00:00Z", '
            '"eventType": "QueueItemDeleted", "severity": "Error", '
            '"message": "Deleted", "itemTitle": "Item", "itemHash": "abc"}], '
            '"page": 2, "pageSize": 50, "totalCount": 120, "totalPages": 3}',
            200,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>[Headers.jsonContentType],
            },
          );
        },
      );

      final api = CleanuparrApi(dio);
      final page = await api.getEventsPage(page: 2);
      expect(page.items.length, 1);
      expect(page.items.first.isDeletion, isTrue);
      expect(page.totalCount, 120);
      expect(page.totalPages, 3);
      expect(page.hasNext, isTrue);
    });

    test('deleteStrike calls DELETE api/strikes/{id}', () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter(
        handler: (options) {
          expect(options.method, 'DELETE');
          expect(options.path, 'api/strikes/item-123');
          return ResponseBody.fromString('', 204);
        },
      );

      final api = CleanuparrApi(dio);
      await expectLater(api.deleteStrike('item-123'), completes);
    });

    test('triggerJob calls POST api/jobs/{jobType}/trigger', () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter(
        handler: (options) {
          expect(options.method, 'POST');
          expect(options.path, 'api/jobs/QueueCleaner/trigger');
          return ResponseBody.fromString('', 200);
        },
      );

      final api = CleanuparrApi(dio);
      await expectLater(api.triggerJob('QueueCleaner'), completes);
    });

    test('a failed request surfaces as a NetworkException, not a DioException', () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter(
        handler: (options) => ResponseBody.fromString(
          '{"error": "Service Unavailable"}',
          503,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        ),
      );

      final api = CleanuparrApi(dio);
      await expectLater(
        api.getStats(),
        throwsA(
          isA<NetworkServerException>().having(
            (NetworkServerException e) => e.message,
            'message',
            'Server error (HTTP 503): Service Unavailable',
          ),
        ),
      );
      await expectLater(api.triggerJob('QueueCleaner'), throwsA(isA<NetworkServerException>()));
    });
  });
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({required this.handler});

  final ResponseBody Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}
