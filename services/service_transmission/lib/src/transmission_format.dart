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
