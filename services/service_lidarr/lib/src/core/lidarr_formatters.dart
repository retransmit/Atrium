/// Shared formatting utilities for Lidarr UI (file sizes, dates, durations).
class LidarrFormatters {
  LidarrFormatters._();

  /// Formats byte count into human-readable representation (e.g. 1.5 GB).
  static String formatBytes(num? bytes) {
    if (bytes == null || bytes <= 0) return '0 B';
    const List<String> suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    int i = 0;
    double count = bytes.toDouble();
    while (count >= 1024 && i < suffixes.length - 1) {
      count /= 1024;
      i++;
    }
    return '${count.toStringAsFixed(1)} ${suffixes[i]}';
  }

  /// Formats ISO 8601 date string to `YYYY-MM-DD HH:mm` format.
  static String formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '--';
    final DateTime? dt = DateTime.tryParse(isoString);
    if (dt == null) return isoString;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  /// Formats ISO 8601 date string to `YYYY-MM-DD` date only.
  static String formatDateShort(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '--';
    final DateTime? dt = DateTime.tryParse(isoString);
    if (dt == null) return isoString;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  /// Formats ISO 8601 date string to relative time (e.g. "5m ago", "2d ago").
  static String formatRelativeDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    final DateTime? dt = DateTime.tryParse(isoString);
    if (dt == null) return isoString;
    final Duration diff = DateTime.now().toUtc().difference(dt.toUtc());
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }

  /// Formats duration in seconds to `mm:ss` or `hh:mm:ss`.
  static String formatDuration(num? seconds) {
    if (seconds == null || seconds <= 0) return '0:00';
    final int sec = seconds.toInt();
    final int h = sec ~/ 3600;
    final int m = (sec % 3600) ~/ 60;
    final int s = sec % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Formats duration in milliseconds to `mm:ss` or `--:--`.
  static String formatDurationMs(num? milliseconds) {
    if (milliseconds == null || milliseconds <= 0) return '--:--';
    final duration = Duration(milliseconds: milliseconds.toInt());
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Formats audio bit depth (e.g. '24', '24bit', '24-bit' -> '24-bit').
  static String formatBitDepth(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final String digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isNotEmpty ? '$digits-bit' : raw;
  }

  /// Formats audio sample rate (e.g. '96000', '96kHz', '44.1 kHz' -> '96 kHz').
  static String formatSampleRate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final String trimmed = raw.trim();
    if (trimmed.toLowerCase().endsWith('khz') ||
        trimmed.toLowerCase().endsWith('hz')) {
      return trimmed;
    }
    final num? numVal = num.tryParse(trimmed);
    if (numVal != null) {
      if (numVal >= 1000) {
        final double inKhz = numVal / 1000.0;
        return inKhz == inKhz.roundToDouble()
            ? '${inKhz.toInt()} kHz'
            : '${inKhz.toStringAsFixed(1)} kHz';
      }
      return '$numVal Hz';
    }
    return '$trimmed Hz';
  }

  /// Formats raw C# backend wire enum strings (e.g. 'torrentDownloadProtocol' -> 'TORRENT', 'usenetDownloadProtocol' -> 'USENET').
  static String formatWireEnum(String? raw) {
    if (raw == null || raw.isEmpty) return '--';
    String s = raw;
    if (s.toLowerCase().endsWith('downloadprotocol')) {
      s = s.substring(0, s.length - 'downloadprotocol'.length);
    } else if (s.toLowerCase().endsWith('protocol')) {
      s = s.substring(0, s.length - 'protocol'.length);
    }
    return s.toUpperCase();
  }
}

