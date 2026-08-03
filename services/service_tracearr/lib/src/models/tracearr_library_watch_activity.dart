class TracearrLibraryWatchResponse {
  final List<TracearrLibraryWatchItem> items;
  final TracearrWatchSummary summary;
  final TracearrWatchPagination pagination;

  const TracearrLibraryWatchResponse({
    required this.items,
    required this.summary,
    required this.pagination,
  });

  factory TracearrLibraryWatchResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> itemsJson = json['items'] is List ? json['items'] as List<dynamic> : <dynamic>[];

    return TracearrLibraryWatchResponse(
      items: itemsJson
          .map((dynamic item) => TracearrLibraryWatchItem.fromJson(item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{}))
          .toList(),
      summary: TracearrWatchSummary.fromJson(json['summary'] is Map ? Map<String, dynamic>.from(json['summary'] as Map) : <String, dynamic>{}),
      pagination: TracearrWatchPagination.fromJson(json['pagination'] is Map ? Map<String, dynamic>.from(json['pagination'] as Map) : <String, dynamic>{}),
    );
  }
}

class TracearrLibraryWatchItem {
  final String id;
  final String serverId;
  final String serverName;
  final String libraryId;
  final String title;
  final String mediaType;
  final int year;
  final int fileSize;
  final String? resolution;
  final String addedAt;
  final int watchCount;
  final int totalWatchMs;
  final String lastWatchedAt;
  final List<String> serverIds;

  const TracearrLibraryWatchItem({
    required this.id,
    required this.serverId,
    required this.serverName,
    required this.libraryId,
    required this.title,
    required this.mediaType,
    required this.year,
    required this.fileSize,
    this.resolution,
    required this.addedAt,
    required this.watchCount,
    required this.totalWatchMs,
    required this.lastWatchedAt,
    required this.serverIds,
  });

  factory TracearrLibraryWatchItem.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return TracearrLibraryWatchItem(
      id: json['id']?.toString() ?? '',
      serverId: json['serverId']?.toString() ?? '',
      serverName: json['serverName']?.toString() ?? '',
      libraryId: json['libraryId']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Unknown',
      mediaType: json['mediaType']?.toString() ?? '',
      year: parseInt(json['year']),
      fileSize: parseInt(json['fileSize']),
      resolution: json['resolution']?.toString(),
      addedAt: json['addedAt']?.toString() ?? '',
      watchCount: parseInt(json['watchCount']),
      totalWatchMs: parseInt(json['totalWatchMs']),
      lastWatchedAt: json['lastWatchedAt']?.toString() ?? '',
      serverIds: (json['serverIds'] as List<dynamic>?)
              ?.map((dynamic e) => e.toString())
              .toList() ??
          <String>[],
    );
  }
}

class TracearrWatchSummary {
  final int totalItems;
  final int watchedCount;
  final int unwatchedCount;
  final double watchedPct;
  final int totalWatchMs;
  final double avgWatchesPerItem;
  final int completedCount;

  const TracearrWatchSummary({
    required this.totalItems,
    required this.watchedCount,
    required this.unwatchedCount,
    required this.watchedPct,
    required this.totalWatchMs,
    required this.avgWatchesPerItem,
    required this.completedCount,
  });

  factory TracearrWatchSummary.fromJson(Map<String, dynamic> json) {
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

    return TracearrWatchSummary(
      totalItems: parseInt(json['totalItems']),
      watchedCount: parseInt(json['watchedCount']),
      unwatchedCount: parseInt(json['unwatchedCount']),
      watchedPct: parseDouble(json['watchedPct']),
      totalWatchMs: parseInt(json['totalWatchMs']),
      avgWatchesPerItem: parseDouble(json['avgWatchesPerItem']),
      completedCount: parseInt(json['completedCount']),
    );
  }
}

class TracearrWatchPagination {
  final int page;
  final int pageSize;
  final int total;

  const TracearrWatchPagination({
    required this.page,
    required this.pageSize,
    required this.total,
  });

  factory TracearrWatchPagination.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return TracearrWatchPagination(
      page: parseInt(json['page']),
      pageSize: parseInt(json['pageSize']),
      total: parseInt(json['total']),
    );
  }
}