import 'models/adguard_home_clients.dart';

/// The largest cache size the server can hold: it keeps it in 32 bits.
const int adguardHomeMaxCacheSize = 4294967295;

/// What is wrong with a draft, a sentence for each field that will not do.
class AdguardHomeClientProblems {
  const AdguardHomeClientProblems({this.name, this.ids, this.cacheSize});

  final String? name;
  final String? ids;
  final String? cacheSize;

  bool get any => name != null || ids != null || cacheSize != null;
}

/// A client as the form holds it: the settings a person can change, with
/// the text fields as they are typed.
class AdguardHomeClientDraft {
  const AdguardHomeClientDraft({
    required this.name,
    required this.ids,
    required this.tags,
    required this.useGlobalSettings,
    required this.filteringEnabled,
    required this.safeBrowsingEnabled,
    required this.parentalEnabled,
    required this.safeSearch,
    required this.useGlobalBlockedServices,
    required this.blockedServices,
    required this.upstreams,
    required this.upstreamsCacheEnabled,
    required this.upstreamsCacheSize,
    required this.ignoreQueryLog,
    required this.ignoreStatistics,
  });

  /// A client that is not there yet, as the web UI starts one: on the
  /// global settings, with the server's own safe search to start from.
  const AdguardHomeClientDraft.blank({
    this.safeSearch = const AdguardHomeSafeSearch(),
    this.name = '',
    this.ids = const <String>[''],
  })  : tags = const <String>[],
        useGlobalSettings = true,
        filteringEnabled = false,
        safeBrowsingEnabled = false,
        parentalEnabled = false,
        useGlobalBlockedServices = true,
        blockedServices = const <String>[],
        upstreams = '',
        upstreamsCacheEnabled = false,
        upstreamsCacheSize = '0',
        ignoreQueryLog = false,
        ignoreStatistics = false;

  /// The settings of [client], to be changed.
  factory AdguardHomeClientDraft.of(AdguardHomeClient client) {
    final List<String> ids = client.ids;
    return AdguardHomeClientDraft(
      name: client.name,
      // A row to type in, even for a client that somehow has none.
      ids: ids.isEmpty ? const <String>[''] : ids,
      tags: client.tags,
      useGlobalSettings: client.useGlobalSettings,
      filteringEnabled: client.filteringEnabled,
      safeBrowsingEnabled: client.safeBrowsingEnabled,
      parentalEnabled: client.parentalEnabled,
      safeSearch: client.safeSearch,
      useGlobalBlockedServices: client.useGlobalBlockedServices,
      blockedServices: client.blockedServices,
      upstreams: client.upstreams.join('\n'),
      upstreamsCacheEnabled: client.upstreamsCacheEnabled,
      upstreamsCacheSize: '${client.upstreamsCacheSize}',
      ignoreQueryLog: client.ignoreQueryLog,
      ignoreStatistics: client.ignoreStatistics,
    );
  }

  final String name;

  /// The identifier rows, as typed. An empty row is one not filled in yet.
  final List<String> ids;
  final List<String> tags;
  final bool useGlobalSettings;
  final bool filteringEnabled;
  final bool safeBrowsingEnabled;
  final bool parentalEnabled;
  final AdguardHomeSafeSearch safeSearch;
  final bool useGlobalBlockedServices;

  /// The ids of the services blocked for this client.
  final List<String> blockedServices;

  /// The upstream servers as typed, one to a line.
  final String upstreams;
  final bool upstreamsCacheEnabled;

  /// The cache size as typed, in bytes.
  final String upstreamsCacheSize;
  final bool ignoreQueryLog;
  final bool ignoreStatistics;

  AdguardHomeClientDraft copyWith({
    String? name,
    List<String>? ids,
    List<String>? tags,
    bool? useGlobalSettings,
    bool? filteringEnabled,
    bool? safeBrowsingEnabled,
    bool? parentalEnabled,
    AdguardHomeSafeSearch? safeSearch,
    bool? useGlobalBlockedServices,
    List<String>? blockedServices,
    String? upstreams,
    bool? upstreamsCacheEnabled,
    String? upstreamsCacheSize,
    bool? ignoreQueryLog,
    bool? ignoreStatistics,
  }) =>
      AdguardHomeClientDraft(
        name: name ?? this.name,
        ids: ids ?? this.ids,
        tags: tags ?? this.tags,
        useGlobalSettings: useGlobalSettings ?? this.useGlobalSettings,
        filteringEnabled: filteringEnabled ?? this.filteringEnabled,
        safeBrowsingEnabled: safeBrowsingEnabled ?? this.safeBrowsingEnabled,
        parentalEnabled: parentalEnabled ?? this.parentalEnabled,
        safeSearch: safeSearch ?? this.safeSearch,
        useGlobalBlockedServices:
            useGlobalBlockedServices ?? this.useGlobalBlockedServices,
        blockedServices: blockedServices ?? this.blockedServices,
        upstreams: upstreams ?? this.upstreams,
        upstreamsCacheEnabled:
            upstreamsCacheEnabled ?? this.upstreamsCacheEnabled,
        upstreamsCacheSize: upstreamsCacheSize ?? this.upstreamsCacheSize,
        ignoreQueryLog: ignoreQueryLog ?? this.ignoreQueryLog,
        ignoreStatistics: ignoreStatistics ?? this.ignoreStatistics,
      );

  /// The identifiers that will be sent: trimmed, and no empty rows. The
  /// server refuses one with a space before or after it.
  List<String> get cleanIds => <String>[
        for (final String id in ids)
          if (id.trim().isNotEmpty) id.trim(),
      ];

  /// The upstream servers that will be sent, one per entry.
  List<String> get upstreamLines => <String>[
        for (final String line in upstreams.split('\n'))
          if (line.trim().isNotEmpty) line.trim(),
      ];

  /// The cache size as a number. Null when what was typed is none the
  /// server can hold. An empty field is zero.
  int? get cacheSize {
    final String text = upstreamsCacheSize.trim();
    if (text.isEmpty) return 0;
    final int? size = int.tryParse(text);
    if (size == null || size < 0 || size > adguardHomeMaxCacheSize) return null;
    return size;
  }

  /// What has to be put right before this can be sent.
  ///
  /// Only what the server gets wrong or says badly is checked here: it
  /// takes a name of spaces as a name, and answers a cache size it cannot
  /// hold with an error about its own code. An identifier it cannot read it
  /// names itself, in plain words.
  AdguardHomeClientProblems get problems => AdguardHomeClientProblems(
        name: name.trim().isEmpty ? 'Give the client a name.' : null,
        ids: cleanIds.isEmpty ? 'Add at least one identifier.' : null,
        cacheSize: cacheSize == null
            ? 'A whole number from 0 to $adguardHomeMaxCacheSize.'
            : null,
      );

  /// The settings the form shows, the way the server takes them.
  ///
  /// Tags and services are put in order, so that taking one off and putting
  /// it back is no change. Safe search goes in both the forms the server
  /// reads: the object, and the single switch servers from before it know.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name.trim(),
        'ids': cleanIds,
        'tags': <String>[...tags]..sort(),
        'use_global_settings': useGlobalSettings,
        'filtering_enabled': filteringEnabled,
        'safebrowsing_enabled': safeBrowsingEnabled,
        'parental_enabled': parentalEnabled,
        'safe_search': safeSearch.toJson(),
        'safesearch_enabled': safeSearch.enabled,
        'use_global_blocked_services': useGlobalBlockedServices,
        'blocked_services': <String>[...blockedServices]..sort(),
        'upstreams': upstreamLines,
        'upstreams_cache_enabled': upstreamsCacheEnabled,
        'upstreams_cache_size': cacheSize ?? 0,
        'ignore_querylog': ignoreQueryLog,
        'ignore_statistics': ignoreStatistics,
      };
}

/// What to send for a client that is not on the server yet.
///
/// Every setting is spelled out: what is left out the server takes as off,
/// so a client added with only a name would not use the global settings.
/// The pause schedule starts empty in the server's own time zone, as the
/// web UI starts it.
Map<String, dynamic> adguardHomeNewClient(AdguardHomeClientDraft draft) =>
    <String, dynamic>{
      ...draft.toJson(),
      'blocked_services_schedule': <String, dynamic>{'time_zone': 'Local'},
    };

/// What to send for a client that was changed in the form: [current], the
/// client as the server has it now, with the settings that differ between
/// [before], what the form started with, and [after], what it holds now.
///
/// The server resets whatever a write leaves out, so the whole object goes
/// back. Built this way, what the form does not show survives (the pause
/// schedule, anything a newer server adds), and so does a setting someone
/// changed elsewhere while the form was open, unless it was changed here
/// too. [current] is not changed.
Map<String, dynamic> adguardHomeClientWrite({
  required Map<String, dynamic> current,
  required AdguardHomeClientDraft before,
  required AdguardHomeClientDraft after,
}) {
  final Map<String, dynamic> was = before.toJson();
  return <String, dynamic>{
    ...current,
    for (final MapEntry<String, dynamic> setting in after.toJson().entries)
      if (!adguardHomeJsonEquals(was[setting.key], setting.value))
        setting.key: setting.value,
  };
}

/// Whether two values read from JSON, or built to be sent as it, hold the
/// same. The order of an object's properties does not count; a list's does.
bool adguardHomeJsonEquals(Object? a, Object? b) {
  if (a is Map<Object?, Object?> && b is Map<Object?, Object?>) {
    if (a.length != b.length) return false;
    for (final MapEntry<Object?, Object?> entry in a.entries) {
      if (!b.containsKey(entry.key)) return false;
      if (!adguardHomeJsonEquals(entry.value, b[entry.key])) return false;
    }
    return true;
  }
  if (a is List<Object?> && b is List<Object?>) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!adguardHomeJsonEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

/// The persistent client among [clients] that [id] belongs to: one that
/// lists it, or else the one with the narrowest range it is inside, which
/// is how the server picks. Null when it is nobody's.
///
/// This is what can be told without asking the server. A device that a
/// client names by its MAC address is not found by its IP address here.
AdguardHomeClient? adguardHomeClientOwning(
  List<AdguardHomeClient> clients,
  String id,
) {
  final String wanted = id.trim().toLowerCase();
  if (wanted.isEmpty) return null;
  for (final AdguardHomeClient client in clients) {
    for (final String own in client.ids) {
      if (own.toLowerCase() == wanted) return client;
    }
  }

  final List<int>? address = adguardHomeAddressBytes(wanted);
  if (address == null) return null;
  AdguardHomeClient? owner;
  int narrowest = -1;
  for (final AdguardHomeClient client in clients) {
    for (final String own in client.ids) {
      final int bits = _bitsOfRangeHolding(own, address);
      if (bits > narrowest) {
        narrowest = bits;
        owner = client;
      }
    }
  }
  return owner;
}

/// The bytes of an IP address of either kind, or null when [text] is none.
List<int>? adguardHomeAddressBytes(String text) {
  // What follows a percent sign names an interface.
  final String bare = text.split('%').first;
  try {
    return Uri.parseIPv4Address(bare);
  } on FormatException {
    // Not of the older kind. It may be of the newer.
  }
  try {
    return Uri.parseIPv6Address(bare);
  } on FormatException {
    return null;
  }
}

/// How many leading bits [range] fixes, when it is a range that [address]
/// is inside. Minus one when it is not a range, cannot be read, or does not
/// hold the address.
int _bitsOfRangeHolding(String range, List<int> address) {
  final int slash = range.indexOf('/');
  if (slash < 0) return -1;
  final List<int>? network = adguardHomeAddressBytes(range.substring(0, slash));
  final int? bits = int.tryParse(range.substring(slash + 1));
  if (network == null || bits == null) return -1;
  if (network.length != address.length) return -1;
  if (bits < 0 || bits > network.length * 8) return -1;

  final int whole = bits ~/ 8;
  for (int i = 0; i < whole; i++) {
    if (network[i] != address[i]) return -1;
  }
  final int rest = bits % 8;
  if (rest > 0) {
    final int mask = (0xff << (8 - rest)) & 0xff;
    if ((network[whole] & mask) != (address[whole] & mask)) return -1;
  }
  return bits;
}
