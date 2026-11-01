import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

import 'support/adguard_home_filters_fixtures.dart';
import 'support/fake_adguard_home.dart';

void main() {
  late FakeAdguardHome server;
  late AdguardHomeApi api;

  setUp(() {
    server = FakeAdguardHome();
    api = AdguardHomeApi(dioFor(server), AdguardHomeSession());
  });

  Object? sent(String method, String path) => server.single(method, path).data;

  group('filter lists', () {
    test('a list is added with its name and address', () async {
      await api.addFilterList(
        name: 'Ads',
        url: 'https://lists.example/ads.txt',
        allowlist: false,
      );

      expect(sent('POST', 'control/filtering/add_url'), <String, dynamic>{
        'name': 'Ads',
        'url': 'https://lists.example/ads.txt',
        'whitelist': false,
      });
    });

    test('a list is changed under the address it has now', () async {
      await api.updateFilterList(
        url: 'https://lists.example/old.txt',
        allowlist: true,
        name: 'Renamed',
        newUrl: 'https://lists.example/new.txt',
        enabled: false,
      );

      expect(sent('POST', 'control/filtering/set_url'), <String, dynamic>{
        'url': 'https://lists.example/old.txt',
        'whitelist': true,
        'data': <String, dynamic>{
          'name': 'Renamed',
          'url': 'https://lists.example/new.txt',
          'enabled': false,
        },
      });
    });

    test('a list is removed by its address and kind', () async {
      await api.removeFilterList(
        url: 'https://lists.example/ads.txt',
        allowlist: false,
      );

      expect(sent('POST', 'control/filtering/remove_url'), <String, dynamic>{
        'url': 'https://lists.example/ads.txt',
        'whitelist': false,
      });
    });

    test('checking for updates says how many lists were updated', () async {
      server.on(
        'POST',
        'control/filtering/refresh',
        <String, dynamic>{'updated': 2},
      );

      expect(await api.refreshFilterLists(allowlist: true), 2);
      expect(
        sent('POST', 'control/filtering/refresh'),
        <String, dynamic>{'whitelist': true},
      );
    });

    test('the update interval goes with whether filtering is on', () async {
      await api.setFilteringConfig(enabled: true, intervalHours: 72);

      expect(sent('POST', 'control/filtering/config'), <String, dynamic>{
        'enabled': true,
        'interval': 72,
      });
    });

    test('says why the server turned a list down', () async {
      server.fail(
        'POST',
        'control/filtering/add_url',
        400,
        'Filter with URL "https://lists.example/ads.txt": url already exists',
      );

      await expectLater(
        api.addFilterList(
          name: 'Ads',
          url: 'https://lists.example/ads.txt',
          allowlist: false,
        ),
        throwsA(
          isA<AdguardHomeRequestRefused>().having(
            (AdguardHomeRequestRefused e) => e.message,
            'message',
            contains('url already exists'),
          ),
        ),
      );
    });
  });

  group('check a host', () {
    test('asks about the name and reads what the server would do', () async {
      final AdguardHomeHostCheck check = await api.checkHost('www.tiktok.com');

      expect(
        server.single('GET', 'control/filtering/check_host').queryParameters,
        <String, dynamic>{'name': 'www.tiktok.com'},
      );
      expect(check.name, 'www.tiktok.com');
      expect(check.result, AdguardHomeQueryResult.blockedService);
    });

    test('asks for a client when one is given', () async {
      await api.checkHost('nas.home.example', client: '172.17.0.1');

      expect(
        server.single('GET', 'control/filtering/check_host').queryParameters,
        <String, dynamic>{'name': 'nas.home.example', 'client': '172.17.0.1'},
      );
    });
  });

  group('the blocked services of the server', () {
    test('are read with their schedule', () async {
      final AdguardHomeGlobalServices services = await api.getGlobalServices();

      expect(services.ids, <String>['tiktok']);
      expect(services.schedule.timeZone, 'Europe/Berlin');
    });

    test('are written with their schedule', () async {
      final AdguardHomeGlobalServices services =
          AdguardHomeGlobalServices.fromJson(globalServicesJson());

      await api.setGlobalServices(services.copyWith(ids: <String>['youtube']));

      final Map<String, dynamic> body = sent(
        'PUT',
        'control/blocked_services/update',
      )! as Map<String, dynamic>;
      expect(body['ids'], <String>['youtube']);
      expect(body['schedule'], services.schedule.toJson());
    });
  });

  group('rewrites', () {
    const AdguardHomeRewrite rewrite = AdguardHomeRewrite(
      domain: '*.lan.example',
      answer: 'nas.home.example',
      enabled: false,
    );

    test('are listed', () async {
      final List<AdguardHomeRewrite> rewrites = await api.getRewrites();

      expect(server.single('GET', 'control/rewrite/list'), isNotNull);
      expect(rewrites, hasLength(2));
    });

    test('a list that is no list is not AdGuard Home', () async {
      server.on('GET', 'control/rewrite/list', <String, dynamic>{'x': 1});

      await expectLater(
        api.getRewrites(),
        throwsA(isA<AdguardHomeUnexpectedAnswer>()),
      );
    });

    test('a rewrite is added, changed and deleted', () async {
      await api.addRewrite(rewrite);
      await api.updateRewrite(rewrite, rewrite.copyWith(enabled: true));
      await api.deleteRewrite(rewrite);

      expect(sent('POST', 'control/rewrite/add'), rewrite.toJson());
      expect(sent('PUT', 'control/rewrite/update'), <String, dynamic>{
        'target': rewrite.toJson(),
        'update': rewrite.copyWith(enabled: true).toJson(),
      });
      expect(sent('POST', 'control/rewrite/delete'), rewrite.toJson());
    });

    test('are all switched on or off', () async {
      expect(await api.getRewritesEnabled(), isTrue);

      await api.setRewritesEnabled(enabled: false);

      expect(
        sent('PUT', 'control/rewrite/settings/update'),
        <String, dynamic>{'enabled': false},
      );
    });
  });

  test('a refused sign-in on one of these sends nothing more', () async {
    server.refusing = true;

    await expectLater(
      api.getRewrites(),
      throwsA(isA<AdguardHomeSignInRefused>()),
    );
    await expectLater(
      api.checkHost('a.example'),
      throwsA(isA<AdguardHomeSignInRefused>()),
    );
    await expectLater(
      api.setRewritesEnabled(enabled: true),
      throwsA(isA<AdguardHomeSignInRefused>()),
    );

    expect(server.requests, hasLength(1));
  });
}
