class TracearrTopShowsResponse {
  const TracearrTopShowsResponse({
    required this.items,
    required this.summary,
    required this.pagination,
  });

  final List<TracearrTopShowItem> items;
  final TracearrTopShowsSummary summary;
  final TracearrTopShowsPagination pagination;

  factory TracearrTopShowsResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> itemsJson = json['items'] is List ? json['items'] as List<dynamic> : <dynamic>[];
    return TracearrTopShowsResponse(
      items: itemsJson
          .map((dynamic item) => TracearrTopShowItem.fromJson(item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{}))
          .toList(),
      summary: TracearrTopShowsSummary.fromJson(json['summary'] is Map ? Map<String, dynamic>.from(json['summary'] as Map) : <String, dynamic>{}),
      pagination: TracearrTopShowsPagination.fromJson(json['pagination'] is Map ? Map<String, dynamic>.from(json['pagination'] as Map) : <String, dynamic>{}),
    );
  }
}

class TracearrTopShowItem {
  const TracearrTopShowItem({
    required this.showTitle,
    required this.year,
    this.thumbPath,
    required this.serverId,
    required this.serverIds,
    required this.totalEpisodeViews,
    required this.totalWatchHours,
    required this.uniqueViewers,
    required this.avgCompletionRate,
    required this.bingeScore,
  });

  final String showTitle;
  final int year;
  final String? thumbPath;
  final String serverId;
  final List<String> serverIds;
  final int totalEpisodeViews;
  final double totalWatchHours;
  final int uniqueViewers;
  final double avgCompletionRate;
  final double bingeScore;

  factory TracearrTopShowItem.fromJson(Map<String, dynamic> json) {
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

    return TracearrTopShowItem(
      showTitle: json['showTitle']?.toString() ?? 'Unknown Show',
      year: parseInt(json['year']),
      thumbPath: json['thumbPath']?.toString(),
      serverId: json['serverId']?.toString() ?? '',
      serverIds: (json['serverIds'] as List<dynamic>?)
              ?.map((dynamic e) => e.toString())
              .toList() ??
          <String>[],
      totalEpisodeViews: parseInt(json['totalEpisodeViews']),
      totalWatchHours: parseDouble(json['totalWatchHours']),
      uniqueViewers: parseInt(json['uniqueViewers']),
      avgCompletionRate: parseDouble(json['avgCompletionRate']),
      bingeScore: parseDouble(json['bingeScore']),
    );
  }
}

class TracearrTopShowsSummary {
  const TracearrTopShowsSummary({
    required this.totalShows,
    required this.totalWatchHours,
  });

  final int totalShows;
  final double totalWatchHours;

  factory TracearrTopShowsSummary.fromJson(Map<String, dynamic> json) {
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

    return TracearrTopShowsSummary(
      totalShows: parseInt(json['totalShows']),
      totalWatchHours: parseDouble(json['totalWatchHours']),
    );
  }
}

class TracearrTopShowsPagination {
  const TracearrTopShowsPagination({
    required this.page,
    required this.pageSize,
    required this.total,
  });

  final int page;
  final int pageSize;
  final int total;

  factory TracearrTopShowsPagination.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return TracearrTopShowsPagination(
      page: parseInt(json['page']),
      pageSize: parseInt(json['pageSize']),
      total: parseInt(json['total']),
    );
  }
}
