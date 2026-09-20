import 'package:flutter/material.dart';

import 'models/transmission_torrent.dart';

/// Human-readable byte size.
String trFmtBytes(num bytes) {
  if (bytes <= 0) return '0 B';
  const List<String> units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
  double value = bytes.toDouble();
  int unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final String text = value >= 100 || unit == 0
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$text ${units[unit]}';
}

/// '2.5 MB/s' from a bytes-per-second rate.
String trFmtRate(num bytesPerSec) =>
    bytesPerSec <= 0 ? '0 B/s' : '${trFmtBytes(bytesPerSec)}/s';

/// Compact ETA.
///
/// Transmission uses **negative sentinels** rather than zero: -1 means "not
/// available" and -2 "unknown", so anything below 1 renders as a dash instead
/// of a nonsense duration.
String trFmtEta(int seconds) {
  if (seconds < 1) return '-';
  if (seconds < 60) return '${seconds}s';
  if (seconds < 3600) {
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    return s == 0 ? '${m}m' : '${m}m ${s}s';
  }
  if (seconds < 86400) {
    final int h = seconds ~/ 3600;
    final int m = (seconds % 3600) ~/ 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
  final int d = seconds ~/ 86400;
  final int h = (seconds % 86400) ~/ 3600;
  return h == 0 ? '${d}d' : '${d}d ${h}h';
}

/// A global bandwidth cap for display. Transmission keeps the value and its
/// enabled flag apart, so both are needed to say anything true.
String trFmtLimit({required int kbps, required bool enabled}) {
  if (!enabled) return 'Unlimited';
  if (kbps <= 0) return 'Stopped';
  if (kbps >= 1024) {
    final double mb = kbps / 1024;
    return '${mb == mb.roundToDouble() ? mb.toInt() : mb.toStringAsFixed(1)} '
        'MB/s';
  }
  return '$kbps KB/s';
}

/// Splits a rate into number and unit so the two can be typeset at different
/// sizes: `('1.2', 'MB/s')`.
(String, String) trSplitRate(num bytesPerSec) {
  final String joined = trFmtRate(bytesPerSec);
  final int space = joined.indexOf(' ');
  if (space < 0) return (joined, '');
  return (joined.substring(0, space), joined.substring(space + 1));
}

/// A tracker's seeder/leecher count, which is -1 until an announce succeeds.
String trFmtPeerCount(int count) => count < 0 ? '?' : '$count';

/// A duration the way the web UI's `Formatter.timeInterval` words it: the two
/// largest units, pluralised, a zero second unit dropped.
String trTimeInterval(int seconds) {
  if (seconds < 1) return '0 seconds';
  final int days = seconds ~/ 86400;
  final int hours = (seconds % 86400) ~/ 3600;
  final int minutes = (seconds % 3600) ~/ 60;
  final int secs = seconds % 60;
  String unit(int n, String word) => '$n $word${n == 1 ? '' : 's'}';
  final List<(int, String)> parts = <(int, String)>[
    (days, 'day'),
    (hours, 'hour'),
    (minutes, 'minute'),
    (secs, 'second'),
  ];
  final int first = parts.indexWhere(((int, String) p) => p.$1 > 0);
  final (int, String) big = parts[first];
  final (int, String)? small =
      first + 1 < parts.length ? parts[first + 1] : null;
  if (small == null || small.$1 == 0) return unit(big.$1, big.$2);
  return '${unit(big.$1, big.$2)}, ${unit(small.$1, small.$2)}';
}

/// Local date and time to the minute, `2026-09-20 14:05`.
String trTimestamp(int unixSeconds) {
  final DateTime d =
      DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000).toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} '
      '${two(d.hour)}:${two(d.minute)}';
}

/// A share ratio the way the web UI shows one: None below zero (nothing
/// uploaded yet), and fewer decimals the larger it gets.
String trRatioString(double ratio) {
  if (ratio < 0) return 'None';
  if (ratio >= 100) return ratio.toStringAsFixed(0);
  if (ratio >= 10) return ratio.toStringAsFixed(1);
  return ratio.toStringAsFixed(2);
}

/// A 0.0 - 1.0 fraction as a percentage with one decimal, `100` when whole.
String trPct(double fraction) {
  final double value = (fraction * 100).clamp(0, 100).toDouble();
  return value >= 100 ? '100' : value.toStringAsFixed(1);
}

String trCount(int n, String singular, String plural) =>
    '$n ${n == 1 ? singular : plural}';

/// Transmission's `alt-speed-time-day` bits.
const int trEveryDay = 127;
const int trWeekdays = 62;
const int trWeekends = 65;

/// Each day's bit and short name, Sunday first as Transmission counts them.
const List<(int, String)> trDays = <(int, String)>[
  (1, 'Sun'),
  (2, 'Mon'),
  (4, 'Tue'),
  (8, 'Wed'),
  (16, 'Thu'),
  (32, 'Fri'),
  (64, 'Sat'),
];

String trDaySummary(int mask) {
  if (mask == trEveryDay) return 'Every day';
  if (mask == trWeekdays) return 'Weekdays';
  if (mask == trWeekends) return 'Weekends';
  if (mask == 0) return 'Never';
  return <String>[
    for (final (int bit, String name) in trDays)
      if (mask & bit != 0) name,
  ].join(', ');
}

int trToggleDay(int mask, int bit) => mask ^ bit;

/// Colour for a status, taken from the active scheme so the palette follows
/// the device's dynamic colour.
Color trStatusColor(ColorScheme scheme, TransmissionTorrent t) {
  if (t.hasError) return scheme.error;
  return switch (t.status) {
    TransmissionStatus.downloading => scheme.primary,
    TransmissionStatus.seeding => scheme.tertiary,
    TransmissionStatus.stopped => scheme.outline,
    _ => scheme.secondary,
  };
}

/// Icon for a status.
IconData trStatusIcon(TransmissionTorrent t) {
  if (t.hasError) return Icons.error_outline;
  return switch (t.status) {
    TransmissionStatus.downloading => Icons.download_outlined,
    TransmissionStatus.seeding => Icons.upload_outlined,
    TransmissionStatus.stopped => Icons.pause_circle_outline,
    TransmissionStatus.checking => Icons.fact_check_outlined,
    TransmissionStatus.checkWait ||
    TransmissionStatus.downloadWait ||
    TransmissionStatus.seedWait =>
      Icons.schedule_outlined,
    _ => Icons.help_outline,
  };
}
