/// Models for the slice of Unraid's GraphQL schema Atrium reads.
///
/// Shapes come from a live Unraid 7.3 server rather than the published docs.
/// Two differences drive most of this file: the array hands back its disks in
/// three separate lists rather than one, and every size is a count of
/// kilobytes, not the human string an earlier reading of an obfuscated sample
/// suggested.
library;

/// Renders a count of kilobytes the way Unraid's own UI does.
///
/// Unraid reports storage in kilobytes, so this starts a step up from bytes.
/// The metrics endpoint reports memory in bytes instead, which is what
/// [unraidFmtBytes] is for. Mixing the two silently misreports by 1024x, so
/// they are kept as separate calls rather than one with a flag.
String unraidFmtKb(int? kilobytes) =>
    _scale(kilobytes, const <String>['KB', 'MB', 'GB', 'TB', 'PB']);

/// Renders a count of bytes, as the metrics endpoint reports memory.
String unraidFmtBytes(int? bytes) =>
    _scale(bytes, const <String>['B', 'KB', 'MB', 'GB', 'TB', 'PB']);

/// Powers of 1024, to match the numbers the server prints beside them.
String _scale(int? value, List<String> units) {
  final int? v = value;
  if (v == null) return '';
  if (v <= 0) return '0 ${units.first}';
  double scaled = v.toDouble();
  int unit = 0;
  while (scaled >= 1024 && unit < units.length - 1) {
    scaled /= 1024;
    unit++;
  }
  final String text = scaled >= 100 || unit == 0
      ? scaled.toStringAsFixed(0)
      : scaled.toStringAsFixed(1);
  return '$text ${units[unit]}';
}

/// Reads a GraphQL `BigInt`.
///
/// The scalar is serialised as a plain number while it fits one exactly and as
/// a string once it does not, so a disk large enough to matter is precisely
/// the one that would arrive in the other form. Both are accepted.
int? _bigInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw);
  return null;
}

/// How warm a disk is running, as a band rather than a raw number.
enum DiskHeat {
  /// No temperature reported, which is normal for a spun-down disk.
  unknown,
  cool,
  normal,
  warm,
  hot,
}

/// One disk, whether it holds data, parity, or sits in a cache pool.
class UnraidDisk {
  const UnraidDisk({
    required this.name,
    this.idx,
    this.type,
    this.device,
    this.sizeKb,
    this.status,
    this.temp,
    this.fsType,
    this.fsSizeKb,
    this.fsFreeKb,
    this.fsUsedKb,
    this.isSpinning,
    this.warning,
    this.critical,
    this.numErrors,
  });

  factory UnraidDisk.fromJson(Map<String, dynamic> json) => UnraidDisk(
        name: json['name']?.toString() ?? '',
        idx: json['idx'] is num ? (json['idx'] as num).toInt() : null,
        type: json['type']?.toString(),
        device: json['device']?.toString(),
        sizeKb: _bigInt(json['size']),
        status: json['status']?.toString(),
        // Spinning disks report null while parked, so absent is not zero.
        temp: json['temp'] is num ? (json['temp'] as num).toInt() : null,
        fsType: json['fsType']?.toString(),
        fsSizeKb: _bigInt(json['fsSize']),
        fsFreeKb: _bigInt(json['fsFree']),
        fsUsedKb: _bigInt(json['fsUsed']),
        isSpinning: json['isSpinning'] is bool ? json['isSpinning'] as bool : null,
        warning: json['warning'] is num ? (json['warning'] as num).toInt() : null,
        critical: json['critical'] is num ? (json['critical'] as num).toInt() : null,
        numErrors: _bigInt(json['numErrors']),
      );

  final String name;

  /// The disk's slot. Parity is 0, data disks count up from 1.
  final int? idx;

  /// `DATA`, `PARITY`, `CACHE`, `BOOT` or `FLASH`.
  final String? type;

  /// The kernel name, such as `sdc`. Useful when a disk has no label yet.
  final String? device;

  /// Raw capacity in kilobytes, which is the unit Unraid reports.
  final int? sizeKb;

  /// `DISK_OK`, `DISK_DSBL`, and so on. Rendered through [statusLabel].
  final String? status;

  /// Celsius, or null when the disk is spun down or reports nothing.
  final int? temp;

  /// `xfs`, `btrfs`, `zfs`. Null on parity, which carries no filesystem.
  final String? fsType;

  /// Filesystem totals in kilobytes. All null on a parity disk, and on a data
  /// disk that has not been formatted yet.
  final int? fsSizeKb;
  final int? fsFreeKb;
  final int? fsUsedKb;

  /// Whether the platters are turning. Null when the server cannot tell.
  final bool? isSpinning;

  /// This disk's own temperature thresholds, when the user has overridden the
  /// server-wide defaults. Null means fall back to those defaults.
  final int? warning;
  final int? critical;

  /// Read and write errors the array has recorded against this disk.
  final int? numErrors;

  /// True only when Unraid actively says the disk is fine.
  ///
  /// An unknown status is not treated as healthy: a status this app has never
  /// seen is exactly the case where it should not reassure anyone.
  bool get isHealthy => status == 'DISK_OK';

  /// True for a parity disk, which holds no filesystem of its own.
  ///
  /// `type` is the server's own answer, so it is trusted first. The name check
  /// behind it only covers a response that omitted the field.
  bool get isParity =>
      type == null ? name.toLowerCase().startsWith('parity') : type == 'PARITY';

  /// Which temperature band this disk falls in. See [DiskHeat].
  ///
  /// A disk with its own thresholds is judged by those rather than the
  /// defaults, so a disk this app calls warm is the same disk the server would
  /// email about.
  DiskHeat get heat {
    final int? c = temp;
    if (c == null) return DiskHeat.unknown;
    // Unraid's own defaults: warn at 45C, critical at 55C.
    if (c >= (critical ?? 55)) return DiskHeat.hot;
    if (c >= (warning ?? 45)) return DiskHeat.warm;
    if (c < 30) return DiskHeat.cool;
    return DiskHeat.normal;
  }

  /// Capacity as a phrase, or an empty string when the server gave no size.
  String get sizeLabel => unraidFmtKb(sizeKb);

  /// How full the filesystem is, 0 to 1, or null when there is not one.
  ///
  /// Parity disks and unformatted disks both report nothing here, and neither
  /// should be drawn as an empty bar: that would read as plenty of room.
  double? get usedFraction {
    final int? size = fsSizeKb;
    final int? used = fsUsedKb;
    if (size == null || used == null || size <= 0) return null;
    return (used / size).clamp(0.0, 1.0);
  }

  /// `disk1 - 3.2 GB of 5.0 GB used`, or null when there is no filesystem.
  String? get usageLabel {
    final int? size = fsSizeKb;
    final int? used = fsUsedKb;
    if (size == null || used == null || size <= 0) return null;
    return '${unraidFmtKb(used)} of ${unraidFmtKb(size)}';
  }

  /// `DISK_DSBL` reads as noise on a phone screen.
  String get statusLabel {
    final String raw = status ?? '';
    if (raw.isEmpty) return 'Unknown';
    return switch (raw) {
      'DISK_OK' => 'Healthy',
      'DISK_NP' => 'Not present',
      'DISK_NP_DSBL' || 'DISK_DSBL' => 'Disabled',
      'DISK_DSBL_NEW' => 'Disabled, new disk',
      'DISK_INVALID' => 'Invalid',
      'DISK_WRONG' => 'Wrong disk',
      'DISK_NP_MISSING' => 'Missing',
      'DISK_NEW' => 'New',
      _ => raw,
    };
  }
}

/// The state of the last, or currently running, parity check.
class UnraidParityCheck {
  const UnraidParityCheck({
    this.status,
    this.progress,
    this.errors,
    this.date,
    this.duration,
    this.correcting,
    this.running,
    this.paused,
  });

  factory UnraidParityCheck.fromJson(Map<String, dynamic> json) =>
      UnraidParityCheck(
        status: json['status']?.toString(),
        progress:
            json['progress'] is num ? (json['progress'] as num).toInt() : null,
        errors: json['errors'] is num ? (json['errors'] as num).toInt() : null,
        date: DateTime.tryParse(json['date']?.toString() ?? ''),
        duration:
            json['duration'] is num ? (json['duration'] as num).toInt() : null,
        correcting:
            json['correcting'] is bool ? json['correcting'] as bool : null,
        running: json['running'] is bool ? json['running'] as bool : null,
        paused: json['paused'] is bool ? json['paused'] as bool : null,
      );

  /// `NEVER_RUN`, `RUNNING`, `PAUSED`, `COMPLETED`, `CANCELLED` or `FAILED`.
  final String? status;

  /// Percent complete while a check is running.
  final int? progress;

  /// Errors the check found. Null rather than zero when it has not run.
  final int? errors;

  /// When the last check finished.
  final DateTime? date;

  /// How long the last check took, in seconds.
  final int? duration;

  /// The three flags below are left null by a server that is not mid-check,
  /// so none of them can stand in for the status on its own.
  final bool? correcting;
  final bool? running;
  final bool? paused;

  /// True while a check is actually under way.
  ///
  /// A live server leaves `running` null unless a check is in progress, so the
  /// status is the dependable signal and the flag only reinforces it.
  bool get isRunning => running == true || status == 'RUNNING';

  bool get isPaused => paused == true || status == 'PAUSED';

  /// True when the last check found something, which is the whole point of
  /// running one and the only case worth putting on screen unprompted.
  bool get foundErrors => (errors ?? 0) > 0;

  /// Plain words for the status, or null when the server has said nothing.
  String? get statusLabel => switch (status) {
        null || '' => null,
        'NEVER_RUN' => 'Never run',
        'RUNNING' => 'Running',
        'PAUSED' => 'Paused',
        'COMPLETED' => 'Completed',
        'CANCELLED' => 'Cancelled',
        'FAILED' => 'Failed',
        _ => status,
      };
}

/// The array as a whole.
///
/// Unraid splits its disks three ways and Atrium keeps that split rather than
/// flattening it: parity holds no data, cache pools live outside the array's
/// capacity, and merging them would misreport both.
class UnraidArray {
  const UnraidArray({
    required this.state,
    this.parities = const <UnraidDisk>[],
    this.disks = const <UnraidDisk>[],
    this.caches = const <UnraidDisk>[],
    this.parityCheck,
    this.freeKb,
    this.usedKb,
    this.totalKb,
  });

  factory UnraidArray.fromJson(Map<String, dynamic> json) {
    List<UnraidDisk> read(String key) =>
        (json[key] as List<dynamic>? ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(UnraidDisk.fromJson)
            .toList();

    // Capacity is nested two deep and its numbers are strings, unlike the
    // BigInt sizes on the disks themselves.
    final dynamic capacity = json['capacity'];
    final dynamic kilobytes =
        capacity is Map<String, dynamic> ? capacity['kilobytes'] : null;
    final Map<String, dynamic> kb =
        kilobytes is Map<String, dynamic> ? kilobytes : <String, dynamic>{};

    final dynamic check = json['parityCheckStatus'];

    return UnraidArray(
      state: json['state']?.toString() ?? '',
      parities: read('parities'),
      disks: read('disks'),
      caches: read('caches'),
      parityCheck: check is Map<String, dynamic>
          ? UnraidParityCheck.fromJson(check)
          : null,
      freeKb: _bigInt(kb['free']),
      usedKb: _bigInt(kb['used']),
      totalKb: _bigInt(kb['total']),
    );
  }

  /// `STARTED`, `STOPPED`, `TOO_MANY_MISSING_DISKS` and so on.
  final String state;

  /// Parity disks, which protect the array but store none of it.
  final List<UnraidDisk> parities;

  /// The disks that hold data. This is the array's capacity.
  final List<UnraidDisk> disks;

  /// Cache pool members, which sit outside the array and its parity.
  final List<UnraidDisk> caches;

  final UnraidParityCheck? parityCheck;

  /// Array totals in kilobytes, covering the data disks only.
  final int? freeKb;
  final int? usedKb;
  final int? totalKb;

  bool get isStarted => state == 'STARTED';

  String get stateLabel {
    if (state.isEmpty) return 'Unknown';
    final String lower = state.toLowerCase().replaceAll('_', ' ');
    return lower[0].toUpperCase() + lower.substring(1);
  }

  /// Every disk the server reported, in the order it presents them.
  List<UnraidDisk> get allDisks => <UnraidDisk>[...parities, ...disks, ...caches];

  /// Disks Unraid does not report as healthy, parity and cache included: a
  /// failed parity disk is exactly the one you want to hear about.
  List<UnraidDisk> get unhealthyDisks =>
      allDisks.where((UnraidDisk d) => !d.isHealthy).toList();

  /// The disk running warmest, or null when none is reporting a temperature.
  ///
  /// Spun-down disks report nothing, so this is the warmest disk currently
  /// awake rather than the warmest in the array.
  UnraidDisk? get warmestDisk {
    UnraidDisk? warmest;
    for (final UnraidDisk d in allDisks) {
      final int? t = d.temp;
      if (t == null) continue;
      if (warmest == null || t > warmest.temp!) warmest = d;
    }
    return warmest;
  }

  /// How full the array is, 0 to 1, or null when the server reported nothing.
  ///
  /// A freshly formatted array reports a total of zero, which would divide to
  /// nothing useful, so that is treated as unknown rather than empty.
  double? get usedFraction {
    final int? total = totalKb;
    final int? used = usedKb;
    if (total == null || used == null || total <= 0) return null;
    return (used / total).clamp(0.0, 1.0);
  }

  /// `4.0 GB of 12.1 GB used`, or null when there are no totals to show.
  String? get usageLabel {
    final int? total = totalKb;
    final int? used = usedKb;
    if (total == null || used == null || total <= 0) return null;
    return '${unraidFmtKb(used)} of ${unraidFmtKb(total)}';
  }
}

/// One port a container publishes.
class UnraidPort {
  const UnraidPort({this.privatePort, this.publicPort, this.type});

  factory UnraidPort.fromJson(Map<String, dynamic> json) => UnraidPort(
        privatePort: json['privatePort'] is num
            ? (json['privatePort'] as num).toInt()
            : null,
        publicPort: json['publicPort'] is num
            ? (json['publicPort'] as num).toInt()
            : null,
        type: json['type']?.toString(),
      );

  /// The port inside the container.
  final int? privatePort;

  /// The port on the host, or null when the port is not published outside.
  final int? publicPort;

  /// `TCP` or `UDP`.
  final String? type;
}

/// One Docker container.
class UnraidContainer {
  const UnraidContainer({
    required this.id,
    required this.names,
    this.image,
    this.state,
    this.status,
    this.autoStart = false,
    this.isOrphaned = false,
    this.isUpdateAvailable,
    this.iconUrl,
    this.webUiUrl,
    this.ports = const <UnraidPort>[],
  });

  factory UnraidContainer.fromJson(Map<String, dynamic> json) =>
      UnraidContainer(
        id: json['id']?.toString() ?? '',
        names: (json['names'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic e) => e.toString())
            .toList(),
        image: json['image']?.toString(),
        state: json['state']?.toString(),
        status: json['status']?.toString(),
        autoStart: json['autoStart'] == true,
        isOrphaned: json['isOrphaned'] == true,
        isUpdateAvailable: json['isUpdateAvailable'] is bool
            ? json['isUpdateAvailable'] as bool
            : null,
        iconUrl: json['iconUrl']?.toString(),
        webUiUrl: json['webUiUrl']?.toString(),
        ports: (json['ports'] as List<dynamic>? ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(UnraidPort.fromJson)
            .toList(),
      );

  /// Unraid's own identifier, which pairs the server id with the container id.
  /// Mutations take this whole string, not the bare Docker id inside it.
  final String id;

  /// Docker reports names with a leading slash, as `/plex`.
  final List<String> names;

  final String? image;

  /// `RUNNING`, `PAUSED` or `EXITED`.
  final String? state;

  /// Docker's own sentence, such as `Up 24 hours (healthy)`. Shown as given:
  /// it is written for people, and parsing it would only invent meaning.
  final String? status;

  final bool autoStart;

  /// True when no Unraid template matches the container, which is normal for
  /// anything created outside the web UI and costs it its icon and web link.
  final bool isOrphaned;

  final bool? isUpdateAvailable;

  /// Taken from the container's Unraid template, so both are null while it is
  /// orphaned.
  final String? iconUrl;
  final String? webUiUrl;

  final List<UnraidPort> ports;

  bool get isRunning => state == 'RUNNING';

  /// Paused is neither running nor stopped: the process is still there, frozen.
  /// Folding it into either would misreport what a resume would do.
  bool get isPaused => state == 'PAUSED';

  /// True when the container is not doing anything, paused included.
  bool get isStopped => !isRunning;

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

  /// The published ports, as `8989, 7878`. Ports the container exposes but
  /// does not publish are left out: nothing outside the host can reach them.
  String? get publishedPortsLabel {
    final List<int> published = ports
        .map((UnraidPort p) => p.publicPort)
        .whereType<int>()
        .toList()
      ..sort();
    return published.isEmpty ? null : published.join(', ');
  }
}

/// One logical CPU.
class UnraidCpuCore {
  const UnraidCpuCore({
    this.percentTotal,
    this.percentUser,
    this.percentSystem,
    this.percentIdle,
  });

  factory UnraidCpuCore.fromJson(Map<String, dynamic> json) => UnraidCpuCore(
        percentTotal: _double(json['percentTotal']),
        percentUser: _double(json['percentUser']),
        percentSystem: _double(json['percentSystem']),
        percentIdle: _double(json['percentIdle']),
      );

  final double? percentTotal;
  final double? percentUser;
  final double? percentSystem;
  final double? percentIdle;
}

/// Processor load across the whole machine and per core.
class UnraidCpu {
  const UnraidCpu({this.percentTotal, this.cores = const <UnraidCpuCore>[]});

  factory UnraidCpu.fromJson(Map<String, dynamic> json) => UnraidCpu(
        percentTotal: _double(json['percentTotal']),
        cores: (json['cpus'] as List<dynamic>? ?? <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(UnraidCpuCore.fromJson)
            .toList(),
      );

  /// Load across every core, 0 to 100.
  final double? percentTotal;

  final List<UnraidCpuCore> cores;

  int get coreCount => cores.length;

  /// The load on the busiest core.
  ///
  /// Worth showing beside the average, because they part company in the case
  /// that matters: one core pinned while the rest idle is a single-threaded
  /// job holding everything up, and the average alone reads as a quiet
  /// machine.
  double? get busiestCorePercent {
    double? peak;
    for (final UnraidCpuCore c in cores) {
      final double? p = c.percentTotal;
      if (p == null) continue;
      if (peak == null || p > peak) peak = p;
    }
    return peak;
  }
}

/// Memory as the server accounts for it.
///
/// The important part is what counts as used. Linux's `used` includes the
/// buffers and cache it hands straight back the moment anything asks, so
/// reading that as memory in use reports a machine sitting at 82% when it is
/// really at 24%. What is actually committed is total minus available, which
/// is the figure the server itself computes for `percentTotal`, so that is
/// what this exposes and what the screen draws.
class UnraidMemory {
  const UnraidMemory({
    this.totalBytes,
    this.usedBytes,
    this.freeBytes,
    this.availableBytes,
    this.buffcacheBytes,
    this.percentUsed,
    this.swapTotalBytes,
    this.swapUsedBytes,
    this.percentSwapUsed,
  });

  factory UnraidMemory.fromJson(Map<String, dynamic> json) => UnraidMemory(
        totalBytes: _bigInt(json['total']),
        usedBytes: _bigInt(json['used']),
        freeBytes: _bigInt(json['free']),
        availableBytes: _bigInt(json['available']),
        buffcacheBytes: _bigInt(json['buffcache']),
        percentUsed: _double(json['percentTotal']),
        swapTotalBytes: _bigInt(json['swapTotal']),
        swapUsedBytes: _bigInt(json['swapUsed']),
        percentSwapUsed: _double(json['percentSwapTotal']),
      );

  final int? totalBytes;

  /// Linux's own `used`, which counts buff/cache. Kept because it is what the
  /// server sent, but [inUseBytes] is the number worth showing anyone.
  final int? usedBytes;

  final int? freeBytes;

  /// What a new process could actually claim, cache reclaim included.
  final int? availableBytes;

  final int? buffcacheBytes;

  /// The server's own figure, already computed from total minus available.
  final double? percentUsed;

  final int? swapTotalBytes;
  final int? swapUsedBytes;
  final double? percentSwapUsed;

  /// Memory genuinely committed, rather than the figure that counts cache.
  int? get inUseBytes {
    final int? total = totalBytes;
    final int? available = availableBytes;
    if (total == null || available == null) return null;
    final int used = total - available;
    return used < 0 ? 0 : used;
  }

  /// How full memory is, 0 to 1, or null when the server reported nothing.
  ///
  /// Prefers the server's own percentage and falls back to computing it, so
  /// the bar and the number beside it can never disagree.
  double? get usedFraction {
    final double? pct = percentUsed;
    if (pct != null) return (pct / 100).clamp(0.0, 1.0);
    final int? total = totalBytes;
    final int? used = inUseBytes;
    if (total == null || used == null || total <= 0) return null;
    return (used / total).clamp(0.0, 1.0);
  }

  /// `943 MB of 3.8 GB`, or null when there is nothing to show.
  String? get usageLabel {
    final int? total = totalBytes;
    final int? used = inUseBytes;
    if (total == null || used == null || total <= 0) return null;
    return '${unraidFmtBytes(used)} of ${unraidFmtBytes(total)}';
  }

  /// True only when swap exists. A machine without any reports zero totals,
  /// and a swap bar pinned at nothing is worse than no swap bar.
  bool get hasSwap => (swapTotalBytes ?? 0) > 0;

  double? get swapFraction {
    if (!hasSwap) return null;
    final double? pct = percentSwapUsed;
    if (pct != null) return (pct / 100).clamp(0.0, 1.0);
    final int total = swapTotalBytes!;
    final int? used = swapUsedBytes;
    if (used == null) return null;
    return (used / total).clamp(0.0, 1.0);
  }
}

/// One network interface, with the rates the server has already worked out.
class UnraidNetworkInterface {
  const UnraidNetworkInterface({
    this.name,
    this.operstate,
    this.rxBytesPerSec,
    this.txBytesPerSec,
  });

  factory UnraidNetworkInterface.fromJson(Map<String, dynamic> json) =>
      UnraidNetworkInterface(
        name: json['name']?.toString(),
        operstate: json['operstate']?.toString(),
        rxBytesPerSec: _double(json['rxSec']),
        txBytesPerSec: _double(json['txSec']),
      );

  final String? name;

  /// `up`, `down`, `unknown`.
  final String? operstate;

  /// Bytes per second. The server differentiates the counters itself, so
  /// nothing here has to remember a previous sample to get a rate.
  final double? rxBytesPerSec;
  final double? txBytesPerSec;

  bool get isUp => operstate?.toLowerCase() == 'up';

  /// True for the loopback and the docker and virtual bridges, which carry
  /// traffic that never leaves the machine and would swamp the real figure.
  bool get isVirtual {
    final String n = name?.toLowerCase() ?? '';
    return n == 'lo' ||
        n.startsWith('docker') ||
        n.startsWith('veth') ||
        n.startsWith('virbr') ||
        n.startsWith('vnet');
  }
}

/// A snapshot of how hard the machine is working.
class UnraidMetrics {
  const UnraidMetrics({
    this.cpu,
    this.memory,
    this.network = const <UnraidNetworkInterface>[],
  });

  factory UnraidMetrics.fromJson(Map<String, dynamic> json) {
    final dynamic cpu = json['cpu'];
    final dynamic memory = json['memory'];
    return UnraidMetrics(
      cpu: cpu is Map<String, dynamic> ? UnraidCpu.fromJson(cpu) : null,
      memory:
          memory is Map<String, dynamic> ? UnraidMemory.fromJson(memory) : null,
      network: (json['network'] as List<dynamic>? ?? <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(UnraidNetworkInterface.fromJson)
          .toList(),
    );
  }

  final UnraidCpu? cpu;
  final UnraidMemory? memory;
  final List<UnraidNetworkInterface> network;

  /// The interfaces worth totalling: physical, and actually up.
  List<UnraidNetworkInterface> get physicalInterfaces => network
      .where((UnraidNetworkInterface n) => !n.isVirtual && n.isUp)
      .toList();

  /// Total receive and send rates across the real interfaces, in bytes/sec.
  double get rxBytesPerSec => physicalInterfaces.fold<double>(
        0,
        (double sum, UnraidNetworkInterface n) => sum + (n.rxBytesPerSec ?? 0),
      );

  double get txBytesPerSec => physicalInterfaces.fold<double>(
        0,
        (double sum, UnraidNetworkInterface n) => sum + (n.txBytesPerSec ?? 0),
      );
}

/// Reads a GraphQL `Float`, which can arrive as an int when it lands exactly.
double? _double(Object? raw) {
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw);
  return null;
}
