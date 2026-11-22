import 'package:flutter_test/flutter_test.dart';
import 'package:service_technitium/service_technitium.dart';

void main() {
  group('TechnitiumStatus', () {
    test('parses active protected status', () {
      final DateTime now = DateTime(2026, 11, 22, 12);
      final TechnitiumStatus status = TechnitiumStatus.fromJson(
        <String, dynamic>{
          'status': 'ok',
          'response': <String, dynamic>{
            'version': '13.0.0',
            'dnsServerDomain': 'dns.local',
            'enableBlocking': true,
            'temporaryDisableBlockingTill': null,
            'uptime': 3600,
          },
        },
        readAt: now,
      );

      expect(status.version, '13.0.0');
      expect(status.dnsServerDomain, 'dns.local');
      expect(status.isBlockingEnabled, isTrue);
      expect(status.protection, TechnitiumProtection.on);
      expect(status.pauseLeft, Duration.zero);
    });

    test('parses paused status with countdown', () {
      final DateTime now = DateTime(2026, 11, 22, 12);
      final DateTime future = now.add(const Duration(minutes: 5));
      final TechnitiumStatus status = TechnitiumStatus.fromJson(
        <String, dynamic>{
          'status': 'ok',
          'response': <String, dynamic>{
            'version': '13.0.0',
            'enableBlocking': true,
            'temporaryDisableBlockingTill': future.toIso8601String(),
          },
        },
        readAt: now,
      );

      expect(status.protection, TechnitiumProtection.paused);
      expect(status.pauseLeft, const Duration(minutes: 5));
    });

    test('parses disabled status', () {
      final DateTime now = DateTime(2026, 11, 22, 12);
      final TechnitiumStatus status = TechnitiumStatus.fromJson(
        <String, dynamic>{
          'status': 'ok',
          'response': <String, dynamic>{
            'enableBlocking': false,
          },
        },
        readAt: now,
      );

      expect(status.protection, TechnitiumProtection.off);
    });
  });

  group('TechnitiumStats', () {
    test('parses totals, charts, and top lists', () {
      final TechnitiumStats stats = TechnitiumStats.fromJson(<String, dynamic>{
        'status': 'ok',
        'response': <String, dynamic>{
          'stats': <String, dynamic>{
            'totalQueries': 1000,
            'blockedQueries': 200,
            'cachedQueries': 300,
            'totalClients': 5,
          },
          'mainChartData': <String, dynamic>{
            'totalQueries': <int>[100, 200, 700],
            'blockedQueries': <int>[20, 40, 140],
            'labels': <String>['10:00', '11:00', '12:00'],
          },
          'topClients': <dynamic>[
            <String, dynamic>{'name': '192.168.1.10', 'hits': 500},
          ],
          'topDomains': <dynamic>[
            <String, dynamic>{'name': 'google.com', 'hits': 300},
          ],
          'topBlockedDomains': <dynamic>[
            <String, dynamic>{'name': 'ads.example.com', 'hits': 100},
          ],
        },
      });

      expect(stats.totalQueries, 1000);
      expect(stats.blockedQueries, 200);
      expect(stats.cachedQueries, 300);
      expect(stats.clientsCount, 5);
      expect(stats.blockedPercent, 20.0);
      expect(stats.cachedPercent, 30.0);
      expect(stats.queriesSeries, <int>[100, 200, 700]);
      expect(stats.blockedSeries, <int>[20, 40, 140]);
      expect(stats.topClients.first.name, '192.168.1.10');
      expect(stats.topClients.first.hits, 500);
      expect(stats.topDomains.first.name, 'google.com');
      expect(stats.topBlockedDomains.first.name, 'ads.example.com');
    });
  });

  group('TechnitiumQueryLog', () {
    test('parses log page and entries', () {
      final TechnitiumQueryLogPage page =
          TechnitiumQueryLogPage.fromJson(<String, dynamic>{
        'status': 'ok',
        'response': <String, dynamic>{
          'pageNumber': 1,
          'totalPages': 3,
          'totalEntries': 150,
          'entries': <dynamic>[
            <String, dynamic>{
              'qname': 'tracker.com',
              'qtype': 'A',
              'clientIpAddress': '192.168.1.5',
              'responseType': 'Blocked',
              'rcode': 'NxDomain',
              'protocol': 'UDP',
              'roundTripTime': 1.2,
              'answer': '0.0.0.0',
            },
          ],
        },
      });

      expect(page.pageNumber, 1);
      expect(page.totalPages, 3);
      expect(page.totalEntries, 150);
      expect(page.entries.length, 1);
      expect(page.entries.first.qname, 'tracker.com');
      expect(page.entries.first.isBlocked, isTrue);
    });
  });

  group('TechnitiumSettings & BlockedZones', () {
    test('parses server settings', () {
      final TechnitiumSettings settings =
          TechnitiumSettings.fromJson(<String, dynamic>{
        'status': 'ok',
        'response': <String, dynamic>{
          'enableBlocking': true,
          'blockingType': 'NxDomain',
          'blockListUpdateIntervalHours': 12,
          'blockLists': <dynamic>[
            'https://example.com/blocklist.txt',
          ],
        },
      });

      expect(settings.enableBlocking, isTrue);
      expect(settings.blockingType, 'NxDomain');
      expect(settings.blockListUpdateIntervalHours, 12);
      expect(
        settings.blockLists,
        <String>['https://example.com/blocklist.txt'],
      );
    });

    test('parses blocked zones', () {
      final TechnitiumBlockedZone zone =
          TechnitiumBlockedZone.fromJson(<String, dynamic>{
        'domain': 'ads.example.com',
        'disabled': false,
      });

      expect(zone.domain, 'ads.example.com');
      expect(zone.disabled, isFalse);
    });
  });
}
