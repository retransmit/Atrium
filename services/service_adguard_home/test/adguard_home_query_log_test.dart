import 'dart:async';
import 'dart:collection';

import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

import 'support/adguard_home_query_log_fixtures.dart';
import 'support/adguard_home_test_instance.dart';
import 'support/fake_adguard_home.dart';

void main() {
  late FakeAdguardHome server;
  late ProviderContainer container;

  /// The answers the server gives to its next requests for the log, in
  /// order. When they run out it says the log has ended.
  late Queue<Map<String, dynamic>> pages;

  final provider = adguardHomeQueryLogProvider(adguardHomeTestInstance);

  /// A page of [count] entries named after [name], stopping at [oldest].
  Map<String, dynamic> page(int count, String oldest, {String name = 'q'}) {
    final Map<String, dynamic> first =
        (queryLogJson()['data'] as List<dynamic>).first as Map<String, dynamic>;
    return <String, dynamic>{
      'data': <dynamic>[
        for (int i = 0; i < count; i++)
          <String, dynamic>{
            ...first,
            'question': <String, dynamic>{
              'class': 'IN',
              'name': '$name$i.$oldest.example',
              'type': 'A',
            },
          },
      ],
      'oldest': oldest,
    };
  }

  setUp(() {
    server = FakeAdguardHome();
    pages = Queue<Map<String, dynamic>>();
    server.onCall(
      'GET',
      'control/querylog',
      (RequestOptions _) => pages.isEmpty
          ? <String, dynamic>{'data': <dynamic>[], 'oldest': ''}
          : pages.removeFirst(),
    );
    container = ProviderContainer(
      overrides: <Override>[
        instanceDioProvider(adguardHomeTestInstance)
            .overrideWith((Ref ref) async => dioFor(server)),
      ],
    );
    addTearDown(container.dispose);
  });

  /// Lets pending work run until [condition] holds.
  Future<void> until(bool Function() condition) async {
    for (int turn = 0; turn < 500 && !condition(); turn++) {
      await pumpEventQueue(times: 1);
    }
    expect(condition(), isTrue, reason: 'the awaited state never came');
  }

  AdguardHomeQueryLogState state() => container.read(provider);

  AdguardHomeQueryLog log() => container.read(provider.notifier);

  /// Starts watching the log, as opening the tab does, and waits for the
  /// first read to finish.
  Future<void> open() async {
    container.listen(provider, (_, __) {});
    await until(() => !state().loading);
  }

  /// What each request for the log asked, in order.
  List<Map<String, dynamic>> asked() => <Map<String, dynamic>>[
        for (final RequestOptions request
            in server.to('GET', 'control/querylog'))
          request.queryParameters,
      ];

  AdguardHomeActions actions() =>
      container.read(adguardHomeActionsProvider(adguardHomeTestInstance));

  group('reading', () {
    test('opening reads the newest page', () async {
      pages.add(page(50, 'c1'));

      await open();

      expect(asked(), <Map<String, dynamic>>[
        <String, dynamic>{'limit': 50},
      ]);
      expect(state().entries, hasLength(50));
      expect(state().reachedEnd, isFalse);
      expect(state().stalled, isFalse);
      expect(state().error, isNull);
      expect(state().wantsMore, isTrue);
    });

    test('more is read from where the page before stopped', () async {
      pages
        ..add(page(50, 'c1'))
        ..add(page(50, 'c2'));
      await open();

      await log().loadMore();

      expect(asked().last, <String, dynamic>{
        'older_than': 'c1',
        'limit': 50,
      });
      expect(state().entries, hasLength(100));
      expect(state().entries.last.domain, 'q49.c2.example');
      expect(state().loadingMore, isFalse);
    });

    test('an empty answer with no oldest time is the end, and stays it',
        () async {
      pages
        ..add(page(50, 'c1'))
        ..add(page(10, 'c2'));
      await open();

      await log().loadMore();

      // The ten came short of a page, so it asked on and was told the end.
      expect(asked(), hasLength(3));
      expect(state().entries, hasLength(60));
      expect(state().reachedEnd, isTrue);
      expect(state().wantsMore, isFalse);

      await log().loadMore();
      expect(asked(), hasLength(3));
    });

    test('a short answer that is not the end is followed up at once', () async {
      // Under a filter the server gives up scanning after a while and says
      // how far it got. The web UI asks on until it has a page.
      pages
        ..add(page(3, 'c1'))
        ..add(page(0, 'c2'))
        ..add(page(50, 'c3'));

      await open();

      expect(
        asked().map((Map<String, dynamic> query) => query['older_than']),
        <Object?>[null, 'c1', 'c2'],
      );
      expect(state().entries, hasLength(53));
      expect(state().stalled, isFalse);
    });

    test('it stops asking after five answers and says how far it got',
        () async {
      // A rare filter in a long log: nothing found, never the end.
      for (int i = 1; i <= 7; i++) {
        pages.add(page(0, 'c$i'));
      }

      await open();

      expect(asked(), hasLength(5));
      expect(state().entries, isEmpty);
      expect(state().stalled, isTrue);
      expect(state().reachedEnd, isFalse);
      // Left for the user to ask for, not asked for by itself.
      expect(state().wantsMore, isFalse);
      expect(state().searchedBackTo, 'c5');

      await log().loadMore();

      expect(asked()[5]['older_than'], 'c5');
      // Two more answers were left, then the end.
      expect(asked(), hasLength(8));
      expect(state().reachedEnd, isTrue);
      expect(state().stalled, isFalse);
    });

    test('reading again starts from the top and replaces what was there',
        () async {
      pages
        ..add(page(50, 'c1'))
        ..add(page(50, 'd1', name: 'fresh'));
      await open();

      await log().reload();

      expect(asked().last, <String, dynamic>{'limit': 50});
      expect(state().entries, hasLength(50));
      expect(state().entries.first.domain, 'fresh0.d1.example');
    });
  });

  group('narrowing down', () {
    test('a search empties the list at once and is sent trimmed', () async {
      pages.add(page(50, 'c1'));
      await open();
      pages.add(page(2, ''));

      final Future<void> done = log().setSearch('  Laptop ');

      expect(state().entries, isEmpty);
      expect(state().loading, isTrue);
      expect(state().search, 'Laptop');
      await done;
      expect(asked().last, <String, dynamic>{'limit': 50, 'search': 'Laptop'});
      expect(state().entries, hasLength(2));
      expect(state().reachedEnd, isTrue);
    });

    test('the same search again sends nothing', () async {
      await open();
      await log().setSearch('Laptop');
      final int before = asked().length;

      await log().setSearch(' Laptop');

      expect(asked(), hasLength(before));
    });

    test('a filter is sent in the server\'s word for it', () async {
      await open();

      await log().setFilter(AdguardHomeLogFilter.blockedThreats);

      expect(asked().last, <String, dynamic>{
        'limit': 50,
        'response_status': 'blocked_safebrowsing',
      });
      expect(state().filter, AdguardHomeLogFilter.blockedThreats);
    });

    test('more of a narrowed list keeps the search and the filter', () async {
      await open();
      pages.add(page(50, 'c1'));
      await log().setSearch('google');
      pages.add(page(50, 'c2'));
      await log().setFilter(AdguardHomeLogFilter.blocked);
      pages.add(page(50, 'c3'));

      await log().loadMore();

      expect(asked().last, <String, dynamic>{
        'older_than': 'c2',
        'limit': 50,
        'search': 'google',
        'response_status': 'blocked',
      });
    });

    test('clearing the search and the filter together is one read', () async {
      await open();
      await log().setSearch('google');
      await log().setFilter(AdguardHomeLogFilter.blocked);
      final int before = asked().length;

      await log().clearNarrowing();

      expect(asked(), hasLength(before + 1));
      expect(asked().last, <String, dynamic>{'limit': 50});
      expect(state().narrowed, isFalse);
    });

    test('clearing when nothing narrows the list sends nothing', () async {
      await open();
      final int before = asked().length;

      await log().clearNarrowing();

      expect(asked(), hasLength(before));
    });

    test('an answer to a question no longer asked is thrown away', () async {
      // The first read is still on its way when the search changes.
      pages
        ..add(page(50, 'c1', name: 'old'))
        ..add(page(4, '', name: 'new'));
      server.hold = Completer<void>();
      final List<AdguardHomeQueryLogState> seen = <AdguardHomeQueryLogState>[];
      container.listen(
        provider,
        (AdguardHomeQueryLogState? _, AdguardHomeQueryLogState next) =>
            seen.add(next),
      );
      await until(() => server.requests.isNotEmpty);

      final Future<void> searched = log().setSearch('new');
      seen.clear();
      server.hold!.complete();
      server.hold = null;
      await searched;
      await until(() => !state().loading);

      expect(state().entries, hasLength(4));
      // Not even for a moment: the late answer never shows under the new
      // search, and never puts the old search back.
      for (final AdguardHomeQueryLogState each in seen) {
        expect(each.search, 'new');
        expect(
          each.entries.where(
            (AdguardHomeQueryLogEntry entry) => entry.domain.startsWith('old'),
          ),
          isEmpty,
        );
      }
    });

    test('a read that was overtaken stops asking', () async {
      // It would have gone on from c1. The filter changed first.
      pages
        ..add(page(0, 'c1'))
        ..add(page(50, 'd1'));
      server.hold = Completer<void>();
      container.listen(provider, (_, __) {});
      await until(() => server.requests.isNotEmpty);

      final Future<void> filtered = log().setFilter(AdguardHomeLogFilter.blocked);
      server.hold!.complete();
      server.hold = null;
      await filtered;
      await until(() => !state().loading);
      await pumpEventQueue();

      expect(asked(), <Map<String, dynamic>>[
        <String, dynamic>{'limit': 50},
        <String, dynamic>{'limit': 50, 'response_status': 'blocked'},
      ]);
    });
  });

  group('failing', () {
    test('a first read that fails shows why and holds nothing', () async {
      server.fail(
        'GET',
        'control/querylog',
        502,
        '<html>bad gateway</html>',
        contentType: 'text/html',
      );

      await open();

      expect(state().error, isA<NetworkException>());
      expect(state().entries, isEmpty);
      expect(state().wantsMore, isFalse);
    });

    test('a later read that fails keeps what was there, to go on from',
        () async {
      pages.add(page(50, 'c1'));
      await open();
      server.fail(
        'GET',
        'control/querylog',
        502,
        '<html>bad gateway</html>',
        contentType: 'text/html',
      );

      await log().loadMore();

      expect(state().error, isA<NetworkException>());
      expect(state().entries, hasLength(50));
      // Not asked for again by itself.
      expect(state().wantsMore, isFalse);
    });

    test('a bad value the server turns down is said in its words', () async {
      server.fail(
        'GET',
        'control/querylog',
        400,
        'parsing params: invalid value nonsense',
      );

      await open();

      expect(
        describeAdguardHomeError(state().error!),
        'parsing params: invalid value nonsense',
      );
    });

    test('after a refused sign-in nothing here sends anything', () async {
      server.refusing = true;
      await open();
      expect(state().error, isA<AdguardHomeSignInRefused>());
      expect(server.requests, hasLength(1));

      await log().setSearch('a');
      await log().setFilter(AdguardHomeLogFilter.blocked);
      await log().reload();
      await log().loadMore();

      expect(server.requests, hasLength(1));
      expect(state().error, isA<AdguardHomeSignInRefused>());
    });

    test('trying again costs one request and reads the log', () async {
      server.refusing = true;
      await open();
      server.refusing = false;
      pages.add(page(50, 'c1'));

      actions().retrySignIn();
      await log().reload();

      expect(state().error, isNull);
      expect(state().entries, hasLength(50));
    });
  });

  group('acting on an entry', () {
    Object? rulesSent() =>
        (server.single('POST', 'control/filtering/set_rules').data
            as Map<String, dynamic>)['rules'];

    test('blocking for one client names it as the server knows it', () async {
      final AdguardHomeRuleEdit edit = await actions().toggleBlocking(
        'ads.example',
        block: true,
        clientAddress: '172.17.0.1',
      );

      expect(server.single('GET', 'control/clients'), isNotNull);
      expect(edit.rule, r"||ads.example^$client='Laptop'");
      expect(rulesSent(), <String>[r"||ads.example^$client='Laptop'"]);
    });

    test('a client the server has no name for is written by its address',
        () async {
      final AdguardHomeRuleEdit edit = await actions().toggleBlocking(
        'ads.example',
        block: false,
        clientAddress: '192.168.1.40',
      );

      expect(edit.rule, r"@@||ads.example^$client='192.168.1.40'");
    });

    test('blocking for everyone does not read the clients', () async {
      await actions().toggleBlocking('ads.example', block: true);

      expect(server.to('GET', 'control/clients'), isEmpty);
      expect(rulesSent(), <String>[r'||ads.example^$important']);
    });

    test('shutting a client out reads the lists fresh and writes all three',
        () async {
      await actions().setClientAccess(
        address: '172.17.0.1',
        disallowed: false,
        disallowedRule: '',
      );

      expect(server.single('GET', 'control/access/list'), isNotNull);
      expect(
        server.single('POST', 'control/access/set').data,
        <String, dynamic>{
          'allowed_clients': <String>[],
          'disallowed_clients': <String>['172.17.0.1'],
          'blocked_hosts': <String>[
            'version.bind',
            'id.server',
            'hostname.bind',
          ],
        },
      );
    });

    test('the last allowed client is not taken off, whatever was confirmed',
        () async {
      server.on('GET', 'control/access/list', <String, dynamic>{
        'allowed_clients': <dynamic>['172.17.0.1'],
        'disallowed_clients': <dynamic>[],
        'blocked_hosts': <dynamic>[],
      });

      await expectLater(
        actions().setClientAccess(
          address: '172.17.0.1',
          disallowed: false,
          disallowedRule: '',
        ),
        throwsA(isA<AdguardHomeLastAllowedClient>()),
      );
      expect(server.to('POST', 'control/access/set'), isEmpty);
    });

    test('reads the access list for the question to ask first', () async {
      final AdguardHomeAccessList list = await actions().readAccessList();

      expect(list.allowlistInUse, isFalse);
      expect(server.to('POST', 'control/access/set'), isEmpty);
    });

    test('clears the log', () async {
      await actions().clearQueryLog();

      expect(server.single('POST', 'control/querylog_clear'), isNotNull);
    });
  });

  test('a list that has gone away takes a late call without complaint',
      () async {
    // The end of the list asks for more a frame after it is drawn, and a
    // search a moment after the typing. The screen can be left in between.
    pages.add(page(50, 'c1'));
    await open();
    final AdguardHomeQueryLog late = log();
    final int before = asked().length;

    container.dispose();

    await late.loadMore();
    await late.reload();
    await late.setSearch('late');
    await late.setFilter(AdguardHomeLogFilter.blocked);
    await late.clearNarrowing();
    expect(asked(), hasLength(before));
  });

  test('whether a log is kept is read once, when asked', () async {
    final AdguardHomeQueryLogConfig config = await container.read(
      adguardHomeQueryLogConfigProvider(adguardHomeTestInstance).future,
    );

    expect(config.enabled, isTrue);
    expect(server.single('GET', 'control/querylog/config'), isNotNull);
  });
}
