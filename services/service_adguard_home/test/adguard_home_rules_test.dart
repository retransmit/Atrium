import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

void main() {
  const String block = r'||ads.example^$important';
  const String allow = r'@@||ads.example^$important';

  test('blocking a domain adds the rule the web UI adds', () {
    final AdguardHomeRuleEdit edit = adguardHomeBlockingEdit(
      <String>['||other.example^'],
      'ads.example',
      block: true,
    );

    expect(edit.change, AdguardHomeRuleChange.added);
    expect(edit.rule, block);
    expect(edit.rules, <String>['||other.example^', block]);
  });

  test('blocking a domain that was allowed takes the allow rule away', () {
    // The web UI does not stack a block on top of an allow: it undoes the
    // allow and leaves the lists to decide.
    final AdguardHomeRuleEdit edit = adguardHomeBlockingEdit(
      <String>[allow, '||other.example^'],
      'ads.example',
      block: true,
    );

    expect(edit.change, AdguardHomeRuleChange.removed);
    expect(edit.rule, allow);
    expect(edit.rules, <String>['||other.example^']);
  });

  test('unblocking adds the allow rule', () {
    final AdguardHomeRuleEdit edit =
        adguardHomeBlockingEdit(<String>[], 'ads.example', block: false);

    expect(edit.change, AdguardHomeRuleChange.added);
    expect(edit.rule, allow);
    expect(edit.rules, <String>[allow]);
  });

  test('unblocking a domain blocked by a custom rule takes that rule away',
      () {
    final AdguardHomeRuleEdit edit =
        adguardHomeBlockingEdit(<String>[block], 'ads.example', block: false);

    expect(edit.change, AdguardHomeRuleChange.removed);
    expect(edit.rule, block);
    expect(edit.rules, isEmpty);
  });

  test('asking twice changes nothing the second time', () {
    final AdguardHomeRuleEdit edit =
        adguardHomeBlockingEdit(<String>[block], 'ads.example', block: true);

    expect(edit.change, AdguardHomeRuleChange.alreadyThere);
    expect(edit.rules, <String>[block]);
  });

  test('only the exact rule counts, not one that merely mentions the domain',
      () {
    final AdguardHomeRuleEdit edit = adguardHomeBlockingEdit(
      <String>['||sub.ads.example^\$important', '||ads.example^'],
      'ads.example',
      block: true,
    );

    expect(edit.change, AdguardHomeRuleChange.added);
    expect(edit.rules.last, block);
    expect(edit.rules, hasLength(3));
  });

  test('the list handed in is left as it was', () {
    final List<String> rules = <String>[allow];
    adguardHomeBlockingEdit(rules, 'ads.example', block: true);

    expect(rules, <String>[allow]);
  });

  group('for one client only', () {
    const String blockFor = r"||ads.example^$client='Laptop'";
    const String allowFor = r"@@||ads.example^$client='Laptop'";

    test('blocking writes the rule with the client in it', () {
      // The web UI's rule for one client. It carries no $important.
      final AdguardHomeRuleEdit edit = adguardHomeBlockingEdit(
        <String>[block],
        'ads.example',
        block: true,
        client: 'Laptop',
      );

      expect(edit.change, AdguardHomeRuleChange.added);
      expect(edit.rule, blockFor);
      expect(edit.rules, <String>[block, blockFor]);
    });

    test('unblocking writes the exception with the client in it', () {
      final AdguardHomeRuleEdit edit = adguardHomeBlockingEdit(
        const <String>[],
        'ads.example',
        block: false,
        client: 'Laptop',
      );

      expect(edit.change, AdguardHomeRuleChange.added);
      expect(edit.rule, allowFor);
    });

    test('unblocking what was blocked for the client takes that rule away',
        () {
      // The rule for everyone is a different line and is left alone.
      final AdguardHomeRuleEdit edit = adguardHomeBlockingEdit(
        <String>[block, blockFor],
        'ads.example',
        block: false,
        client: 'Laptop',
      );

      expect(edit.change, AdguardHomeRuleChange.removed);
      expect(edit.rule, blockFor);
      expect(edit.rules, <String>[block]);
    });

    test('a name with a quote, a comma or a bar in it is escaped', () {
      // The four characters that would end the name early inside a rule
      // each get a backslash, as the web UI gives them.
      final AdguardHomeRuleEdit edit = adguardHomeBlockingEdit(
        const <String>[],
        'ads.example',
        block: true,
        client: 'Tom\'s "big", box|1',
      );

      expect(
        edit.rule,
        '||ads.example^\$client=\'Tom\\\'s \\"big\\"\\, box\\|1\'',
      );
    });

    test('an address is written as it is', () {
      final AdguardHomeRuleEdit edit = adguardHomeBlockingEdit(
        const <String>[],
        'ads.example',
        block: true,
        client: '192.168.1.40',
      );

      expect(edit.rule, r"||ads.example^$client='192.168.1.40'");
    });
  });

  group('the name a rule calls a client by', () {
    const List<AdguardHomeClientRef> clients = <AdguardHomeClientRef>[
      AdguardHomeClientRef(
        name: 'Laptop',
        ids: <String>['aa:bb:cc:dd:ee:ff', '172.17.0.1'],
      ),
      AdguardHomeClientRef(name: 'Guests', ids: <String>['192.168.50.0/24']),
    ];

    test('is the name of the client that has the address among its ids', () {
      expect(adguardHomeBlockingClientName(clients, '172.17.0.1'), 'Laptop');
    });

    test('is the address itself for one the server has no settings for', () {
      expect(
        adguardHomeBlockingClientName(clients, '192.168.1.40'),
        '192.168.1.40',
      );
      // An address inside a range is not that range, as in the web UI.
      expect(
        adguardHomeBlockingClientName(clients, '192.168.50.7'),
        '192.168.50.7',
      );
    });
  });

  group('shutting a client out or letting it back in', () {
    const List<String> hosts = <String>['version.bind', 'id.server'];

    test('adds it to the disallowed clients', () {
      final AdguardHomeAccessList next = adguardHomeClientAccessEdit(
        const AdguardHomeAccessList(
          disallowedClients: <String>['10.0.0.9'],
          blockedHosts: hosts,
        ),
        address: '172.17.0.1',
        disallowed: false,
        disallowedRule: '172.17.0.1',
      );

      expect(next.disallowedClients, <String>['10.0.0.9', '172.17.0.1']);
      expect(next.allowedClients, isEmpty);
      // The server replaces all three lists, so this one goes back whole.
      expect(next.blockedHosts, hosts);
    });

    test('does not add it twice', () {
      final AdguardHomeAccessList next = adguardHomeClientAccessEdit(
        const AdguardHomeAccessList(
          disallowedClients: <String>['172.17.0.1'],
        ),
        address: '172.17.0.1',
        disallowed: false,
        disallowedRule: '',
      );

      expect(next.disallowedClients, <String>['172.17.0.1']);
    });

    test('lets it back in by removing the entry that shut it out', () {
      // That entry can be a range the address falls in.
      final AdguardHomeAccessList next = adguardHomeClientAccessEdit(
        const AdguardHomeAccessList(
          disallowedClients: <String>['172.17.0.0/16', '10.0.0.9'],
          blockedHosts: hosts,
        ),
        address: '172.17.0.1',
        disallowed: true,
        disallowedRule: '172.17.0.0/16',
      );

      expect(next.disallowedClients, <String>['10.0.0.9']);
      expect(next.blockedHosts, hosts);
    });

    test('with no entry named, removes the address itself', () {
      final AdguardHomeAccessList next = adguardHomeClientAccessEdit(
        const AdguardHomeAccessList(
          disallowedClients: <String>['172.17.0.1'],
        ),
        address: '172.17.0.1',
        disallowed: true,
        disallowedRule: '',
      );

      expect(next.disallowedClients, isEmpty);
    });

    group('while only the allowed clients are answered', () {
      const AdguardHomeAccessList allowlist = AdguardHomeAccessList(
        allowedClients: <String>['127.0.0.1', '172.17.0.1'],
        blockedHosts: hosts,
      );

      test('shutting one out takes it off the allowed clients', () {
        final AdguardHomeAccessList next = adguardHomeClientAccessEdit(
          allowlist,
          address: '172.17.0.1',
          disallowed: false,
          disallowedRule: '172.17.0.1',
        );

        expect(next.allowedClients, <String>['127.0.0.1']);
        expect(next.disallowedClients, isEmpty);
        expect(next.blockedHosts, hosts);
      });

      test('letting one in puts it on the allowed clients', () {
        final AdguardHomeAccessList next = adguardHomeClientAccessEdit(
          allowlist,
          address: '192.168.1.40',
          disallowed: true,
          disallowedRule: '',
        );

        expect(
          next.allowedClients,
          <String>['127.0.0.1', '172.17.0.1', '192.168.1.40'],
        );
        expect(next.disallowedClients, isEmpty);
      });
    });

    test('the last allowed client cannot be shut out this way', () {
      // Taking it off would empty the list, and an empty list allows
      // everyone: the opposite of what was asked.
      const AdguardHomeAccessList only = AdguardHomeAccessList(
        allowedClients: <String>['172.17.0.1'],
      );

      expect(
        adguardHomeIsLastAllowedClient(only, '172.17.0.1', disallowed: false),
        isTrue,
      );
      expect(
        adguardHomeIsLastAllowedClient(only, '10.0.0.9', disallowed: true),
        isFalse,
      );
      expect(
        adguardHomeIsLastAllowedClient(
          const AdguardHomeAccessList(
            allowedClients: <String>['172.17.0.1', '10.0.0.9'],
          ),
          '172.17.0.1',
          disallowed: false,
        ),
        isFalse,
      );
      expect(
        adguardHomeIsLastAllowedClient(
          const AdguardHomeAccessList(),
          '172.17.0.1',
          disallowed: false,
        ),
        isFalse,
      );
    });
  });
}
