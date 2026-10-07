import 'adguard_home_json.dart';

/// The colour family the web UI gives a query's result.
enum AdguardHomeResultTone {
  /// Answered with nothing in the way. White in the web UI.
  plain,

  /// Let through by a rule. Green.
  allowed,

  /// Blocked by a list, a rule or a blocked service. Red.
  blocked,

  /// Safe search, safe browsing and parental control. Yellow.
  restricted,

  /// Answered from a rewrite. Blue.
  rewritten,
}

/// What became of a query, in the words the web UI uses for it.
enum AdguardHomeQueryResult {
  processed('Processed', AdguardHomeResultTone.plain),
  allowed('Allowed', AdguardHomeResultTone.allowed),
  blocked('Blocked', AdguardHomeResultTone.blocked),
  blockedService('Blocked service', AdguardHomeResultTone.blocked),
  blockedThreat('Blocked threats', AdguardHomeResultTone.restricted),
  blockedParental(
    'Blocked by parental control',
    AdguardHomeResultTone.restricted,
    short: 'Parental control',
  ),
  safeSearch('Safe search', AdguardHomeResultTone.restricted),
  rewritten('Rewritten', AdguardHomeResultTone.rewritten),

  /// A reason this app has no name for. It is shown as the server wrote it.
  other('', AdguardHomeResultTone.plain);

  const AdguardHomeQueryResult(this.label, this.tone, {String? short})
      : shortLabel = short ?? label;

  final String label;

  /// [label], or a shorter word for it where it would not fit a row of the
  /// list beside the client.
  final String shortLabel;
  final AdguardHomeResultTone tone;

  /// The result the server's [reason] stands for.
  static AdguardHomeQueryResult of(String reason) => switch (reason) {
        'NotFilteredNotFound' => AdguardHomeQueryResult.processed,
        'NotFilteredWhiteList' => AdguardHomeQueryResult.allowed,
        'FilteredBlackList' => AdguardHomeQueryResult.blocked,
        'FilteredBlockedService' => AdguardHomeQueryResult.blockedService,
        'FilteredSafeBrowsing' => AdguardHomeQueryResult.blockedThreat,
        'FilteredParental' => AdguardHomeQueryResult.blockedParental,
        'FilteredSafeSearch' => AdguardHomeQueryResult.safeSearch,
        'Rewrite' ||
        'RewriteEtcHosts' ||
        'RewriteRule' =>
          AdguardHomeQueryResult.rewritten,
        _ => AdguardHomeQueryResult.other,
      };
}

/// The ten ways the web UI narrows the query log, in its order.
enum AdguardHomeLogFilter {
  all('all', 'All queries'),
  filtered('filtered', 'Filtered'),
  processed('processed', 'Processed'),
  blocked('blocked', 'Blocked'),
  blockedServices('blocked_services', 'Blocked services'),
  blockedThreats('blocked_safebrowsing', 'Blocked threats'),
  blockedParental('blocked_parental', 'Blocked by parental control'),
  allowed('whitelisted', 'Allowed'),
  rewritten('rewritten', 'Rewritten'),
  safeSearch('safe_search', 'Safe search');

  const AdguardHomeLogFilter(this.query, this.label);

  /// What `response_status` is set to.
  final String query;
  final String label;
}

/// One record of an answer.
class AdguardHomeDnsAnswer {
  const AdguardHomeDnsAnswer({
    required this.type,
    required this.value,
    required this.ttl,
  });

  final String type;
  final String value;

  /// In seconds.
  final int ttl;
}

/// A filtering rule a query matched, and the list it is on.
class AdguardHomeMatchedRule {
  const AdguardHomeMatchedRule({required this.listId, required this.text});

  /// The id of a blocklist or allowlist, zero for the custom rules, or one
  /// of the server's negative ids for its built-in sources.
  final int listId;
  final String text;
}

/// One DNS query in the log.
class AdguardHomeQueryLogEntry {
  const AdguardHomeQueryLogEntry({
    required this.domain,
    required this.reason,
    this.time,
    this.unicodeName = '',
    this.type = '',
    this.status = '',
    this.answers = const <AdguardHomeDnsAnswer>[],
    this.originalAnswers = const <AdguardHomeDnsAnswer>[],
    this.rules = const <AdguardHomeMatchedRule>[],
    this.serviceName = '',
    this.client = '',
    this.clientId = '',
    this.clientName = '',
    this.clientCountry = '',
    this.clientCity = '',
    this.clientNetwork = '',
    this.clientDisallowed = false,
    this.clientDisallowedRule = '',
    this.protocol = '',
    this.upstream = '',
    this.cached = false,
    this.dnssec = false,
    this.elapsed,
  });

  factory AdguardHomeQueryLogEntry.fromJson(Map<Object?, Object?> json) {
    final Map<Object?, Object?> question = _map(json['question']);
    final Map<Object?, Object?> info = _map(json['client_info']);
    final Map<Object?, Object?> whois = _map(info['whois']);
    final double? elapsedMs = double.tryParse(readString(json['elapsedMs']));

    List<AdguardHomeMatchedRule> rules = <AdguardHomeMatchedRule>[
      for (final Object? rule in _list(json['rules']))
        if (rule is Map)
          AdguardHomeMatchedRule(
            listId: readInt(rule['filter_list_id']),
            text: readString(rule['text']),
          ),
    ];
    // Older servers name one rule and its list in two properties of their
    // own. Newer ones still send them beside the list.
    final String oldRule = readString(json['rule']);
    if (rules.isEmpty && oldRule.isNotEmpty) {
      rules = <AdguardHomeMatchedRule>[
        AdguardHomeMatchedRule(
          listId: readInt(json['filterId']),
          text: oldRule,
        ),
      ];
    }

    return AdguardHomeQueryLogEntry(
      domain: readString(question['name']),
      unicodeName: readString(question['unicode_name']),
      type: readString(question['type']),
      status: readString(json['status']),
      reason: readString(json['reason']),
      time: DateTime.tryParse(readString(json['time'])),
      answers: _answers(json['answer']),
      originalAnswers: _answers(json['original_answer']),
      rules: rules,
      serviceName: readString(json['service_name']),
      client: readString(json['client']),
      clientId: readString(json['client_id']),
      clientName: readString(info['name']),
      clientCountry: readString(whois['country']),
      clientCity: readString(whois['city']),
      clientNetwork: readString(whois['orgname']),
      clientDisallowed: readBool(info['disallowed']),
      clientDisallowedRule: readString(info['disallowed_rule']),
      protocol: readString(json['client_proto']),
      upstream: readString(json['upstream']),
      cached: readBool(json['cached']),
      dnssec: readBool(json['answer_dnssec']),
      elapsed: elapsedMs == null
          ? null
          : Duration(microseconds: (elapsedMs * 1000).round()),
    );
  }

  /// The name that was asked for, in ASCII. This is what a rule is written
  /// for.
  final String domain;

  /// The same name in its own script where it has one, otherwise empty.
  final String unicodeName;

  /// The record type: A, AAAA, HTTPS and so on.
  final String type;

  /// The response code: NOERROR, NXDOMAIN and so on.
  final String status;

  /// Why the server answered as it did, in its own word.
  final String reason;

  /// When the query came in. Null where the server's text is not a time.
  final DateTime? time;
  final List<AdguardHomeDnsAnswer> answers;

  /// What the upstream said before a rule replaced it.
  final List<AdguardHomeDnsAnswer> originalAnswers;
  final List<AdguardHomeMatchedRule> rules;

  /// The id of the blocked service that matched, such as `tiktok`.
  final String serviceName;

  /// The client's address.
  final String client;
  final String clientId;

  /// The name of a client the server knows, by its settings or by what it
  /// learned.
  final String clientName;
  final String clientCountry;
  final String clientCity;
  final String clientNetwork;

  /// Whether the access settings shut this client out as things stand now.
  /// The server works this out when the log is read, not when the query
  /// came in.
  final bool clientDisallowed;

  /// The entry of the disallowed list that shuts it out. Empty when it is
  /// shut out by not being on the allowlist. Only means anything while
  /// [clientDisallowed] is true.
  final String clientDisallowedRule;

  /// How the query arrived: empty for plain DNS, or `doh`, `dot`, `doq`,
  /// `dnscrypt`.
  final String protocol;
  final String upstream;
  final bool cached;
  final bool dnssec;

  /// How long the answer took. Null where the server's text is not a number.
  final Duration? elapsed;

  /// The name to show.
  String get displayName => unicodeName.isEmpty ? domain : unicodeName;

  /// What to call the client: its name, its id, or its address.
  String get clientLabel {
    if (clientName.isNotEmpty) return clientName;
    if (clientId.isNotEmpty) return clientId;
    return client;
  }

  AdguardHomeQueryResult get result => AdguardHomeQueryResult.of(reason);

  /// Whether filtering did something to this query. The web UI offers
  /// Unblock for these and Block for the rest.
  bool get isFiltered => reason.startsWith('Filtered');

  /// The result in words.
  String get resultLabel {
    final AdguardHomeQueryResult result = this.result;
    final bool blocked = result == AdguardHomeQueryResult.blocked ||
        result == AdguardHomeQueryResult.blockedService;
    // The name passed, and something in the answer was on a list.
    if (blocked && originalAnswers.isNotEmpty) return 'Blocked by CNAME or IP';
    return result == AdguardHomeQueryResult.other ? reason : result.label;
  }

  /// The result in as few words as say it, for a row of the list.
  String get chipLabel {
    final AdguardHomeQueryResult result = this.result;
    return result == AdguardHomeQueryResult.other ? reason : result.shortLabel;
  }
}

/// A stretch of the query log: `GET control/querylog`.
class AdguardHomeQueryLogPage {
  const AdguardHomeQueryLogPage({
    this.entries = const <AdguardHomeQueryLogEntry>[],
    this.oldest = '',
  });

  factory AdguardHomeQueryLogPage.fromJson(Map<String, dynamic> json) {
    return AdguardHomeQueryLogPage(
      entries: <AdguardHomeQueryLogEntry>[
        for (final Object? entry in _list(json['data']))
          if (entry is Map) AdguardHomeQueryLogEntry.fromJson(entry),
      ],
      oldest: readString(json['oldest']),
    );
  }

  /// Newest first.
  final List<AdguardHomeQueryLogEntry> entries;

  /// Where the server stopped, in its own writing. Sent back as
  /// `older_than` to go on from there, so it is never reformatted.
  final String oldest;

  /// Whether there is nothing older. A page can be short without being the
  /// last: under a filter the server gives up scanning after a while and
  /// says how far it got.
  bool get isEnd => oldest.isEmpty;
}

/// Whether the server keeps a query log, from `GET control/querylog/config`.
class AdguardHomeQueryLogConfig {
  const AdguardHomeQueryLogConfig({
    this.enabled = true,
    this.anonymizeClientIp = false,
    this.interval = Duration.zero,
  });

  factory AdguardHomeQueryLogConfig.fromJson(Map<String, dynamic> json) {
    return AdguardHomeQueryLogConfig(
      enabled: readBool(json['enabled']),
      anonymizeClientIp: readBool(json['anonymize_client_ip']),
      interval: Duration(milliseconds: readInt(json['interval'])),
    );
  }

  final bool enabled;

  /// Whether the server hides the end of each client's address.
  final bool anonymizeClientIp;

  /// How long entries are kept.
  final Duration interval;
}

Map<Object?, Object?> _map(Object? value) =>
    value is Map ? value : const <Object?, Object?>{};

List<Object?> _list(Object? value) =>
    value is List ? value : const <Object?>[];

List<AdguardHomeDnsAnswer> _answers(Object? value) => <AdguardHomeDnsAnswer>[
      for (final Object? answer in _list(value))
        if (answer is Map)
          AdguardHomeDnsAnswer(
            type: readString(answer['type']),
            value: readString(answer['value']),
            ttl: readInt(answer['ttl']),
          ),
    ];
