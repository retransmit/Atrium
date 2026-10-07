import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

import 'support/adguard_home_clients_fixtures.dart';

void main() {
  late AdguardHomeClientList list;
  late Map<String, AdguardHomeFoundClient> found;

  setUp(() {
    list = AdguardHomeClientList.fromJson(clientListJson());
    found = AdguardHomeFoundClient.mapFromJson(clientSearchJson());
  });

  AdguardHomeClientList listOf(
    Map<String, List<String>> persistent, [
    List<String> runtime = const <String>[],
  ]) =>
      AdguardHomeClientList.fromJson(<String, dynamic>{
        'clients': <dynamic>[
          for (final MapEntry<String, List<String>> entry in persistent.entries)
            <String, dynamic>{'name': entry.key, 'ids': entry.value},
        ],
        'auto_clients': <dynamic>[
          for (final String address in runtime)
            <String, dynamic>{'ip': address, 'name': '', 'source': 'ARP'},
        ],
      });

  AdguardHomePersistentRow row(AdguardHomeClientsView view, String name) =>
      view.persistent.firstWhere(
        (AdguardHomePersistentRow row) => row.client.name == name,
      );

  AdguardHomeRuntimeRow at(AdguardHomeClientsView view, String address) =>
      view.runtime.firstWhere(
        (AdguardHomeRuntimeRow row) => row.client.address == address,
      );

  group('the clients with their queries', () {
    test('as the server answered: counts from the top clients', () {
      final AdguardHomeClientsView view = AdguardHomeClientsView.build(
        list: list,
        topClients: const <AdguardHomeCount>[
          AdguardHomeCount('172.17.0.1', 150),
          AdguardHomeCount('127.0.0.1', 122),
        ],
        found: found,
      );

      expect(row(view, 'Laptop').queries, 150);
      expect(row(view, 'Kids tablet').queries, isNull);
      expect(row(view, 'Work phone').queries, isNull);
      expect(at(view, '127.0.0.1').queries, 122);
      expect(at(view, '127.0.0.1').owner, isNull);
      // The address is Laptop's and a runtime client both.
      expect(at(view, '172.17.0.1').queries, 150);
      expect(at(view, '172.17.0.1').owner, 'Laptop');
      expect(at(view, '::1').queries, isNull);
      expect(view.supportedTags, hasLength(21));
    });

    test('adds up what a client asked under each thing it goes by', () {
      final AdguardHomeClientsView view = AdguardHomeClientsView.build(
        list: list,
        topClients: const <AdguardHomeCount>[
          AdguardHomeCount('192.168.50.3', 40),
          AdguardHomeCount('aa:bb:cc:dd:ee:01', 2),
          AdguardHomeCount('work-phone', 7),
        ],
        found: found,
      );

      expect(row(view, 'Kids tablet').queries, 42);
      expect(row(view, 'Work phone').queries, 7);
    });

    test('on a server that cannot look clients up, by matching ids here', () {
      final AdguardHomeClientsView view = AdguardHomeClientsView.build(
        list: list,
        topClients: const <AdguardHomeCount>[
          AdguardHomeCount('172.17.0.1', 150),
          AdguardHomeCount('192.168.50.3', 40),
          AdguardHomeCount('work-phone', 7),
          AdguardHomeCount('10.9.9.9', 3),
        ],
      );

      expect(row(view, 'Laptop').queries, 150);
      // Inside its range.
      expect(row(view, 'Kids tablet').queries, 40);
      expect(row(view, 'Work phone').queries, 7);
      expect(at(view, '172.17.0.1').owner, 'Laptop');
    });

    test('takes the server\'s word that an address is nobody\'s', () {
      // Matched here it would be Kids tablet's: it is inside the range.
      final AdguardHomeClientsView view = AdguardHomeClientsView.build(
        list: list,
        topClients: const <AdguardHomeCount>[
          AdguardHomeCount('192.168.50.4', 9),
        ],
        found: const <String, AdguardHomeFoundClient>{
          '192.168.50.4': AdguardHomeFoundClient(
            id: '192.168.50.4',
            ids: <String>['192.168.50.4'],
          ),
        },
      );

      expect(row(view, 'Kids tablet').queries, isNull);
    });

    test('a runtime client is not a persistent one for sharing its name', () {
      final AdguardHomeClientsView view = AdguardHomeClientsView.build(
        list: listOf(
          <String, List<String>>{
            'nas': <String>['192.168.1.5'],
          },
          <String>['192.168.1.9'],
        ),
        topClients: const <AdguardHomeCount>[
          AdguardHomeCount('192.168.1.9', 30),
        ],
        // What the server says of a runtime client that reverse DNS also
        // calls "nas".
        found: const <String, AdguardHomeFoundClient>{
          '192.168.1.9': AdguardHomeFoundClient(
            id: '192.168.1.9',
            name: 'nas',
            ids: <String>['192.168.1.9'],
          ),
        },
      );

      expect(row(view, 'nas').queries, isNull);
      expect(at(view, '192.168.1.9').owner, isNull);
      expect(at(view, '192.168.1.9').queries, 30);
    });

    test('with no clients at all is empty', () {
      final AdguardHomeClientsView view = AdguardHomeClientsView.build(
        list: const AdguardHomeClientList(),
      );

      expect(view.persistent, isEmpty);
      expect(view.runtime, isEmpty);
    });
  });

  group('the order', () {
    test('of persistent clients: most queries first, then by name', () {
      final AdguardHomeClientsView view = AdguardHomeClientsView.build(
        list: listOf(<String, List<String>>{
          'zebra': <String>['10.0.0.1'],
          'Beta': <String>['10.0.0.2'],
          'alpha': <String>['10.0.0.3'],
          'Busy': <String>['10.0.0.4'],
          'Quiet': <String>['10.0.0.5'],
        }),
        topClients: const <AdguardHomeCount>[
          AdguardHomeCount('10.0.0.4', 90),
          AdguardHomeCount('10.0.0.5', 5),
        ],
      );

      expect(
        view.persistent.map((AdguardHomePersistentRow row) => row.client.name),
        // Those the statistics say nothing of come last, by name, and a
        // capital letter does not come before the small ones.
        <String>['Busy', 'Quiet', 'alpha', 'Beta', 'zebra'],
      );
    });

    test('of runtime clients: most queries first, then by address', () {
      final AdguardHomeClientsView view = AdguardHomeClientsView.build(
        list: listOf(
          const <String, List<String>>{},
          <String>[
            '10.0.0.10',
            '::1',
            '10.0.0.9',
            '192.168.1.1',
            '10.0.0.200',
            'fe80::2',
          ],
        ),
        topClients: const <AdguardHomeCount>[
          AdguardHomeCount('192.168.1.1', 4),
        ],
      );

      expect(
        view.runtime.map((AdguardHomeRuntimeRow row) => row.client.address),
        // By the number, not the spelling: .9 before .10, and the older
        // kind of address before the newer.
        <String>[
          '192.168.1.1',
          '10.0.0.9',
          '10.0.0.10',
          '10.0.0.200',
          '::1',
          'fe80::2',
        ],
      );
    });
  });

  group('one client, looked up', () {
    test('that is persistent', () {
      final AdguardHomeClientLookup lookup = AdguardHomeClientLookup.of(
        address: '172.17.0.1',
        list: list,
        found: found['172.17.0.1'],
        queries: 150,
      );

      expect(lookup.persistent?.name, 'Laptop');
      // It is a runtime client too, and the sheet says where it was seen.
      expect(lookup.runtime?.source, 'ARP');
      expect(lookup.queries, 150);
      expect(lookup.supportedTags, hasLength(21));
      expect(lookup.title, 'Laptop');
    });

    test('that the server knows only as a runtime client', () {
      final AdguardHomeClientLookup lookup = AdguardHomeClientLookup.of(
        address: '127.0.0.1',
        list: list,
        found: found['127.0.0.1'],
      );

      expect(lookup.persistent, isNull);
      expect(lookup.runtime?.name, 'localhost');
      expect(lookup.title, 'localhost');
      expect(lookup.queries, isNull);
    });

    test('that nobody knows', () {
      final AdguardHomeClientLookup lookup = AdguardHomeClientLookup.of(
        address: '10.9.9.9',
        list: list,
      );

      expect(lookup.persistent, isNull);
      expect(lookup.runtime, isNull);
      expect(lookup.title, '10.9.9.9');
    });

    test('found by its MAC address or inside its range', () {
      expect(
        AdguardHomeClientLookup.of(
          address: '192.168.50.3',
          list: list,
          found: found['192.168.50.3'],
        ).persistent?.name,
        'Kids tablet',
      );
      // Without the server's word, the range still tells.
      expect(
        AdguardHomeClientLookup.of(address: '192.168.50.3', list: list)
            .persistent
            ?.name,
        'Kids tablet',
      );
    });

    test('takes the name and WHOIS the lookup found for an address that is '
        'not in the list', () {
      final AdguardHomeClientLookup lookup = AdguardHomeClientLookup.of(
        address: '198.51.100.4',
        list: list,
        found: const AdguardHomeFoundClient(
          id: '198.51.100.4',
          name: 'edge.example',
          ids: <String>['198.51.100.4'],
          whois: <String, String>{'orgname': 'Net AS'},
        ),
      );

      expect(lookup.persistent, isNull);
      expect(lookup.runtime?.name, 'edge.example');
      expect(lookup.runtime?.whoisLine, 'Net AS');
      expect(lookup.title, 'edge.example');
    });
  });
}
