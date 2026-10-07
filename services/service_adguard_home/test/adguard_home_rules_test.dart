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
}
