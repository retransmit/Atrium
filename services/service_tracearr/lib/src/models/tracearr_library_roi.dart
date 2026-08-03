class TracearrLibraryRoiResponse {
  final List<TracearrRoiItem> items;
  final TracearrRoiSummary summary;
  final TracearrRoiThresholds thresholds;
  final TracearrRoiPagination pagination;

  const TracearrLibraryRoiResponse({
    required this.items,
    required this.summary,
    required this.thresholds,
    required this.pagination,
  });

  factory TracearrLibraryRoiResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> itemsJson = json['items'] is List ? json['items'] as List<dynamic> : <dynamic>[];

    return TracearrLibraryRoiResponse(
      items: itemsJson
          .map((dynamic item) => TracearrRoiItem.fromJson(item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{}))
          .toList(),
      summary: TracearrRoiSummary.fromJson(json['summary'] is Map ? Map<String, dynamic>.from(json['summary'] as Map) : <String, dynamic>{}),
      thresholds: TracearrRoiThresholds.fromJson(json['thresholds'] is Map ? Map<String, dynamic>.from(json['thresholds'] as Map) : <String, dynamic>{}),
      pagination: TracearrRoiPagination.fromJson(json['pagination'] is Map ? Map<String, dynamic>.from(json['pagination'] as Map) : <String, dynamic>{}),
    );
  }
}

class TracearrRoiItem {
  final String id;
  final String serverId;
  final String serverName;
  final String title;
  final String mediaType;
  final int? year;
  final int fileSizeBytes;
  final double fileSizeGb;
  final int watchCount;
  final int totalWatchMs;
  final double totalWatchHours;
  final String? lastWatchedAt;
  final int daysSinceLastWatch;
  final double watchHoursPerGb;
  final double valueScore;
  final String valueCategory;
  final bool suggestDeletion;

  const TracearrRoiItem({
    required this.id,
    required this.serverId,
    required this.serverName,
    required this.title,
    required this.mediaType,
    this.year,
    required this.fileSizeBytes,
    required this.fileSizeGb,
    required this.watchCount,
    required this.totalWatchMs,
    required this.totalWatchHours,
    this.lastWatchedAt,
    required this.daysSinceLastWatch,
    required this.watchHoursPerGb,
    required this.valueScore,
    required this.valueCategory,
    required this.suggestDeletion,
  });

  factory TracearrRoiItem.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

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

    return TracearrRoiItem(
      id: json['id']?.toString() ?? '',
      serverId: json['serverId']?.toString() ?? '',
      serverName: json['serverName']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Unknown',
      mediaType: json['mediaType']?.toString() ?? '',
      year: parseOptionalInt(json['year']),
      fileSizeBytes: parseInt(json['fileSizeBytes']),
      fileSizeGb: parseDouble(json['fileSizeGb']),
      watchCount: parseInt(json['watchCount']),
      totalWatchMs: parseInt(json['totalWatchMs']),
      totalWatchHours: parseDouble(json['totalWatchHours']),
      lastWatchedAt: json['lastWatchedAt']?.toString(),
      daysSinceLastWatch: parseInt(json['daysSinceLastWatch']),
      watchHoursPerGb: parseDouble(json['watchHoursPerGb']),
      valueScore: parseDouble(json['valueScore']),
      valueCategory: json['valueCategory']?.toString() ?? 'medium_value',
      suggestDeletion: json['suggestDeletion'] == true,
    );
  }
}

class TracearrRoiSummary {
  final int totalItems;
  final double totalStorageGb;
  final double totalWatchHours;
  final double avgWatchHoursPerGb;
  final int lowValueItems;
  final double lowValueStorageGb;
  final double potentialSavingsGb;

  const TracearrRoiSummary({
    required this.totalItems,
    required this.totalStorageGb,
    required this.totalWatchHours,
    required this.avgWatchHoursPerGb,
    required this.lowValueItems,
    required this.lowValueStorageGb,
    required this.potentialSavingsGb,
  });

  factory TracearrRoiSummary.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return TracearrRoiSummary(
      totalItems: parseInt(json['totalItems']),
      totalStorageGb: parseDouble(json['totalStorageGb']),
      totalWatchHours: parseDouble(json['totalWatchHours']),
      avgWatchHoursPerGb: parseDouble(json['avgWatchHoursPerGb']),
      lowValueItems: parseInt(json['lowValueItems']),
      lowValueStorageGb: parseDouble(json['lowValueStorageGb']),
      potentialSavingsGb: parseDouble(json['potentialSavingsGb']),
    );
  }
}

class TracearrRoiThresholds {
  final TracearrRoiCategoryThreshold movie;
  final TracearrRoiCategoryThreshold episode;
  final TracearrRoiCategoryThreshold show;

  const TracearrRoiThresholds({
    required this.movie,
    required this.episode,
    required this.show,
  });

  factory TracearrRoiThresholds.fromJson(Map<String, dynamic> json) {
    return TracearrRoiThresholds(
      movie: TracearrRoiCategoryThreshold.fromJson(json['movie'] is Map ? Map<String, dynamic>.from(json['movie'] as Map) : <String, dynamic>{}),
      episode: TracearrRoiCategoryThreshold.fromJson(json['episode'] is Map ? Map<String, dynamic>.from(json['episode'] as Map) : <String, dynamic>{}),
      show: TracearrRoiCategoryThreshold.fromJson(json['show'] is Map ? Map<String, dynamic>.from(json['show'] as Map) : <String, dynamic>{}),
    );
  }
}

class TracearrRoiCategoryThreshold {
  final double lowValue;
  final double highValue;

  const TracearrRoiCategoryThreshold({
    required this.lowValue,
    required this.highValue,
  });

  factory TracearrRoiCategoryThreshold.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return TracearrRoiCategoryThreshold(
      lowValue: parseDouble(json['lowValue']),
      highValue: parseDouble(json['highValue']),
    );
  }
}

class TracearrRoiPagination {
  final int page;
  final int pageSize;
  final int total;

  const TracearrRoiPagination({
    required this.page,
    required this.pageSize,
    required this.total,
  });

  factory TracearrRoiPagination.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return TracearrRoiPagination(
      page: parseInt(json['page']),
      pageSize: parseInt(json['pageSize']),
      total: parseInt(json['total']),
    );
  }
}
