import 'adguard_home_json.dart';

/// One blocklist or allowlist.
class AdguardHomeFilterList {
  const AdguardHomeFilterList({
    required this.id,
    required this.name,
    required this.url,
    required this.enabled,
    required this.rulesCount,
    this.lastUpdated,
  });

  factory AdguardHomeFilterList.fromJson(Map<Object?, Object?> json) {
    return AdguardHomeFilterList(
      id: readInt(json['id']),
      name: readString(json['name']),
      url: readString(json['url']),
      enabled: readBool(json['enabled']),
      rulesCount: readInt(json['rules_count']),
      lastUpdated: DateTime.tryParse(readString(json['last_updated'])),
    );
  }

  final int id;
  final String name;
  final String url;
  final bool enabled;
  final int rulesCount;

  /// Null for a list the server has never fetched.
  final DateTime? lastUpdated;
}

/// What `GET control/filtering/status` says: the lists, the custom rules
/// and whether filtering is on at all.
class AdguardHomeFiltering {
  const AdguardHomeFiltering({
    this.enabled = false,
    this.intervalHours = 0,
    this.blocklists = const <AdguardHomeFilterList>[],
    this.allowlists = const <AdguardHomeFilterList>[],
    this.userRules = const <String>[],
  });

  factory AdguardHomeFiltering.fromJson(Map<String, dynamic> json) {
    return AdguardHomeFiltering(
      enabled: readBool(json['enabled']),
      intervalHours: readInt(json['interval']),
      blocklists: _lists(json['filters']),
      allowlists: _lists(json['whitelist_filters']),
      userRules: readStrings(json['user_rules']),
    );
  }

  final bool enabled;

  /// How often the lists are refreshed. Zero means never.
  final int intervalHours;
  final List<AdguardHomeFilterList> blocklists;
  final List<AdguardHomeFilterList> allowlists;

  /// The custom filtering rules, one per line of the web UI's editor.
  final List<String> userRules;

  /// The rules of every blocklist that is switched on, added up. This is
  /// the "domains on blocklists" figure.
  int get rulesOnBlocklists => blocklists
      .where((AdguardHomeFilterList list) => list.enabled)
      .fold<int>(0, (int sum, AdguardHomeFilterList list) => sum + list.rulesCount);
}

/// The server sends null, not an empty list, where there are no lists.
List<AdguardHomeFilterList> _lists(Object? value) {
  if (value is! List) return const <AdguardHomeFilterList>[];
  return <AdguardHomeFilterList>[
    for (final Object? item in value)
      if (item is Map<Object?, Object?>) AdguardHomeFilterList.fromJson(item),
  ];
}
