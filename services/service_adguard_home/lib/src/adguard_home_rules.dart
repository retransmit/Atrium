import 'models/adguard_home_access.dart';

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
///
/// With a [client], the rule is the one the web UI writes for "this client
/// only" (`toggleBlockingForClient`): it names the client and carries no
/// `$important`. [client] is a name from [adguardHomeBlockingClientName].
AdguardHomeRuleEdit adguardHomeBlockingEdit(
  List<String> userRules,
  String domain, {
  required bool block,
  String? client,
}) {
  final String blockRule = client == null
      ? '||$domain^\$important'
      : "||$domain^\$client='${_escapedClient(client)}'";
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

/// [name] as it has to be written inside `$client='...'`: the four
/// characters that would end it early each get a backslash.
String _escapedClient(String name) => name
    .replaceAll("'", r"\'")
    .replaceAll('"', r'\"')
    .replaceAll(',', r'\,')
    .replaceAll('|', r'\|');

/// What a rule for one client calls the client at [address]: the name of
/// the client the server has settings for, where one of [clients] has the
/// address among its ids, and otherwise the address.
///
/// The address has to be listed as it is. One that only falls inside a
/// listed range is not that client, here as in the web UI.
String adguardHomeBlockingClientName(
  List<AdguardHomeClientRef> clients,
  String address,
) {
  for (final AdguardHomeClientRef client in clients) {
    if (client.ids.contains(address)) return client.name;
  }
  return address;
}
