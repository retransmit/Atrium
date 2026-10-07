import 'adguard_home_json.dart';

/// Safe search: whether it is enforced, and on which search engines.
class AdguardHomeSafeSearch {
  const AdguardHomeSafeSearch({
    this.enabled = false,
    this.engines = const <String, bool>{},
  });

  /// From a `safe_search` object, or `GET control/safesearch/status`: every
  /// property but `enabled` is a search engine.
  factory AdguardHomeSafeSearch.fromJson(Object? json) {
    if (json is! Map<Object?, Object?>) return const AdguardHomeSafeSearch();
    return AdguardHomeSafeSearch(
      enabled: readBool(json['enabled']),
      engines: <String, bool>{
        for (final MapEntry<Object?, Object?> entry in json.entries)
          if (entry.key case final String engine)
            if (engine != 'enabled') engine: readBool(entry.value),
      },
    );
  }

  final bool enabled;

  /// The search engines the server knows, in its order, and whether safe
  /// search applies to each.
  final Map<String, bool> engines;

  AdguardHomeSafeSearch copyWith({bool? enabled}) => AdguardHomeSafeSearch(
        enabled: enabled ?? this.enabled,
        engines: engines,
      );

  /// This with safe search turned [on] or off for [engine].
  AdguardHomeSafeSearch withEngine(String engine, {required bool on}) =>
      AdguardHomeSafeSearch(
        enabled: enabled,
        engines: <String, bool>{...engines, engine: on},
      );

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'enabled': enabled, ...engines};
}

/// A stretch of one weekday during which a client's blocked services are
/// let through.
class AdguardHomeServicePause {
  const AdguardHomeServicePause({
    required this.day,
    required this.start,
    required this.end,
  });

  /// The server's name for the weekday: `mon`, `tue` and so on.
  final String day;

  /// From midnight, in the schedule's time zone.
  final Duration start;
  final Duration end;
}

/// A client the server has settings for.
///
/// It keeps the object the server sent: a write has to send the whole
/// client back, and whatever is left out of it the server resets.
class AdguardHomeClient {
  const AdguardHomeClient(this.json);

  /// The weekdays of a pause schedule, as the server names them, Monday
  /// first.
  static const List<String> _days = <String>[
    'mon',
    'tue',
    'wed',
    'thu',
    'fri',
    'sat',
    'sun',
  ];

  /// The client exactly as it was read.
  final Map<String, dynamic> json;

  String get name => readString(json['name']);

  /// What the client goes by: addresses, ranges, MAC addresses, ClientIDs.
  List<String> get ids => readStrings(json['ids']);

  List<String> get tags => readStrings(json['tags']);

  /// Whether the server's own protection settings apply, rather than the
  /// four below.
  bool get useGlobalSettings => readBool(json['use_global_settings']);

  bool get filteringEnabled => readBool(json['filtering_enabled']);

  bool get safeBrowsingEnabled => readBool(json['safebrowsing_enabled']);

  bool get parentalEnabled => readBool(json['parental_enabled']);

  /// Servers from before the per-engine switches send only the one flag.
  AdguardHomeSafeSearch get safeSearch {
    final Object? safe = json['safe_search'];
    if (safe is Map<Object?, Object?>) {
      return AdguardHomeSafeSearch.fromJson(safe);
    }
    return AdguardHomeSafeSearch(
      enabled: readBool(json['safesearch_enabled']),
    );
  }

  /// Whether the server's own list of blocked services applies, rather
  /// than [blockedServices].
  bool get useGlobalBlockedServices =>
      readBool(json['use_global_blocked_services']);

  /// The ids of the services blocked for this client.
  List<String> get blockedServices => readStrings(json['blocked_services']);

  /// Upstream servers of its own, one per entry. Empty means the server's.
  List<String> get upstreams => readStrings(json['upstreams']);

  bool get upstreamsCacheEnabled => readBool(json['upstreams_cache_enabled']);

  /// In bytes.
  int get upstreamsCacheSize => readInt(json['upstreams_cache_size']);

  bool get ignoreQueryLog => readBool(json['ignore_querylog']);

  bool get ignoreStatistics => readBool(json['ignore_statistics']);

  /// The time zone the pause schedule is written in.
  String get pauseTimeZone {
    final Object? schedule = json['blocked_services_schedule'];
    return schedule is Map<Object?, Object?>
        ? readString(schedule['time_zone'])
        : '';
  }

  /// When service blocking pauses for this client, Monday first. At most
  /// one stretch a day.
  List<AdguardHomeServicePause> get pauses {
    final Object? schedule = json['blocked_services_schedule'];
    if (schedule is! Map<Object?, Object?>) {
      return const <AdguardHomeServicePause>[];
    }
    final List<AdguardHomeServicePause> pauses = <AdguardHomeServicePause>[];
    for (final String day in _days) {
      final Object? range = schedule[day];
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
    return pauses;
  }
}

/// A device the server has seen without having settings for it.
class AdguardHomeRuntimeClient {
  const AdguardHomeRuntimeClient({
    required this.address,
    this.name = '',
    this.source = '',
    this.whois = const <String, String>{},
  });

  factory AdguardHomeRuntimeClient.fromJson(Map<Object?, Object?> json) {
    return AdguardHomeRuntimeClient(
      address: readString(json['ip']),
      name: readString(json['name']),
      source: readString(json['source']),
      whois: readWhois(json['whois_info']),
    );
  }

  final String address;

  /// The name the server found for it, if any.
  final String name;

  /// Where the server learned of it: `ARP`, `DHCP`, `rDNS`, `WHOIS`,
  /// `etc/hosts`.
  final String source;

  /// What WHOIS says about the address. Only public addresses have any.
  final Map<String, String> whois;

  /// [whois] in one line, or nothing.
  String get whoisLine => formatAdguardHomeWhois(whois);
}

/// What `GET control/clients` says.
class AdguardHomeClientList {
  const AdguardHomeClientList({
    this.persistent = const <AdguardHomeClient>[],
    this.runtime = const <AdguardHomeRuntimeClient>[],
    this.supportedTags = const <String>[],
  });

  factory AdguardHomeClientList.fromJson(Map<String, dynamic> json) {
    final Object? clients = json['clients'];
    final Object? auto = json['auto_clients'];
    return AdguardHomeClientList(
      persistent: <AdguardHomeClient>[
        if (clients is List)
          for (final Object? client in clients)
            if (client is Map<String, dynamic>) AdguardHomeClient(client),
      ],
      runtime: <AdguardHomeRuntimeClient>[
        if (auto is List)
          for (final Object? client in auto)
            if (client is Map<Object?, Object?>)
              AdguardHomeRuntimeClient.fromJson(client),
      ],
      supportedTags: readStrings(json['supported_tags']),
    );
  }

  final List<AdguardHomeClient> persistent;
  final List<AdguardHomeRuntimeClient> runtime;

  /// The tags a client can be given. The server refuses any other.
  final List<String> supportedTags;
}

/// What `POST control/clients/search` says about one thing a client can go
/// by: an address, a MAC address, a ClientID.
class AdguardHomeFoundClient {
  const AdguardHomeFoundClient({
    required this.id,
    this.name = '',
    this.ids = const <String>[],
    this.whois = const <String, String>{},
    this.disallowed = false,
    this.disallowedRule = '',
  });

  /// The answer is a list of objects with one entry each, keyed by what was
  /// asked for.
  static Map<String, AdguardHomeFoundClient> mapFromJson(Object? json) {
    if (json is! List) return const <String, AdguardHomeFoundClient>{};
    return <String, AdguardHomeFoundClient>{
      for (final Object? row in json)
        if (row is Map<Object?, Object?>)
          for (final MapEntry<Object?, Object?> entry in row.entries)
            if (entry.key case final String id)
              if (entry.value case final Map<Object?, Object?> client)
                id: AdguardHomeFoundClient(
                  id: id,
                  name: readString(client['name']),
                  ids: readStrings(client['ids']),
                  whois: readWhois(client['whois_info']),
                  disallowed: readBool(client['disallowed']),
                  disallowedRule: readString(client['disallowed_rule']),
                ),
    };
  }

  /// What was asked for.
  final String id;

  /// A persistent client's name, a runtime client's, or nothing.
  final String name;

  /// Everything a persistent client goes by. For anything else, just [id].
  final List<String> ids;

  final Map<String, String> whois;

  /// Whether the access settings shut this client out.
  final bool disallowed;

  /// The entry of the disallowed clients that does it.
  final String disallowedRule;
}

/// A `whois_info` object: whatever it holds that is text.
Map<String, String> readWhois(Object? value) => value is Map<Object?, Object?>
    ? <String, String>{
        for (final MapEntry<Object?, Object?> entry in value.entries)
          if (entry.key case final String key)
            if (entry.value case final String text)
              if (text.isNotEmpty) key: text,
      }
    : const <String, String>{};

/// WHOIS in one line: who owns the address, then where, then whatever else
/// there is.
String formatAdguardHomeWhois(Map<String, String> whois) => <String>[
      if (whois['orgname'] case final String owner) owner,
      if (whois['country'] case final String country) country,
      if (whois['city'] case final String city) city,
      for (final MapEntry<String, String> entry in whois.entries)
        if (!const <String>{'orgname', 'country', 'city'}.contains(entry.key))
          entry.value,
    ].join(', ');
