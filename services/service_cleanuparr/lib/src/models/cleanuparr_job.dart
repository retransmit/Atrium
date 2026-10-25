/// Represents a registered background job / scheduled task in Cleanuparr.
class CleanuparrJob {
  const CleanuparrJob({
    required this.jobType,
    required this.displayName,
    this.status = 'Idle',
    this.intervalDescription,
    this.lastRunTime,
    this.nextRunTime,
  });

  final String jobType;
  final String displayName;
  final String status;
  final String? intervalDescription;
  final DateTime? lastRunTime;
  final DateTime? nextRunTime;

  bool get isRunning => status.toLowerCase() == 'running';

  factory CleanuparrJob.fromJson(Map<String, dynamic> json) {
    final String type = json['jobType']?.toString() ??
        json['type']?.toString() ??
        json['name']?.toString() ??
        'Job';

    final String rawName = json['displayName']?.toString() ??
        json['name']?.toString() ??
        type;
    final String name = _formatJobName(rawName);

    DateTime? last;
    final dynamic rawLast =
        json['previousRunTime'] ?? json['lastRunTime'] ?? json['lastRun'];
    if (rawLast != null) {
      last = DateTime.tryParse(rawLast.toString());
    }

    DateTime? next;
    final dynamic rawNext = json['nextRunTime'] ?? json['nextRun'];
    if (rawNext != null) {
      next = DateTime.tryParse(rawNext.toString());
    }

    return CleanuparrJob(
      jobType: type,
      displayName: name,
      status: json['status']?.toString() ?? 'Idle',
      intervalDescription: json['interval']?.toString() ?? json['schedule']?.toString(),
      lastRunTime: last,
      nextRunTime: next,
    );
  }

  static String _formatJobName(String raw) {
    // Splits PascalCase like 'MalwareBlocker' into 'Malware Blocker'
    return raw.replaceAllMapped(
      RegExp(r'(?<=[a-z])[A-Z]'),
      (Match m) => ' ${m.group(0)}',
    );
  }
}
