class TracearrTopMoviesResponse {
  const TracearrTopMoviesResponse({
    required this.items,
    required this.summary,
    required this.pagination,
  });

  final List<TracearrTopMovieItem> items;
  final TracearrTopMoviesSummary summary;
  final TracearrTopMoviesPagination pagination;

  factory TracearrTopMoviesResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> itemsJson = json['items'] is List ? json['items'] as List<dynamic> : <dynamic>[];
    return TracearrTopMoviesResponse(
      items: itemsJson
          .map((dynamic item) => TracearrTopMovieItem.fromJson(item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{}))
          .toList(),
      summary: TracearrTopMoviesSummary.fromJson(json['summary'] is Map ? Map<String, dynamic>.from(json['summary'] as Map) : <String, dynamic>{}),
      pagination: TracearrTopMoviesPagination.fromJson(json['pagination'] is Map ? Map<String, dynamic>.from(json['pagination'] as Map) : <String, dynamic>{}),
    );
  }
}

class TracearrTopMovieItem {
  const TracearrTopMovieItem({
    required this.ratingKey,
    required this.title,
    required this.year,
    this.thumbPath,
    required this.serverId,
    required this.serverIds,
    required this.totalPlays,
    required this.totalWatchHours,
    required this.uniqueViewers,
    required this.completionRate,
  });

  final String ratingKey;
  final String title;
  final int year;
  final String? thumbPath;
  final String serverId;
  final List<String> serverIds;
  final int totalPlays;
  final double totalWatchHours;
  final int uniqueViewers;
  final double completionRate;

  factory TracearrTopMovieItem.fromJson(Map<String, dynamic> json) {
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

    return TracearrTopMovieItem(
      ratingKey: json['ratingKey']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Unknown Movie',
      year: parseInt(json['year']),
      thumbPath: json['thumbPath']?.toString(),
      serverId: json['serverId']?.toString() ?? '',
      serverIds: (json['serverIds'] as List<dynamic>?)
              ?.map((dynamic e) => e.toString())
              .toList() ??
          <String>[],
      totalPlays: parseInt(json['totalPlays']),
      totalWatchHours: parseDouble(json['totalWatchHours']),
      uniqueViewers: parseInt(json['uniqueViewers']),
      completionRate: parseDouble(json['completionRate']),
    );
  }
}

class TracearrTopMoviesSummary {
  const TracearrTopMoviesSummary({
    required this.totalMovies,
    required this.totalWatchHours,
  });

  final int totalMovies;
  final double totalWatchHours;

  factory TracearrTopMoviesSummary.fromJson(Map<String, dynamic> json) {
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

    return TracearrTopMoviesSummary(
      totalMovies: parseInt(json['totalMovies']),
      totalWatchHours: parseDouble(json['totalWatchHours']),
    );
  }
}

class TracearrTopMoviesPagination {
  const TracearrTopMoviesPagination({
    required this.page,
    required this.pageSize,
    required this.total,
  });

  final int page;
  final int pageSize;
  final int total;

  factory TracearrTopMoviesPagination.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return TracearrTopMoviesPagination(
      page: parseInt(json['page']),
      pageSize: parseInt(json['pageSize']),
      total: parseInt(json['total']),
    );
  }
}
