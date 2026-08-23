/// Models for the slice of Unraid's GraphQL schema Atrium reads.
///
/// Field names and value shapes come from real responses off a live 7.x
/// server rather than the published docs, which describe a flatter schema
/// than the one actually served.
library;

/// How warm a disk is running, as a band rather than a raw number.
///
/// The thresholds are Unraid's own defaults for disk temperature notifications
/// (warning at 45C, critical at 55C), so a disk this app calls warm is the same
/// disk the server would email about.
enum DiskHeat {
  /// No temperature reported, which is normal for a spun-down disk.
  unknown,
  cool,
  normal,
  warm,
  hot,
}

/// One disk in the array.
class UnraidDisk {
  const UnraidDisk({
    required this.name,
    this.size,
    this.status,
    this.temp,
  });

  factory UnraidDisk.fromJson(Map<String, dynamic> json) => UnraidDisk(
        name: json['name']?.toString() ?? '',
        size: json['size']?.toString(),
        status: json['status']?.toString(),
        // Spinning disks report null while parked, so absent is not zero.
        temp: json['temp'] is num ? (json['temp'] as num).toInt() : null,
      );

  final String name;

  /// Free-form as served: Unraid returns a human size, not a byte count.
  final String? size;

  /// `DISK_OK`, `DISK_DSBL`, and so on. Rendered through [statusLabel].
  final String? status;

  /// Celsius, or null when the disk is spun down or reports nothing.
  final int? temp;

  /// True only when Unraid actively says the disk is fine.
  ///
  /// An unknown status is not treated as healthy: a status this app has never
  /// seen is exactly the case where it should not reassure anyone.
  bool get isHealthy => status == 'DISK_OK';

  /// True for a parity disk, which holds no data and is listed separately.
  ///
  /// Unraid names them `parity` and `parity2`; there is no flag to read.
  bool get isParity => name.toLowerCase().startsWith('parity');

  /// Which temperature band this disk falls in. See [DiskHeat].
  DiskHeat get heat {
    final int? c = temp;
    if (c == null) return DiskHeat.unknown;
    if (c >= 55) return DiskHeat.hot;
    if (c >= 45) return DiskHeat.warm;
    if (c < 30) return DiskHeat.cool;
    return DiskHeat.normal;
  }

  /// `DISK_DSBL` reads as noise on a phone screen.
  String get statusLabel {
    final String raw = status ?? '';
    if (raw.isEmpty) return 'Unknown';
    return switch (raw) {
      'DISK_OK' => 'Healthy',
      'DISK_NP' => 'Not present',
      'DISK_NP_DSBL' || 'DISK_DSBL' => 'Disabled',
      'DISK_INVALID' => 'Invalid',
      'DISK_WRONG' => 'Wrong disk',
      'DISK_NP_MISSING' => 'Missing',
      'DISK_NEW' => 'New',
      _ => raw,
    };
  }
}

/// The array as a whole.
class UnraidArray {
  const UnraidArray({required this.state, this.disks = const <UnraidDisk>[]});

  factory UnraidArray.fromJson(Map<String, dynamic> json) => UnraidArray(
        state: json['state']?.toString() ?? '',
        disks: (json['disks'] as List<dynamic>? ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(UnraidDisk.fromJson)
            .toList(),
      );

  /// `STARTED`, `STOPPED`, and so on.
  final String state;
  final List<UnraidDisk> disks;

  bool get isStarted => state == 'STARTED';

  String get stateLabel {
    if (state.isEmpty) return 'Unknown';
    final String lower = state.toLowerCase().replaceAll('_', ' ');
    return lower[0].toUpperCase() + lower.substring(1);
  }

  /// Disks Unraid does not report as healthy.
  List<UnraidDisk> get unhealthyDisks =>
      disks.where((UnraidDisk d) => !d.isHealthy).toList();

  /// Parity disks, which are shown apart from the disks that hold data.
  List<UnraidDisk> get parityDisks =>
      disks.where((UnraidDisk d) => d.isParity).toList();

  /// Everything that is not parity.
  List<UnraidDisk> get dataDisks =>
      disks.where((UnraidDisk d) => !d.isParity).toList();

  /// The disk running warmest, or null when none is reporting a temperature.
  ///
  /// Spun-down disks report nothing, so this is the warmest disk currently
  /// awake rather than the warmest in the array.
  UnraidDisk? get warmestDisk {
    UnraidDisk? warmest;
    for (final UnraidDisk d in disks) {
      final int? t = d.temp;
      if (t == null) continue;
      if (warmest == null || t > warmest.temp!) warmest = d;
    }
    return warmest;
  }
}

/// One Docker container.
class UnraidContainer {
  const UnraidContainer({
    required this.id,
    required this.names,
    this.state,
    this.status,
    this.autoStart = false,
  });

  factory UnraidContainer.fromJson(Map<String, dynamic> json) =>
      UnraidContainer(
        id: json['id']?.toString() ?? '',
        names: (json['names'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic e) => e.toString())
            .toList(),
        state: json['state']?.toString(),
        status: json['status']?.toString(),
        autoStart: json['autoStart'] == true,
      );

  final String id;

  /// Docker reports names with a leading slash, as `/plex`.
  final List<String> names;

  /// `RUNNING` or `EXITED`.
  final String? state;

  /// Docker's own sentence, such as `Up 24 hours (healthy)`. Shown as given:
  /// it is written for people, and parsing it would only invent meaning.
  final String? status;

  final bool autoStart;

  bool get isRunning => state == 'RUNNING';

  /// The leading slash is Docker's, not part of the name anyone recognises.
  String get displayName {
    if (names.isEmpty) return id.isEmpty ? 'Unknown' : id;
    final String first = names.first;
    return first.startsWith('/') ? first.substring(1) : first;
  }

  /// True when Docker's status line says the container's healthcheck passes.
  bool get isHealthy => status?.contains('(healthy)') ?? false;

  /// True when a healthcheck is failing, which `state` alone does not show:
  /// an unhealthy container still reports RUNNING.
  bool get isUnhealthy => status?.contains('(unhealthy)') ?? false;
}
