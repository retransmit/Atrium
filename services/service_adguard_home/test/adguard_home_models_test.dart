import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

import 'support/adguard_home_fixtures.dart';

void main() {
  final DateTime readAt = DateTime(2026, 10, 7, 18, 30);

  group('AdguardHomeStatus', () {
    test('reads what the server sends', () {
      final AdguardHomeStatus status =
          AdguardHomeStatus.fromJson(statusJson(), readAt: readAt);

      expect(status.version, 'v0.107.79');
      expect(status.running, isTrue);
      expect(status.protectionEnabled, isTrue);
      expect(status.dnsAddresses, <String>['127.0.0.1', '::1', '172.17.0.4']);
      expect(status.dnsPort, 53);
      expect(status.httpPort, 80);
      expect(status.protection, AdguardHomeProtection.on);
      expect(status.pausedUntil, isNull);
    });

    test('a pause is protection off with time left on it', () {
      final AdguardHomeStatus status = AdguardHomeStatus.fromJson(
        statusJson()
          ..['protection_enabled'] = false
          ..['protection_disabled_duration'] = 29748,
        readAt: readAt,
      );

      expect(status.protection, AdguardHomeProtection.paused);
      expect(status.pauseLeft, const Duration(milliseconds: 29748));
      expect(
        status.pausedUntil,
        readAt.add(const Duration(milliseconds: 29748)),
      );
    });

    test('off with no time left is off until turned back on', () {
      final AdguardHomeStatus status = AdguardHomeStatus.fromJson(
        statusJson()..['protection_enabled'] = false,
        readAt: readAt,
      );

      expect(status.protection, AdguardHomeProtection.off);
      expect(status.pausedUntil, isNull);
    });

    test('an answer with nothing in it reads as stopped, not as a crash', () {
      final AdguardHomeStatus status =
          AdguardHomeStatus.fromJson(<String, dynamic>{}, readAt: readAt);

      expect(status.version, '');
      expect(status.running, isFalse);
      expect(status.protection, AdguardHomeProtection.off);
      expect(status.dnsAddresses, isEmpty);
    });
  });

  group('AdguardHomeStats', () {
    test('reads the totals, the series and the top lists', () {
      final AdguardHomeStats stats = AdguardHomeStats.fromJson(statsJson());

      expect(stats.byDay, isFalse);
      expect(stats.queries, 68);
      expect(stats.blockedByFilters, 24);
      expect(stats.blockedThreats, 0);
      expect(stats.blockedAdult, 0);
      expect(stats.safeSearchEnforced, 0);
      // The server reports seconds.
      expect(stats.averageProcessingTime, const Duration(microseconds: 67046));
      expect(stats.queriesSeries, hasLength(24));
      expect(stats.queriesSeries.last, 68);
      expect(stats.blockedSeries.last, 24);

      // Each row of a top list arrives as an object with one entry.
      // Five domains tie at 8; a tie is settled by name.
      expect(stats.topQueriedDomains.first.name, 'ads.google.com');
      expect(stats.topQueriedDomains.first.value, 8);
      expect(stats.topQueriedDomains, hasLength(7));
      expect(stats.topClients.single.name, '127.0.0.1');
      expect(stats.topClients.single.value, 68);
      expect(
        stats.topBlockedDomains.map((AdguardHomeCount c) => c.name),
        <String>[
          'adservice.google.com',
          'doubleclick.net',
          'google-analytics.com',
        ],
      );
      expect(stats.topUpstreams.single.value, 24);
      expect(
        stats.topUpstreamTimes.single.value,
        closeTo(0.18939, 0.00001),
      );
    });

    test('works the blocked share out', () {
      expect(
        AdguardHomeStats.fromJson(statsJson()).blockedPercent,
        closeTo(35.294, 0.001),
      );
    });

    test('a server nobody has asked anything yet blocks nothing of nothing',
        () {
      final AdguardHomeStats stats = AdguardHomeStats.fromJson(<String, dynamic>{
        'time_units': 'days',
        'num_dns_queries': 0,
        'num_blocked_filtering': 0,
        'top_queried_domains': <dynamic>[],
        'top_clients': null,
        'dns_queries': <dynamic>[0, 0, 0],
      });

      expect(stats.byDay, isTrue);
      expect(stats.blockedPercent, 0);
      expect(stats.topQueriedDomains, isEmpty);
      expect(stats.topClients, isEmpty);
      expect(stats.topBlockedDomains, isEmpty);
      expect(stats.queriesSeries, <int>[0, 0, 0]);
      expect(stats.blockedSeries, isEmpty);
      expect(stats.averageProcessingTime, Duration.zero);
    });

    test('rows the server ties come out in one order, however it sent them',
        () {
      // AdGuard Home returns rows of equal count in a different order on
      // every read. Shown as they come, they would swap places at each poll,
      // and a tap could land on the wrong domain.
      List<String> names(List<Map<String, dynamic>> rows) =>
          AdguardHomeStats.fromJson(<String, dynamic>{
            'top_queried_domains': rows,
          }).topQueriedDomains.map((AdguardHomeCount c) => c.name).toList();

      final List<String> once = names(<Map<String, dynamic>>[
        <String, dynamic>{'big.example': 12},
        <String, dynamic>{'github.com': 10},
        <String, dynamic>{'flutter.dev': 10},
        <String, dynamic>{'example.com': 10},
        <String, dynamic>{'f-droid.org': 2},
      ]);
      final List<String> again = names(<Map<String, dynamic>>[
        <String, dynamic>{'big.example': 12},
        <String, dynamic>{'example.com': 10},
        <String, dynamic>{'github.com': 10},
        <String, dynamic>{'flutter.dev': 10},
        <String, dynamic>{'f-droid.org': 2},
      ]);

      expect(once, again);
      // Largest first still, and a tie by name.
      expect(once, <String>[
        'big.example',
        'example.com',
        'flutter.dev',
        'github.com',
        'f-droid.org',
      ]);
    });

    test('skips a top list row it cannot read', () {
      final AdguardHomeStats stats = AdguardHomeStats.fromJson(<String, dynamic>{
        'top_queried_domains': <dynamic>[
          <String, dynamic>{'good.example': 3},
          'not an object',
          <String, dynamic>{'bad.example': 'three'},
          <String, dynamic>{},
          null,
        ],
      });

      expect(stats.topQueriedDomains.single.name, 'good.example');
    });
  });

  group('AdguardHomeFiltering', () {
    test('reads the lists and tells them apart', () {
      final AdguardHomeFiltering filtering =
          AdguardHomeFiltering.fromJson(filteringJson());

      expect(filtering.enabled, isTrue);
      expect(filtering.intervalHours, 24);
      expect(filtering.blocklists, hasLength(2));
      expect(filtering.blocklists.first.name, 'AdGuard DNS filter');
      expect(filtering.blocklists.first.rulesCount, 179185);
      expect(
        filtering.blocklists.first.lastUpdated,
        DateTime.utc(2026, 10, 7, 14, 27, 2),
      );
      // A list that has never been fetched carries no date.
      expect(filtering.blocklists.last.lastUpdated, isNull);
      expect(filtering.blocklists.last.enabled, isFalse);
      // No allowlists is sent as null, not as an empty list.
      expect(filtering.allowlists, isEmpty);
      expect(filtering.userRules, isEmpty);
    });

    test('counts the rules of the lists that are switched on', () {
      final Map<String, dynamic> json = filteringJson();
      (json['filters'] as List<dynamic>).add(<String, dynamic>{
        'url': 'https://lists.example/third.txt',
        'name': 'Third',
        'id': 3,
        'rules_count': 815,
        'enabled': true,
      });
      // The second list is off; give it rules to prove they are left out.
      final Map<String, dynamic> second =
          (json['filters'] as List<dynamic>)[1] as Map<String, dynamic>;
      second['rules_count'] = 5000;

      expect(
        AdguardHomeFiltering.fromJson(json).rulesOnBlocklists,
        179185 + 815,
      );
    });

    test('a server with no lists at all sends null for them', () {
      final AdguardHomeFiltering filtering =
          AdguardHomeFiltering.fromJson(<String, dynamic>{
        'filters': null,
        'whitelist_filters': null,
        'user_rules': null,
        'interval': 0,
        'enabled': false,
      });

      expect(filtering.blocklists, isEmpty);
      expect(filtering.allowlists, isEmpty);
      expect(filtering.userRules, isEmpty);
      expect(filtering.rulesOnBlocklists, 0);
    });

    group('the name of the list a rule is on', () {
      const AdguardHomeFiltering filtering = AdguardHomeFiltering(
        blocklists: <AdguardHomeFilterList>[
          AdguardHomeFilterList(
            id: 1,
            name: 'AdGuard DNS filter',
            url: 'https://lists.example/1.txt',
            enabled: true,
            rulesCount: 10,
          ),
        ],
        allowlists: <AdguardHomeFilterList>[
          AdguardHomeFilterList(
            id: 1759000000,
            name: 'Work exceptions',
            url: 'https://lists.example/allow.txt',
            enabled: true,
            rulesCount: 3,
          ),
        ],
      );

      test('is the list\'s own, on either side', () {
        expect(adguardHomeFilterListName(filtering, 1), 'AdGuard DNS filter');
        expect(
          adguardHomeFilterListName(filtering, 1759000000),
          'Work exceptions',
        );
      });

      test('is the web UI\'s for the sources the server has built in', () {
        expect(adguardHomeFilterListName(filtering, 0), 'Custom filtering rules');
        expect(adguardHomeFilterListName(filtering, -1), 'System hosts files');
        expect(adguardHomeFilterListName(filtering, -2), 'Blocked services');
        expect(adguardHomeFilterListName(filtering, -3), 'Parental control');
        expect(adguardHomeFilterListName(filtering, -4), 'Safe browsing');
        expect(adguardHomeFilterListName(filtering, -5), 'Safe search');
        // These need no lists to have been read.
        expect(adguardHomeFilterListName(null, 0), 'Custom filtering rules');
      });

      test('says so when the list is gone or was never read', () {
        expect(adguardHomeFilterListName(filtering, 99), 'Unknown filter 99');
        expect(adguardHomeFilterListName(null, 1), 'Unknown filter 1');
      });
    });
  });
}
