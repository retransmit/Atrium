import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

import 'support/adguard_home_filters_fixtures.dart';

void main() {
  group('a pause schedule', () {
    final AdguardHomeSchedule captured = AdguardHomeSchedule.fromJson(
      globalServicesJson()['schedule'],
    );

    test('reads the time zone and the days, Monday first', () {
      expect(captured.timeZone, 'Europe/Berlin');
      expect(
        captured.pauses.map((AdguardHomeServicePause pause) => pause.day),
        <String>['sat', 'sun'],
      );
      expect(captured.pauses.first.start, const Duration(hours: 9));
      expect(captured.pauses.first.end, const Duration(hours: 17));
      // All day ends at the end of the day.
      expect(captured.pauses.last.end, const Duration(hours: 24));
    });

    test('finds the pause of a day, or none', () {
      expect(captured.pauseOn('sat')?.start, const Duration(hours: 9));
      expect(captured.pauseOn('mon'), isNull);
    });

    test('goes back the way the server wrote it', () {
      expect(
        jsonEncode(captured.toJson()),
        jsonEncode(<String, dynamic>{
          'time_zone': 'Europe/Berlin',
          'sat': <String, dynamic>{'start': 32400000, 'end': 61200000},
          'sun': <String, dynamic>{'start': 0, 'end': 86400000},
        }),
      );
    });

    test('sets, replaces and clears a day without touching the others', () {
      final AdguardHomeSchedule changed = captured
          .withPause(
            'mon',
            start: const Duration(hours: 22),
            end: const Duration(hours: 24),
          )
          .withPause(
            'sat',
            start: const Duration(hours: 10),
            end: const Duration(hours: 12),
          )
          .withoutPause('sun');

      expect(
        changed.pauses.map((AdguardHomeServicePause pause) => pause.day),
        <String>['mon', 'sat'],
      );
      expect(changed.pauseOn('sat')?.start, const Duration(hours: 10));
      expect(changed.timeZone, 'Europe/Berlin');
      // The one it was made from is as it was.
      expect(captured.pauseOn('sun'), isNotNull);
    });

    test('changes the time zone and keeps the days', () {
      final AdguardHomeSchedule moved = captured.withTimeZone('Local');

      expect(moved.timeZone, 'Local');
      expect(moved.pauses, hasLength(2));
    });

    test('that is missing or odd reads as no pauses in no zone', () {
      expect(AdguardHomeSchedule.fromJson(null).pauses, isEmpty);
      expect(AdguardHomeSchedule.fromJson(null).timeZone, isEmpty);
      final AdguardHomeSchedule odd = AdguardHomeSchedule.fromJson(
        <String, dynamic>{
          'time_zone': 'UTC',
          'mon': 'all day',
          'tue': <String, dynamic>{'start': 0},
          'wed': <String, dynamic>{'start': 60000, 'end': 120000},
        },
      );
      expect(
        odd.pauses.map((AdguardHomeServicePause pause) => pause.day),
        <String>['wed'],
      );
    });

    test('with no time zone goes out with none rather than an empty one', () {
      const AdguardHomeSchedule none = AdguardHomeSchedule();

      expect(none.toJson(), <String, dynamic>{});
    });

    test('says what is wrong with a range before the server does', () {
      expect(
        adguardHomeScheduleProblem(Duration.zero, const Duration(hours: 24)),
        isNull,
      );
      expect(
        adguardHomeScheduleProblem(
          const Duration(hours: 9),
          const Duration(hours: 9),
        ),
        'The end has to be after the start.',
      );
      expect(
        adguardHomeScheduleProblem(
          const Duration(hours: 10),
          const Duration(hours: 9),
        ),
        'The end has to be after the start.',
      );
      expect(
        adguardHomeScheduleProblem(
          Duration.zero,
          const Duration(hours: 24, minutes: 1),
        ),
        isNotNull,
      );
      expect(
        adguardHomeScheduleProblem(
          const Duration(seconds: 30),
          const Duration(hours: 1),
        ),
        isNotNull,
      );
    });
  });

  group('the blocked services of the server', () {
    test('reads the ids and the schedule', () {
      final AdguardHomeGlobalServices services =
          AdguardHomeGlobalServices.fromJson(globalServicesJson());

      expect(services.ids, <String>['tiktok']);
      expect(services.schedule.timeZone, 'Europe/Berlin');
      expect(services.schedule.pauses, hasLength(2));
    });

    test('goes out with both, as the server resets what is left out', () {
      final AdguardHomeGlobalServices services =
          AdguardHomeGlobalServices.fromJson(globalServicesJson());

      final Map<String, dynamic> json =
          services.copyWith(ids: <String>['youtube', 'tiktok']).toJson();

      expect(json['ids'], <String>['youtube', 'tiktok']);
      expect(
        jsonEncode(json['schedule']),
        jsonEncode(services.schedule.toJson()),
      );
    });

    test('null ids read as none', () {
      expect(
        AdguardHomeGlobalServices.fromJson(<String, dynamic>{'ids': null})
            .ids,
        isEmpty,
      );
    });
  });

  group('rewrites', () {
    test('read as the server lists them', () {
      final List<AdguardHomeRewrite> rewrites =
          AdguardHomeRewrite.listFromJson(rewritesJson());

      expect(rewrites, hasLength(2));
      expect(rewrites.first.domain, 'nas.home.example');
      expect(rewrites.first.answer, '192.168.1.50');
      expect(rewrites.first.enabled, isTrue);
      expect(rewrites.last.domain, '*.lan.example');
      expect(rewrites.last.enabled, isFalse);
    });

    test('a rewrite with no enabled field is on, as the server takes it', () {
      final List<AdguardHomeRewrite> rewrites = AdguardHomeRewrite.listFromJson(
        <dynamic>[
          <String, dynamic>{'domain': 'a.example', 'answer': 'A'},
          'nonsense',
        ],
      );

      expect(rewrites.single.enabled, isTrue);
      // A server from before the switch: none to show, and none to send.
      expect(rewrites.single.switchable, isFalse);
      expect(rewrites.single.toJson(), <String, dynamic>{
        'domain': 'a.example',
        'answer': 'A',
      });
      expect(rewrites.single.copyWith(answer: 'AAAA').switchable, isFalse);
      expect(
        AdguardHomeRewrite.listFromJson(rewritesJson())
            .every((AdguardHomeRewrite r) => r.switchable),
        isTrue,
      );
    });

    test('null reads as none', () {
      expect(AdguardHomeRewrite.listFromJson(null), isEmpty);
    });

    test('goes out with its three fields', () {
      expect(
        const AdguardHomeRewrite(
          domain: 'a.example',
          answer: '10.0.0.1',
          enabled: false,
        ).toJson(),
        <String, dynamic>{
          'domain': 'a.example',
          'answer': '10.0.0.1',
          'enabled': false,
        },
      );
    });

    test('are equal by what they hold', () {
      expect(
        const AdguardHomeRewrite(domain: 'a', answer: 'b'),
        const AdguardHomeRewrite(domain: 'a', answer: 'b'),
      );
    });
  });

  group('a host check', () {
    AdguardHomeHostCheck check(String name) => AdguardHomeHostCheck.fromJson(
          name,
          hostChecksJson()[name] as Map<String, dynamic>,
        );

    test('of a blocked service names the service and its rule', () {
      final AdguardHomeHostCheck tiktok = check('www.tiktok.com');

      expect(tiktok.name, 'www.tiktok.com');
      expect(tiktok.result, AdguardHomeQueryResult.blockedService);
      expect(tiktok.serviceName, 'tiktok');
      expect(tiktok.rules.single.text, '||tiktok.com^');
      expect(tiktok.rules.single.listId, -2);
      expect(tiktok.isFiltered, isTrue);
    });

    test('of a custom block and a custom allow', () {
      expect(check('blocked-by-custom.example').isFiltered, isTrue);
      expect(
        check('blocked-by-custom.example').rules.single.listId,
        0,
      );
      final AdguardHomeHostCheck allowed = check('wikipedia.org');
      expect(allowed.result, AdguardHomeQueryResult.allowed);
      expect(allowed.isFiltered, isFalse);
    });

    test('allowed by an allowlist names the list by its id', () {
      expect(check('doubleclick.net').rules.single.listId, 1792423510);
    });

    test('that matched nothing has no rules', () {
      final AdguardHomeHostCheck nothing = check('example.com');

      expect(nothing.result, AdguardHomeQueryResult.processed);
      expect(nothing.rules, isEmpty);
      expect(nothing.ipAddresses, isEmpty);
    });

    test('of a rewrite', () {
      expect(check('nas.home.example').result, AdguardHomeQueryResult.rewritten);
      expect(
        check('rule-rewrite.example').result,
        AdguardHomeQueryResult.rewritten,
      );
    });

    test('from an older server with only the single rule field', () {
      final AdguardHomeHostCheck old = AdguardHomeHostCheck.fromJson(
        'a.example',
        <String, dynamic>{
          'reason': 'FilteredBlackList',
          'rule': '||a.example^',
          'filter_id': 1,
          'ip_addrs': <dynamic>['0.0.0.0'],
          'cname': 'b.example',
        },
      );

      expect(old.rules.single.text, '||a.example^');
      expect(old.rules.single.listId, 1);
      expect(old.ipAddresses, <String>['0.0.0.0']);
      expect(old.cname, 'b.example');
    });
  });

  group('custom rules as text', () {
    test('count every line that is a rule', () {
      expect(
        adguardHomeRuleCount(
          '||a.example^\n\n! a comment\n# another\n   \n@@||b.example^\n',
        ),
        2,
      );
      expect(adguardHomeRuleCount(''), 0);
    });

    test('become the list the server takes, without blank lines', () {
      expect(
        adguardHomeRulesFromText('||a.example^\r\n\n  \n! note\n||b.example^\n'),
        <String>['||a.example^', '! note', '||b.example^'],
      );
      expect(adguardHomeRulesFromText('\n\n'), isEmpty);
    });

    test('come from the list one to a line', () {
      expect(
        adguardHomeRulesToText(<String>['||a.example^', '||b.example^']),
        '||a.example^\n||b.example^',
      );
    });
  });

  group('rules that name a client', () {
    const List<String> rules = <String>[
      "||tiktok.com^\$client='Kids tablet'",
      "@@||school.example^\$client='Kids tablet'",
      "||ads.example^\$client='Laptop'",
      '||plain.example^',
      r"||a.example^$client='O\'Brien'",
    ];

    test('are counted by the name they give', () {
      expect(adguardHomeRulesNamingClient(rules, 'Kids tablet'), 2);
      expect(adguardHomeRulesNamingClient(rules, 'Laptop'), 1);
      expect(adguardHomeRulesNamingClient(rules, "O'Brien"), 1);
      expect(adguardHomeRulesNamingClient(rules, 'Kids'), 0);
    });

    test('follow a rename and leave the rest alone', () {
      final List<String> renamed =
          adguardHomeRenameClientInRules(rules, 'Kids tablet', 'Tablet');

      expect(renamed, <String>[
        "||tiktok.com^\$client='Tablet'",
        "@@||school.example^\$client='Tablet'",
        "||ads.example^\$client='Laptop'",
        '||plain.example^',
        r"||a.example^$client='O\'Brien'",
      ]);
    });

    test('are written with the new name escaped as the rules want it', () {
      final List<String> renamed =
          adguardHomeRenameClientInRules(rules, 'Laptop', "Dad's, laptop");

      expect(renamed[2], r"||ads.example^$client='Dad\'s\, laptop'");
    });

    test('are found however the modifier is written', () {
      const List<String> written = <String>[
        r"||a.example^$important,client='Kids tablet'",
        r"||b.example^$client='Laptop'|'Kids tablet'",
        r'||c.example^$client=Laptop',
        r'||d.example^$client=~"Laptop",important',
        r"||e.example^$client='Old\,client=Laptop|Other'",
        r"||f.example^$client='Laptop'",
      ];

      expect(adguardHomeRulesNamingClient(written, 'Kids tablet'), 2);
      expect(adguardHomeRulesNamingClient(written, 'Laptop'), 4);
      expect(adguardHomeRulesNamingClient(written, 'Old,client=Laptop|Other'), 1);
      expect(
        adguardHomeRenameClientInRules(written, 'Laptop', 'Work laptop'),
        <String>[
          r"||a.example^$important,client='Kids tablet'",
          r"||b.example^$client='Work laptop'|'Kids tablet'",
          r"||c.example^$client='Work laptop'",
          r"||d.example^$client=~'Work laptop',important",
          r"||e.example^$client='Old\,client=Laptop|Other'",
          r"||f.example^$client='Work laptop'",
        ],
      );
    });
  });
}
