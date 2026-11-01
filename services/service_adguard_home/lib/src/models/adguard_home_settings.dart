import 'adguard_home_json.dart';

/// How long the query log or the statistics keep what they keep, and what
/// they leave out: `GET control/querylog/config` and `GET control/stats/config`.
///
/// Both are written whole (`PUT .../config/update`): the server refuses a
/// write that leaves a field out. What it sent that is not modelled here
/// goes back as it came, in [json].
class AdguardHomeRetention {
  const AdguardHomeRetention({
    this.json = const <String, dynamic>{},
    this.enabled = true,
    this.interval = const Duration(days: 1),
    this.ignored = const <String>[],
    this.ignoredEnabled = false,
    this.hasIgnoredSwitch = true,
    this.anonymizeClientIp,
  });

  factory AdguardHomeRetention.fromJson(Map<String, dynamic> json) =>
      AdguardHomeRetention(
        json: json,
        enabled: readBool(json['enabled']),
        interval: Duration(milliseconds: readInt(json['interval'])),
        ignored: readStrings(json['ignored']),
        // A server from before the switch always leaves the list out.
        ignoredEnabled: json.containsKey('ignored_enabled')
            ? readBool(json['ignored_enabled'])
            : true,
        hasIgnoredSwitch: json.containsKey('ignored_enabled'),
        anonymizeClientIp: json.containsKey('anonymize_client_ip')
            ? readBool(json['anonymize_client_ip'])
            : null,
      );

  /// The answer as read.
  final Map<String, dynamic> json;

  final bool enabled;
  final Duration interval;

  /// Rules for the queries that are not kept, one an entry.
  final List<String> ignored;

  /// Whether [ignored] is in force.
  final bool ignoredEnabled;

  /// Whether the server has a switch for [ignored]. One from before it
  /// always applies the list, and is sent no switch.
  final bool hasIgnoredSwitch;

  /// The query log's alone: whether client addresses are kept short. Null
  /// for the statistics.
  final bool? anonymizeClientIp;

  AdguardHomeRetention copyWith({
    bool? enabled,
    Duration? interval,
    List<String>? ignored,
    bool? ignoredEnabled,
    bool? anonymizeClientIp,
  }) =>
      AdguardHomeRetention(
        json: json,
        enabled: enabled ?? this.enabled,
        interval: interval ?? this.interval,
        ignored: ignored ?? this.ignored,
        ignoredEnabled: ignoredEnabled ?? this.ignoredEnabled,
        hasIgnoredSwitch: hasIgnoredSwitch,
        anonymizeClientIp: anonymizeClientIp ?? this.anonymizeClientIp,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        ...json,
        'enabled': enabled,
        'interval': interval.inMilliseconds,
        'ignored': ignored,
        if (hasIgnoredSwitch) 'ignored_enabled': ignoredEnabled,
        if (anonymizeClientIp != null) 'anonymize_client_ip': anonymizeClientIp,
      };
}

/// The longest the server keeps a query log or statistics: a year.
const int adguardHomeRetentionMaxHours = 365 * 24;

/// What is wrong with [hours] as a custom retention, or null when the
/// server takes it: whole hours from one to a year.
String? adguardHomeRetentionProblem(int? hours) {
  if (hours == null) return 'Enter a number of hours.';
  if (hours < 1 || hours > adguardHomeRetentionMaxHours) {
    return 'From 1 to $adguardHomeRetentionMaxHours hours.';
  }
  return null;
}

/// How the server picks among its upstream servers.
enum AdguardHomeUpstreamMode {
  loadBalance('load_balance', 'Load-balancing'),
  parallel('parallel', 'Parallel requests'),
  fastestAddress('fastest_addr', 'Fastest IP address');

  const AdguardHomeUpstreamMode(this.wire, this.label);

  /// As the server takes it. It reports load balancing as "".
  final String wire;
  final String label;

  static AdguardHomeUpstreamMode fromWire(String value) =>
      AdguardHomeUpstreamMode.values.firstWhere(
        (AdguardHomeUpstreamMode mode) => mode.wire == value,
        orElse: () => AdguardHomeUpstreamMode.loadBalance,
      );
}

/// What a blocked name is answered with.
enum AdguardHomeBlockingMode {
  normal('default', 'Default'),
  refused('refused', 'REFUSED'),
  nxdomain('nxdomain', 'NXDOMAIN'),
  nullIp('null_ip', 'Null IP'),
  customIp('custom_ip', 'Custom IP');

  const AdguardHomeBlockingMode(this.wire, this.label);

  final String wire;
  final String label;

  static AdguardHomeBlockingMode fromWire(String value) =>
      AdguardHomeBlockingMode.values.firstWhere(
        (AdguardHomeBlockingMode mode) => mode.wire == value,
        orElse: () => AdguardHomeBlockingMode.normal,
      );
}

/// The server's DNS settings, `GET control/dns_info`, kept as read.
///
/// `POST control/dns_config` takes only what is to change and keeps the
/// rest, so a screen sends [adguardHomeChangedSettings] of its part.
class AdguardHomeDnsConfig {
  const AdguardHomeDnsConfig(this.json);

  final Map<String, dynamic> json;

  List<String> get upstreams => readStrings(json['upstream_dns']);

  /// Where the upstreams are read from instead, when the server is set up
  /// that way. Then [upstreams] is not the list in force and is not sent.
  String get upstreamsFile => readString(json['upstream_dns_file']);
  List<String> get bootstrap => readStrings(json['bootstrap_dns']);
  List<String> get fallback => readStrings(json['fallback_dns']);
  AdguardHomeUpstreamMode get upstreamMode =>
      AdguardHomeUpstreamMode.fromWire(readString(json['upstream_mode']));

  /// Seconds.
  int get upstreamTimeout => readInt(json['upstream_timeout']);
  List<String> get privateUpstreams => readStrings(json['local_ptr_upstreams']);

  /// What the server falls back to for private reverse lookups. Read only.
  List<String> get defaultPrivateUpstreams =>
      readStrings(json['default_local_ptr_upstreams']);
  bool get usePrivatePtrResolvers => readBool(json['use_private_ptr_resolvers']);
  bool get resolveClients => readBool(json['resolve_clients']);

  /// Requests a second from one client; 0 is no limit.
  int get ratelimit => readInt(json['ratelimit']);
  int get ratelimitSubnetIpv4 => readInt(json['ratelimit_subnet_len_ipv4']);
  int get ratelimitSubnetIpv6 => readInt(json['ratelimit_subnet_len_ipv6']);
  List<String> get ratelimitWhitelist =>
      readStrings(json['ratelimit_whitelist']);
  bool get ednsEnabled => readBool(json['edns_cs_enabled']);
  bool get ednsUseCustom => readBool(json['edns_cs_use_custom']);
  String get ednsCustomIp => readString(json['edns_cs_custom_ip']);
  bool get dnssecEnabled => readBool(json['dnssec_enabled']);
  bool get disableIpv6 => readBool(json['disable_ipv6']);
  AdguardHomeBlockingMode get blockingMode =>
      AdguardHomeBlockingMode.fromWire(readString(json['blocking_mode']));
  String get blockingIpv4 => readString(json['blocking_ipv4']);
  String get blockingIpv6 => readString(json['blocking_ipv6']);

  /// Seconds.
  int get blockedResponseTtl => readInt(json['blocked_response_ttl']);
  bool get cacheEnabled => readBool(json['cache_enabled']);

  /// Bytes.
  int get cacheSize => readInt(json['cache_size']);

  /// Seconds; 0 leaves the TTL as the upstream gave it.
  int get cacheTtlMin => readInt(json['cache_ttl_min']);
  int get cacheTtlMax => readInt(json['cache_ttl_max']);
  bool get cacheOptimistic => readBool(json['cache_optimistic']);
}

/// Of the settings in [after], those that are not as in [before]: what a
/// partial write sends. A list in another order is a change.
Map<String, dynamic> adguardHomeChangedSettings(
  Map<String, dynamic> before,
  Map<String, dynamic> after,
) =>
    <String, dynamic>{
      for (final MapEntry<String, dynamic> setting in after.entries)
        if (!adguardHomeJsonEquals(before[setting.key], setting.value))
          setting.key: setting.value,
    };

/// DNS settings the server takes only together. Sent alone, a blocking
/// address or the custom EDNS address is ignored with a 200, and Custom IP
/// is refused unless its addresses come with it (probed on v0.107.79).
const List<Set<String>> adguardHomeDnsSettingGroups = <Set<String>>[
  <String>{'blocking_mode', 'blocking_ipv4', 'blocking_ipv6'},
  <String>{'edns_cs_enabled', 'edns_cs_use_custom', 'edns_cs_custom_ip'},
];

/// What a DNS write sends: the settings [after] has otherwise than
/// [before], and with any of a group of [adguardHomeDnsSettingGroups] the
/// rest of that group, as [after] has them.
Map<String, dynamic> adguardHomeDnsChanges(
  Map<String, dynamic> before,
  Map<String, dynamic> after,
) {
  final Map<String, dynamic> changes = adguardHomeChangedSettings(before, after);
  for (final Set<String> group in adguardHomeDnsSettingGroups) {
    if (!group.any(changes.containsKey)) continue;
    for (final String key in group) {
      if (after.containsKey(key)) changes[key] = after[key];
    }
  }
  return changes;
}

/// Whether encryption is set up, and how: `GET control/tls/status`.
///
/// The answer carries the certificate chain and the private key as text.
/// They are not read into this, so nothing here can show, keep or log them.
class AdguardHomeTlsStatus {
  const AdguardHomeTlsStatus({
    this.enabled = false,
    this.serverName = '',
    this.forceHttps = false,
    this.servePlainDns = true,
    this.portHttps = 0,
    this.portDnsOverTls = 0,
    this.portDnsOverQuic = 0,
    this.portDnsCrypt = 0,
    this.validCertificate = false,
    this.validChain = false,
    this.validKey = false,
    this.validPair = false,
    this.issuer = '',
    this.subject = '',
    this.keyType = '',
    this.dnsNames = const <String>[],
    this.notBefore,
    this.notAfter,
    this.warning = '',
  });

  factory AdguardHomeTlsStatus.fromJson(Map<String, dynamic> json) =>
      AdguardHomeTlsStatus(
        enabled: readBool(json['enabled']),
        serverName: readString(json['server_name']),
        forceHttps: readBool(json['force_https']),
        servePlainDns: json['serve_plain_dns'] != false,
        portHttps: readInt(json['port_https']),
        portDnsOverTls: readInt(json['port_dns_over_tls']),
        portDnsOverQuic: readInt(json['port_dns_over_quic']),
        portDnsCrypt: readInt(json['port_dnscrypt']),
        validCertificate: readBool(json['valid_cert']),
        validChain: readBool(json['valid_chain']),
        validKey: readBool(json['valid_key']),
        validPair: readBool(json['valid_pair']),
        issuer: readString(json['issuer']),
        subject: readString(json['subject']),
        keyType: readString(json['key_type']),
        dnsNames: readStrings(json['dns_names']),
        notBefore: _date(json['not_before']),
        notAfter: _date(json['not_after']),
        warning: readString(json['warning_validation']),
      );

  final bool enabled;
  final String serverName;
  final bool forceHttps;

  /// Whether plain DNS is still answered beside the encrypted kinds.
  final bool servePlainDns;
  final int portHttps;
  final int portDnsOverTls;
  final int portDnsOverQuic;

  /// 0 when DNSCrypt is not served.
  final int portDnsCrypt;
  final bool validCertificate;
  final bool validChain;
  final bool validKey;
  final bool validPair;
  final String issuer;
  final String subject;
  final String keyType;
  final List<String> dnsNames;
  final DateTime? notBefore;
  final DateTime? notAfter;

  /// What the server found wrong with the certificate or key.
  final String warning;

  @override
  String toString() => 'AdguardHomeTlsStatus(enabled: $enabled, '
      'serverName: $serverName, notAfter: $notAfter)';
}

/// A date the server sends, or null for its zero date ("0001-01-01...").
DateTime? _date(Object? value) {
  final DateTime? date = DateTime.tryParse(readString(value));
  if (date == null || date.year <= 1) return null;
  return date;
}

/// The server's DHCP: `GET control/dhcp/status`. Read only here.
class AdguardHomeDhcpStatus {
  const AdguardHomeDhcpStatus({
    this.enabled = false,
    this.interfaceName = '',
    this.v4 = const AdguardHomeDhcpRange(),
    this.v6 = const AdguardHomeDhcpRange(),
    this.leases = const <AdguardHomeDhcpLease>[],
    this.staticLeases = const <AdguardHomeDhcpLease>[],
  });

  factory AdguardHomeDhcpStatus.fromJson(Map<String, dynamic> json) =>
      AdguardHomeDhcpStatus(
        enabled: readBool(json['enabled']),
        interfaceName: readString(json['interface_name']),
        v4: AdguardHomeDhcpRange.fromJson(json['v4']),
        v6: AdguardHomeDhcpRange.fromJson(json['v6']),
        leases: AdguardHomeDhcpLease.listFromJson(json['leases']),
        staticLeases: AdguardHomeDhcpLease.listFromJson(json['static_leases']),
      );

  final bool enabled;
  final String interfaceName;
  final AdguardHomeDhcpRange v4;
  final AdguardHomeDhcpRange v6;
  final List<AdguardHomeDhcpLease> leases;
  final List<AdguardHomeDhcpLease> staticLeases;
}

/// The addresses DHCP hands out over one IP version. IPv6 has only a start.
class AdguardHomeDhcpRange {
  const AdguardHomeDhcpRange({
    this.gateway = '',
    this.subnetMask = '',
    this.rangeStart = '',
    this.rangeEnd = '',
    this.leaseDuration = Duration.zero,
  });

  factory AdguardHomeDhcpRange.fromJson(Object? json) {
    if (json is! Map<Object?, Object?>) return const AdguardHomeDhcpRange();
    return AdguardHomeDhcpRange(
      gateway: readString(json['gateway_ip']),
      subnetMask: readString(json['subnet_mask']),
      rangeStart: readString(json['range_start']),
      rangeEnd: readString(json['range_end']),
      leaseDuration: Duration(seconds: readInt(json['lease_duration'])),
    );
  }

  final String gateway;
  final String subnetMask;
  final String rangeStart;
  final String rangeEnd;
  final Duration leaseDuration;
}

/// An address handed out, or set aside for one device (a static lease,
/// which does not expire).
class AdguardHomeDhcpLease {
  const AdguardHomeDhcpLease({
    required this.mac,
    required this.ip,
    this.hostname = '',
    this.expires,
  });

  static List<AdguardHomeDhcpLease> listFromJson(Object? json) =>
      <AdguardHomeDhcpLease>[
        if (json is List)
          for (final Object? row in json)
            if (row is Map<Object?, Object?>)
              AdguardHomeDhcpLease(
                mac: readString(row['mac']),
                ip: readString(row['ip']),
                hostname: readString(row['hostname']),
                expires: _date(row['expires']),
              ),
      ];

  final String mac;
  final String ip;
  final String hostname;
  final DateTime? expires;
}

/// Whether a newer AdGuard Home is out: `POST control/version.json`.
class AdguardHomeVersionCheck {
  const AdguardHomeVersionCheck({
    this.disabled = false,
    this.newVersion = '',
    this.announcement = '',
    this.announcementUrl = '',
  });

  factory AdguardHomeVersionCheck.fromJson(Map<String, dynamic> json) =>
      AdguardHomeVersionCheck(
        disabled: readBool(json['disabled']),
        newVersion: readString(json['new_version']),
        announcement: readString(json['announcement']),
        announcementUrl: readString(json['announcement_url']),
      );

  /// The server's own update check is off, so it says nothing of versions.
  final bool disabled;
  final String newVersion;
  final String announcement;
  final String announcementUrl;

  /// Whether [newVersion] is another version than [current], as the web UI
  /// judges it: the same but for a leading "v" is the same.
  bool isNewerThan(String current) {
    if (newVersion.isEmpty) return false;
    String bare(String version) =>
        version.startsWith('v') ? version.substring(1) : version;
    return bare(newVersion) != bare(current);
  }
}

/// What one server said when the upstreams were tested.
class AdguardHomeUpstreamResult {
  const AdguardHomeUpstreamResult(this.server, this.message);

  /// `POST control/test_upstream_dns`: one entry per server, "OK" or why
  /// not.
  static List<AdguardHomeUpstreamResult> listFromJson(Object? json) =>
      <AdguardHomeUpstreamResult>[
        if (json is Map<Object?, Object?>)
          for (final MapEntry<Object?, Object?> entry in json.entries)
            if (entry.key case final String server)
              AdguardHomeUpstreamResult(server, readString(entry.value)),
      ];

  final String server;
  final String message;

  bool get ok => message == 'OK';
}

/// The largest number the server keeps in its 32-bit settings.
const int adguardHomeMaxUint32 = 4294967295;

/// What is wrong with [text] as a whole number from [min] to [max], or null
/// when it is one.
String? adguardHomeWholeNumberProblem(
  String text, {
  int min = 0,
  int max = adguardHomeMaxUint32,
}) {
  final int? value = int.tryParse(text.trim());
  if (value == null) return 'Enter a number.';
  if (value < min || value > max) return 'From $min to $max.';
  return null;
}
