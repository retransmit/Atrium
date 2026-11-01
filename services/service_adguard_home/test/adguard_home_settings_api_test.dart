import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

import 'support/fake_adguard_home.dart';

void main() {
  late FakeAdguardHome server;
  late AdguardHomeApi api;

  setUp(() {
    server = FakeAdguardHome();
    api = AdguardHomeApi(dioFor(server), AdguardHomeSession());
  });

  Object? sent(String method, String path) => server.single(method, path).data;

  group('general', () {
    test('safe browsing and parental control are read and switched', () async {
      expect(await api.getSafeBrowsing(), isTrue);
      expect(await api.getParental(), isFalse);

      await api.setSafeBrowsing(enabled: false);
      await api.setParental(enabled: true);

      expect(server.to('POST', 'control/safebrowsing/disable'), hasLength(1));
      expect(server.to('POST', 'control/parental/enable'), hasLength(1));
    });

    test('safe search goes out whole', () async {
      final AdguardHomeSafeSearch now = await api.getSafeSearch();

      await api.setSafeSearch(now.copyWith(enabled: false));

      final Object? body = sent('PUT', 'control/safesearch/settings');
      expect(body, isA<Map<String, dynamic>>());
      expect((body! as Map<String, dynamic>)['enabled'], isFalse);
      expect(
        (body as Map<String, dynamic>).keys,
        containsAll(<String>['bing', 'google', 'youtube']),
      );
    });
  });

  group('retention', () {
    test('of the query log and the statistics is read and written', () async {
      final AdguardHomeRetention log = await api.getQueryLogRetention();
      final AdguardHomeRetention stats = await api.getStatsRetention();
      expect(log.anonymizeClientIp, isFalse);
      expect(stats.anonymizeClientIp, isNull);

      await api.setQueryLogRetention(log.copyWith(enabled: false));
      await api.setStatsRetention(stats.copyWith(interval: Duration.zero));

      expect(
        sent('PUT', 'control/querylog/config/update'),
        log.copyWith(enabled: false).toJson(),
      );
      expect(
        (sent('PUT', 'control/stats/config/update')!
            as Map<String, dynamic>)['interval'],
        0,
      );
    });

    test('statistics are reset', () async {
      await api.resetStats();

      expect(server.to('POST', 'control/stats_reset'), hasLength(1));
    });
  });

  group('DNS', () {
    test('settings are read, and only what is to change is written',
        () async {
      final AdguardHomeDnsConfig dns = await api.getDnsConfig();
      expect(dns.ratelimit, 20);

      await api.setDnsConfig(<String, dynamic>{'ratelimit': 25});

      expect(sent('POST', 'control/dns_config'), <String, dynamic>{
        'ratelimit': 25,
      });
    });

    test('upstreams are tested as typed, and each answer read', () async {
      final List<AdguardHomeUpstreamResult> results = await api.testUpstreams(
        upstreams: <String>['https://dns10.quad9.net/dns-query'],
        bootstrap: <String>['9.9.9.10'],
        fallback: const <String>[],
        privateUpstreams: const <String>[],
      );

      expect(sent('POST', 'control/test_upstream_dns'), <String, dynamic>{
        'upstream_dns': <String>['https://dns10.quad9.net/dns-query'],
        'bootstrap_dns': <String>['9.9.9.10'],
        'fallback_dns': <String>[],
        'private_upstream': <String>[],
      });
      expect(results, hasLength(2));
    });

    test('the cache is cleared', () async {
      await api.clearDnsCache();

      expect(server.to('POST', 'control/cache_clear'), hasLength(1));
    });
  });

  group('status pages', () {
    test('encryption and DHCP are read', () async {
      expect((await api.getTlsStatus()).enabled, isFalse);
      expect((await api.getDhcpStatus()).enabled, isFalse);
    });

    test('the update check asks the server, now when told to', () async {
      expect((await api.checkVersion()).disabled, isTrue);
      await api.checkVersion(recheck: true);

      final List<Object?> bodies = <Object?>[
        for (final RequestOptions request
            in server.to('POST', 'control/version.json'))
          request.data,
      ];
      expect(bodies, <Object?>[
        <String, dynamic>{'recheck_now': false},
        <String, dynamic>{'recheck_now': true},
      ]);
    });
  });

  test('a refused setting is said in the server\'s words', () async {
    server.fail(
      'POST',
      'control/dns_config',
      400,
      'validating dns config: upstream_mode: incorrect value "weird"',
    );

    await expectLater(
      api.setDnsConfig(<String, dynamic>{'upstream_mode': 'weird'}),
      throwsA(
        isA<AdguardHomeRequestRefused>().having(
          (AdguardHomeRequestRefused e) => e.message,
          'message',
          contains('incorrect value'),
        ),
      ),
    );
  });

}
