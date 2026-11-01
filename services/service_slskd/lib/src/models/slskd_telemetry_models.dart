/// Data models for slskd Telemetry, Metrics, Reports, and Leaderboard.
library;

class SlskdTransferSummary {
  const SlskdTransferSummary({
    this.username,
    this.totalBytes = 0,
    this.count = 0,
    this.distinctUsers = 0,
    this.averageSpeed = 0.0,
    this.averageWait = 0.0,
    this.averageDuration = 0.0,
  });

  factory SlskdTransferSummary.fromJson(Map<String, dynamic> json) {
    return SlskdTransferSummary(
      username: (json['username'] ?? json['Username'])?.toString(),
      totalBytes: ((json['totalBytes'] ?? json['TotalBytes'] ?? 0) as num).toInt(),
      count: ((json['count'] ?? json['Count'] ?? 0) as num).toInt(),
      distinctUsers: ((json['distinctUsers'] ?? json['DistinctUsers'] ?? 0) as num).toInt(),
      averageSpeed: ((json['averageSpeed'] ?? json['AverageSpeed'] ?? 0.0) as num).toDouble(),
      averageWait: ((json['averageWait'] ?? json['AverageWait'] ?? 0.0) as num).toDouble(),
      averageDuration: ((json['averageDuration'] ?? json['AverageDuration'] ?? 0.0) as num).toDouble(),
    );
  }

  final String? username;
  final int totalBytes;
  final int count;
  final int distinctUsers;
  final double averageSpeed;
  final double averageWait;
  final double averageDuration;

  Map<String, dynamic> toJson() => {
        if (username != null) 'username': username,
        'totalBytes': totalBytes,
        'count': count,
        'distinctUsers': distinctUsers,
        'averageSpeed': averageSpeed,
        'averageWait': averageWait,
        'averageDuration': averageDuration,
      };
}

class SlskdTransferExceptionSummary {
  const SlskdTransferExceptionSummary({
    required this.exception,
    this.count = 0,
    this.distinctUsers = 0,
  });

  factory SlskdTransferExceptionSummary.fromJson(Map<String, dynamic> json) {
    return SlskdTransferExceptionSummary(
      exception: (json['exception'] ?? json['Exception'] ?? '').toString(),
      count: ((json['count'] ?? json['Count'] ?? 0) as num).toInt(),
      distinctUsers: ((json['distinctUsers'] ?? json['DistinctUsers'] ?? 0) as num).toInt(),
    );
  }

  final String exception;
  final int count;
  final int distinctUsers;

  Map<String, dynamic> toJson() => {
        'exception': exception,
        'count': count,
        'distinctUsers': distinctUsers,
      };
}

class SlskdTransferExceptionDetail {
  const SlskdTransferExceptionDetail({
    required this.id,
    required this.username,
    required this.direction,
    required this.filename,
    this.size = 0,
    this.state = '',
    this.requestedAt,
    this.enqueuedAt,
    this.startedAt,
    this.endedAt,
    this.bytesTransferred = 0,
    this.averageSpeed = 0.0,
    required this.exception,
  });

  factory SlskdTransferExceptionDetail.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v.toLocal();
      return DateTime.tryParse(v.toString())?.toLocal();
    }

    return SlskdTransferExceptionDetail(
      id: (json['id'] ?? json['Id'] ?? '').toString(),
      username: (json['username'] ?? json['Username'] ?? '').toString(),
      direction: (json['direction'] ?? json['Direction'] ?? '').toString(),
      filename: (json['filename'] ?? json['Filename'] ?? '').toString(),
      size: ((json['size'] ?? json['Size'] ?? 0) as num).toInt(),
      state: (json['state'] ?? json['State'] ?? '').toString(),
      requestedAt: parseDate(json['requestedAt'] ?? json['RequestedAt']),
      enqueuedAt: parseDate(json['enqueuedAt'] ?? json['EnqueuedAt']),
      startedAt: parseDate(json['startedAt'] ?? json['StartedAt']),
      endedAt: parseDate(json['endedAt'] ?? json['EndedAt']),
      bytesTransferred: ((json['bytesTransferred'] ?? json['BytesTransferred'] ?? 0) as num).toInt(),
      averageSpeed: ((json['averageSpeed'] ?? json['AverageSpeed'] ?? 0.0) as num).toDouble(),
      exception: (json['exception'] ?? json['Exception'] ?? '').toString(),
    );
  }

  final String id;
  final String username;
  final String direction;
  final String filename;
  final int size;
  final String state;
  final DateTime? requestedAt;
  final DateTime? enqueuedAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int bytesTransferred;
  final double averageSpeed;
  final String exception;

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'direction': direction,
        'filename': filename,
        'size': size,
        'state': state,
        if (requestedAt != null) 'requestedAt': requestedAt!.toIso8601String(),
        if (enqueuedAt != null) 'enqueuedAt': enqueuedAt!.toIso8601String(),
        if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
        if (endedAt != null) 'endedAt': endedAt!.toIso8601String(),
        'bytesTransferred': bytesTransferred,
        'averageSpeed': averageSpeed,
        'exception': exception,
      };
}

class SlskdTransferDirectorySummary {
  const SlskdTransferDirectorySummary({
    required this.directory,
    this.count = 0,
    this.distinctUsers = 0,
  });

  factory SlskdTransferDirectorySummary.fromJson(Map<String, dynamic> json) {
    return SlskdTransferDirectorySummary(
      directory: (json['directory'] ?? json['Directory'] ?? '').toString(),
      count: ((json['count'] ?? json['Count'] ?? 0) as num).toInt(),
      distinctUsers: ((json['distinctUsers'] ?? json['DistinctUsers'] ?? 0) as num).toInt(),
    );
  }

  final String directory;
  final int count;
  final int distinctUsers;

  Map<String, dynamic> toJson() => {
        'directory': directory,
        'count': count,
        'distinctUsers': distinctUsers,
      };
}

class SlskdPrometheusMetricSample {
  const SlskdPrometheusMetricSample({
    this.value,
    this.labels = const <String, String>{},
  });

  factory SlskdPrometheusMetricSample.fromJson(Map<String, dynamic> json) {
    final rawLabels = json['labels'] ?? json['Labels'];
    final Map<String, String> labelsMap = {};
    if (rawLabels is Map) {
      for (final e in rawLabels.entries) {
        labelsMap[e.key.toString()] = e.value.toString();
      }
    }
    return SlskdPrometheusMetricSample(
      value: (json['value'] ?? json['Value']) != null
          ? ((json['value'] ?? json['Value']) as num).toDouble()
          : null,
      labels: labelsMap,
    );
  }

  final double? value;
  final Map<String, String> labels;

  Map<String, dynamic> toJson() => {
        if (value != null) 'value': value,
        'labels': labels,
      };
}

class SlskdPrometheusMetric {
  const SlskdPrometheusMetric({
    required this.name,
    this.help,
    this.type,
    this.sum,
    this.count,
    this.samples = const <SlskdPrometheusMetricSample>[],
  });

  factory SlskdPrometheusMetric.fromJson(Map<String, dynamic> json) {
    final rawSamples = json['samples'] ?? json['Samples'];
    final List<SlskdPrometheusMetricSample> samplesList = [];
    if (rawSamples is Iterable) {
      for (final item in rawSamples) {
        if (item is Map<String, dynamic>) {
          samplesList.add(SlskdPrometheusMetricSample.fromJson(item));
        } else if (item is Map) {
          samplesList.add(SlskdPrometheusMetricSample.fromJson(item.cast<String, dynamic>()));
        }
      }
    }

    return SlskdPrometheusMetric(
      name: (json['name'] ?? json['Name'] ?? '').toString(),
      help: (json['help'] ?? json['Help'])?.toString(),
      type: (json['type'] ?? json['Type'])?.toString(),
      sum: (json['sum'] ?? json['Sum']) != null
          ? ((json['sum'] ?? json['Sum']) as num).toDouble()
          : null,
      count: (json['count'] ?? json['Count']) != null
          ? ((json['count'] ?? json['Count']) as num).toDouble()
          : null,
      samples: samplesList,
    );
  }

  final String name;
  final String? help;
  final String? type;
  final double? sum;
  final double? count;
  final List<SlskdPrometheusMetricSample> samples;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (help != null) 'help': help,
        if (type != null) 'type': type,
        if (sum != null) 'sum': sum,
        if (count != null) 'count': count,
        'samples': samples.map((s) => s.toJson()).toList(),
      };
}
