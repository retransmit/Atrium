import 'models/adguard_home_clients.dart';
import 'models/adguard_home_filters.dart';
import 'models/adguard_home_json.dart';

export 'models/adguard_home_json.dart' show adguardHomeJsonEquals;

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
    this.schedule = const AdguardHomeSchedule(),
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
        ignoreStatistics = false,
        // Empty, in the server's own time zone, as the web UI starts one.
        schedule = const AdguardHomeSchedule(timeZone: 'Local');

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
      schedule: AdguardHomeSchedule.fromJson(
        client.json['blocked_services_schedule'],
      ),
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

  /// When its own blocked services are let through. It applies only while
  /// the client does not use the global list.
  final AdguardHomeSchedule schedule;

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
    AdguardHomeSchedule? schedule,
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
        schedule: schedule ?? this.schedule,
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
        'blocked_services_schedule': schedule.toJson(),
      };
}

/// What to send for a client that is not on the server yet.
///
/// Every setting is spelled out: what is left out the server takes as off,
/// so a client added with only a name would not use the global settings.
Map<String, dynamic> adguardHomeNewClient(AdguardHomeClientDraft draft) =>
    draft.toJson();

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

/// An address [client] can be checked as. The server's Check a host takes
/// only an address for its client: not a name, a MAC address or a ClientID.
/// So the first address the client lists, or else the first in its first
/// range of the older kind; null when it has neither.
String? adguardHomeCheckAddressOf(AdguardHomeClient client) {
  for (final String id in client.ids) {
    if (!id.contains('/') && adguardHomeAddressBytes(id) != null) return id;
  }
  for (final String id in client.ids) {
    final int slash = id.indexOf('/');
    if (slash < 0) continue;
    final String start = id.substring(0, slash);
    final int? bits = int.tryParse(id.substring(slash + 1));
    final List<int>? network = adguardHomeAddressBytes(start);
    if (network == null || network.length != 4 || bits == null) continue;
    if (bits < 0 || bits > 32) continue;
    if (bits >= 31) return start;
    // Past the network's own address, which no device has.
    final int value = ((network[0] << 24) |
            (network[1] << 16) |
            (network[2] << 8) |
            network[3]) &
        (0xffffffff << (32 - bits)) &
        0xffffffff;
    final int host = value + 1;
    return <int>[
      (host >> 24) & 0xff,
      (host >> 16) & 0xff,
      (host >> 8) & 0xff,
      host & 0xff,
    ].join('.');
  }
  return null;
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

/// What is wrong with [text] as an IP address of the kind [version] says
/// (4, 6, or either when null), or null when it is one.
String? adguardHomeIpProblem(String text, {int? version}) {
  final List<int>? bytes = adguardHomeAddressBytes(text.trim());
  final bool fits = bytes != null &&
      (version == null ||
          (version == 4 && bytes.length == 4) ||
          (version == 6 && bytes.length == 16));
  if (fits) return null;
  return switch (version) {
    4 => 'An IPv4 address, such as 0.0.0.0.',
    6 => 'An IPv6 address, such as ::.',
    _ => 'An IP address.',
  };
}
