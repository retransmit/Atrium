/// Represents the system and integration status of a Cleanuparr instance.
class CleanuparrStatus {
  const CleanuparrStatus({
    required this.version,
    required this.appName,
    this.branch,
    this.startTime,
    this.memoryUsageMB,
    this.mediaManagers = const <CleanuparrManagerStatus>[],
    this.downloadClients = const <CleanuparrClientStatus>[],
  });

  final String version;
  final String appName;
  final String? branch;
  final DateTime? startTime;
  final double? memoryUsageMB;
  final List<CleanuparrManagerStatus> mediaManagers;
  final List<CleanuparrClientStatus> downloadClients;

  factory CleanuparrStatus.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? app =
        json['application'] is Map<String, dynamic>
            ? json['application'] as Map<String, dynamic>
            : (json['app'] is Map<String, dynamic>
                ? json['app'] as Map<String, dynamic>
                : null);

    final String version =
        app?['version']?.toString() ??
        json['version']?.toString() ??
        'Unknown';

    final String appName =
        app?['appName']?.toString() ??
        app?['name']?.toString() ??
        'Cleanuparr';

    final String? branch =
        app?['branch']?.toString() ?? json['branch']?.toString();

    DateTime? startTime;
    final dynamic rawStart = app?['startTime'] ?? json['startTime'];
    if (rawStart != null) {
      startTime = DateTime.tryParse(rawStart.toString());
    }

    double? mem;
    final dynamic rawMem =
        app?['memoryUsageMB'] ??
        app?['memoryMb'] ??
        json['memoryUsageMB'] ??
        json['memoryUsage'];
    if (rawMem is num) {
      mem = rawMem.toDouble();
      // If provided in raw bytes (e.g. > 1 MB in bytes), convert to megabytes
      if (mem > 1000000) {
        mem = mem / (1024 * 1024);
      }
    } else if (rawMem != null) {
      mem = double.tryParse(rawMem.toString());
      if (mem != null && mem > 1000000) {
        mem = mem / (1024 * 1024);
      }
    }

    final List<CleanuparrManagerStatus> managers = <CleanuparrManagerStatus>[];
    final dynamic rawManagers = json['mediaManagers'] ?? json['arrs'];
    if (rawManagers is Map) {
      for (final MapEntry<dynamic, dynamic> entry in rawManagers.entries) {
        final String name = entry.key.toString();
        final dynamic val = entry.value;
        int count = 1;
        if (val is Map) {
          count = val['instanceCount'] as int? ?? val['count'] as int? ?? 1;
        }
        if (count > 0) {
          managers.add(
            CleanuparrManagerStatus(
              name: name,
              type: name,
            ),
          );
        }
      }
    } else if (rawManagers is List) {
      for (final dynamic item in rawManagers) {
        if (item is Map<String, dynamic>) {
          managers.add(CleanuparrManagerStatus.fromJson(item));
        }
      }
    }

    final List<CleanuparrClientStatus> clients = <CleanuparrClientStatus>[];
    final dynamic rawClients = json['downloadClients'] ?? json['clients'] ?? json['Clients'];
    if (rawClients is List) {
      for (final dynamic item in rawClients) {
        if (item is Map<String, dynamic>) {
          clients.add(CleanuparrClientStatus.fromJson(item));
        }
      }
    }

    return CleanuparrStatus(
      version: version,
      appName: appName,
      branch: branch,
      startTime: startTime,
      memoryUsageMB: mem,
      mediaManagers: List<CleanuparrManagerStatus>.unmodifiable(managers),
      downloadClients: List<CleanuparrClientStatus>.unmodifiable(clients),
    );
  }
}

class CleanuparrManagerStatus {
  const CleanuparrManagerStatus({
    required this.name,
    required this.type,
    this.enabled = true,
    this.health = 'Healthy',
  });

  final String name;
  final String type;
  final bool enabled;
  final String health;

  factory CleanuparrManagerStatus.fromJson(Map<String, dynamic> json) {
    return CleanuparrManagerStatus(
      name: json['name']?.toString() ?? 'Media Manager',
      type: json['type']?.toString() ?? 'Arr',
      enabled: json['enabled'] as bool? ?? true,
      health: json['health']?.toString() ??
          (json['status']?.toString() ?? 'Healthy'),
    );
  }
}

class CleanuparrClientStatus {
  const CleanuparrClientStatus({
    required this.name,
    required this.type,
    this.enabled = true,
    this.health = 'Healthy',
  });

  final String name;
  final String type;
  final bool enabled;
  final String health;

  factory CleanuparrClientStatus.fromJson(Map<String, dynamic> json) {
    return CleanuparrClientStatus(
      name: json['name']?.toString() ?? 'Download Client',
      type: json['type']?.toString() ?? 'Client',
      enabled: json['enabled'] as bool? ?? true,
      health: json['health']?.toString() ??
          (json['status']?.toString() ?? 'Healthy'),
    );
  }
}
