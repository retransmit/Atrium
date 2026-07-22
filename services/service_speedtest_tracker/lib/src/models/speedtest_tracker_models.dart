enum SpeedtestResultStatus {
  waiting,
  started,
  checking,
  running,
  benchmarking,
  completed,
  failed,
  skipped,
  unknown,
}

extension SpeedtestResultStatusX on SpeedtestResultStatus {
  bool get isInProgress => switch (this) {
        SpeedtestResultStatus.waiting ||
        SpeedtestResultStatus.started ||
        SpeedtestResultStatus.checking ||
        SpeedtestResultStatus.running ||
        SpeedtestResultStatus.benchmarking =>
          true,
        _ => false,
      };

  bool get isFailure =>
      this == SpeedtestResultStatus.failed ||
      this == SpeedtestResultStatus.skipped;

  String get label => switch (this) {
        SpeedtestResultStatus.waiting => 'Waiting',
        SpeedtestResultStatus.started => 'Started',
        SpeedtestResultStatus.checking => 'Checking',
        SpeedtestResultStatus.running => 'Running',
        SpeedtestResultStatus.benchmarking => 'Benchmarking',
        SpeedtestResultStatus.completed => 'Completed',
        SpeedtestResultStatus.failed => 'Failed',
        SpeedtestResultStatus.skipped => 'Skipped',
        SpeedtestResultStatus.unknown => 'Unknown',
      };
}

class SpeedtestProtocolException implements Exception {
  const SpeedtestProtocolException(this.message);

  final String message;

  @override
  String toString() => 'SpeedtestProtocolException: $message';
}

class SpeedtestServer {
  const SpeedtestServer({
    this.id,
    this.name,
    this.host,
    this.location,
    this.country,
  });

  final String? id;
  final String? name;
  final String? host;
  final String? location;
  final String? country;

  String? get displayName => _firstNonEmpty(<String?>[name, host]);

  String? get displayLocation {
    final List<String> parts = <String>[
      if (location != null && location!.isNotEmpty) location!,
      if (country != null && country!.isNotEmpty) country!,
    ];
    return parts.isEmpty ? null : parts.join(', ');
  }
}

class SpeedtestResult {
  const SpeedtestResult({
    required this.id,
    required this.status,
    this.downloadBitsPerSecond,
    this.uploadBitsPerSecond,
    this.pingMilliseconds,
    this.jitterMilliseconds,
    this.packetLossPercent,
    this.healthy,
    this.server,
    this.isp,
    this.createdAt,
    this.updatedAt,
    this.measuredAt,
    this.message,
    this.resultUrl,
  });

  factory SpeedtestResult.fromJson(Object? value) {
    final Map<String, dynamic> json = _asStringMap(value);
    final int? id = _asInt(json['id']);
    final String? statusValue = _asString(json['status']);
    if (id == null || statusValue == null) {
      throw const SpeedtestProtocolException(
        'A result is missing its id or status.',
      );
    }

    final Map<String, dynamic> raw = _optionalMap(json['data']);
    final Map<String, dynamic> rawPing = _optionalMap(raw['ping']);
    final Map<String, dynamic> rawServer = _optionalMap(
      raw['server'] ?? json['server'],
    );
    final Map<String, dynamic> rawResult = _optionalMap(raw['result']);

    return SpeedtestResult(
      id: id,
      status: _parseStatus(statusValue),
      downloadBitsPerSecond: _bitsPerSecond(
        bits: json['download_bits'],
        bytes: json['download'] ?? _optionalMap(raw['download'])['bandwidth'],
      ),
      uploadBitsPerSecond: _bitsPerSecond(
        bits: json['upload_bits'],
        bytes: json['upload'] ?? _optionalMap(raw['upload'])['bandwidth'],
      ),
      pingMilliseconds: _asDouble(json['ping']) ??
          _asDouble(rawPing['latency'] ?? rawPing['iqm']),
      jitterMilliseconds: _asDouble(
        json['jitter'] ?? rawPing['jitter'],
      ),
      packetLossPercent: _asDouble(
        json['packet_loss'] ?? raw['packetLoss'],
      ),
      healthy: _asBool(json['healthy']),
      server: rawServer.isEmpty
          ? null
          : SpeedtestServer(
              id: _asString(rawServer['id']),
              name: _asString(rawServer['name']),
              host: _asString(rawServer['host']),
              location: _asString(rawServer['location']),
              country: _asString(rawServer['country']),
            ),
      isp: _asString(json['isp'] ?? raw['isp']),
      createdAt: _asDateTime(json['created_at']),
      updatedAt: _asDateTime(json['updated_at']),
      measuredAt: _asDateTime(raw['timestamp']),
      message: _asString(
        json['message'] ?? json['comments'] ?? raw['message'] ?? raw['error'],
      ),
      resultUrl: _asString(json['result_url'] ?? rawResult['url']),
    );
  }

  final int id;
  final SpeedtestResultStatus status;
  final double? downloadBitsPerSecond;
  final double? uploadBitsPerSecond;
  final double? pingMilliseconds;
  final double? jitterMilliseconds;
  final double? packetLossPercent;
  final bool? healthy;
  final SpeedtestServer? server;
  final String? isp;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? measuredAt;
  final String? message;
  final String? resultUrl;

  DateTime? get completedAt => measuredAt ?? updatedAt ?? createdAt;

  String? get serverOrProvider =>
      _firstNonEmpty(<String?>[server?.displayName, isp]);
}

class SpeedtestResultsPage {
  const SpeedtestResultsPage({
    required this.results,
    required this.page,
    required this.hasMore,
  });

  factory SpeedtestResultsPage.fromJson(
    Object? value, {
    required int requestedPage,
    required int pageSize,
  }) {
    final Map<String, dynamic> json = _asStringMap(value);
    final Object? data = json['data'];
    if (data is! List<dynamic>) {
      throw const SpeedtestProtocolException(
        'The result history response does not contain a data list.',
      );
    }
    final List<SpeedtestResult> results = <SpeedtestResult>[
      for (final Object? row in data) SpeedtestResult.fromJson(row),
    ];
    final Map<String, dynamic> meta = _optionalMap(json['meta']);
    final Map<String, dynamic> links = _optionalMap(json['links']);
    final int page = _asInt(
          meta['current_page'] ??
              _optionalMap(meta['page'])['current'] ??
              _optionalMap(meta['page'])['number'],
        ) ??
        requestedPage;
    final int? lastPage = _asInt(
      meta['last_page'] ?? _optionalMap(meta['page'])['last'],
    );
    final bool hasMore = links['next'] != null ||
        (lastPage != null ? page < lastPage : results.length >= pageSize);
    return SpeedtestResultsPage(
      results: results,
      page: page,
      hasMore: hasMore,
    );
  }

  final List<SpeedtestResult> results;
  final int page;
  final bool hasMore;
}

class SpeedtestOverview {
  const SpeedtestOverview({
    required this.latestAny,
    required this.completedResults,
  });

  final SpeedtestResult? latestAny;
  final List<SpeedtestResult> completedResults;

  SpeedtestResult? get latestCompleted =>
      completedResults.isEmpty ? null : completedResults.first;
}

String formatSpeed(double? bitsPerSecond) {
  if (bitsPerSecond == null) {
    return '—';
  }
  if (bitsPerSecond >= 1000000000) {
    final double value = bitsPerSecond / 1000000000;
    return '${value.toStringAsFixed(value >= 10 ? 1 : 2)} Gbps';
  }
  final double value = bitsPerSecond / 1000000;
  return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} Mbps';
}

String formatMilliseconds(double? milliseconds) => milliseconds == null
    ? '—'
    : '${milliseconds.toStringAsFixed(milliseconds >= 100 ? 0 : 1)} ms';

String formatPacketLoss(double? percent) => percent == null
    ? '—'
    : '${percent.toStringAsFixed(percent >= 10 ? 0 : 1)}%';

SpeedtestResultStatus _parseStatus(String value) =>
    switch (value.toLowerCase()) {
      'waiting' => SpeedtestResultStatus.waiting,
      'started' => SpeedtestResultStatus.started,
      'checking' => SpeedtestResultStatus.checking,
      'running' => SpeedtestResultStatus.running,
      'benchmarking' => SpeedtestResultStatus.benchmarking,
      'completed' => SpeedtestResultStatus.completed,
      'failed' => SpeedtestResultStatus.failed,
      'skipped' => SpeedtestResultStatus.skipped,
      _ => SpeedtestResultStatus.unknown,
    };

double? _bitsPerSecond({required Object? bits, required Object? bytes}) {
  final double? explicitBits = _asDouble(bits);
  if (explicitBits != null) {
    return explicitBits;
  }
  final double? rawBytes = _asDouble(bytes);
  return rawBytes == null ? null : rawBytes * 8;
}

Map<String, dynamic> _asStringMap(Object? value) {
  if (value is! Map) {
    throw const SpeedtestProtocolException('Expected a JSON object.');
  }
  return <String, dynamic>{
    for (final MapEntry<dynamic, dynamic> entry in value.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}

Map<String, dynamic> _optionalMap(Object? value) {
  if (value is! Map) {
    return const <String, dynamic>{};
  }
  return <String, dynamic>{
    for (final MapEntry<dynamic, dynamic> entry in value.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}

String? _asString(Object? value) {
  if (value == null) {
    return null;
  }
  final String result = value.toString().trim();
  return result.isEmpty ? null : result;
}

String? _firstNonEmpty(List<String?> values) {
  for (final String? value in values) {
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

double? _asDouble(Object? value) {
  double? parsed;
  if (value is num) {
    parsed = value.toDouble();
  } else if (value is String) {
    parsed = double.tryParse(value);
  }
  return parsed != null && parsed.isFinite && parsed >= 0 ? parsed : null;
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return value is String ? int.tryParse(value) : null;
}

bool? _asBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    return switch (value.toLowerCase()) {
      'true' || '1' => true,
      'false' || '0' => false,
      _ => null,
    };
  }
  return null;
}

DateTime? _asDateTime(Object? value) {
  final String? raw = _asString(value);
  return raw == null ? null : DateTime.tryParse(raw);
}
