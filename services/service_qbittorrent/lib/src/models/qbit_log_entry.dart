/// Severity levels for qBittorrent log entries.
enum QbitLogLevel {
  normal('Normal'),
  info('Info'),
  warning('Warning'),
  critical('Critical');

  const QbitLogLevel(this.label);
  final String label;

  static QbitLogLevel fromType(int type) {
    return switch (type) {
      1 => QbitLogLevel.normal,
      2 => QbitLogLevel.info,
      4 => QbitLogLevel.warning,
      8 => QbitLogLevel.critical,
      _ => QbitLogLevel.normal,
    };
  }
}

/// A single application log message from `GET /api/v2/log/main`.
class QbitLogEntry {
  const QbitLogEntry({
    required this.id,
    required this.message,
    required this.timestamp,
    required this.type,
  });

  /// The unique ID of the message.
  final int id;

  /// The content of the log entry.
  final String message;

  /// When the message was logged, in seconds since the epoch. qBittorrent
  /// sent milliseconds before 4.5.0, so [dateTime] reads either.
  final int timestamp;

  /// Message type: 1 = normal, 2 = info, 4 = warning, 8 = critical.
  final int type;

  /// Parsed severity level.
  QbitLogLevel get level => QbitLogLevel.fromType(type);

  /// Normalized [DateTime] from [timestamp].
  DateTime get dateTime {
    if (timestamp > 100000000000) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
  }

  /// Formatted `HH:mm:ss` local time string.
  String get timeText {
    final DateTime local = dateTime.toLocal();
    final String h = local.hour.toString().padLeft(2, '0');
    final String m = local.minute.toString().padLeft(2, '0');
    final String s = local.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  factory QbitLogEntry.fromJson(Map<String, dynamic> json) {
    return QbitLogEntry(
      id: json['id'] as int? ?? 0,
      message: json['message'] as String? ?? '',
      timestamp: json['timestamp'] as int? ?? 0,
      type: json['type'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'message': message,
        'timestamp': timestamp,
        'type': type,
      };
}
