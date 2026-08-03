class TracearrCompletionResponse {
  const TracearrCompletionResponse({
    required this.items,
    required this.summary,
    required this.pagination,
  });

  final List<TracearrCompletionItem> items;
  final TracearrCompletionSummary summary;
  final TracearrCompletionPagination pagination;

  factory TracearrCompletionResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> itemsJson = json['items'] is List ? json['items'] as List<dynamic> : <dynamic>[];
    return TracearrCompletionResponse(
      items: itemsJson
          .map((dynamic item) => TracearrCompletionItem.fromJson(item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{}))
          .toList(),
      summary: TracearrCompletionSummary.fromJson(json['summary'] is Map ? Map<String, dynamic>.from(json['summary'] as Map) : <String, dynamic>{}),
      pagination: TracearrCompletionPagination.fromJson(json['pagination'] is Map ? Map<String, dynamic>.from(json['pagination'] as Map) : <String, dynamic>{}),
    );
  }
}

class TracearrCompletionItem {
  const TracearrCompletionItem({
    required this.id,
    required this.serverId,
    required this.serverName,
    required this.title,
    required this.mediaType,
    required this.completionPct,
    required this.watchedMs,
    required this.runtimeMs,
    this.showTitle,
    this.seasonNumber,
    this.episodeNumber,
    required this.status,
    this.lastWatchedAt,
  });

  final String id;
  final String serverId;
  final String serverName;
  final String title;
  final String mediaType;
  final double completionPct;
  final int watchedMs;
  final int runtimeMs;
  final String? showTitle;
  final int? seasonNumber;
  final int? episodeNumber;
  final String status;
  final String? lastWatchedAt;

  factory TracearrCompletionItem.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    int? parseOptionalInt(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return TracearrCompletionItem(
      id: json['id']?.toString() ?? '',
      serverId: json['serverId']?.toString() ?? '',
      serverName: json['serverName']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Unknown',
      mediaType: json['mediaType']?.toString() ?? '',
      completionPct: parseDouble(json['completionPct']),
      watchedMs: parseInt(json['watchedMs']),
      runtimeMs: parseInt(json['runtimeMs']),
      showTitle: json['showTitle']?.toString(),
      seasonNumber: parseOptionalInt(json['seasonNumber']),
      episodeNumber: parseOptionalInt(json['episodeNumber']),
      status: json['status']?.toString() ?? 'not_started',
      lastWatchedAt: json['lastWatchedAt']?.toString(),
    );
  }
}

class TracearrCompletionSummary {
  const TracearrCompletionSummary({
    required this.totalItems,
    required this.completedCount,
    required this.inProgressCount,
    required this.notStartedCount,
    required this.overallCompletionPct,
  });

  final int totalItems;
  final int completedCount;
  final int inProgressCount;
  final int notStartedCount;
  final double overallCompletionPct;

  factory TracearrCompletionSummary.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return TracearrCompletionSummary(
      totalItems: parseInt(json['totalItems']),
      completedCount: parseInt(json['completedCount']),
      inProgressCount: parseInt(json['inProgressCount']),
      notStartedCount: parseInt(json['notStartedCount']),
      overallCompletionPct: parseDouble(json['overallCompletionPct']),
    );
  }

  static TracearrCompletionSummary aggregate(Iterable<TracearrCompletionSummary> summaries) {
    int total = 0;
    int completed = 0;
    int inProgress = 0;
    int notStarted = 0;

    for (final TracearrCompletionSummary s in summaries) {
      total += s.totalItems;
      completed += s.completedCount;
      inProgress += s.inProgressCount;
      notStarted += s.notStartedCount;
    }

    final double pct = total > 0 ? (completed / total) * 100.0 : 0.0;

    return TracearrCompletionSummary(
      totalItems: total,
      completedCount: completed,
      inProgressCount: inProgress,
      notStartedCount: notStarted,
      overallCompletionPct: pct,
    );
  }
}

class TracearrCompletionPagination {
  const TracearrCompletionPagination({
    required this.page,
    required this.pageSize,
    required this.total,
  });

  final int page;
  final int pageSize;
  final int total;

  factory TracearrCompletionPagination.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return TracearrCompletionPagination(
      page: parseInt(json['page']),
      pageSize: parseInt(json['pageSize']),
      total: parseInt(json['total']),
    );
  }
}
