import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_cleanuparr/service_cleanuparr.dart';

/// Live HTTP test for [CleanuparrApi] using an active in-memory HTTP daemon server.
///
/// Anchored to the exact real C# DTO shapes from the Cleanuparr backend
/// (StatsV2Response, SystemStatusResponse, DownloadItemStrikesDto, EventListItem, JobInfo).
void main() {
  late HttpServer server;
  late CleanuparrApi api;
  late String serverUrl;

  const String expectedApiKey = 'test-cleanuparr-key-999';

  setUpAll(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    serverUrl = 'http://${server.address.address}:${server.port}/';

    final Dio dio = Dio(
      BaseOptions(
        baseUrl: serverUrl,
        headers: <String, dynamic>{
          'X-Api-Key': expectedApiKey,
        },
      ),
    );
    api = CleanuparrApi(dio);

    server.listen((HttpRequest request) async {
      final String path = request.uri.path;
      final String method = request.method;

      // Verify API Key
      final String? providedKey = request.headers.value('x-api-key');
      if (providedKey != expectedApiKey) {
        request.response.statusCode = HttpStatus.unauthorized;
        request.response.write(jsonEncode(<String, dynamic>{'error': 'Unauthorized'}));
        await request.response.close();
        return;
      }

      request.response.headers.contentType = ContentType.json;

      if (path == '/api/status' && method == 'GET') {
        // Real SystemStatusResponse shape: mediaManagers is a Dictionary<string, ArrStatus>
        request.response.write(
          jsonEncode(<String, dynamic>{
            'application': <String, dynamic>{
              'version': '2.4.0',
              'appName': 'Cleanuparr',
              'branch': 'master',
              'memoryUsageMB': 128.0,
              'startTime': '2026-10-23T10:00:00Z',
            },
            'mediaManagers': <String, dynamic>{
              'Sonarr': <String, dynamic>{'instanceCount': 1},
              'Radarr': <String, dynamic>{'instanceCount': 1},
            },
          }),
        );
      } else if (path == '/api/status/download-client' && method == 'GET') {
        // Real api/status/download-client shape: { "clients": [...] }
        request.response.write(
          jsonEncode(<String, dynamic>{
            'clients': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'e4f8d9b2-3c4a-4d5e-9f0a-1b2c3d4e5f60',
                'name': 'qBittorrent Seeder',
                'type': 'qBittorrent',
                'enabled': true,
                'isConnected': true,
              },
            ],
          }),
        );
      } else if (path == '/api/v2/stats' && method == 'GET') {
        // Real StatsV2Response shape
        request.response.write(
          jsonEncode(<String, dynamic>{
            'strikes': <String, dynamic>{
              'total': 19,
              'recovered': 7,
              'byType': <String, dynamic>{
                'StalledStrike': 12,
                'FailedImportStrike': 7,
              },
            },
            'removals': <String, dynamic>{
              'total': 12,
              'byReason': <String, dynamic>{
                'AllFilesBlocked': 5,
                'AtLeastOneFileBlocked': 3,
                'MaxStrikesReached': 4,
              },
            },
            'cleaned': <String, dynamic>{
              'total': 24,
              'byReason': <String, dynamic>{
                'SeedingCompleted': 24,
              },
            },
            'searches': <String, dynamic>{
              'total': 15,
              'completed': 15,
              'failed': 0,
              'grabbed': 6,
              'byReason': <String, dynamic>{
                'Interactive': 15,
              },
            },
            'health': <String, dynamic>{
              'downloadClients': <dynamic>[],
              'arrInstances': <dynamic>[],
            },
          }),
        );
      } else if (path == '/api/strikes' && method == 'GET') {
        // Real PaginatedResult<DownloadItemStrikesDto> shape
        final String? search = request.uri.queryParameters['search'];
        final List<Map<String, dynamic>> allItems = <Map<String, dynamic>>[
          <String, dynamic>{
            'downloadItemId': 'b3f07a21-9988-4fbb-a123-5e9218d61001',
            'downloadId': '4a5b6c7d8e9f0123456789abcdef0123456789ab',
            'title': 'Gladiator.II.2024.1080p.AMZN.WEB-DL',
            'totalStrikes': 2,
            'strikesByType': <String, dynamic>{'StalledStrike': 2},
            'isMarkedForRemoval': false,
            'isRemoved': false,
            'strikes': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': '11111111-2222-3333-4444-555555555555',
                'type': 'StalledStrike',
                'createdAt': '2026-10-23T10:15:00Z',
                'isDryRun': false,
              },
            ],
          },
          <String, dynamic>{
            'downloadItemId': 'c4d18b32-aa99-4ecc-b234-6f0329e72112',
            'downloadId': '9f8e7d6c5b4a3210fedcba9876543210fedcba98',
            'title': 'Slow.Horses.S04E06.1080p',
            'totalStrikes': 3,
            'strikesByType': <String, dynamic>{'FailedImportStrike': 3},
            'isMarkedForRemoval': true,
            'isRemoved': false,
            'strikes': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': '66666666-7777-8888-9999-000000000000',
                'type': 'FailedImportStrike',
                'createdAt': '2026-10-23T10:16:00Z',
                'isDryRun': false,
              },
            ],
          },
        ];

        final List<Map<String, dynamic>> filtered = search != null && search.isNotEmpty
            ? allItems
                .where(
                  (it) =>
                      (it['title'] as String).toLowerCase().contains(search.toLowerCase()) ||
                      (it['downloadId'] as String).toLowerCase().contains(search.toLowerCase()),
                )
                .toList()
            : allItems;

        request.response.write(
          jsonEncode(<String, dynamic>{
            'items': filtered,
            'page': 1,
            'pageSize': 50,
            'totalCount': filtered.length,
            'totalPages': 1,
          }),
        );
      } else if (path.startsWith('/api/strikes/') && method == 'DELETE') {
        final String strikeId = path.substring('/api/strikes/'.length);
        if (strikeId.isNotEmpty) {
          request.response.statusCode = HttpStatus.noContent;
        } else {
          request.response.statusCode = HttpStatus.badRequest;
        }
      } else if (path == '/api/events' && method == 'GET') {
        // Real PaginatedResult<EventListItem> shape
        request.response.write(
          jsonEncode(<String, dynamic>{
            'items': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': '8a09f1d2-0011-2233-4455-66778899aabb',
                'timestamp': '2026-10-23T11:00:00Z',
                'eventType': 'QueueItemDeleted',
                'severity': 'Error',
                'message': 'Blocked executable disguised payload inside archive',
                'itemTitle': 'Photoshop.2025.Crack.Payload.exe',
                'itemHash': 'fedcba9876543210',
                'deleteReason': 'AllFilesBlocked',
              },
              <String, dynamic>{
                'id': '9b1ae2e3-1122-3344-5566-778899aabbcc',
                'timestamp': '2026-10-23T10:30:00Z',
                'eventType': 'StalledStrike',
                'severity': 'Warning',
                'message': 'Download stalled exceeding 15m idle threshold',
                'itemTitle': 'Gladiator.II.2024.1080p',
                'itemHash': '0123456789abcdef',
              },
            ],
            'page': 1,
            'pageSize': 50,
            'totalCount': 2,
            'totalPages': 1,
          }),
        );
      } else if (path == '/api/jobs' && method == 'GET') {
        // Real List<JobInfo> shape
        request.response.write(
          jsonEncode(<Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'MalwareBlocker',
              'jobType': 'MalwareBlocker',
              'status': 'Idle',
              'schedule': '0 */5 * * * ?',
              'previousRunTime': '2026-10-23T10:55:00Z',
              'nextRunTime': '2026-10-23T11:00:00Z',
            },
            <String, dynamic>{
              'name': 'QueueCleaner',
              'jobType': 'QueueCleaner',
              'status': 'Idle',
              'schedule': '0 */15 * * * ?',
              'previousRunTime': '2026-10-23T10:45:00Z',
              'nextRunTime': '2026-10-23T11:00:00Z',
            },
          ]),
        );
      } else if (path.startsWith('/api/jobs/') && path.endsWith('/trigger') && method == 'POST') {
        request.response.statusCode = HttpStatus.ok;
        request.response.write(
          jsonEncode(<String, dynamic>{
            'message': 'Job triggered successfully for one-time execution',
          }),
        );
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write(jsonEncode(<String, dynamic>{'error': 'Not Found'}));
      }

      await request.response.close();
    });
  });

  tearDownAll(() async {
    await server.close(force: true);
  });

  test('Live HTTP GET /api/status returns valid CleanuparrStatus', () async {
    final CleanuparrStatus status = await api.getStatus();
    expect(status.version, equals('2.4.0'));
    expect(status.appName, equals('Cleanuparr'));
    expect(status.memoryUsageMB, equals(128.0));
    expect(status.mediaManagers.length, equals(2));
    expect(status.mediaManagers.first.name, equals('Sonarr'));
    expect(status.downloadClients.length, equals(1));
    expect(status.downloadClients.first.name, equals('qBittorrent Seeder'));
  });

  test('Live HTTP GET /api/v2/stats with timeframe query params returns CleanuparrStats', () async {
    final CleanuparrStats stats = await api.getStats();
    expect(stats.hours, equals(168));
    expect(stats.strikesIssued, equals(19));
    expect(stats.strikesRecovered, equals(7));
    // StatsV2Response carries no active field; the exact live count comes
    // from the strikes ledger instead (see getActiveStrikesCount test).
    expect(stats.activeStrikes, equals(0));
    expect(stats.malwareBlocked, equals(8)); // 5 + 3
    expect(stats.totalCleaned, equals(24));
    expect(stats.seekerTriggers, equals(15));
    expect(stats.seekerGrabbed, equals(6));
  });

  test('Live HTTP GET /api/strikes counts the ledger items not yet removed', () async {
    // The daemon fixture reports 2 grouped download items, neither removed.
    expect(await api.getActiveStrikesCount(), equals(2));
  });

  test('Live HTTP GET /api/strikes returns parsed strikes ledger and handles search filter', () async {
    final List<CleanuparrStrikeItem> strikes = await api.getStrikes();
    expect(strikes.length, equals(2));
    expect(strikes.first.title, contains('Gladiator'));
    expect(strikes.first.hash, equals('4a5b6c7d8e9f0123456789abcdef0123456789ab'));
    expect(strikes.first.strikeCount, equals(2));
    expect(strikes.first.isMarkedForRemoval, isFalse);
    expect(strikes.first.strikes.first.type, equals('StalledStrike'));

    final List<CleanuparrStrikeItem> filtered = await api.getStrikes(search: 'Slow');
    expect(filtered.length, equals(1));
    expect(filtered.first.title, contains('Slow.Horses'));
    expect(filtered.first.isMarkedForRemoval, isTrue);
  });

  test('Live HTTP DELETE /api/strikes/{id} successfully resets strikes', () async {
    expect(api.deleteStrike('b3f07a21-9988-4fbb-a123-5e9218d61001'), completes);
  });

  test('Live HTTP GET /api/events parses event logs and severities', () async {
    final List<CleanuparrEvent> events = await api.getEvents();
    expect(events.length, equals(2));
    expect(events.first.eventType, equals('QueueItemDeleted'));
    expect(events.first.severity, equals('Error'));
    expect(events.first.downloadItemTitle, contains('Photoshop'));
    expect(events.first.hash, equals('fedcba9876543210'));
    expect(events.first.deleteReason, equals('AllFilesBlocked'));
    expect(events.first.isMalware, isTrue);
  });

  test('Live HTTP GET /api/jobs and POST /api/jobs/{type}/trigger handles on-demand run', () async {
    final List<CleanuparrJob> jobs = await api.getJobs();
    expect(jobs.length, equals(2));
    expect(jobs.first.displayName, equals('Malware Blocker'));
    expect(jobs.first.jobType, equals('MalwareBlocker'));
    expect(jobs.first.lastRunTime, isNotNull);
    expect(jobs.first.nextRunTime, isNotNull);

    expect(api.triggerJob('MalwareBlocker'), completes);
  });
}
