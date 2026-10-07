import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

import 'support/fake_adguard_home.dart';

void main() {
  late FakeAdguardHome server;
  late AdguardHomeApi api;
  final DateTime now = DateTime(2026, 10, 7, 18, 30);

  setUp(() {
    server = FakeAdguardHome();
    api = AdguardHomeApi(
      dioFor(server),
      AdguardHomeSession(),
      now: () => now,
    );
  });

  test('reads the status and notes when it was read', () async {
    final AdguardHomeStatus status = await api.getStatus();

    expect(server.single('GET', 'control/status'), isNotNull);
    expect(status.version, 'v0.107.79');
    expect(status.readAt, now);
  });

  test('reads the statistics', () async {
    final AdguardHomeStats stats = await api.getStats();

    expect(server.single('GET', 'control/stats'), isNotNull);
    expect(stats.queries, 68);
    expect(stats.blockedByFilters, 24);
  });

  test('reads the filter lists', () async {
    final AdguardHomeFiltering filtering = await api.getFiltering();

    expect(server.single('GET', 'control/filtering/status'), isNotNull);
    expect(filtering.rulesOnBlocklists, 179185);
  });

  test('reads how far back the statistics go', () async {
    // The server gives the interval in milliseconds.
    expect(await api.getStatsPeriod(), const Duration(hours: 24));
    expect(server.single('GET', 'control/stats/config'), isNotNull);
  });

  group('protection', () {
    Object? sent() => server.single('POST', 'control/protection').data;

    test('a pause sends its length in milliseconds', () async {
      await api.setProtection(
        enabled: false,
        pause: const Duration(seconds: 30),
      );

      expect(sent(), <String, dynamic>{'enabled': false, 'duration': 30000});
    });

    test('off with no pause sends no length, which means until turned on',
        () async {
      await api.setProtection(enabled: false);

      expect(sent(), <String, dynamic>{'enabled': false});
    });

    test('turning it on never sends a length', () async {
      await api.setProtection(
        enabled: true,
        pause: const Duration(minutes: 10),
      );

      expect(sent(), <String, dynamic>{'enabled': true});
    });
  });

  test('writes the custom rules as a list of lines', () async {
    await api.setUserRules(<String>[
      r'||ads.example^$important',
      r'@@||fine.example^$important',
    ]);

    expect(
      server.single('POST', 'control/filtering/set_rules').data,
      <String, dynamic>{
        'rules': <String>[
          r'||ads.example^$important',
          r'@@||fine.example^$important',
        ],
      },
    );
  });

  group('query log', () {
    Map<String, dynamic> asked() =>
        server.single('GET', 'control/querylog').queryParameters;

    test('asks for the newest page when nothing is narrowed down', () async {
      final AdguardHomeQueryLogPage page = await api.getQueryLog();

      expect(asked(), <String, dynamic>{'limit': 50});
      expect(page.entries, hasLength(15));
      expect(page.oldest, '2026-10-07T18:31:41.552491023Z');
    });

    test('sends where to go on from, the search and the filter', () async {
      await api.getQueryLog(
        olderThan: '2026-10-07T18:31:41.552491023Z',
        limit: 20,
        search: 'Laptop',
        filter: AdguardHomeLogFilter.blockedServices,
      );

      expect(asked(), <String, dynamic>{
        // Exactly as the server wrote it.
        'older_than': '2026-10-07T18:31:41.552491023Z',
        'limit': 20,
        'search': 'Laptop',
        'response_status': 'blocked_services',
      });
    });

    test('reads whether a log is kept', () async {
      final AdguardHomeQueryLogConfig config = await api.getQueryLogConfig();

      expect(server.single('GET', 'control/querylog/config'), isNotNull);
      expect(config.enabled, isTrue);
    });

    test('clears the log', () async {
      await api.clearQueryLog();

      expect(server.single('POST', 'control/querylog_clear').data, isNull);
    });
  });

  group('access', () {
    test('reads who may use the server', () async {
      final AdguardHomeAccessList list = await api.getAccessList();

      expect(server.single('GET', 'control/access/list'), isNotNull);
      expect(list.blockedHosts, hasLength(3));
    });

    test('writes all three lists, since the server replaces all three',
        () async {
      await api.setAccessList(
        const AdguardHomeAccessList(
          disallowedClients: <String>['172.17.0.1'],
          blockedHosts: <String>['version.bind'],
        ),
      );

      expect(
        server.single('POST', 'control/access/set').data,
        <String, dynamic>{
          'allowed_clients': <String>[],
          'disallowed_clients': <String>['172.17.0.1'],
          'blocked_hosts': <String>['version.bind'],
        },
      );
    });

    test('says why the server turned a list down', () async {
      server.fail(
        'POST',
        'control/access/set',
        400,
        'creating access ctx: adding blocked: value "x y" at index 0: '
            'bad ip, cidr, or clientid',
      );

      await expectLater(
        api.setAccessList(const AdguardHomeAccessList()),
        throwsA(
          isA<AdguardHomeRequestRefused>().having(
            (AdguardHomeRequestRefused error) => error.message,
            'message',
            contains('bad ip, cidr, or clientid'),
          ),
        ),
      );
    });
  });

  test('reads the clients the server has names for', () async {
    final List<AdguardHomeClientRef> clients = await api.getPersistentClients();

    expect(server.single('GET', 'control/clients'), isNotNull);
    expect(clients.single.name, 'Laptop');
  });

  test('an answer that is not a JSON object is not AdGuard Home', () async {
    // What a proxy's sign-in page or a single-page app answers with.
    server.on('GET', 'control/status', 'Sign in to continue');

    await expectLater(
      api.getStatus(),
      throwsA(isA<AdguardHomeUnexpectedAnswer>()),
    );
  });

  test('describes each failure in a sentence', () {
    expect(
      describeAdguardHomeError(const AdguardHomeSignInRefused()),
      'AdGuard Home refused the sign-in.',
    );
    expect(
      describeAdguardHomeError(const AdguardHomeRequestRefused('bad rule')),
      'bad rule',
    );
    expect(
      describeAdguardHomeError(const AdguardHomeUnexpectedAnswer()),
      'This address answered, but not as AdGuard Home.',
    );
    expect(
      describeAdguardHomeError(
        DioException(requestOptions: RequestOptions(path: 'x')),
      ),
      'Something went wrong talking to AdGuard Home.',
    );
  });
}
