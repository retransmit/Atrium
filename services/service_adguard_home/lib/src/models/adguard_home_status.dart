import 'adguard_home_json.dart';

/// Whether AdGuard Home is filtering right now.
enum AdguardHomeProtection {
  on,

  /// Off for a while, and coming back on by itself.
  paused,

  /// Off until someone turns it back on.
  off,
}

/// What `GET control/status` says about the server.
class AdguardHomeStatus {
  const AdguardHomeStatus({
    required this.version,
    required this.running,
    required this.protectionEnabled,
    required this.pauseLeft,
    required this.readAt,
    this.dnsAddresses = const <String>[],
    this.dnsPort = 53,
    this.httpPort = 80,
  });

  /// [readAt] is when the answer arrived. A pause is reported as time left
  /// rather than as a moment, so it only means something beside the time it
  /// was read.
  factory AdguardHomeStatus.fromJson(
    Map<String, dynamic> json, {
    required DateTime readAt,
  }) {
    return AdguardHomeStatus(
      version: readString(json['version']),
      running: readBool(json['running']),
      protectionEnabled: readBool(json['protection_enabled']),
      pauseLeft: Duration(
        milliseconds: readInt(json['protection_disabled_duration']),
      ),
      readAt: readAt,
      dnsAddresses: readStrings(json['dns_addresses']),
      dnsPort: json['dns_port'] == null ? 53 : readInt(json['dns_port']),
      httpPort: json['http_port'] == null ? 80 : readInt(json['http_port']),
    );
  }

  final String version;
  final bool running;
  final bool protectionEnabled;

  /// How long protection stays paused, counted from [readAt]. Zero while
  /// protection is on, and zero too when it was turned off with no timer.
  final Duration pauseLeft;
  final DateTime readAt;
  final List<String> dnsAddresses;
  final int dnsPort;
  final int httpPort;

  AdguardHomeProtection get protection {
    if (protectionEnabled) return AdguardHomeProtection.on;
    return pauseLeft > Duration.zero
        ? AdguardHomeProtection.paused
        : AdguardHomeProtection.off;
  }

  /// The moment a pause ends, or null when protection is not paused.
  DateTime? get pausedUntil => protection == AdguardHomeProtection.paused
      ? readAt.add(pauseLeft)
      : null;
}
