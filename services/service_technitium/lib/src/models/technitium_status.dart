import 'technitium_json.dart';

/// Whether Technitium DNS blocking is filtering right now.
enum TechnitiumProtection {
  on,

  /// Temporarily disabled for a duration, auto-resuming.
  paused,

  /// Disabled until explicitly enabled.
  off,
}

/// What `/api/status` or status polling reports about the server.
class TechnitiumStatus {
  const TechnitiumStatus({
    required this.version,
    required this.isBlockingEnabled,
    required this.readAt,
    this.pausedUntil,
    this.dnsServerDomain = '',
    this.uptimeSeconds = 0,
    this.serverIp = '',
  });

  factory TechnitiumStatus.fromJson(
    Map<String, dynamic> json, {
    required DateTime readAt,
    bool isBlockingEnabled = true,
    DateTime? pausedUntil,
  }) {
    final Map<String, dynamic> response =
        json['response'] is Map<String, dynamic>
            ? json['response'] as Map<String, dynamic>
            : json;

    final Object? rawPaused = response['temporaryDisableBlockingTill'];
    final DateTime? parsedPaused =
        rawPaused != null ? parseTechnitiumDate(rawPaused) : pausedUntil;

    final bool blocking = response.containsKey('enableBlocking')
        ? readBool(response['enableBlocking'])
        : isBlockingEnabled;

    return TechnitiumStatus(
      version: readString(response['version']),
      dnsServerDomain:
          readString(response['dnsServerDomain'] ?? response['serverDomain']),
      isBlockingEnabled: blocking,
      pausedUntil: parsedPaused,
      readAt: readAt,
      uptimeSeconds: readInt(response['uptime']),
      serverIp: readString(response['serverIp'] ?? response['ip']),
    );
  }

  final String version;
  final String dnsServerDomain;
  final bool isBlockingEnabled;
  final DateTime? pausedUntil;
  final DateTime readAt;
  final int uptimeSeconds;
  final String serverIp;

  TechnitiumProtection get protection {
    if (!isBlockingEnabled) return TechnitiumProtection.off;
    if (pausedUntil != null && pausedUntil!.isAfter(readAt)) {
      return TechnitiumProtection.paused;
    }
    return TechnitiumProtection.on;
  }

  Duration get pauseLeft {
    if (protection == TechnitiumProtection.paused && pausedUntil != null) {
      final Duration diff = pausedUntil!.difference(readAt);
      return diff > Duration.zero ? diff : Duration.zero;
    }
    return Duration.zero;
  }
}
