import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

import 'support/adguard_home_query_log_fixtures.dart';

void main() {
  late AdguardHomeQueryLogPage page;

  /// The entry of the captured log that asked for [domain].
  AdguardHomeQueryLogEntry entry(String domain) => page.entries
      .firstWhere((AdguardHomeQueryLogEntry entry) => entry.domain == domain);

  /// One entry, as the server would send it with [changes] applied.
  AdguardHomeQueryLogEntry parse(Map<String, dynamic> changes) {
    final Map<String, dynamic> json = Map<String, dynamic>.of(
      (queryLogJson()['data'] as List<dynamic>).first as Map<String, dynamic>,
    )..addAll(changes);
    return AdguardHomeQueryLogEntry.fromJson(json);
  }

  setUp(() => page = AdguardHomeQueryLogPage.fromJson(queryLogJson()));

  test('reads the page: its entries, newest first, and where it stopped', () {
    expect(page.entries, hasLength(15));
    expect(page.entries.first.domain, 'example.org');
    expect(page.entries.last.domain, 'radarr.video');
    // Kept as the server wrote it: this goes back as `older_than`.
    expect(page.oldest, '2026-10-07T18:31:41.552491023Z');
    expect(page.isEnd, isFalse);
  });

  test('an empty page with no oldest time is the end of the log', () {
    final AdguardHomeQueryLogPage end = AdguardHomeQueryLogPage.fromJson(
      <String, dynamic>{'data': <dynamic>[], 'oldest': ''},
    );

    expect(end.entries, isEmpty);
    expect(end.isEnd, isTrue);
  });

  test('a page the server sends with nothing in it reads as the end', () {
    // Null for an empty list, and a missing property, are both things this
    // server does elsewhere.
    final AdguardHomeQueryLogPage end = AdguardHomeQueryLogPage.fromJson(
      <String, dynamic>{'data': null},
    );

    expect(end.entries, isEmpty);
    expect(end.isEnd, isTrue);
  });

  test('reads what an answered query carries', () {
    final AdguardHomeQueryLogEntry query = entry('example.org');

    expect(query.type, 'A');
    expect(query.status, 'NOERROR');
    expect(query.reason, 'NotFilteredNotFound');
    // Nanoseconds in, microseconds kept, and it is UTC.
    expect(query.time, DateTime.utc(2026, 10, 7, 20, 29, 32, 377, 246));
    expect(query.elapsed, const Duration(microseconds: 365871));
    expect(query.upstream, 'https://dns10.quad9.net:443/dns-query');
    expect(query.cached, isFalse);
    expect(query.dnssec, isFalse);
    expect(query.protocol, '');
    expect(query.answers, hasLength(2));
    expect(query.answers.first.type, 'A');
    expect(query.answers.first.value, '172.66.157.237');
    expect(query.answers.first.ttl, 262);
    expect(query.originalAnswers, isEmpty);
    expect(query.rules, isEmpty);
  });

  test('reads the client: its address, its name and whether it is shut out',
      () {
    final AdguardHomeQueryLogEntry named = entry('example.org');
    expect(named.client, '172.17.0.1');
    expect(named.clientName, 'Laptop');
    expect(named.clientLabel, 'Laptop');
    expect(named.clientDisallowed, isFalse);

    // Known only by the name the server learned for it.
    final AdguardHomeQueryLogEntry runtime = entry('radarr.video');
    expect(runtime.client, '127.0.0.1');
    expect(runtime.clientLabel, 'localhost');
  });

  test('a client with no name is called by its id, then by its address', () {
    final Map<String, dynamic> nameless = <String, dynamic>{
      'client_info': <String, dynamic>{'name': '', 'disallowed': false},
    };

    expect(parse(nameless).clientLabel, '172.17.0.1');
    expect(
      parse(<String, dynamic>{...nameless, 'client_id': 'kitchen-tablet'})
          .clientLabel,
      'kitchen-tablet',
    );
  });

  test('reads where a shut-out client is shut out, and its whois', () {
    final AdguardHomeQueryLogEntry query = parse(<String, dynamic>{
      'client': '203.0.113.9',
      'client_info': <String, dynamic>{
        'name': '',
        'whois': <String, dynamic>{
          'country': 'NL',
          'city': 'Amsterdam',
          'orgname': 'Example Hosting',
        },
        'disallowed': true,
        'disallowed_rule': '203.0.113.0/24',
      },
    });

    expect(query.clientDisallowed, isTrue);
    expect(query.clientDisallowedRule, '203.0.113.0/24');
    expect(query.clientCountry, 'NL');
    expect(query.clientCity, 'Amsterdam');
    expect(query.clientNetwork, 'Example Hosting');
  });

  test('an entry with no client details at all still reads', () {
    // Anonymised addresses and older servers leave things out.
    final AdguardHomeQueryLogEntry query = parse(<String, dynamic>{
      'client': '',
      'client_info': null,
    });

    expect(query.client, '');
    expect(query.clientLabel, '');
    expect(query.clientDisallowed, isFalse);
  });

  test('an entry with no answer has an empty one', () {
    expect(entry('github.com').answers, isEmpty);
    expect(entry('no-such-name-atrium-test.invalid').status, 'NXDOMAIN');
  });

  test('reads the rule that matched and the list it is on', () {
    final AdguardHomeQueryLogEntry byList = entry('adservice.google.com');
    expect(byList.rules.single.listId, 1);
    expect(byList.rules.single.text, '||adservice.google.');

    final AdguardHomeQueryLogEntry hosts = entry('localhost');
    expect(hosts.rules, hasLength(2));
    expect(hosts.rules.first.listId, -1);
  });

  test('falls back on the old single rule where the new list is empty', () {
    final AdguardHomeQueryLogEntry query = parse(<String, dynamic>{
      'rules': <dynamic>[],
      'rule': '||old.example^',
      'filterId': 7,
    });

    expect(query.rules.single.text, '||old.example^');
    expect(query.rules.single.listId, 7);
  });

  test('says what happened to each query in the web UI\'s words', () {
    AdguardHomeQueryResult of(String domain) => entry(domain).result;

    expect(of('example.org'), AdguardHomeQueryResult.processed);
    expect(of('en.wikipedia.org'), AdguardHomeQueryResult.allowed);
    expect(of('adservice.google.com'), AdguardHomeQueryResult.blocked);
    expect(of('blocked-by-custom.example'), AdguardHomeQueryResult.blocked);
    expect(of('www.tiktok.com'), AdguardHomeQueryResult.blockedService);
    expect(of('pornhub.com'), AdguardHomeQueryResult.blockedParental);
    expect(of('www.youtube.com'), AdguardHomeQueryResult.safeSearch);
    expect(of('nas.home.example'), AdguardHomeQueryResult.rewritten);
    expect(of('rule-rewrite.example'), AdguardHomeQueryResult.rewritten);
    expect(of('localhost'), AdguardHomeQueryResult.rewritten);

    expect(entry('example.org').resultLabel, 'Processed');
    expect(entry('www.tiktok.com').resultLabel, 'Blocked service');
    expect(entry('pornhub.com').resultLabel, 'Blocked by parental control');
    expect(entry('www.tiktok.com').serviceName, 'tiktok');
  });

  test('a row of the list gets a name short enough to sit beside the client',
      () {
    // In full it would be cut off on a phone. The sheet has the room.
    expect(entry('pornhub.com').chipLabel, 'Parental control');
    expect(entry('pornhub.com').resultLabel, 'Blocked by parental control');
    // The others are short as they are.
    expect(entry('example.org').chipLabel, 'Processed');
    expect(entry('www.tiktok.com').chipLabel, 'Blocked service');
    expect(entry('www.youtube.com').chipLabel, 'Safe search');
    // A block that came from the answer is still a block in the list.
    expect(
      parse(<String, dynamic>{
        'reason': 'FilteredBlackList',
        'original_answer': <dynamic>[
          <String, dynamic>{'type': 'A', 'value': '203.0.113.5', 'ttl': 5},
        ],
      }).chipLabel,
      'Blocked',
    );
    expect(
      parse(<String, dynamic>{'reason': 'FilteredSomethingNew'}).chipLabel,
      'FilteredSomethingNew',
    );
  });

  test('a threat the server blocked is its own result', () {
    final AdguardHomeQueryLogEntry query =
        parse(<String, dynamic>{'reason': 'FilteredSafeBrowsing'});

    expect(query.result, AdguardHomeQueryResult.blockedThreat);
    expect(query.resultLabel, 'Blocked threats');
  });

  test('a reason this app does not know is shown as the server names it', () {
    final AdguardHomeQueryLogEntry query =
        parse(<String, dynamic>{'reason': 'FilteredSomethingNew'});

    expect(query.result, AdguardHomeQueryResult.other);
    expect(query.resultLabel, 'FilteredSomethingNew');
    expect(query.result.tone, AdguardHomeResultTone.plain);
  });

  test('a block that came from the answer says so', () {
    // The name was fine; a CNAME or address in the answer was on a list.
    final AdguardHomeQueryLogEntry query = parse(<String, dynamic>{
      'reason': 'FilteredBlackList',
      'original_answer': <dynamic>[
        <String, dynamic>{'type': 'CNAME', 'value': 'ads.example.', 'ttl': 5},
      ],
    });

    expect(query.resultLabel, 'Blocked by CNAME or IP');
    expect(query.originalAnswers.single.value, 'ads.example.');
  });

  test('the results are coloured the way the web UI colours them', () {
    AdguardHomeResultTone tone(AdguardHomeQueryResult result) => result.tone;

    expect(tone(AdguardHomeQueryResult.processed), AdguardHomeResultTone.plain);
    expect(tone(AdguardHomeQueryResult.allowed), AdguardHomeResultTone.allowed);
    expect(tone(AdguardHomeQueryResult.blocked), AdguardHomeResultTone.blocked);
    expect(
      tone(AdguardHomeQueryResult.blockedService),
      AdguardHomeResultTone.blocked,
    );
    expect(
      tone(AdguardHomeQueryResult.blockedThreat),
      AdguardHomeResultTone.restricted,
    );
    expect(
      tone(AdguardHomeQueryResult.blockedParental),
      AdguardHomeResultTone.restricted,
    );
    expect(
      tone(AdguardHomeQueryResult.safeSearch),
      AdguardHomeResultTone.restricted,
    );
    expect(
      tone(AdguardHomeQueryResult.rewritten),
      AdguardHomeResultTone.rewritten,
    );
  });

  test('a filtered query offers Unblock, any other offers Block', () {
    // The web UI's test: the reason begins with "Filtered".
    expect(entry('adservice.google.com').isFiltered, isTrue);
    expect(entry('www.tiktok.com').isFiltered, isTrue);
    expect(entry('pornhub.com').isFiltered, isTrue);
    expect(entry('www.youtube.com').isFiltered, isTrue);
    expect(entry('example.org').isFiltered, isFalse);
    expect(entry('en.wikipedia.org').isFiltered, isFalse);
    expect(entry('nas.home.example').isFiltered, isFalse);
  });

  test('a name in another script is shown in it, and blocked by its ASCII',
      () {
    final AdguardHomeQueryLogEntry query = parse(<String, dynamic>{
      'question': <String, dynamic>{
        'class': 'IN',
        'name': 'xn--mnchen-3ya.example',
        'unicode_name': 'münchen.example',
        'type': 'A',
      },
    });

    expect(query.domain, 'xn--mnchen-3ya.example');
    expect(query.displayName, 'münchen.example');
    expect(entry('example.org').displayName, 'example.org');
  });

  test('a time or a duration that is not one reads as none', () {
    final AdguardHomeQueryLogEntry query = parse(<String, dynamic>{
      'time': 'yesterday',
      'elapsedMs': 'fast',
    });

    expect(query.time, isNull);
    expect(query.elapsed, isNull);
  });

  test('a duration that is no finite number reads as none, and the page stays',
      () {
    // Any of these would otherwise fail the whole page it came in.
    for (final String odd in <String>[
      'NaN',
      'Infinity',
      '-Infinity',
      '1e999',
    ]) {
      expect(
        parse(<String, dynamic>{'elapsedMs': odd}).elapsed,
        isNull,
        reason: odd,
      );
    }
  });

  test('the ten filters carry the values the server takes', () {
    expect(
      AdguardHomeLogFilter.values
          .map((AdguardHomeLogFilter filter) => filter.query),
      <String>[
        'all',
        'filtered',
        'processed',
        'blocked',
        'blocked_services',
        'blocked_safebrowsing',
        'blocked_parental',
        'whitelisted',
        'rewritten',
        'safe_search',
      ],
    );
    expect(AdguardHomeLogFilter.all.label, 'All queries');
    expect(AdguardHomeLogFilter.allowed.label, 'Allowed');
  });

  test('reads whether the log is kept and whether addresses are hidden', () {
    final AdguardHomeQueryLogConfig config =
        AdguardHomeQueryLogConfig.fromJson(queryLogConfigJson());

    expect(config.enabled, isTrue);
    expect(config.anonymizeClientIp, isFalse);
    expect(config.interval, const Duration(days: 90));
  });

  test('reads the access list and writes all three of its lists back', () {
    final AdguardHomeAccessList list =
        AdguardHomeAccessList.fromJson(accessListJson());

    expect(list.allowedClients, isEmpty);
    expect(list.disallowedClients, isEmpty);
    expect(
      list.blockedHosts,
      <String>['version.bind', 'id.server', 'hostname.bind'],
    );
    expect(list.toJson(), <String, dynamic>{
      'allowed_clients': <String>[],
      'disallowed_clients': <String>[],
      'blocked_hosts': <String>['version.bind', 'id.server', 'hostname.bind'],
    });
  });

  test('reads the named clients and the addresses each goes by', () {
    final List<AdguardHomeClientRef> clients =
        AdguardHomeClientRef.listFromJson(clientsJson());

    expect(clients.single.name, 'Laptop');
    expect(clients.single.ids, <String>['172.17.0.1']);
    // A server with no named clients sends null.
    expect(
      AdguardHomeClientRef.listFromJson(<String, dynamic>{'clients': null}),
      isEmpty,
    );
  });
}
