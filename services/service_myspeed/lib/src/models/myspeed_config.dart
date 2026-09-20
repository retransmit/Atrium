/// Configuration info returned from MySpeed `/api/config`.
class MySpeedConfig {
  const MySpeedConfig({
    required this.entries,
    this.cron,
    this.provider,
    this.server,
    this.raw,
  });

  /// All configuration properties as a key-value map.
  final Map<String, dynamic> entries;

  /// Cron expression for automated speed tests, if defined.
  final String? cron;

  /// Underlying speed test provider (e.g. 'ookla', 'librespeed', 'cloudflare').
  final String? provider;

  /// Server or host name if configured.
  final String? server;

  /// Raw payload from API.
  final dynamic raw;

  factory MySpeedConfig.fromResponse(dynamic data) {
    final Map<String, dynamic> map = <String, dynamic>{};

    if (data is Map) {
      for (final MapEntry<dynamic, dynamic> entry in data.entries) {
        map[entry.key.toString()] = entry.value;
      }
    } else if (data is List) {
      for (final dynamic item in data) {
        if (item is Map) {
          final dynamic key = item['key'] ?? item['name'] ?? item['id'];
          final dynamic val = item['value'] ?? item['val'];
          if (key != null) {
            map[key.toString()] = val;
          }
        }
      }
    }

    final String? cron = map['cron']?.toString() ??
        map['schedule']?.toString() ??
        map['interval']?.toString();

    final String? provider = map['provider']?.toString() ??
        map['speedtest_provider']?.toString() ??
        map['type']?.toString();

    final String? server = map['server']?.toString() ??
        map['hostname']?.toString() ??
        map['name']?.toString();

    return MySpeedConfig(
      entries: map,
      cron: cron,
      provider: provider,
      server: server,
      raw: data,
    );
  }
}
