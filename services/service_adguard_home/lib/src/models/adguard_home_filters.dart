import 'adguard_home_clients.dart';
import 'adguard_home_json.dart';
import 'adguard_home_query_log.dart';

/// The weekdays of a pause schedule, as the server names them, Monday first.
const List<String> adguardHomeWeekdays = <String>[
  'mon',
  'tue',
  'wed',
  'thu',
  'fri',
  'sat',
  'sun',
];

/// When blocking of services pauses: at most one stretch a weekday, in a
/// time zone. The server's own list of blocked services has one, and so can
/// each client with services of its own.
class AdguardHomeSchedule {
  const AdguardHomeSchedule({
    this.timeZone = '',
    this.pauses = const <AdguardHomeServicePause>[],
  });

  /// From a `schedule` or `blocked_services_schedule` object.
  factory AdguardHomeSchedule.fromJson(Object? json) {
    if (json is! Map<Object?, Object?>) return const AdguardHomeSchedule();
    final List<AdguardHomeServicePause> pauses = <AdguardHomeServicePause>[];
    for (final String day in adguardHomeWeekdays) {
      final Object? range = json[day];
      if (range is! Map<Object?, Object?>) continue;
      final Object? start = range['start'];
      final Object? end = range['end'];
      if (start is! num || end is! num) continue;
      pauses.add(
        AdguardHomeServicePause(
          day: day,
          start: Duration(milliseconds: start.toInt()),
          end: Duration(milliseconds: end.toInt()),
        ),
      );
    }
    return AdguardHomeSchedule(
      timeZone: readString(json['time_zone']),
      pauses: pauses,
    );
  }

  /// An IANA name, or `Local` for the server's own time zone.
  final String timeZone;

  /// Monday first.
  final List<AdguardHomeServicePause> pauses;

  /// The pause on [day], if there is one.
  AdguardHomeServicePause? pauseOn(String day) {
    for (final AdguardHomeServicePause pause in pauses) {
      if (pause.day == day) return pause;
    }
    return null;
  }

  /// This with [day] paused from [start] to [end], instead of whatever it
  /// had.
  AdguardHomeSchedule withPause(
    String day, {
    required Duration start,
    required Duration end,
  }) =>
      _with(day, AdguardHomeServicePause(day: day, start: start, end: end));

  /// This with nothing paused on [day].
  AdguardHomeSchedule withoutPause(String day) => _with(day, null);

  AdguardHomeSchedule withTimeZone(String timeZone) =>
      AdguardHomeSchedule(timeZone: timeZone, pauses: pauses);

  AdguardHomeSchedule _with(String day, AdguardHomeServicePause? pause) {
    final List<AdguardHomeServicePause> pauses = <AdguardHomeServicePause>[];
    for (final String each in adguardHomeWeekdays) {
      final AdguardHomeServicePause? kept = each == day ? pause : pauseOn(each);
      if (kept != null) pauses.add(kept);
    }
    return AdguardHomeSchedule(timeZone: timeZone, pauses: pauses);
  }

  /// The way the server takes it: milliseconds from midnight.
  Map<String, dynamic> toJson() => <String, dynamic>{
        if (timeZone.isNotEmpty) 'time_zone': timeZone,
        for (final AdguardHomeServicePause pause in pauses)
          pause.day: <String, dynamic>{
            'start': pause.start.inMilliseconds,
            'end': pause.end.inMilliseconds,
          },
      };
}

/// What is wrong with pausing from [start] to [end], in a sentence, or null
/// when the server will take it: whole minutes, start before end, and no
/// later than the end of the day.
String? adguardHomeScheduleProblem(Duration start, Duration end) {
  const Duration day = Duration(hours: 24);
  if (start.inMicroseconds % Duration.microsecondsPerMinute != 0 ||
      end.inMicroseconds % Duration.microsecondsPerMinute != 0) {
    return 'Times are in whole minutes.';
  }
  if (start.isNegative || end > day) {
    return 'A pause has to fit in one day.';
  }
  if (end <= start) return 'The end has to be after the start.';
  return null;
}

/// The services the server blocks for everyone, and when it pauses that.
class AdguardHomeGlobalServices {
  const AdguardHomeGlobalServices({
    this.ids = const <String>[],
    this.schedule = const AdguardHomeSchedule(),
  });

  /// From `GET control/blocked_services/get`.
  factory AdguardHomeGlobalServices.fromJson(Map<String, dynamic> json) =>
      AdguardHomeGlobalServices(
        ids: readStrings(json['ids']),
        schedule: AdguardHomeSchedule.fromJson(json['schedule']),
      );

  final List<String> ids;
  final AdguardHomeSchedule schedule;

  AdguardHomeGlobalServices copyWith({
    List<String>? ids,
    AdguardHomeSchedule? schedule,
  }) =>
      AdguardHomeGlobalServices(
        ids: ids ?? this.ids,
        schedule: schedule ?? this.schedule,
      );

  /// Both parts, always: what a write leaves out the server resets.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'ids': ids,
        'schedule': schedule.toJson(),
      };
}

/// A DNS rewrite: a domain, possibly a wildcard, answered with [answer].
class AdguardHomeRewrite {
  const AdguardHomeRewrite({
    required this.domain,
    required this.answer,
    this.enabled = true,
    this.switchable = true,
  });

  /// `GET control/rewrite/list`. A rewrite without the field comes from a
  /// server from before the per-rule switch: it is on, as that server
  /// treats every one, and has no switch.
  static List<AdguardHomeRewrite> listFromJson(Object? json) =>
      <AdguardHomeRewrite>[
        if (json is List)
          for (final Object? row in json)
            if (row is Map<Object?, Object?>)
              AdguardHomeRewrite(
                domain: readString(row['domain']),
                answer: readString(row['answer']),
                enabled: row['enabled'] != false,
                switchable: row.containsKey('enabled'),
              ),
      ];

  final String domain;

  /// An address, a domain, or `A` or `AAAA` to keep the upstream's records
  /// of that type.
  final String answer;
  final bool enabled;

  /// Whether the server has a switch for this rewrite. One that does not
  /// is never sent a switch either.
  final bool switchable;

  AdguardHomeRewrite copyWith({
    String? domain,
    String? answer,
    bool? enabled,
  }) =>
      AdguardHomeRewrite(
        domain: domain ?? this.domain,
        answer: answer ?? this.answer,
        enabled: enabled ?? this.enabled,
        switchable: switchable,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'domain': domain,
        'answer': answer,
        if (switchable) 'enabled': enabled,
      };

  @override
  bool operator ==(Object other) =>
      other is AdguardHomeRewrite &&
      other.domain == domain &&
      other.answer == answer &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(domain, answer, enabled);

  /// Whether the server would take [other] for this one: it tells rewrites
  /// apart by their domain and answer only.
  bool sameTarget(AdguardHomeRewrite other) =>
      other.domain == domain && other.answer == answer;
}

/// What the server would do with a name: `GET control/filtering/check_host`.
class AdguardHomeHostCheck {
  const AdguardHomeHostCheck({
    required this.name,
    required this.reason,
    this.rules = const <AdguardHomeMatchedRule>[],
    this.serviceName = '',
    this.cname = '',
    this.ipAddresses = const <String>[],
  });

  /// [name] is what was asked about; the answer does not repeat it.
  factory AdguardHomeHostCheck.fromJson(
    String name,
    Map<String, dynamic> json,
  ) {
    final Object? rules = json['rules'];
    final List<AdguardHomeMatchedRule> matched = <AdguardHomeMatchedRule>[
      if (rules is List)
        for (final Object? rule in rules)
          if (rule is Map<Object?, Object?>)
            AdguardHomeMatchedRule(
              listId: readInt(rule['filter_list_id']),
              text: readString(rule['text']),
            ),
    ];
    // Servers from before the list of rules send one.
    final String single = readString(json['rule']);
    if (matched.isEmpty && single.isNotEmpty) {
      matched.add(
        AdguardHomeMatchedRule(
          listId: readInt(json['filter_id']),
          text: single,
        ),
      );
    }
    return AdguardHomeHostCheck(
      name: name,
      reason: readString(json['reason']),
      rules: matched,
      serviceName: readString(json['service_name']),
      cname: readString(json['cname']),
      ipAddresses: readStrings(json['ip_addrs']),
    );
  }

  final String name;
  final String reason;
  final List<AdguardHomeMatchedRule> rules;

  /// The id of the blocked service that matched.
  final String serviceName;
  final String cname;
  final List<String> ipAddresses;

  AdguardHomeQueryResult get result => AdguardHomeQueryResult.of(reason);

  /// Whether the name would be blocked, so the opposite action is Unblock.
  bool get isFiltered => reason.startsWith('Filtered');
}
