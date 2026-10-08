import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

import 'support/adguard_home_clients_fixtures.dart';

void main() {
  late AdguardHomeClientList list;

  AdguardHomeClient named(String name) => list.persistent
      .firstWhere((AdguardHomeClient client) => client.name == name);

  AdguardHomeRuntimeClient at(String address) => list.runtime.firstWhere(
        (AdguardHomeRuntimeClient client) => client.address == address,
      );

  /// The first captured client, as the server would send it with [changes]
  /// applied.
  AdguardHomeClient parse(Map<String, dynamic> changes) {
    final Map<String, dynamic> json = Map<String, dynamic>.of(
      (clientListJson()['clients'] as List<dynamic>).first
          as Map<String, dynamic>,
    )..addAll(changes);
    return AdguardHomeClient(json);
  }

  setUp(() => list = AdguardHomeClientList.fromJson(clientListJson()));

  group('the list of clients', () {
    test('reads the persistent clients, the runtime ones and the tags', () {
      expect(
        list.persistent.map((AdguardHomeClient client) => client.name),
        <String>['Kids tablet', 'Laptop', 'Work phone'],
      );
      expect(list.runtime, hasLength(9));
      expect(list.supportedTags, hasLength(21));
      expect(list.supportedTags.first, 'device_audio');
    });

    test('null where a list is meant reads as none', () {
      // The server sends null for clients when there are none.
      final AdguardHomeClientList empty = AdguardHomeClientList.fromJson(
        <String, dynamic>{
          'clients': null,
          'auto_clients': null,
          'supported_tags': null,
        },
      );

      expect(empty.persistent, isEmpty);
      expect(empty.runtime, isEmpty);
      expect(empty.supportedTags, isEmpty);
    });

    test('an entry that is not an object is passed over', () {
      final AdguardHomeClientList odd = AdguardHomeClientList.fromJson(
        <String, dynamic>{
          'clients': <dynamic>['nonsense', 7, null],
          'auto_clients': <dynamic>['nonsense'],
        },
      );

      expect(odd.persistent, isEmpty);
      expect(odd.runtime, isEmpty);
    });
  });

  group('a persistent client', () {
    test('with everything of its own', () {
      final AdguardHomeClient kids = named('Kids tablet');

      expect(kids.ids, <String>['192.168.50.0/28', 'aa:bb:cc:dd:ee:01']);
      expect(kids.tags, <String>['device_tablet', 'user_child']);
      expect(kids.useGlobalSettings, isFalse);
      expect(kids.filteringEnabled, isTrue);
      expect(kids.safeBrowsingEnabled, isTrue);
      expect(kids.parentalEnabled, isTrue);
      expect(kids.useGlobalBlockedServices, isFalse);
      // In the order they were saved, which is not the alphabet's.
      expect(kids.blockedServices, <String>['tiktok', 'roblox', 'youtube']);
      expect(kids.upstreams, isEmpty);
      expect(kids.ignoreQueryLog, isFalse);
      expect(kids.ignoreStatistics, isFalse);
    });

    test('reads safe search with its engines in the server\'s order', () {
      final AdguardHomeSafeSearch safe = named('Kids tablet').safeSearch;

      expect(safe.enabled, isTrue);
      expect(safe.engines.keys, <String>[
        'bing',
        'duckduckgo',
        'ecosia',
        'google',
        'pixabay',
        'yandex',
        'youtube',
      ]);
      expect(safe.engines['google'], isTrue);
      expect(safe.engines['youtube'], isFalse);
    });

    test('reads the times service blocking pauses, Monday first', () {
      final AdguardHomeClient kids = named('Kids tablet');

      expect(kids.pauseTimeZone, 'Europe/Berlin');
      expect(
        kids.pauses.map((AdguardHomeServicePause pause) => pause.day),
        <String>['sat', 'sun'],
      );
      expect(kids.pauses.first.start, const Duration(hours: 9));
      expect(kids.pauses.first.end, const Duration(hours: 17));
    });

    test('that uses the global settings: null lists read as empty', () {
      final AdguardHomeClient laptop = named('Laptop');

      expect(laptop.ids, <String>['172.17.0.1']);
      expect(laptop.useGlobalSettings, isTrue);
      expect(laptop.useGlobalBlockedServices, isTrue);
      expect(laptop.blockedServices, isEmpty);
      expect(laptop.upstreams, isEmpty);
      expect(laptop.safeSearch.enabled, isFalse);
      expect(laptop.pauses, isEmpty);
      expect(laptop.pauseTimeZone, 'UTC');
    });

    test('with upstream servers of its own', () {
      final AdguardHomeClient work = named('Work phone');

      expect(work.ids, <String>['work-phone']);
      expect(work.upstreams, <String>['1.1.1.1', '[/corp.example/]10.0.0.1']);
      expect(work.upstreamsCacheEnabled, isTrue);
      expect(work.upstreamsCacheSize, 4096);
      expect(work.ignoreQueryLog, isTrue);
    });

    test('keeps what the server sent, to send it back', () {
      final Map<String, dynamic> sent =
          (clientListJson()['clients'] as List<dynamic>).first
              as Map<String, dynamic>;

      expect(jsonEncode(named('Kids tablet').json), jsonEncode(sent));
    });

    test('without a safe search object reads the older switch', () {
      final AdguardHomeClient old = parse(<String, dynamic>{
        'safe_search': null,
        'safesearch_enabled': true,
      });

      expect(old.safeSearch.enabled, isTrue);
      expect(old.safeSearch.engines, isEmpty);
    });

    test('with nothing but a name is read, not thrown', () {
      const AdguardHomeClient bare =
          AdguardHomeClient(<String, dynamic>{'name': 'Bare'});

      expect(bare.name, 'Bare');
      expect(bare.ids, isEmpty);
      expect(bare.tags, isEmpty);
      expect(bare.useGlobalSettings, isFalse);
      expect(bare.safeSearch.enabled, isFalse);
      expect(bare.blockedServices, isEmpty);
      expect(bare.upstreamsCacheSize, 0);
      expect(bare.pauses, isEmpty);
      expect(bare.pauseTimeZone, isEmpty);
    });

    test('a pause that is not a pair of times is passed over', () {
      final AdguardHomeClient odd = parse(<String, dynamic>{
        'blocked_services_schedule': <String, dynamic>{
          'time_zone': 'UTC',
          'mon': 'all day',
          'tue': <String, dynamic>{'start': 0},
          'wed': <String, dynamic>{'start': 3600000, 'end': 7200000},
        },
      });

      expect(
        odd.pauses.map((AdguardHomeServicePause pause) => pause.day),
        <String>['wed'],
      );
    });
  });

  group('a runtime client', () {
    test('reads its address, its name and where it was learned', () {
      final AdguardHomeRuntimeClient local = at('127.0.0.1');

      expect(local.name, 'localhost');
      expect(local.source, 'etc/hosts');
      expect(local.whois, isEmpty);
      expect(local.whoisLine, isEmpty);
    });

    test('can have no name', () {
      expect(at('172.17.0.1').name, isEmpty);
      expect(at('172.17.0.1').source, 'ARP');
    });

    test('says who the address belongs to, where the server knows', () {
      final AdguardHomeRuntimeClient outside = at('203.0.113.9');

      expect(outside.whois, <String, String>{
        'orgname': 'Example Networks',
        'country': 'DE',
        'city': 'Berlin',
      });
      expect(outside.whoisLine, 'Example Networks, DE, Berlin');
    });

    test('with no WHOIS at all is read, not thrown', () {
      final AdguardHomeRuntimeClient bare = AdguardHomeRuntimeClient.fromJson(
        <String, dynamic>{'ip': '10.0.0.9'},
      );

      expect(bare.address, '10.0.0.9');
      expect(bare.name, isEmpty);
      expect(bare.source, isEmpty);
      expect(bare.whois, isEmpty);
    });

    test('puts what else WHOIS says after the owner and the place', () {
      final AdguardHomeRuntimeClient client = AdguardHomeRuntimeClient.fromJson(
        <String, dynamic>{
          'ip': '198.51.100.4',
          'whois_info': <String, dynamic>{
            'descr': 'Transit',
            'city': 'Oslo',
            'orgname': 'Net AS',
            'ignored': 7,
          },
        },
      );

      expect(client.whoisLine, 'Net AS, Oslo, Transit');
    });
  });

  group('clients looked up by what they go by', () {
    late Map<String, AdguardHomeFoundClient> found;

    setUp(() => found = AdguardHomeFoundClient.mapFromJson(clientSearchJson()));

    test('are keyed by what was asked for', () {
      expect(found.keys, <String>[
        '172.17.0.1',
        '127.0.0.1',
        'aa:bb:cc:dd:ee:01',
        'work-phone',
        '192.168.50.3',
        '203.0.113.9',
      ]);
    });

    test('a persistent client comes with its name and all its ids', () {
      expect(found['172.17.0.1']!.name, 'Laptop');
      expect(found['172.17.0.1']!.ids, <String>['172.17.0.1']);
      // Found by its MAC address, and by an address inside its range.
      expect(found['aa:bb:cc:dd:ee:01']!.name, 'Kids tablet');
      expect(found['192.168.50.3']!.name, 'Kids tablet');
      expect(
        found['192.168.50.3']!.ids,
        <String>['192.168.50.0/28', 'aa:bb:cc:dd:ee:01'],
      );
      expect(found['work-phone']!.name, 'Work phone');
    });

    test('a runtime client comes with the name the server has for it', () {
      expect(found['127.0.0.1']!.name, 'localhost');
      expect(found['127.0.0.1']!.ids, <String>['127.0.0.1']);
    });

    test('an address nobody knows comes with no name', () {
      expect(found['203.0.113.9']!.name, isEmpty);
      expect(found['203.0.113.9']!.ids, <String>['203.0.113.9']);
      expect(found['203.0.113.9']!.disallowed, isFalse);
    });

    test('an answer that is not a list reads as nothing found', () {
      expect(AdguardHomeFoundClient.mapFromJson(null), isEmpty);
      expect(
        AdguardHomeFoundClient.mapFromJson(<String, dynamic>{'a': 1}),
        isEmpty,
      );
      expect(
        AdguardHomeFoundClient.mapFromJson(<dynamic>['x', 3, null]),
        isEmpty,
      );
    });

    test('says when the client is shut out', () {
      final Map<String, AdguardHomeFoundClient> shutOut =
          AdguardHomeFoundClient.mapFromJson(<dynamic>[
        <String, dynamic>{
          '10.0.0.5': <String, dynamic>{
            'name': '',
            'ids': <dynamic>['10.0.0.5'],
            'disallowed': true,
            'disallowed_rule': '10.0.0.0/8',
          },
        },
      ]);

      expect(shutOut['10.0.0.5']!.disallowed, isTrue);
      expect(shutOut['10.0.0.5']!.disallowedRule, '10.0.0.0/8');
    });
  });

  group('safe search', () {
    test('goes back as it came', () {
      final AdguardHomeSafeSearch safe =
          AdguardHomeSafeSearch.fromJson(safeSearchJson());

      expect(safe.enabled, isTrue);
      expect(jsonEncode(safe.toJson()), jsonEncode(safeSearchJson()));
    });

    test('changes one engine and leaves the rest', () {
      final AdguardHomeSafeSearch safe = AdguardHomeSafeSearch.fromJson(
        safeSearchJson(),
      ).withEngine('google', on: false);

      expect(safe.engines['google'], isFalse);
      expect(safe.engines['bing'], isTrue);
      expect(safe.engines.keys.first, 'bing');
      expect(safe.enabled, isTrue);
    });

    test('is turned on and off without touching the engines', () {
      final AdguardHomeSafeSearch safe = AdguardHomeSafeSearch.fromJson(
        safeSearchJson(),
      ).copyWith(enabled: false);

      expect(safe.enabled, isFalse);
      expect(safe.engines['youtube'], isTrue);
    });

    test('that is not an object reads as off, with no engines', () {
      expect(AdguardHomeSafeSearch.fromJson(null).enabled, isFalse);
      expect(AdguardHomeSafeSearch.fromJson('yes').engines, isEmpty);
    });
  });

  group('the catalogue of services', () {
    late AdguardHomeServiceCatalogue catalogue;

    setUp(
      () => catalogue =
          AdguardHomeServiceCatalogue.fromJson(blockedServicesJson()),
    );

    test('reads each service with its name and its group', () {
      expect(
        catalogue.services
            .map((AdguardHomeBlockedService service) => service.id),
        <String>['tiktok', 'youtube', 'roblox', 'netflix', 'meta_ai', 'twitter'],
      );
      final AdguardHomeBlockedService x = catalogue.services.last;
      expect(x.name, 'X (formerly Twitter)');
      expect(x.groupId, 'social_network');
    });

    test('decodes an icon to the SVG it is', () {
      final AdguardHomeBlockedService tiktok = catalogue.services.first;

      expect(utf8.decode(tiktok.icon!), startsWith('<svg '));
    });

    test('keeps the groups in the server\'s order', () {
      expect(catalogue.groups, hasLength(12));
      expect(catalogue.groups.first, 'ai');
      expect(catalogue.groups.last, 'streaming');
    });

    test('gives the services of a group', () {
      expect(
        catalogue
            .inGroup('streaming')
            .map((AdguardHomeBlockedService service) => service.id),
        <String>['youtube', 'netflix'],
      );
      expect(catalogue.inGroup('dating'), isEmpty);
    });

    test('names a service, or gives its id back when it has none', () {
      expect(catalogue.nameOf('tiktok'), 'TikTok');
      expect(catalogue.nameOf('gone_service'), 'gone_service');
    });

    test('lists a service whose icon cannot be decoded, without the icon', () {
      final AdguardHomeServiceCatalogue odd =
          AdguardHomeServiceCatalogue.fromJson(<String, dynamic>{
        'blocked_services': <dynamic>[
          <String, dynamic>{
            'id': 'odd',
            'name': 'Odd',
            'icon_svg': 'not base64 at all!',
            'group_id': 'ai',
          },
          <String, dynamic>{'id': 'bare'},
        ],
      });

      expect(odd.services, hasLength(2));
      expect(odd.services.first.icon, isNull);
      // A service with no name goes by its id, and one with no group has
      // none.
      expect(odd.services.last.name, 'bare');
      expect(odd.services.last.groupId, isEmpty);
      expect(odd.services.last.icon, isNull);
      expect(odd.groups, isEmpty);
    });

    test('with nothing in it is empty, not thrown', () {
      final AdguardHomeServiceCatalogue empty =
          AdguardHomeServiceCatalogue.fromJson(
        <String, dynamic>{'blocked_services': null, 'groups': null},
      );

      expect(empty.services, isEmpty);
      expect(empty.groups, isEmpty);
    });

    test('a service with no id is passed over', () {
      final AdguardHomeServiceCatalogue odd =
          AdguardHomeServiceCatalogue.fromJson(<String, dynamic>{
        'blocked_services': <dynamic>[
          <String, dynamic>{'name': 'Nameless id'},
          'nonsense',
        ],
      });

      expect(odd.services, isEmpty);
    });
  });
}
