import 'adguard_home_rules.dart';

/// How many rules [text] holds: its lines that are neither blank nor a
/// comment (`!` or `#`).
int adguardHomeRuleCount(String text) => <String>[
      for (final String line in text.split('\n'))
        if (_isRule(line)) line,
    ].length;

bool _isRule(String line) {
  final String rule = line.trim();
  return rule.isNotEmpty && !rule.startsWith('!') && !rule.startsWith('#');
}

/// The custom rules as the server takes them, one per entry, from the text
/// of the editor. Blank lines are dropped, as the web UI drops them; the
/// rest is kept as typed, comments included.
List<String> adguardHomeRulesFromText(String text) => <String>[
      for (final String line in text.replaceAll('\r', '').split('\n'))
        if (line.trim().isNotEmpty) line.trimRight(),
    ];

/// The custom rules as the editor shows them, one to a line.
String adguardHomeRulesToText(List<String> rules) => rules.join('\n');

/// One name in a rule's `client` modifier, where it sits in the rule.
class _ClientName {
  const _ClientName(this.start, this.end, this.name, {required this.negated});

  /// Where it starts in the rule, a `~` included, and where it ends.
  final int start;
  final int end;

  /// The name as the server reads it, quotes and backslashes taken off.
  final String name;
  final bool negated;
}

final RegExp _clientKey = RegExp(r'[$,]client=');

/// Every name the `client` modifiers of [rule] list. A modifier can come
/// after others (`$important,client=...`) and list several names at once
/// (`'A'|'B'`), each quoted or bare and each maybe negated with `~`.
List<_ClientName> _clientNames(String rule) {
  final List<_ClientName> names = <_ClientName>[];
  for (final RegExpMatch key in _clientKey.allMatches(rule)) {
    // A `$` or `,` with a backslash before it is part of a value.
    if (key.start > 0 && rule[key.start - 1] == r'\') continue;
    int i = key.end;
    while (i < rule.length) {
      final int start = i;
      final bool negated = rule[i] == '~';
      if (negated) i++;
      if (i >= rule.length) break;
      final String quote = rule[i];
      final StringBuffer name = StringBuffer();
      if (quote == "'" || quote == '"') {
        i++;
        while (i < rule.length && rule[i] != quote) {
          if (rule[i] == r'\' && i + 1 < rule.length) i++;
          name.write(rule[i]);
          i++;
        }
        if (i >= rule.length) break; // never closed: not a name
        i++;
      } else {
        while (i < rule.length && rule[i] != '|' && rule[i] != ',') {
          if (rule[i] == r'\' && i + 1 < rule.length) i++;
          name.write(rule[i]);
          i++;
        }
      }
      names.add(
        _ClientName(start, i, name.toString(), negated: negated),
      );
      if (i < rule.length && rule[i] == '|') {
        i++;
      } else {
        break;
      }
    }
  }
  return names;
}

/// How many of [rules] name the client called [name] in a `client`
/// modifier, alone or among others.
int adguardHomeRulesNamingClient(List<String> rules, String name) => rules
    .where(
      (String rule) =>
          _clientNames(rule).any((_ClientName found) => found.name == name),
    )
    .length;

/// [rules] with the client called [from] named [to] instead, so the rules
/// written for it still apply after a rename. The rest is left alone.
List<String> adguardHomeRenameClientInRules(
  List<String> rules,
  String from,
  String to,
) {
  final String renamed = "'${adguardHomeEscapedClient(to)}'";
  return <String>[
    for (final String rule in rules) _renamed(rule, from, renamed),
  ];
}

String _renamed(String rule, String from, String renamed) {
  String out = rule;
  // From the end, so the places of the earlier names still hold.
  for (final _ClientName found in _clientNames(rule).reversed) {
    if (found.name != from) continue;
    out = out.replaceRange(
      found.start,
      found.end,
      '${found.negated ? '~' : ''}$renamed',
    );
  }
  return out;
}

final RegExp _listUrl = RegExp(r'^https?://[^/\s]+(/.*)?$');
final RegExp _listPath = RegExp(r'^([a-zA-Z]:)?[\\/]\S*[^\\/]$');

/// What is wrong with [url] as the address of a filter list, or null when
/// it will do: an http or https address, or the full path of a file on the
/// server, as the web UI accepts.
String? adguardHomeListUrlProblem(String url) {
  final String address = url.trim();
  if (address.isEmpty) return 'Enter the address of the list.';
  if (_listUrl.hasMatch(address) || _listPath.hasMatch(address)) return null;
  return 'An address starting with http:// or https://, or the full path of '
      'a file on the server.';
}
