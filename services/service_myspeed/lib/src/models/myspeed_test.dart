import 'package:intl/intl.dart';

/// An individual speedtest result record from MySpeed.
class MySpeedTest {
  const MySpeedTest({
    required this.id,
    required this.download,
    required this.upload,
    required this.ping,
    this.jitter,
    this.createdAt,
    this.server,
    this.duration,
    this.error,
    this.raw,
  });

  final String id;

  /// Download speed in Mbps.
  final double download;

  /// Upload speed in Mbps.
  final double upload;

  /// Ping / latency in ms.
  final double ping;

  /// Jitter in ms, if available.
  final double? jitter;

  /// When the speed test occurred.
  final DateTime? createdAt;

  /// Server or provider information.
  final String? server;

  /// Test execution duration in seconds or ms, if provided by API.
  final int? duration;

  /// What went wrong, for a run that failed. MySpeed keeps such runs as
  /// rows with this set and no speeds.
  final String? error;

  /// Raw payload from MySpeed API.
  final Map<String, dynamic>? raw;

  factory MySpeedTest.fromJson(Map<String, dynamic> json) {
    final dynamic idVal = json['id'] ?? json['_id'] ?? json['uuid'] ?? '';
    final double downloadVal = _parseDouble(json['download'] ?? json['down'] ?? json['downloadSpeed']);
    final double uploadVal = _parseDouble(json['upload'] ?? json['up'] ?? json['uploadSpeed']);
    final double pingVal = _parseDouble(json['ping'] ?? json['latency']);
    final double? jitterVal = json['jitter'] != null ? _parseDouble(json['jitter']) : null;

    DateTime? date;
    // MySpeed API returns "created" as ISO timestamp e.g. "2024-03-24T18:15:32.000Z"
    // Note: Do NOT fallback to json['time'] because 'time' in MySpeed is the duration of test.
    final dynamic rawDate = json['created'] ??
        json['createdAt'] ??
        json['created_at'] ??
        json['timestamp'] ??
        json['date'];

    if (rawDate is String) {
      final String trimmed = rawDate.trim();
      DateTime? parsed = DateTime.tryParse(trimmed);
      if (parsed == null && trimmed.contains(' ')) {
        parsed = DateTime.tryParse(trimmed.replaceFirst(' ', 'T'));
      }
      date = parsed?.toLocal();
    } else if (rawDate is int) {
      if (rawDate < 10000000000) {
        date = DateTime.fromMillisecondsSinceEpoch(rawDate * 1000).toLocal();
      } else {
        date = DateTime.fromMillisecondsSinceEpoch(rawDate).toLocal();
      }
    }

    String? serverName;
    if (json['serverName'] != null) {
      serverName = json['serverName'].toString();
    } else if (json['serverHost'] != null) {
      serverName = json['serverHost'].toString();
    } else if (json['server'] is String) {
      serverName = json['server'] as String;
    } else if (json['server'] is Map) {
      final Map<dynamic, dynamic> sMap = json['server'] as Map<dynamic, dynamic>;
      serverName = (sMap['name'] ?? sMap['sponsor'] ?? sMap['location'])?.toString();
    }

    final int? durVal = json['time'] is int ? json['time'] as int : null;
    final dynamic rawError = json['error'];
    final String? errorVal =
        rawError is String && rawError.trim().isNotEmpty ? rawError : null;

    return MySpeedTest(
      id: idVal.toString(),
      download: downloadVal,
      upload: uploadVal,
      ping: pingVal,
      jitter: jitterVal,
      createdAt: date,
      server: serverName,
      duration: durVal,
      error: errorVal,
      raw: json,
    );
  }

  static double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  String get formattedDownload => '${download.toStringAsFixed(1)} Mbps';
  String get formattedUpload => '${upload.toStringAsFixed(1)} Mbps';
  String get formattedPing => '${ping.toStringAsFixed(0)} ms';
  String? get formattedJitter => jitter != null ? '${jitter!.toStringAsFixed(0)} ms' : null;

  /// Formats time in local format (e.g., "5:30 PM" or "17:30").
  String get formattedTime {
    if (createdAt == null) return '';
    return DateFormat.jm().format(createdAt!);
  }

  /// Formats date and time nicely:
  /// "Today, 5:30 PM", "Yesterday, 11:15 PM", or "Sep 20, 5:30 PM".
  String get formattedDate {
    if (createdAt == null) return '';
    final DateTime now = DateTime.now();
    final bool isToday = createdAt!.year == now.year &&
        createdAt!.month == now.month &&
        createdAt!.day == now.day;
    if (isToday) {
      return 'Today, ${DateFormat.jm().format(createdAt!)}';
    }
    final DateTime yesterday = now.subtract(const Duration(days: 1));
    final bool isYesterday = createdAt!.year == yesterday.year &&
        createdAt!.month == yesterday.month &&
        createdAt!.day == yesterday.day;
    if (isYesterday) {
      return 'Yesterday, ${DateFormat.jm().format(createdAt!)}';
    }
    return DateFormat.yMMMd().add_jm().format(createdAt!);
  }

  /// Shorter date/time format for dense cards.
  String get formattedShortDate {
    if (createdAt == null) return '';
    return DateFormat.MMMd().add_jm().format(createdAt!);
  }
}
