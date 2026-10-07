/// What blocking or unblocking a domain did to the custom rules.
enum AdguardHomeRuleChange {
  /// A rule was appended.
  added,

  /// The opposite rule was there and was taken away.
  removed,

  /// The rule asked for was there already.
  alreadyThere,
}

/// The custom rules after a block or unblock, and what changed.
class AdguardHomeRuleEdit {
  const AdguardHomeRuleEdit(this.rules, this.change, this.rule);

  /// The whole list, ready to send.
  final List<String> rules;
  final AdguardHomeRuleChange change;

  /// The rule that was added, removed or found.
  final String rule;
}

/// What blocking ([block] true) or unblocking [domain] does to [userRules].
///
/// These are the steps AdGuard Home's own web UI takes (`toggleBlocking` in
/// `client/src/actions/index.tsx`), so that a domain blocked here looks, in
/// the custom rules, exactly as one blocked there:
///
///  * if the opposite rule is among the custom rules, it is removed, and
///    nothing is added;
///  * otherwise the rule is appended, unless it is there already.
///
/// A rule only counts when the whole line matches. [userRules] is not
/// changed.
AdguardHomeRuleEdit adguardHomeBlockingEdit(
  List<String> userRules,
  String domain, {
  required bool block,
}) {
  final String blockRule = '||$domain^\$important';
  final String allowRule = '@@$blockRule';
  final String wanted = block ? blockRule : allowRule;
  final String opposite = block ? allowRule : blockRule;

  if (userRules.contains(opposite)) {
    return AdguardHomeRuleEdit(
      List<String>.of(userRules)..remove(opposite),
      AdguardHomeRuleChange.removed,
      opposite,
    );
  }
  if (userRules.contains(wanted)) {
    return AdguardHomeRuleEdit(
      userRules,
      AdguardHomeRuleChange.alreadyThere,
      wanted,
    );
  }
  return AdguardHomeRuleEdit(
    <String>[...userRules, wanted],
    AdguardHomeRuleChange.added,
    wanted,
  );
}
