/// Status of the MySpeed speedtest execution.
class MySpeedStatus {
  const MySpeedStatus({
    required this.isRunning,
    this.message,
    this.timestamp,
    this.raw,
  });

  /// Whether a speedtest is currently running on the server.
  final bool isRunning;

  /// Optional status message or description from the server.
  final String? message;

  /// Timestamp when the status was checked or reported.
  final DateTime? timestamp;

  /// Unmodified response payload from the endpoint for diagnostics.
  final dynamic raw;

  /// Parses server response from `GET /api/speedtests/status`.
  factory MySpeedStatus.fromResponse(dynamic data) {
    final DateTime now = DateTime.now();
    if (data == null) {
      return MySpeedStatus(isRunning: false, timestamp: now);
    }
    if (data is bool) {
      return MySpeedStatus(isRunning: data, timestamp: now, raw: data);
    }
    if (data is Map) {
      final dynamic runningVal = data['running'] ?? data['isRunning'] ?? data['active'];
      bool running = false;
      if (runningVal is bool) {
        running = runningVal;
      } else if (runningVal != null) {
        running = runningVal.toString().toLowerCase() == 'true';
      }

      final String? statusStr = data['status']?.toString();
      if (!running && statusStr != null) {
        final String lower = statusStr.toLowerCase();
        running = lower == 'running' || lower == 'testing' || lower == 'active' || lower == 'in_progress';
      }

      final String? message = data['message'] as String? ?? statusStr;
      return MySpeedStatus(
        isRunning: running,
        message: message,
        timestamp: now,
        raw: data,
      );
    }
    if (data is String) {
      final String trimmed = data.trim().toLowerCase();
      final bool running = trimmed == 'true' ||
          trimmed.contains('running') ||
          trimmed.contains('testing') ||
          trimmed.contains('active');
      return MySpeedStatus(
        isRunning: running,
        message: data,
        timestamp: now,
        raw: data,
      );
    }
    return MySpeedStatus(isRunning: false, timestamp: now, raw: data);
  }

  @override
  String toString() => 'MySpeedStatus(isRunning: $isRunning, message: $message)';
}
