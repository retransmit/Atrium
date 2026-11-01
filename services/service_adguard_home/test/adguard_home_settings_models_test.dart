import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

import 'support/adguard_home_fixtures.dart';
import 'support/adguard_home_query_log_fixtures.dart';
import 'support/adguard_home_settings_fixtures.dart';

void main() {
  group('retention', () {
    test('of the query log reads as the server sends it', () {
      final AdguardHomeRetention log =
          AdguardHomeRetention.fromJson(queryLogConfigJson());

      expect(log.enabled, isTrue);
      expect(log.interval, const Duration(days: 90));
      expect(log.ignored, isEmpty);
      expect(log.ignoredEnabled, isFalse);
      expect(log.anonymizeClientIp, isFalse);
    });

    test('of the statistics has no anonymising', () {
      final AdguardHomeRetention stats =
          AdguardHomeRetention.fromJson(statsConfigJson());

      expect(stats.interval, const Duration(hours: 24));
      expect(stats.anonymizeClientIp, isNull);
      expect(stats.toJson().containsKey('anonymize_client_ip'), isFalse);
    });

    test('goes out whole, in milliseconds', () {
      final AdguardHomeRetention log = AdguardHomeRetention.fromJson(
        queryLogConfigJson(),
      ).copyWith(
        interval: const Duration(hours: 6),
        ignored: <String>['example.org'],
        ignoredEnabled: true,
        anonymizeClientIp: true,
      );

      expect(log.toJson(), <String, dynamic>{
        'enabled': true,
        'interval': 6 * 3600 * 1000,
        'ignored': <String>['example.org'],
        'ignored_enabled': true,
        'anonymize_client_ip': true,
      });
    });

    test('is between an hour and a year, in whole hours', () {
      expect(adguardHomeRetentionProblem(1), isNull);
      expect(adguardHomeRetentionProblem(8760), isNull);
      expect(adguardHomeRetentionProblem(0), isNotNull);
      expect(adguardHomeRetentionProblem(8761), isNotNull);
      expect(adguardHomeRetentionProblem(null), isNotNull);
    });
  });

  group('DNS settings', () {
    final AdguardHomeDnsConfig dns = AdguardHomeDnsConfig(dnsInfoJson());

    test('read as the server sends them', () {
      expect(dns.upstreams, <String>['https://dns10.quad9.net/dns-query']);
      expect(dns.upstreamsFile, isEmpty);
      expect(dns.bootstrap, hasLength(4));
      expect(dns.fallback, isEmpty);
      expect(dns.upstreamMode, AdguardHomeUpstreamMode.loadBalance);
      expect(dns.upstreamTimeout, 10);
      expect(dns.privateUpstreams, isEmpty);
      expect(dns.defaultPrivateUpstreams, <String>['192.168.65.7:53']);
      expect(dns.usePrivatePtrResolvers, isTrue);
      expect(dns.resolveClients, isTrue);
      expect(dns.ratelimit, 20);
      expect(dns.ratelimitSubnetIpv4, 24);
      expect(dns.ratelimitSubnetIpv6, 56);
      expect(dns.ratelimitWhitelist, isEmpty);
      expect(dns.ednsEnabled, isFalse);
      expect(dns.dnssecEnabled, isTrue);
      expect(dns.disableIpv6, isFalse);
      expect(dns.blockingMode, AdguardHomeBlockingMode.normal);
      expect(dns.blockedResponseTtl, 10);
      expect(dns.cacheEnabled, isTrue);
      expect(dns.cacheSize, 4194304);
      expect(dns.cacheTtlMin, 0);
      expect(dns.cacheTtlMax, 0);
      expect(dns.cacheOptimistic, isFalse);
    });

    test('name the upstream modes and blocking modes as the server does', () {
      expect(
        AdguardHomeUpstreamMode.fromWire(''),
        AdguardHomeUpstreamMode.loadBalance,
      );
      expect(
        AdguardHomeUpstreamMode.fromWire('load_balance'),
        AdguardHomeUpstreamMode.loadBalance,
      );
      expect(
        AdguardHomeUpstreamMode.fromWire('parallel'),
        AdguardHomeUpstreamMode.parallel,
      );
      expect(
        AdguardHomeUpstreamMode.fromWire('fastest_addr'),
        AdguardHomeUpstreamMode.fastestAddress,
      );
      expect(AdguardHomeUpstreamMode.parallel.wire, 'parallel');
      expect(AdguardHomeUpstreamMode.loadBalance.wire, 'load_balance');
      for (final AdguardHomeBlockingMode mode
          in AdguardHomeBlockingMode.values) {
        expect(AdguardHomeBlockingMode.fromWire(mode.wire), mode);
      }
      expect(
        AdguardHomeBlockingMode.fromWire('custom_ip'),
        AdguardHomeBlockingMode.customIp,
      );
    });

    test('a change sends only the settings that changed', () {
      expect(
        adguardHomeChangedSettings(
          <String, dynamic>{'ratelimit': 20, 'upstream_dns': <String>['a']},
          <String, dynamic>{'ratelimit': 25, 'upstream_dns': <String>['a']},
        ),
        <String, dynamic>{'ratelimit': 25},
      );
      expect(
        adguardHomeChangedSettings(
          <String, dynamic>{'upstream_dns': <String>['a', 'b']},
          <String, dynamic>{'upstream_dns': <String>['b', 'a']},
        ),
        <String, dynamic>{
          'upstream_dns': <String>['b', 'a'],
        },
      );
    });
  });

  group('a DNS write', () {
    final Map<String, dynamic> before = <String, dynamic>{
      'blocking_mode': 'default',
      'blocking_ipv4': '',
      'blocking_ipv6': '',
      'edns_cs_enabled': false,
      'edns_cs_use_custom': false,
      'edns_cs_custom_ip': '',
      'ratelimit': 20,
    };

    test('sends the blocking mode and its addresses together', () {
      expect(
        adguardHomeDnsChanges(before, <String, dynamic>{
          ...before,
          'blocking_ipv4': '10.0.0.1',
        }),
        <String, dynamic>{
          'blocking_mode': 'default',
          'blocking_ipv4': '10.0.0.1',
          'blocking_ipv6': '',
        },
      );
    });

    test('sends the EDNS settings together', () {
      expect(
        adguardHomeDnsChanges(before, <String, dynamic>{
          ...before,
          'edns_cs_custom_ip': '203.0.113.0',
        }).keys,
        unorderedEquals(<String>[
          'edns_cs_enabled',
          'edns_cs_use_custom',
          'edns_cs_custom_ip',
        ]),
      );
    });

    test('sends a setting of no group alone', () {
      expect(
        adguardHomeDnsChanges(before, <String, dynamic>{
          ...before,
          'ratelimit': 25,
        }),
        <String, dynamic>{'ratelimit': 25},
      );
    });
  });

  test('retention from a server without the ignored switch keeps the list '
      'in force, and sends no switch', () {
    final AdguardHomeRetention old = AdguardHomeRetention.fromJson(
      <String, dynamic>{
        'enabled': true,
        'interval': 86400000,
        'ignored': <String>['a.example'],
      },
    );

    expect(old.ignoredEnabled, isTrue);
    expect(old.hasIgnoredSwitch, isFalse);
    expect(old.toJson().containsKey('ignored_enabled'), isFalse);
    expect(old.copyWith(enabled: false).hasIgnoredSwitch, isFalse);
  });

  group('encryption', () {
    test('reads its status and never the certificate or key', () {
      final AdguardHomeTlsStatus tls =
          AdguardHomeTlsStatus.fromJson(tlsOnJson());

      expect(tls.enabled, isTrue);
      expect(tls.serverName, 'dns.home.example');
      expect(tls.forceHttps, isTrue);
      expect(tls.portHttps, 443);
      expect(tls.portDnsOverTls, 853);
      expect(tls.portDnsOverQuic, 853);
      expect(tls.portDnsCrypt, 0);
      expect(tls.validCertificate, isTrue);
      expect(tls.validChain, isTrue);
      expect(tls.validKey, isTrue);
      expect(tls.validPair, isTrue);
      expect(tls.issuer, "CN=R11,O=Let's Encrypt,C=US");
      expect(tls.subject, 'CN=dns.home.example');
      expect(tls.keyType, 'ECDSA');
      expect(tls.dnsNames, <String>['dns.home.example']);
      expect(tls.notAfter, DateTime.utc(2026, 11, 30));
      expect(tls.toString(), isNot(contains('LS0t')));
    });

    test('off, has no dates', () {
      final AdguardHomeTlsStatus tls =
          AdguardHomeTlsStatus.fromJson(tlsOffJson());

      expect(tls.enabled, isFalse);
      expect(tls.notBefore, isNull);
      expect(tls.notAfter, isNull);
      expect(tls.dnsNames, isEmpty);
    });
  });

  group('DHCP', () {
    test('reads the ranges and the leases', () {
      final AdguardHomeDhcpStatus dhcp =
          AdguardHomeDhcpStatus.fromJson(dhcpOnJson());

      expect(dhcp.enabled, isTrue);
      expect(dhcp.interfaceName, 'eth0');
      expect(dhcp.v4.gateway, '192.168.1.1');
      expect(dhcp.v4.subnetMask, '255.255.255.0');
      expect(dhcp.v4.rangeStart, '192.168.1.100');
      expect(dhcp.v4.rangeEnd, '192.168.1.200');
      expect(dhcp.v4.leaseDuration, const Duration(days: 1));
      expect(dhcp.v6.rangeStart, isEmpty);
      expect(dhcp.leases.single.hostname, 'kitchen-speaker');
      expect(dhcp.leases.single.expires, DateTime.utc(2026, 10, 21, 8, 30));
      expect(dhcp.staticLeases.single.ip, '192.168.1.20');
      expect(dhcp.staticLeases.single.expires, isNull);
    });

    test('off and empty, reads as such', () {
      final AdguardHomeDhcpStatus dhcp =
          AdguardHomeDhcpStatus.fromJson(dhcpOffJson());

      expect(dhcp.enabled, isFalse);
      expect(dhcp.interfaceName, isEmpty);
      expect(dhcp.leases, isEmpty);
      expect(dhcp.staticLeases, isEmpty);
    });
  });

  group('the update check', () {
    test('turned off on the server says so', () {
      final AdguardHomeVersionCheck check =
          AdguardHomeVersionCheck.fromJson(versionDisabledJson());

      expect(check.disabled, isTrue);
      expect(check.newVersion, isEmpty);
    });

    test('names a newer version and where to read of it', () {
      final AdguardHomeVersionCheck check =
          AdguardHomeVersionCheck.fromJson(versionNewJson());

      expect(check.disabled, isFalse);
      expect(check.newVersion, 'v0.107.80');
      expect(check.announcementUrl, contains('v0.107.80'));
      expect(check.isNewerThan('v0.107.79'), isTrue);
      expect(check.isNewerThan('v0.107.80'), isFalse);
      expect(check.isNewerThan('0.107.80'), isFalse);
    });
  });

  test('upstream test answers read per server', () {
    final List<AdguardHomeUpstreamResult> results =
        AdguardHomeUpstreamResult.listFromJson(testUpstreamJson());

    expect(results, hasLength(2));
    expect(results.first.server, 'https://dns10.quad9.net:443/dns-query');
    expect(results.first.ok, isTrue);
    expect(results.last.ok, isFalse);
    expect(results.last.message, contains('i/o timeout'));
  });
}
