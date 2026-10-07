import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

import 'support/adguard_home_clients_fixtures.dart';
import 'support/adguard_home_fixtures.dart';
import 'support/adguard_home_test_instance.dart';
import 'support/fake_adguard_home.dart';

void main() {
  const Instance instance = adguardHomeTestInstance;
  late FakeAdguardHome server;
  late ProviderContainer container;

  /// The statistics with these top clients.
  Map<String, dynamic> statsWith(Map<String, int> topClients) =>
      statsJson()
        ..['top_clients'] = <dynamic>[
          for (final MapEntry<String, int> top in topClients.entries)
            <String, dynamic>{top.key: top.value},
        ];

  setUp(() {
    server = FakeAdguardHome()
      ..on(
        'GET',
        'control/stats',
        statsWith(<String, int>{
          '172.17.0.1': 150,
          '127.0.0.1': 122,
          'work-phone': 7,
        }),
      );
    container = ProviderContainer(
      overrides: <Override>[
        instanceDioProvider(instance)
            .overrideWith((Ref ref) async => dioFor(server)),
      ],
    );
    addTearDown(container.dispose);
  });

  /// Watches [provider] until [close] is called on what it returns, and
  /// completes [done] with its first value or error.
  ProviderSubscription<AsyncValue<T>> watch<T>(
    ProviderListenable<AsyncValue<T>> provider,
    Completer<Object?> done,
  ) =>
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

  /// Keeps [provider] alive for the length of the test and waits for its
  /// first value or error.
  Future<Object?> settle<T>(ProviderListenable<AsyncValue<T>> provider) {
    final Completer<Object?> done = Completer<Object?>();
    watch(provider, done);
    return done.future;
  }

  /// Lets pending work run until [condition] holds.
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

  AdguardHomePersistentRow row(AdguardHomeClientsView view, String name) =>
      view.persistent.firstWhere(
        (AdguardHomePersistentRow row) => row.client.name == name,
      );

  group('the clients of the tab', () {
    test('are read in three requests, in order, and put together', () async {
      final Object? view = await settle(adguardHomeClientsProvider(instance));

      expect(sent(), <String>[
        'GET control/clients',
        'GET control/stats',
        'POST control/clients/search',
      ]);
      // Whose the top clients are, and nothing else, is asked.
      expect(
        server.single('POST', 'control/clients/search').data,
        <String, dynamic>{
          'clients': <Map<String, dynamic>>[
            <String, dynamic>{'id': '172.17.0.1'},
            <String, dynamic>{'id': '127.0.0.1'},
            <String, dynamic>{'id': 'work-phone'},
          ],
        },
      );
      view as AdguardHomeClientsView;
      expect(row(view, 'Laptop').queries, 150);
      expect(row(view, 'Work phone').queries, 7);
      expect(row(view, 'Kids tablet').queries, isNull);
      expect(view.persistent.first.client.name, 'Laptop');
      expect(view.runtime.first.client.address, '172.17.0.1');
      expect(view.runtime.first.owner, 'Laptop');
      expect(view.supportedTags, hasLength(21));
    });

    test('with no top clients ask nobody whose they are', () async {
      server.on('GET', 'control/stats', statsWith(const <String, int>{}));

      final Object? view = await settle(adguardHomeClientsProvider(instance));

      expect(sent(), <String>['GET control/clients', 'GET control/stats']);
      expect((view! as AdguardHomeClientsView).persistent, hasLength(3));
    });

    test('are listed on a server that cannot say whose an address is',
        () async {
      // v0.107.55 and older: no such path.
      server.fail('POST', 'control/clients/search', 404, '404 page not found');

      final Object? view = await settle(adguardHomeClientsProvider(instance));

      view as AdguardHomeClientsView;
      expect(view.persistent, hasLength(3));
      // Matched here instead, by the address the client lists.
      expect(row(view, 'Laptop').queries, 150);
      expect(row(view, 'Work phone').queries, 7);
    });

    test('fail as a whole when the server cannot be reached part way',
        () async {
      server.fail(
        'POST',
        'control/clients/search',
        502,
        '<html>Bad gateway</html>',
        contentType: 'text/html',
      );

      expect(
        await settle(adguardHomeClientsProvider(instance)),
        isA<NetworkException>(),
      );
    });

    test('are not asked for again by themselves after a failure', () async {
      server.fail(
        'GET',
        'control/clients',
        500,
        '<html>Oops</html>',
        contentType: 'text/html',
      );

      await settle(adguardHomeClientsProvider(instance));
      // Riverpod would try again after 200 ms, and again, by itself.
      await Future<void>.delayed(const Duration(milliseconds: 700));

      expect(sent(), <String>['GET control/clients']);
    });

    test('cost one request when the sign-in is refused, and no more',
        () async {
      server.refusing = true;

      expect(
        await settle(adguardHomeClientsProvider(instance)),
        isA<AdguardHomeSignInRefused>(),
      );
      await Future<void>.delayed(const Duration(milliseconds: 700));

      expect(sent(), <String>['GET control/clients']);
    });

    test('are read again when the user asks to try the sign-in again',
        () async {
      server.refusing = true;
      await settle(adguardHomeClientsProvider(instance));
      expect(server.requests, hasLength(1));

      server.refusing = false;
      actions().retrySignIn();
      await until(
        () => container.read(adguardHomeClientsProvider(instance)).hasValue,
      );

      expect(server.to('GET', 'control/clients'), hasLength(2));
    });
  });

  group('the catalogue of services', () {
    test('is read once and kept while nobody is looking', () async {
      final Completer<Object?> first = Completer<Object?>();
      final ProviderSubscription<Object?> watching =
          watch(adguardHomeServicesProvider(instance), first);
      expect(await first.future, isA<AdguardHomeServiceCatalogue>());

      watching.close();
      await pumpEventQueue();
      final Object? again = await settle(adguardHomeServicesProvider(instance));

      expect(again, isA<AdguardHomeServiceCatalogue>());
      expect(server.to('GET', 'control/blocked_services/all'), hasLength(1));
    });

    test('is asked for again after a read that failed', () async {
      server.fail(
        'GET',
        'control/blocked_services/all',
        500,
        '<html>Oops</html>',
        contentType: 'text/html',
      );
      final Completer<Object?> first = Completer<Object?>();
      final ProviderSubscription<Object?> watching =
          watch(adguardHomeServicesProvider(instance), first);
      expect(await first.future, isA<NetworkException>());

      watching.close();
      await pumpEventQueue();
      server.mend('GET', 'control/blocked_services/all');

      expect(
        await settle(adguardHomeServicesProvider(instance)),
        isA<AdguardHomeServiceCatalogue>(),
      );
    });
  });

  test('reads the safe search of the server', () async {
    final Object? safe = await settle(adguardHomeSafeSearchProvider(instance));

    expect((safe! as AdguardHomeSafeSearch).engines, hasLength(7));
    expect(sent(), <String>['GET control/safesearch/status']);
  });

  group('saving a client', () {
    final AdguardHomeClientList captured =
        AdguardHomeClientList.fromJson(clientListJson());
    final AdguardHomeClient laptop = captured.persistent
        .firstWhere((AdguardHomeClient client) => client.name == 'Laptop');

    test('that is new sends every setting, in one request', () async {
      const AdguardHomeClientDraft draft = AdguardHomeClientDraft.blank(
        name: 'Kitchen',
        ids: <String>['10.0.0.4'],
      );

      await actions().saveClient(
        before: const AdguardHomeClientDraft.blank(),
        after: draft,
      );

      expect(sent(), <String>['POST control/clients/add']);
      expect(
        server.single('POST', 'control/clients/add').data,
        adguardHomeNewClient(draft),
      );
    });

    test('that is there reads it again first and writes over that', () async {
      // Since the form was opened, someone gave the client another tag.
      final Map<String, dynamic> fresh = clientListJson();
      ((fresh['clients'] as List<dynamic>)[1] as Map<String, dynamic>)['tags'] =
          <dynamic>['device_laptop', 'os_linux'];
      server.on('GET', 'control/clients', fresh);
      final AdguardHomeClientDraft before = AdguardHomeClientDraft.of(laptop);

      await actions().saveClient(
        originalName: 'Laptop',
        before: before,
        after: before.copyWith(name: 'Old laptop', ignoreQueryLog: true),
      );

      expect(sent(), <String>[
        'GET control/clients',
        'POST control/clients/update',
      ]);
      final Map<String, dynamic> body = server
          .single('POST', 'control/clients/update')
          .data as Map<String, dynamic>;
      // Under the name it has on the server now.
      expect(body['name'], 'Laptop');
      final Map<String, dynamic> data = body['data'] as Map<String, dynamic>;
      expect(data['name'], 'Old laptop');
      expect(data['ignore_querylog'], isTrue);
      expect(data['tags'], <String>['device_laptop', 'os_linux']);
      expect(data['blocked_services_schedule'], <String, dynamic>{
        'time_zone': 'UTC',
      });
    });

    test('that is gone meanwhile writes nothing and says so', () async {
      final AdguardHomeClientDraft before = AdguardHomeClientDraft.of(laptop);

      await expectLater(
        actions().saveClient(
          originalName: 'Renamed elsewhere',
          before: before,
          after: before.copyWith(ignoreQueryLog: true),
        ),
        throwsA(isA<AdguardHomeClientGone>()),
      );

      expect(sent(), <String>['GET control/clients']);
    });

    test('reads the list again behind it', () async {
      await settle(adguardHomeClientsProvider(instance));
      final int before = server.to('GET', 'control/clients').length;

      await actions().saveClient(
        before: const AdguardHomeClientDraft.blank(),
        after: const AdguardHomeClientDraft.blank(
          name: 'Kitchen',
          ids: <String>['10.0.0.4'],
        ),
      );
      await until(
        () => server.to('GET', 'control/clients').length == before + 1,
      );
    });

    test('reads the list again after a refusal too', () async {
      await settle(adguardHomeClientsProvider(instance));
      final int before = server.to('GET', 'control/clients').length;
      server.fail(
        'POST',
        'control/clients/add',
        400,
        'adding client: another client uses the same name "Laptop"',
      );

      await expectLater(
        actions().saveClient(
          before: const AdguardHomeClientDraft.blank(),
          after: const AdguardHomeClientDraft.blank(
            name: 'Laptop',
            ids: <String>['10.0.0.4'],
          ),
        ),
        throwsA(isA<AdguardHomeRequestRefused>()),
      );
      await until(
        () => server.to('GET', 'control/clients').length == before + 1,
      );
    });
  });

  group('deleting a client', () {
    test('sends its name and reads the list again', () async {
      await settle(adguardHomeClientsProvider(instance));
      final int before = server.to('GET', 'control/clients').length;

      await actions().deleteClient('Laptop');

      expect(
        server.single('POST', 'control/clients/delete').data,
        <String, dynamic>{'name': 'Laptop'},
      );
      await until(
        () => server.to('GET', 'control/clients').length == before + 1,
      );
    });
  });

  group('looking one client up', () {
    test('reads the clients and asks whose the address is', () async {
      final AdguardHomeClientLookup lookup =
          await actions().findClient('172.17.0.1', queries: 150);

      expect(sent(), <String>[
        'GET control/clients',
        'POST control/clients/search',
      ]);
      expect(
        server.single('POST', 'control/clients/search').data,
        <String, dynamic>{
          'clients': <Map<String, dynamic>>[
            <String, dynamic>{'id': '172.17.0.1'},
          ],
        },
      );
      expect(lookup.persistent?.name, 'Laptop');
      expect(lookup.queries, 150);
      expect(lookup.supportedTags, hasLength(21));
    });

    test('finds a device a client names by its MAC address', () async {
      // Only the server can tell that the device with this address is the
      // one with that MAC address: nothing the client lists says so.
      final Map<String, dynamic> kids =
          (clientListJson()['clients'] as List<dynamic>).first
              as Map<String, dynamic>;
      server.on('POST', 'control/clients/search', <dynamic>[
        <String, dynamic>{'10.0.0.77': kids},
      ]);

      final AdguardHomeClientLookup lookup =
          await actions().findClient('10.0.0.77');

      expect(lookup.persistent?.name, 'Kids tablet');
    });

    test('says so when the address is nobody\'s', () async {
      final AdguardHomeClientLookup lookup =
          await actions().findClient('10.9.9.9');

      expect(lookup.persistent, isNull);
      expect(lookup.runtime, isNull);
      expect(lookup.title, '10.9.9.9');
    });

    test('matches here on a server that cannot say', () async {
      server.fail('POST', 'control/clients/search', 404, '404 page not found');

      final AdguardHomeClientLookup lookup =
          await actions().findClient('172.17.0.1');

      expect(lookup.persistent?.name, 'Laptop');
    });
  });

  group('once the sign-in is refused', () {
    setUp(() async {
      server.refusing = true;
      await settle(adguardHomeStatusProvider(instance));
      expect(server.requests, hasLength(1));
    });

    test('nothing is sent to save, delete or look up a client', () async {
      const AdguardHomeClientDraft draft = AdguardHomeClientDraft.blank(
        name: 'Kitchen',
        ids: <String>['10.0.0.4'],
      );

      await expectLater(
        actions().saveClient(
          before: const AdguardHomeClientDraft.blank(),
          after: draft,
        ),
        throwsA(isA<AdguardHomeSignInRefused>()),
      );
      await expectLater(
        actions().saveClient(
          originalName: 'Laptop',
          before: draft,
          after: draft,
        ),
        throwsA(isA<AdguardHomeSignInRefused>()),
      );
      await expectLater(
        actions().deleteClient('Laptop'),
        throwsA(isA<AdguardHomeSignInRefused>()),
      );
      await expectLater(
        actions().findClient('172.17.0.1'),
        throwsA(isA<AdguardHomeSignInRefused>()),
      );

      expect(server.requests, hasLength(1));
    });

    test('the tab, the catalogue and the safe search send nothing', () async {
      expect(
        await settle(adguardHomeClientsProvider(instance)),
        isA<AdguardHomeSignInRefused>(),
      );
      expect(
        await settle(adguardHomeServicesProvider(instance)),
        isA<AdguardHomeSignInRefused>(),
      );
      expect(
        await settle(adguardHomeSafeSearchProvider(instance)),
        isA<AdguardHomeSignInRefused>(),
      );

      expect(server.requests, hasLength(1));
    });
  });

  test('says a client is gone in a sentence', () {
    expect(
      describeAdguardHomeError(const AdguardHomeClientGone('Laptop')),
      'The client "Laptop" is no longer on the server. It was renamed or '
      'removed somewhere else.',
    );
  });
}
