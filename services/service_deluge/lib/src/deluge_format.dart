import 'package:flutter/material.dart';

/// Human-readable byte size.
String delugeFmtBytes(num bytes) {
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
String delugeFmtRate(num bytesPerSec) =>
    bytesPerSec <= 0 ? '0 B/s' : '${delugeFmtBytes(bytesPerSec)}/s';

/// Compact ETA. Deluge reports 0 whenever there is nothing to wait for
/// (seeding, paused, queued) rather than a sentinel, so 0 renders as a dash.
String delugeFmtEta(int seconds) {
  if (seconds <= 0) return '-';
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

/// A global bandwidth cap for display. Deluge stores these in KiB/s with -1
/// meaning unlimited.
String delugeFmtLimitKib(double kib) {
  if (kib < 0) return 'Unlimited';
  if (kib == 0) return 'Stopped';
  if (kib >= 1024) {
    final double mb = kib / 1024;
    return '${mb == mb.roundToDouble() ? mb.toInt() : mb.toStringAsFixed(1)} '
        'MB/s';
  }
  return '${kib == kib.roundToDouble() ? kib.toInt() : kib} KB/s';
}

/// Colour for a Deluge state, taken from the active scheme so the palette
/// still follows the device's dynamic colour.
Color delugeStateColor(ColorScheme scheme, String state) => switch (state) {
      'Downloading' => scheme.primary,
      'Seeding' => scheme.tertiary,
      'Paused' => scheme.outline,
      'Error' => scheme.error,
      _ => scheme.secondary,
    };

/// Icon for a Deluge state.
IconData delugeStateIcon(String state) => switch (state) {
      'Downloading' => Icons.download_outlined,
      'Seeding' => Icons.upload_outlined,
      'Paused' => Icons.pause_circle_outline,
      'Queued' => Icons.schedule_outlined,
      'Checking' => Icons.fact_check_outlined,
      'Allocating' => Icons.storage_outlined,
      'Moving' => Icons.drive_file_move_outlined,
      'Error' => Icons.error_outline,
      _ => Icons.help_outline,
    };

/// Splits a rate into number and unit so the two can be typeset at different
/// sizes: `('1.2', 'MB/s')`.
(String, String) delugeSplitRate(num bytesPerSec) {
  final String joined = delugeFmtRate(bytesPerSec);
  final int space = joined.indexOf(' ');
  if (space < 0) return (joined, '');
  return (joined.substring(0, space), joined.substring(space + 1));
}

/// libtorrent file priority as a word. Deluge writes 4 for "normal" on a fresh
/// add, but any value from 1 to 6 is a middling priority in libtorrent's scale.
String delugeFilePriorityLabel(int priority) => switch (priority) {
      0 => 'Skip',
      7 => 'High',
      _ => 'Normal',
    };
