import 'package:flutter/material.dart';

import 'models/rtorrent_torrent.dart';

/// Human-readable byte size.
String rtFmtBytes(num bytes) {
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
String rtFmtRate(num bytesPerSec) =>
    bytesPerSec <= 0 ? '0 B/s' : '${rtFmtBytes(bytesPerSec)}/s';

/// Compact ETA.
///
/// rTorrent publishes no ETA of its own - ruTorrent computes one from the
/// bytes left and the current rate, and so does this. A stalled torrent has no
/// meaningful estimate, hence the dash.
String rtFmtEta(RtorrentTorrent t) {
  if (t.isComplete || t.leftBytes <= 0) return '-';
  if (t.downRate <= 0) return '-';
  final int seconds = t.leftBytes ~/ t.downRate;
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

/// A global bandwidth cap for display.
///
/// rTorrent's limits are plain **bytes per second** with 0 meaning unlimited -
/// there is no separate enabled flag the way Transmission has one.
String rtFmtLimit(int bytesPerSec) =>
    bytesPerSec <= 0 ? 'Unlimited' : rtFmtRate(bytesPerSec);

/// Splits a rate into number and unit so the two can be typeset at different
/// sizes: `('1.2', 'MB/s')`.
(String, String) rtSplitRate(num bytesPerSec) {
  final String joined = rtFmtRate(bytesPerSec);
  final int space = joined.indexOf(' ');
  if (space < 0) return (joined, '');
  return (joined.substring(0, space), joined.substring(space + 1));
}

/// Colour for a status, taken from the active scheme so the palette follows the
/// device's dynamic colour.
Color rtStatusColor(ColorScheme scheme, RtorrentTorrent t) {
  return switch (t.status) {
    RtorrentStatus.error => scheme.error,
    RtorrentStatus.downloading => scheme.primary,
    RtorrentStatus.seeding => scheme.tertiary,
    RtorrentStatus.stopped => scheme.outline,
    _ => scheme.secondary,
  };
}

/// Icon for a status.
IconData rtStatusIcon(RtorrentTorrent t) {
  return switch (t.status) {
    RtorrentStatus.error => Icons.error_outline,
    RtorrentStatus.downloading => Icons.download_outlined,
    RtorrentStatus.seeding => Icons.upload_outlined,
    RtorrentStatus.stopped => Icons.stop_circle_outlined,
    RtorrentStatus.paused => Icons.pause_circle_outline,
    RtorrentStatus.checking => Icons.fact_check_outlined,
    RtorrentStatus.queued => Icons.schedule_outlined,
  };
}
