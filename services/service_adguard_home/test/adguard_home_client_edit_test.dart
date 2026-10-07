import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

import 'support/adguard_home_clients_fixtures.dart';

void main() {
  late AdguardHomeClientList list;

  AdguardHomeClient named(String name) => list.persistent
      .firstWhere((AdguardHomeClient client) => client.name == name);

  /// A copy of a captured client's object, free to change.
  Map<String, dynamic> copyOf(String name) =>
      jsonDecode(jsonEncode(named(name).json)) as Map<String, dynamic>;

  setUp(() => list = AdguardHomeClientList.fromJson(clientListJson()));

  group('a draft of a client that is there', () {
    test('takes over everything the form shows', () {
      final AdguardHomeClientDraft draft =
          AdguardHomeClientDraft.of(named('Kids tablet'));

      expect(draft.name, 'Kids tablet');
      expect(draft.ids, <String>['192.168.50.0/28', 'aa:bb:cc:dd:ee:01']);
      expect(draft.tags, <String>['device_tablet', 'user_child']);
      expect(draft.useGlobalSettings, isFalse);
      expect(draft.filteringEnabled, isTrue);
      expect(draft.safeBrowsingEnabled, isTrue);
      expect(draft.parentalEnabled, isTrue);
      expect(draft.safeSearch.enabled, isTrue);
      expect(draft.safeSearch.engines['youtube'], isFalse);
      expect(draft.useGlobalBlockedServices, isFalse);
      expect(draft.blockedServices, <String>['tiktok', 'roblox', 'youtube']);
      expect(draft.upstreams, isEmpty);
      expect(draft.upstreamsCacheEnabled, isFalse);
      expect(draft.upstreamsCacheSize, '0');
      expect(draft.ignoreQueryLog, isFalse);
      expect(draft.ignoreStatistics, isFalse);
    });

    test('writes the upstream servers one to a line', () {
      final AdguardHomeClientDraft draft =
          AdguardHomeClientDraft.of(named('Work phone'));

      expect(draft.upstreams, '1.1.1.1\n[/corp.example/]10.0.0.1');
      expect(draft.upstreamsCacheEnabled, isTrue);
      expect(draft.upstreamsCacheSize, '4096');
      expect(draft.ignoreQueryLog, isTrue);
    });

    test('of a client with no identifier still has a row to type in', () {
      final AdguardHomeClientDraft draft = AdguardHomeClientDraft.of(
        const AdguardHomeClient(<String, dynamic>{'name': 'Bare'}),
      );

      expect(draft.ids, <String>['']);
    });
  });

  group('a draft of a new client', () {
    test('uses the global settings and has one empty identifier', () {
      const AdguardHomeClientDraft draft = AdguardHomeClientDraft.blank();

      expect(draft.name, isEmpty);
      expect(draft.ids, <String>['']);
      expect(draft.tags, isEmpty);
      expect(draft.useGlobalSettings, isTrue);
      expect(draft.useGlobalBlockedServices, isTrue);
      expect(draft.filteringEnabled, isFalse);
      expect(draft.blockedServices, isEmpty);
      expect(draft.upstreams, isEmpty);
      expect(draft.upstreamsCacheSize, '0');
    });

    test('starts from the safe search of the server, as the web UI does', () {
      final AdguardHomeClientDraft draft = AdguardHomeClientDraft.blank(
        safeSearch: AdguardHomeSafeSearch.fromJson(safeSearchJson()),
      );

      expect(draft.safeSearch.enabled, isTrue);
      expect(draft.safeSearch.engines, hasLength(7));
    });

    test('can come with a name and an identifier filled in', () {
      const AdguardHomeClientDraft draft = AdguardHomeClientDraft.blank(
        name: 'nas',
        ids: <String>['192.168.1.5'],
      );

      expect(draft.name, 'nas');
      expect(draft.ids, <String>['192.168.1.5']);
    });
  });

  group('what a draft sends', () {
    test('has the name without the spaces around it', () {
      const AdguardHomeClientDraft draft = AdguardHomeClientDraft.blank(
        name: '  Kitchen  ',
        ids: <String>['10.0.0.4'],
      );

      expect(draft.toJson()['name'], 'Kitchen');
    });

    test('has each identifier trimmed, and no empty rows', () {
      final AdguardHomeClientDraft draft =
          const AdguardHomeClientDraft.blank().copyWith(
        ids: <String>[' 10.0.0.4 ', '', '   ', 'aa:bb:cc:dd:ee:02'],
      );

      // The server refuses an identifier with a space before or after it.
      expect(draft.toJson()['ids'], <String>['10.0.0.4', 'aa:bb:cc:dd:ee:02']);
    });

    test('has the upstream servers as a list, without the empty lines', () {
      final AdguardHomeClientDraft draft =
          const AdguardHomeClientDraft.blank().copyWith(
        upstreams: '1.1.1.1\r\n\n  9.9.9.9  \n# a comment\n',
      );

      expect(
        draft.toJson()['upstreams'],
        <String>['1.1.1.1', '9.9.9.9', '# a comment'],
      );
    });

    test('has the cache size as a number, zero for an empty field', () {
      const AdguardHomeClientDraft draft = AdguardHomeClientDraft.blank();

      expect(
        draft.copyWith(upstreamsCacheSize: ' 4096 ').toJson()
            ['upstreams_cache_size'],
        4096,
      );
      expect(
        draft.copyWith(upstreamsCacheSize: '').toJson()['upstreams_cache_size'],
        0,
      );
    });

    test('has safe search in both the forms the server reads', () {
      final AdguardHomeClientDraft draft = AdguardHomeClientDraft.blank(
        safeSearch: AdguardHomeSafeSearch.fromJson(safeSearchJson()),
      );
      final Map<String, dynamic> json = draft.toJson();

      expect(jsonEncode(json['safe_search']), jsonEncode(safeSearchJson()));
      // Servers from before the per-engine switches read only this one.
      expect(json['safesearch_enabled'], isTrue);
    });

    test('has tags and services in one order however they were picked', () {
      const AdguardHomeClientDraft draft = AdguardHomeClientDraft.blank();
      final Map<String, dynamic> one = draft.copyWith(
        tags: <String>['user_child', 'device_tablet'],
        blockedServices: <String>['youtube', 'tiktok'],
      ).toJson();
      final Map<String, dynamic> other = draft.copyWith(
        tags: <String>['device_tablet', 'user_child'],
        blockedServices: <String>['tiktok', 'youtube'],
      ).toJson();

      expect(one['tags'], other['tags']);
      expect(one['blocked_services'], other['blocked_services']);
    });

    test('for a new client spells out every setting', () {
      final Map<String, dynamic> json = adguardHomeNewClient(
        const AdguardHomeClientDraft.blank(
          name: 'Kitchen',
          ids: <String>['10.0.0.4'],
        ),
      );

      // What is left out, the server takes as off: a client added with only
      // a name and an identifier does not use the global settings.
      expect(json['use_global_settings'], isTrue);
      expect(json['use_global_blocked_services'], isTrue);
      expect(
        json.keys,
        containsAll(<String>[
          'name',
          'ids',
          'tags',
          'filtering_enabled',
          'safebrowsing_enabled',
          'parental_enabled',
          'safe_search',
          'blocked_services',
          'upstreams',
          'upstreams_cache_enabled',
          'upstreams_cache_size',
          'ignore_querylog',
          'ignore_statistics',
        ]),
      );
      // As the web UI sends it: the server's own time zone, not UTC.
      expect(json['blocked_services_schedule'], <String, dynamic>{
        'time_zone': 'Local',
      });
    });
  });

  group('what is wrong with a draft', () {
    const AdguardHomeClientDraft good = AdguardHomeClientDraft.blank(
      name: 'Kitchen',
      ids: <String>['10.0.0.4'],
    );

    test('nothing, when it has a name and an identifier', () {
      expect(good.problems.any, isFalse);
    });

    test('no name', () {
      expect(good.copyWith(name: '').problems.name, isNotNull);
      // The server takes a name of spaces as a name.
      expect(good.copyWith(name: '   ').problems.name, isNotNull);
      expect(good.copyWith(name: '   ').problems.any, isTrue);
    });

    test('no identifier', () {
      expect(good.copyWith(ids: <String>[]).problems.ids, isNotNull);
      expect(good.copyWith(ids: <String>['', '  ']).problems.ids, isNotNull);
      expect(good.problems.ids, isNull);
    });

    test('a cache size that is no whole number the server can hold', () {
      for (final String fine in <String>['', '0', '4096', ' 4294967295 ']) {
        expect(
          good.copyWith(upstreamsCacheSize: fine).problems.cacheSize,
          isNull,
          reason: fine,
        );
      }
      for (final String bad in <String>['-1', '4294967296', 'abc', '1.5']) {
        expect(
          good.copyWith(upstreamsCacheSize: bad).problems.cacheSize,
          isNotNull,
          reason: bad,
        );
      }
    });
  });

  group('the client that is written', () {
    test('is the one that was read when nothing was changed', () {
      for (final AdguardHomeClient client in list.persistent) {
        final AdguardHomeClientDraft draft = AdguardHomeClientDraft.of(client);

        expect(
          jsonEncode(
            adguardHomeClientWrite(
              current: client.json,
              before: draft,
              after: draft,
            ),
          ),
          jsonEncode(client.json),
          reason: client.name,
        );
      }
    });

    test('has the one switch that was flipped, and the rest as read', () {
      final AdguardHomeClient kids = named('Kids tablet');
      final AdguardHomeClientDraft before = AdguardHomeClientDraft.of(kids);

      final Map<String, dynamic> written = adguardHomeClientWrite(
        current: kids.json,
        before: before,
        after: before.copyWith(ignoreStatistics: true),
      );

      expect(written['ignore_statistics'], isTrue);
      // The pause schedule is nothing the form shows. Left out of a write,
      // the server would empty it.
      expect(
        jsonEncode(written['blocked_services_schedule']),
        jsonEncode(kids.json['blocked_services_schedule']),
      );
      expect(
        written['blocked_services'],
        <String>['tiktok', 'roblox', 'youtube'],
      );
      final Map<String, dynamic> rest = Map<String, dynamic>.of(written)
        ..remove('ignore_statistics');
      final Map<String, dynamic> wasRest = Map<String, dynamic>.of(kids.json)
        ..remove('ignore_statistics');
      expect(jsonEncode(rest), jsonEncode(wasRest));
    });

    test('keeps a property this app does not know', () {
      final Map<String, dynamic> current = copyOf('Laptop')
        ..['some_future_setting'] = <String, dynamic>{'level': 3};
      final AdguardHomeClientDraft before =
          AdguardHomeClientDraft.of(named('Laptop'));

      final Map<String, dynamic> written = adguardHomeClientWrite(
        current: current,
        before: before,
        after: before.copyWith(name: 'Old laptop'),
      );

      expect(written['name'], 'Old laptop');
      expect(written['some_future_setting'], <String, dynamic>{'level': 3});
    });

    test('keeps what was changed elsewhere while the form was open', () {
      final AdguardHomeClientDraft before =
          AdguardHomeClientDraft.of(named('Laptop'));
      // Someone gave it another tag and its own services in the meantime.
      final Map<String, dynamic> current = copyOf('Laptop')
        ..['tags'] = <dynamic>['device_laptop', 'os_linux']
        ..['use_global_blocked_services'] = false
        ..['blocked_services'] = <dynamic>['netflix'];

      final Map<String, dynamic> written = adguardHomeClientWrite(
        current: current,
        before: before,
        after: before.copyWith(ignoreQueryLog: true),
      );

      expect(written['ignore_querylog'], isTrue);
      expect(written['tags'], <String>['device_laptop', 'os_linux']);
      expect(written['use_global_blocked_services'], isFalse);
      expect(written['blocked_services'], <String>['netflix']);
    });

    test('has what the form changed, whatever was changed elsewhere', () {
      final AdguardHomeClientDraft before =
          AdguardHomeClientDraft.of(named('Laptop'));
      final Map<String, dynamic> current = copyOf('Laptop')
        ..['tags'] = <dynamic>['os_linux'];

      final Map<String, dynamic> written = adguardHomeClientWrite(
        current: current,
        before: before,
        after: before.copyWith(tags: <String>['device_laptop', 'os_windows']),
      );

      expect(written['tags'], <String>['device_laptop', 'os_windows']);
    });

    test('has safe search in both forms when it was changed', () {
      final AdguardHomeClient laptop = named('Laptop');
      final AdguardHomeClientDraft before = AdguardHomeClientDraft.of(laptop);

      final Map<String, dynamic> written = adguardHomeClientWrite(
        current: laptop.json,
        before: before,
        after: before.copyWith(
          useGlobalSettings: false,
          safeSearch: before.safeSearch
              .copyWith(enabled: true)
              .withEngine('google', on: true),
        ),
      );

      expect(written['use_global_settings'], isFalse);
      expect(written['safesearch_enabled'], isTrue);
      final Map<String, dynamic> safe =
          written['safe_search'] as Map<String, dynamic>;
      expect(safe['enabled'], isTrue);
      expect(safe['google'], isTrue);
      expect(safe['bing'], isFalse);
    });

    test('leaves the object it was built on as it was', () {
      final Map<String, dynamic> current = copyOf('Laptop');
      final String was = jsonEncode(current);
      final AdguardHomeClientDraft before =
          AdguardHomeClientDraft.of(named('Laptop'));

      adguardHomeClientWrite(
        current: current,
        before: before,
        after: before.copyWith(name: 'Renamed', tags: <String>[]),
      );

      expect(jsonEncode(current), was);
    });

    test('does not write tags or services for being picked in another order',
        () {
      final AdguardHomeClient kids = named('Kids tablet');
      final AdguardHomeClientDraft before = AdguardHomeClientDraft.of(kids);

      final Map<String, dynamic> written = adguardHomeClientWrite(
        current: kids.json,
        before: before,
        // Taken off and put back: the same set, in another order.
        after: before.copyWith(
          blockedServices: <String>['youtube', 'tiktok', 'roblox'],
          tags: <String>['user_child', 'device_tablet'],
        ),
      );

      // Still in the order the server has them.
      expect(
        written['blocked_services'],
        <String>['tiktok', 'roblox', 'youtube'],
      );
      expect(written['tags'], <String>['device_tablet', 'user_child']);
    });
  });

  group('the persistent client something belongs to', () {
    AdguardHomeClient? owning(String id) =>
        adguardHomeClientOwning(list.persistent, id);

    test('is the one that lists it', () {
      expect(owning('172.17.0.1')?.name, 'Laptop');
      expect(owning('work-phone')?.name, 'Work phone');
    });

    test('whatever the case it is written in', () {
      expect(owning('AA:BB:CC:DD:EE:01')?.name, 'Kids tablet');
      expect(owning('Work-Phone')?.name, 'Work phone');
    });

    test('or the one with a range it is inside', () {
      expect(owning('192.168.50.0')?.name, 'Kids tablet');
      expect(owning('192.168.50.15')?.name, 'Kids tablet');
      expect(owning('192.168.50.16'), isNull);
      expect(owning('192.168.49.255'), isNull);
    });

    test('is nobody for an address no client has', () {
      expect(owning('10.9.9.9'), isNull);
      expect(owning('2001:db8::1'), isNull);
      expect(owning('not an address'), isNull);
      expect(owning(''), isNull);
    });

    List<AdguardHomeClient> clients(Map<String, List<String>> ids) =>
        <AdguardHomeClient>[
          for (final MapEntry<String, List<String>> entry in ids.entries)
            AdguardHomeClient(
              <String, dynamic>{'name': entry.key, 'ids': entry.value},
            ),
        ];

    test('the one that lists it comes before one with a range around it', () {
      final List<AdguardHomeClient> two = clients(<String, List<String>>{
        'Guests': <String>['10.0.0.0/8'],
        'Printer': <String>['10.0.0.7'],
      });

      expect(adguardHomeClientOwning(two, '10.0.0.7')?.name, 'Printer');
      expect(adguardHomeClientOwning(two, '10.0.0.8')?.name, 'Guests');
    });

    test('of two ranges the narrower one has it, as on the server', () {
      final List<AdguardHomeClient> two = clients(<String, List<String>>{
        'Everything': <String>['10.0.0.0/8'],
        'Lab': <String>['10.1.0.0/16'],
      });

      expect(adguardHomeClientOwning(two, '10.1.2.3')?.name, 'Lab');
      expect(adguardHomeClientOwning(two, '10.2.2.3')?.name, 'Everything');
    });

    test('ranges of the newer kind of address work too', () {
      final List<AdguardHomeClient> one = clients(<String, List<String>>{
        'Lab': <String>['2001:db8:1::/48'],
      });

      expect(adguardHomeClientOwning(one, '2001:db8:1::5')?.name, 'Lab');
      expect(adguardHomeClientOwning(one, '2001:DB8:1:ffff::1')?.name, 'Lab');
      expect(adguardHomeClientOwning(one, '2001:db8:2::5'), isNull);
      // An address of the older kind is in no range of the newer.
      expect(adguardHomeClientOwning(one, '10.0.0.1'), isNull);
      // The part after a percent sign names an interface, not the address.
      expect(adguardHomeClientOwning(one, '2001:db8:1::5%eth0')?.name, 'Lab');
    });

    test('a range that cannot be read holds nothing, and throws nothing', () {
      final List<AdguardHomeClient> odd = clients(<String, List<String>>{
        'A': <String>['10.0.0.0/99'],
        'B': <String>['10.0.0.0/x'],
        'C': <String>['nonsense/8'],
        'D': <String>['10.0.0.0/-1'],
        'E': <String>['/'],
      });

      expect(adguardHomeClientOwning(odd, '10.0.0.1'), isNull);
    });

    test('a range of no bits holds every address of its kind', () {
      final List<AdguardHomeClient> all = clients(<String, List<String>>{
        'All': <String>['0.0.0.0/0'],
      });

      expect(adguardHomeClientOwning(all, '203.0.113.9')?.name, 'All');
      expect(adguardHomeClientOwning(all, '2001:db8::1'), isNull);
    });

    test('a range that ends inside a byte is cut at the right bit', () {
      final List<AdguardHomeClient> one = clients(<String, List<String>>{
        'Half': <String>['192.168.1.128/25'],
      });

      expect(adguardHomeClientOwning(one, '192.168.1.128')?.name, 'Half');
      expect(adguardHomeClientOwning(one, '192.168.1.255')?.name, 'Half');
      expect(adguardHomeClientOwning(one, '192.168.1.127'), isNull);
    });
  });

  group('two JSON values', () {
    test('are the same when they hold the same, however deep', () {
      expect(
        adguardHomeJsonEquals(
          <String, dynamic>{
            'a': <dynamic>[1, 'x', null],
            'b': <String, dynamic>{'c': true},
          },
          <String, dynamic>{
            'b': <String, dynamic>{'c': true},
            'a': <dynamic>[1, 'x', null],
          },
        ),
        isTrue,
      );
    });

    test('differ by a value, a length, a key or an order of a list', () {
      expect(adguardHomeJsonEquals(<dynamic>[1, 2], <dynamic>[2, 1]), isFalse);
      expect(adguardHomeJsonEquals(<dynamic>[1], <dynamic>[1, 2]), isFalse);
      expect(
        adguardHomeJsonEquals(
          <String, dynamic>{'a': 1},
          <String, dynamic>{'b': 1},
        ),
        isFalse,
      );
      expect(
        adguardHomeJsonEquals(
          <String, dynamic>{'a': 1},
          <String, dynamic>{'a': 1, 'b': null},
        ),
        isFalse,
      );
      expect(adguardHomeJsonEquals('1', 1), isFalse);
      expect(adguardHomeJsonEquals(null, <dynamic>[]), isFalse);
    });
  });
}
