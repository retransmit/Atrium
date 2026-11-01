import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

import 'support/adguard_home_filters_fixtures.dart';
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

  Future<void> until(bool Function() condition) async {
    for (int turn = 0; turn < 500 && !condition(); turn++) {
      await pumpEventQueue(times: 1);
    }
    expect(condition(), isTrue, reason: 'the awaited state never came');
  }

  AdguardHomeActions actions() =>
      container.read(adguardHomeActionsProvider(instance));

  List<String> sent() => <String>[
        for (final RequestOptions request in server.requests)
          '${request.method} ${request.path}',
      ];

  Object? body(String method, String path) => server.single(method, path).data;

  final AdguardHomeFiltering filtering =
      AdguardHomeFiltering.fromJson(filterStatusJson());

  group('reads', () {
    test('the rewrites, their switch and the services, each once', () async {
      expect(
        await settle(adguardHomeRewritesProvider(instance)),
        hasLength(2),
      );
      expect(await settle(adguardHomeRewritesEnabledProvider(instance)), true);
      expect(
        await settle(adguardHomeGlobalServicesProvider(instance)),
        isA<AdguardHomeGlobalServices>(),
      );

      expect(sent(), <String>[
        'GET control/rewrite/list',
        'GET control/rewrite/settings',
        'GET control/blocked_services/get',
      ]);
    });

    test('that fail are not asked for again by themselves', () async {
      server.fail(
        'GET',
        'control/rewrite/list',
        500,
        '<html>no</html>',
        contentType: 'text/html',
      );

      await settle(adguardHomeRewritesProvider(instance));
      await Future<void>.delayed(const Duration(milliseconds: 700));

      expect(sent(), <String>['GET control/rewrite/list']);
    });

    test('are read again when the sign-in is tried again', () async {
      server.refusing = true;
      await settle(adguardHomeRewritesProvider(instance));
      server.refusing = false;

      actions().retrySignIn();
      await until(
        () => container.read(adguardHomeRewritesProvider(instance)).hasValue,
      );

      expect(server.to('GET', 'control/rewrite/list'), hasLength(2));
    });
  });

  group('filter lists', () {
    final AdguardHomeFilterList off = filtering.blocklists.last;

    test('a switch keeps the name and address of the list', () async {
      await actions().setListEnabled(off, allowlist: false, enabled: true);

      expect(body('POST', 'control/filtering/set_url'), <String, dynamic>{
        'url': off.url,
        'whitelist': false,
        'data': <String, dynamic>{
          'name': off.name,
          'url': off.url,
          'enabled': true,
        },
      });
    });

    test('a new list is added, and a changed one keeps its switch', () async {
      await actions().saveList(
        allowlist: true,
        name: 'Mine',
        url: 'https://lists.example/mine.txt',
      );
      await actions().saveList(
        original: off,
        allowlist: false,
        name: 'Renamed',
        url: 'https://lists.example/moved.txt',
      );

      expect(body('POST', 'control/filtering/add_url'), <String, dynamic>{
        'name': 'Mine',
        'url': 'https://lists.example/mine.txt',
        'whitelist': true,
      });
      expect(body('POST', 'control/filtering/set_url'), <String, dynamic>{
        'url': off.url,
        'whitelist': false,
        'data': <String, dynamic>{
          'name': 'Renamed',
          'url': 'https://lists.example/moved.txt',
          'enabled': false,
        },
      });
    });

    /// The filtering read with the second blocklist as [change] makes it.
    Map<String, dynamic> withOff(void Function(Map<String, dynamic>) change) {
      final Map<String, dynamic> json = filterStatusJson();
      change((json['filters'] as List<dynamic>).last as Map<String, dynamic>);
      return json;
    }

    test('a switch sends the name the server has now, not the one shown',
        () async {
      server.on(
        'GET',
        'control/filtering/status',
        withOff((Map<String, dynamic> list) => list['name'] = 'Renamed'),
      );

      await actions().setListEnabled(off, allowlist: false, enabled: true);

      expect(
        (body('POST', 'control/filtering/set_url')! as Map<String, dynamic>)[
            'data'],
        <String, dynamic>{'name': 'Renamed', 'url': off.url, 'enabled': true},
      );
    });

    test('an edit keeps the switch as the server has it now', () async {
      // Switched on elsewhere, or by this screen a moment before.
      server.on(
        'GET',
        'control/filtering/status',
        withOff((Map<String, dynamic> list) => list['enabled'] = true),
      );

      await actions().saveList(
        original: off,
        allowlist: false,
        name: 'Renamed',
        url: off.url,
      );

      expect(
        ((body('POST', 'control/filtering/set_url')!
                as Map<String, dynamic>)['data'] as Map<String, dynamic>)[
            'enabled'],
        true,
      );
    });

    test('a list gone from the server is not written', () async {
      server.on(
        'GET',
        'control/filtering/status',
        <String, dynamic>{...filterStatusJson(), 'filters': <dynamic>[]},
      );

      await expectLater(
        actions().setListEnabled(off, allowlist: false, enabled: true),
        throwsA(isA<AdguardHomeEntryGone>()),
      );
      await expectLater(
        actions().saveList(
          original: off,
          allowlist: false,
          name: 'Renamed',
          url: off.url,
        ),
        throwsA(isA<AdguardHomeEntryGone>()),
      );
      expect(server.to('POST', 'control/filtering/set_url'), isEmpty);
    });

    test('what makes the server fetch lists is given time for it', () async {
      server.on('POST', 'control/filtering/refresh', <String, dynamic>{
        'updated': 0,
      });
      await actions().saveList(allowlist: true, name: 'A', url: 'https://a/');
      await actions().setListEnabled(off, allowlist: false, enabled: true);
      await actions().refreshLists(allowlist: false);

      for (final String path in <String>[
        'control/filtering/add_url',
        'control/filtering/set_url',
        'control/filtering/refresh',
      ]) {
        expect(
          server.single('POST', path).receiveTimeout,
          AdguardHomeApi.listFetchTimeout,
          reason: path,
        );
      }
    });

    test('an add not waited out is checked before it is called failed',
        () async {
      const String url = 'https://lists.example/big.txt';
      bool added = false;
      server
        ..onCall('POST', 'control/filtering/add_url', (RequestOptions request) {
          added = true;
          throw DioException(
            requestOptions: request,
            type: DioExceptionType.receiveTimeout,
          );
        })
        ..onCall('GET', 'control/filtering/status', (RequestOptions _) {
          final Map<String, dynamic> json = filterStatusJson();
          if (added) {
            (json['filters'] as List<dynamic>).add(<String, dynamic>{
              'url': url,
              'name': 'Big',
              'id': 9,
              'rules_count': 1,
              'enabled': true,
            });
          }
          return json;
        });

      // The server got there: nothing to say.
      await actions().saveList(allowlist: false, name: 'Big', url: url);

      // It did not: the timeout is what the user hears.
      await expectLater(
        actions().saveList(
          allowlist: false,
          name: 'Other',
          url: 'https://lists.example/other.txt',
        ),
        throwsA(isA<NetworkTimeoutException>()),
      );
    });

    test('the update interval keeps filtering as the server has it', () async {
      // Switched off elsewhere since the screen was drawn.
      server.on(
        'GET',
        'control/filtering/status',
        filterStatusJson()..['enabled'] = false,
      );

      await actions().setUpdateInterval(168);

      expect(sent(), <String>[
        'GET control/filtering/status',
        'POST control/filtering/config',
      ]);
      expect(body('POST', 'control/filtering/config'), <String, dynamic>{
        'enabled': false,
        'interval': 168,
      });
    });

    test('a change reads the lists again', () async {
      await settle(adguardHomeFilteringProvider(instance));
      final int before = server.to('GET', 'control/filtering/status').length;

      await actions().removeList(off, allowlist: false);

      await until(
        () =>
            server.to('GET', 'control/filtering/status').length == before + 1,
      );
      expect(body('POST', 'control/filtering/remove_url'), <String, dynamic>{
        'url': off.url,
        'whitelist': false,
      });
    });

    test('checking for updates says how many changed', () async {
      server.on(
        'POST',
        'control/filtering/refresh',
        <String, dynamic>{'updated': 1},
      );

      expect(await actions().refreshLists(allowlist: false), 1);
    });
  });

  group('custom rules', () {
    test('are written whole when nobody changed them meanwhile', () async {
      await actions().saveRules(
        before: filtering.userRules,
        after: <String>[...filtering.userRules, '||new.example^'],
      );

      expect(sent(), <String>[
        'GET control/filtering/status',
        'POST control/filtering/set_rules',
      ]);
      expect(
        (body('POST', 'control/filtering/set_rules')!
            as Map<String, dynamic>)['rules'],
        <String>[...filtering.userRules, '||new.example^'],
      );
    });

    test('changed on the server meanwhile are not overwritten unasked',
        () async {
      final List<String> elsewhere = <String>[
        ...filtering.userRules,
        '||blocked-from-the-log.example^\$important',
      ];
      server.on(
        'GET',
        'control/filtering/status',
        filterStatusJson()..['user_rules'] = elsewhere,
      );

      await expectLater(
        actions().saveRules(
          before: filtering.userRules,
          after: <String>['||mine.example^'],
        ),
        throwsA(
          isA<AdguardHomeRulesChanged>().having(
            (AdguardHomeRulesChanged e) => e.rules,
            'rules',
            elsewhere,
          ),
        ),
      );
      expect(server.to('POST', 'control/filtering/set_rules'), isEmpty);

      // Unless the user says to.
      await actions().saveRules(
        before: filtering.userRules,
        after: <String>['||mine.example^'],
        overwrite: true,
      );
      expect(
        (body('POST', 'control/filtering/set_rules')!
            as Map<String, dynamic>)['rules'],
        <String>['||mine.example^'],
      );
    });

    test('follow a renamed client, and say how many did', () async {
      server.on(
        'GET',
        'control/filtering/status',
        filterStatusJson()
          ..['user_rules'] = <String>[
            "||tiktok.com^\$client='Kids tablet'",
            '||plain.example^',
          ],
      );

      expect(
        await actions().renameClientInRules('Kids tablet', 'Tablet'),
        1,
      );
      expect(
        (body('POST', 'control/filtering/set_rules')!
            as Map<String, dynamic>)['rules'],
        <String>["||tiktok.com^\$client='Tablet'", '||plain.example^'],
      );
    });

    test('naming no such client are not written at all', () async {
      expect(await actions().renameClientInRules('Nobody', 'Someone'), 0);
      expect(server.to('POST', 'control/filtering/set_rules'), isEmpty);
    });
  });

  group('the blocked services of the server', () {
    test('changing the services keeps the schedule as the server has it',
        () async {
      await actions().setGlobalServiceIds(<String>['youtube', 'tiktok']);

      expect(sent(), <String>[
        'GET control/blocked_services/get',
        'PUT control/blocked_services/update',
      ]);
      final Map<String, dynamic> sentBody =
          body('PUT', 'control/blocked_services/update')!
              as Map<String, dynamic>;
      expect(sentBody['ids'], <String>['youtube', 'tiktok']);
      expect(
        sentBody['schedule'],
        AdguardHomeSchedule.fromJson(globalServicesJson()['schedule']).toJson(),
      );
    });

    test('changing the schedule keeps the services as the server has them',
        () async {
      // Another service was blocked elsewhere meanwhile.
      server.on(
        'GET',
        'control/blocked_services/get',
        globalServicesJson()..['ids'] = <String>['tiktok', 'netflix'],
      );

      await actions().setGlobalSchedule(
        const AdguardHomeSchedule(timeZone: 'UTC'),
      );

      final Map<String, dynamic> sentBody =
          body('PUT', 'control/blocked_services/update')!
              as Map<String, dynamic>;
      expect(sentBody['ids'], <String>['tiktok', 'netflix']);
      expect(sentBody['schedule'], <String, dynamic>{'time_zone': 'UTC'});
    });
  });

  group('rewrites', () {
    const AdguardHomeRewrite rewrite = AdguardHomeRewrite(
      domain: '*.lan.example',
      answer: 'nas.home.example',
      enabled: false,
    );

    test('a new one is added, a changed one is updated by what it was',
        () async {
      await actions().saveRewrite(rewrite: rewrite);
      await actions().saveRewrite(
        original: rewrite,
        rewrite: rewrite.copyWith(answer: '10.0.0.9'),
      );

      expect(body('POST', 'control/rewrite/add'), rewrite.toJson());
      expect(body('PUT', 'control/rewrite/update'), <String, dynamic>{
        'target': rewrite.toJson(),
        'update': rewrite.copyWith(answer: '10.0.0.9').toJson(),
      });
    });

    test('a switch changes only whether it is on', () async {
      await actions().setRewriteEnabled(rewrite, enabled: true);

      expect(body('PUT', 'control/rewrite/update'), <String, dynamic>{
        'target': rewrite.toJson(),
        'update': rewrite.copyWith(enabled: true).toJson(),
      });
    });

    test('an edit keeps the switch as the server has it now', () async {
      server.on('GET', 'control/rewrite/list', <dynamic>[
        rewrite.copyWith(enabled: true).toJson(),
      ]);

      await actions().saveRewrite(
        original: rewrite,
        rewrite: rewrite.copyWith(answer: '10.0.0.9'),
      );

      expect(body('PUT', 'control/rewrite/update'), <String, dynamic>{
        'target': rewrite.copyWith(enabled: true).toJson(),
        'update': rewrite.copyWith(answer: '10.0.0.9', enabled: true).toJson(),
      });
    });

    test('an edit on a server without switches sends none', () async {
      server.on('GET', 'control/rewrite/list', <dynamic>[
        <String, dynamic>{'domain': rewrite.domain, 'answer': rewrite.answer},
      ]);

      await actions().saveRewrite(
        original: rewrite,
        rewrite: rewrite.copyWith(answer: '10.0.0.9'),
      );

      expect(body('PUT', 'control/rewrite/update'), <String, dynamic>{
        'target': <String, dynamic>{
          'domain': rewrite.domain,
          'answer': rewrite.answer,
        },
        'update': <String, dynamic>{
          'domain': rewrite.domain,
          'answer': '10.0.0.9',
        },
      });
    });

    test('one the server holds twice is not changed, nor one gone', () async {
      server.on('GET', 'control/rewrite/list', <dynamic>[
        rewrite.toJson(),
        rewrite.copyWith(enabled: true).toJson(),
      ]);
      await expectLater(
        actions().setRewriteEnabled(rewrite, enabled: true),
        throwsA(
          isA<AdguardHomeRewriteRepeated>()
              .having((AdguardHomeRewriteRepeated e) => e.copies, 'copies', 2),
        ),
      );
      await expectLater(
        actions().saveRewrite(
          original: rewrite,
          rewrite: rewrite.copyWith(answer: '10.0.0.9'),
        ),
        throwsA(isA<AdguardHomeRewriteRepeated>()),
      );

      server.on('GET', 'control/rewrite/list', <dynamic>[]);
      await expectLater(
        actions().setRewriteEnabled(rewrite, enabled: true),
        throwsA(isA<AdguardHomeEntryGone>()),
      );

      expect(server.to('PUT', 'control/rewrite/update'), isEmpty);
    });

    test('delete, and the overall switch, read the list again', () async {
      await settle(adguardHomeRewritesProvider(instance));
      await settle(adguardHomeRewritesEnabledProvider(instance));

      await actions().deleteRewrite(rewrite);
      await actions().setRewritesEnabled(enabled: false);

      await until(() => server.to('GET', 'control/rewrite/list').length == 2);
      await until(
        () => server.to('GET', 'control/rewrite/settings').length == 2,
      );
    });
  });

  test('checks a host', () async {
    final AdguardHomeHostCheck check =
        await actions().checkHost('wikipedia.org');

    expect(check.result, AdguardHomeQueryResult.allowed);
  });

  test('once the sign-in is refused, no write sends anything', () async {
    server.refusing = true;
    await settle(adguardHomeStatusProvider(instance));
    expect(server.requests, hasLength(1));

    final List<Future<Object?>> writes = <Future<Object?>>[
      actions().setUpdateInterval(1),
      actions().saveRules(before: const <String>[], after: const <String>[]),
      actions().setGlobalServiceIds(const <String>[]),
      actions().setRewritesEnabled(enabled: true),
      actions().checkHost('a.example'),
      actions().refreshLists(allowlist: true),
    ];
    for (final Future<Object?> write in writes) {
      await expectLater(write, throwsA(isA<AdguardHomeSignInRefused>()));
    }

    expect(server.requests, hasLength(1));
  });

  test('says rules changed elsewhere in a sentence', () {
    expect(
      describeAdguardHomeError(const AdguardHomeRulesChanged(<String>[])),
      'The custom rules were changed on the server since you opened them.',
    );
  });
}
