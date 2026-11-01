import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

import 'support/adguard_home_clients_fixtures.dart';
import 'support/adguard_home_filters_fixtures.dart';
import 'support/adguard_home_fixtures.dart';
import 'support/adguard_home_query_log_fixtures.dart';
import 'support/adguard_home_test_instance.dart';
import 'support/fake_adguard_home.dart';

void main() {
  const Instance instance = adguardHomeTestInstance;
  late FakeAdguardHome server;
  late ProviderContainer container;

  setUp(() {
    server = FakeAdguardHome()
      ..on('GET', 'control/filtering/status', filterStatusJson());
    container = ProviderContainer(
      overrides: <Override>[
        instanceDioProvider(instance)
            .overrideWith((Ref ref) async => dioFor(server)),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<Object?> settle<T>(ProviderListenable<AsyncValue<T>> provider) {
    final Completer<Object?> done = Completer<Object?>();
    container.listen<AsyncValue<T>>(
      provider,
      (AsyncValue<T>? _, AsyncValue<T> next) {
        if (done.isCompleted) return;
        if (next.hasError) {
          done.complete(next.error);
        } else if (!next.isLoading) {
          done.complete(next.value);
        }
      },
      fireImmediately: true,
    );
    return done.future;
  }

  AdguardHomeActions actions() =>
      container.read(adguardHomeActionsProvider(instance));

  Map<String, dynamic> body(String method, String path) =>
      server.single(method, path).data! as Map<String, dynamic>;

  test('the general settings are three reads, not repeated on failure',
      () async {
    final AdguardHomeGeneralSettings general = (await settle(
      adguardHomeGeneralSettingsProvider(instance),
    ))! as AdguardHomeGeneralSettings;
    expect(general.safeBrowsing, isTrue);
    expect(general.parental, isFalse);
    expect(general.safeSearch.enabled, isTrue);

    server.fail('GET', 'control/dns_info', 500, 'broken');
    expect(
      await settle(adguardHomeDnsConfigProvider(instance)),
      isA<Exception>(),
    );
    await pumpEventQueue();
    expect(server.to('GET', 'control/dns_info'), hasLength(1));
  });

  test('filtering on or off keeps the update interval the server has now',
      () async {
    server.on(
      'GET',
      'control/filtering/status',
      <String, dynamic>{...filterStatusJson(), 'interval': 72},
    );

    await actions().setFilteringEnabled(enabled: false);

    expect(body('POST', 'control/filtering/config'), <String, dynamic>{
      'enabled': false,
      'interval': 72,
    });
  });

  test('safe search changes only what was switched', () async {
    final AdguardHomeSafeSearch before =
        AdguardHomeSafeSearch.fromJson(safeSearchJson());
    // YouTube switched elsewhere since the screen read it.
    server.on('GET', 'control/safesearch/status', <String, dynamic>{
      ...safeSearchJson(),
      'youtube': !before.engines['youtube']!,
    });

    await actions().setSafeSearch(
      before: before,
      after: AdguardHomeSafeSearch.fromJson(<String, dynamic>{
        ...before.toJson(),
        'google': !before.engines['google']!,
      }),
    );

    final Map<String, dynamic> sent =
        body('PUT', 'control/safesearch/settings');
    expect(sent['google'], !before.engines['google']!);
    expect(sent['youtube'], !before.engines['youtube']!);
    expect(sent['bing'], before.engines['bing']);
  });

  test('retention changes only what the form changed, whole', () async {
    final AdguardHomeRetention before =
        AdguardHomeRetention.fromJson(queryLogConfigJson());
    // Ignored domains set elsewhere since.
    server.on('GET', 'control/querylog/config', <String, dynamic>{
      ...queryLogConfigJson(),
      'ignored': <String>['elsewhere.example'],
      'ignored_enabled': true,
    });

    await actions().saveQueryLogRetention(
      before: before,
      after: before.copyWith(interval: const Duration(days: 7)),
    );

    expect(body('PUT', 'control/querylog/config/update'), <String, dynamic>{
      'ignored': <String>['elsewhere.example'],
      'interval': const Duration(days: 7).inMilliseconds,
      'enabled': true,
      'ignored_enabled': true,
      'anonymize_client_ip': false,
    });
  });

  test('statistics retention is written, and the figures read again',
      () async {
    await settle(adguardHomeStatsProvider(instance));
    final AdguardHomeRetention before =
        AdguardHomeRetention.fromJson(statsConfigJson());

    await actions().saveStatsRetention(
      before: before,
      after: before.copyWith(enabled: false),
    );
    await settle(adguardHomeStatsProvider(instance));

    expect(body('PUT', 'control/stats/config/update')['enabled'], isFalse);
    expect(server.to('GET', 'control/stats'), hasLength(2));
  });

  test('DNS settings send only what changed, and nothing for no change',
      () async {
    await actions().saveDnsSettings(
      before: <String, dynamic>{'ratelimit': 20, 'dnssec_enabled': true},
      after: <String, dynamic>{'ratelimit': 20, 'dnssec_enabled': true},
    );
    expect(server.to('POST', 'control/dns_config'), isEmpty);

    await actions().saveDnsSettings(
      before: <String, dynamic>{'ratelimit': 20, 'dnssec_enabled': true},
      after: <String, dynamic>{'ratelimit': 20, 'dnssec_enabled': false},
    );
    expect(body('POST', 'control/dns_config'), <String, dynamic>{
      'dnssec_enabled': false,
    });
  });

  test('DNS settings the server takes only together go together', () async {
    await actions().saveDnsSettings(
      before: <String, dynamic>{
        'blocking_mode': 'custom_ip',
        'blocking_ipv4': '10.0.0.1',
        'blocking_ipv6': 'fd00::1',
      },
      after: <String, dynamic>{
        'blocking_mode': 'custom_ip',
        'blocking_ipv4': '10.0.0.2',
        'blocking_ipv6': 'fd00::1',
      },
    );

    expect(body('POST', 'control/dns_config'), <String, dynamic>{
      'blocking_mode': 'custom_ip',
      'blocking_ipv4': '10.0.0.2',
      'blocking_ipv6': 'fd00::1',
    });
  });

  test('the access lists replace only the list that was changed', () async {
    final AdguardHomeAccessList before =
        AdguardHomeAccessList.fromJson(accessListJson());
    // A client disallowed elsewhere since.
    server.on('GET', 'control/access/list', <String, dynamic>{
      ...accessListJson(),
      'disallowed_clients': <String>['10.0.0.9'],
    });

    await actions().saveAccessList(
      before: before,
      after: AdguardHomeAccessList.fromJson(<String, dynamic>{
        ...accessListJson(),
        'blocked_hosts': <String>['id.server'],
      }),
    );

    final Map<String, dynamic> sent = body('POST', 'control/access/set');
    expect(sent['disallowed_clients'], <String>['10.0.0.9']);
    expect(sent['blocked_hosts'], <String>['id.server']);
  });

  test('once the sign-in is refused, no settings write sends anything',
      () async {
    server.refusing = true;
    await settle(adguardHomeStatusProvider(instance));
    expect(server.requests, hasLength(1));

    const AdguardHomeRetention retention = AdguardHomeRetention();
    final List<Future<Object?>> writes = <Future<Object?>>[
      actions().setFilteringEnabled(enabled: true),
      actions().setSafeBrowsing(enabled: true),
      actions().setParental(enabled: true),
      actions().saveQueryLogRetention(before: retention, after: retention),
      actions().resetStats(),
      actions().saveDnsSettings(
        before: const <String, dynamic>{},
        after: const <String, dynamic>{'ratelimit': 1},
      ),
      actions().clearDnsCache(),
      actions().checkVersion(),
    ];
    for (final Future<Object?> write in writes) {
      await expectLater(write, throwsA(isA<AdguardHomeSignInRefused>()));
    }

    expect(server.requests, hasLength(1));
  });

  test('the test of upstreams is not a write: the settings stay as read',
      () async {
    await settle(adguardHomeDnsConfigProvider(instance));

    final List<AdguardHomeUpstreamResult> results =
        await actions().testUpstreams(
      upstreams: <String>['1.1.1.1'],
      bootstrap: const <String>[],
      fallback: const <String>[],
      privateUpstreams: const <String>[],
    );
    await pumpEventQueue();

    expect(results, isNotEmpty);
    expect(server.to('GET', 'control/dns_info'), hasLength(1));
    expect(
      <String>[for (final RequestOptions r in server.requests) r.path],
      isNot(contains('control/dns_config')),
    );
  });
}
