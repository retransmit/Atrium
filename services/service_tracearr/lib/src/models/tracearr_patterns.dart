class TracearrPatternsResponse {
  const TracearrPatternsResponse({
    required this.bingeShows,
    required this.peakTimes,
    required this.seasonalTrends,
    required this.summary,
  });

  final List<TracearrBingeShow> bingeShows;
  final TracearrPeakTimes peakTimes;
  final TracearrSeasonalTrends seasonalTrends;
  final TracearrPatternsSummary summary;

  factory TracearrPatternsResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> bingeJson = json['bingeShows'] is List ? json['bingeShows'] as List<dynamic> : <dynamic>[];
    return TracearrPatternsResponse(
      bingeShows: bingeJson
          .map((dynamic item) => TracearrBingeShow.fromJson(item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{}))
          .toList(),
      peakTimes: TracearrPeakTimes.fromJson(json['peakTimes'] is Map ? Map<String, dynamic>.from(json['peakTimes'] as Map) : <String, dynamic>{}),
      seasonalTrends: TracearrSeasonalTrends.fromJson(json['seasonalTrends'] is Map ? Map<String, dynamic>.from(json['seasonalTrends'] as Map) : <String, dynamic>{}),
      summary: TracearrPatternsSummary.fromJson(json['summary'] is Map ? Map<String, dynamic>.from(json['summary'] as Map) : <String, dynamic>{}),
    );
  }
}

class TracearrBingeShow {
  const TracearrBingeShow({
    required this.showTitle,
    required this.primaryServerId,
    this.thumbPath,
    required this.totalEpisodeWatches,
    required this.consecutiveEpisodes,
    required this.consecutivePct,
    required this.avgGapMinutes,
    required this.bingeScore,
    required this.maxEpisodesInOneDay,
    required this.serverIds,
  });

  final String showTitle;
  final String primaryServerId;
  final String? thumbPath;
  final int totalEpisodeWatches;
  final int consecutiveEpisodes;
  final double consecutivePct;
  final double avgGapMinutes;
  final double bingeScore;
  final int maxEpisodesInOneDay;
  final List<String> serverIds;

  factory TracearrBingeShow.fromJson(Map<String, dynamic> json) {
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

    return TracearrBingeShow(
      showTitle: json['showTitle']?.toString() ?? 'Unknown Show',
      primaryServerId: json['primaryServerId']?.toString() ?? '',
      thumbPath: json['thumbPath']?.toString(),
      totalEpisodeWatches: parseInt(json['totalEpisodeWatches']),
      consecutiveEpisodes: parseInt(json['consecutiveEpisodes']),
      consecutivePct: parseDouble(json['consecutivePct']),
      avgGapMinutes: parseDouble(json['avgGapMinutes']),
      bingeScore: parseDouble(json['bingeScore']),
      maxEpisodesInOneDay: parseInt(json['maxEpisodesInOneDay']),
      serverIds: (json['serverIds'] as List<dynamic>?)
              ?.map((dynamic e) => e.toString())
              .toList() ??
          <String>[],
    );
  }
}

class TracearrPeakTimes {
  const TracearrPeakTimes({
    required this.hourlyDistribution,
    required this.peakHour,
    required this.peakDayOfWeek,
  });

  final List<TracearrHourlyDistribution> hourlyDistribution;
  final int peakHour;
  final int peakDayOfWeek;

  factory TracearrPeakTimes.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    final List<dynamic> hourlyJson = json['hourlyDistribution'] is List ? json['hourlyDistribution'] as List<dynamic> : <dynamic>[];
    return TracearrPeakTimes(
      hourlyDistribution: hourlyJson
          .map((dynamic item) => TracearrHourlyDistribution.fromJson(item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{}))
          .toList(),
      peakHour: parseInt(json['peakHour']),
      peakDayOfWeek: parseInt(json['peakDayOfWeek']),
    );
  }
}

class TracearrHourlyDistribution {
  const TracearrHourlyDistribution({
    required this.hour,
    required this.watchCount,
    required this.totalWatchMs,
    required this.pctOfTotal,
  });

  final int hour;
  final int watchCount;
  final int totalWatchMs;
  final double pctOfTotal;

  factory TracearrHourlyDistribution.fromJson(Map<String, dynamic> json) {
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

    return TracearrHourlyDistribution(
      hour: parseInt(json['hour']),
      watchCount: parseInt(json['watchCount']),
      totalWatchMs: parseInt(json['totalWatchMs']),
      pctOfTotal: parseDouble(json['pctOfTotal']),
    );
  }
}

class TracearrSeasonalTrends {
  const TracearrSeasonalTrends({
    required this.monthlyTrends,
    this.busiestMonth,
    this.quietestMonth,
  });

  final List<TracearrMonthlyTrend> monthlyTrends;
  final String? busiestMonth;
  final String? quietestMonth;

  factory TracearrSeasonalTrends.fromJson(Map<String, dynamic> json) {
    final List<dynamic> monthsJson = json['monthlyTrends'] is List ? json['monthlyTrends'] as List<dynamic> : <dynamic>[];
    return TracearrSeasonalTrends(
      monthlyTrends: monthsJson
          .map((dynamic item) => TracearrMonthlyTrend.fromJson(item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{}))
          .toList(),
      busiestMonth: json['busiestMonth']?.toString(),
      quietestMonth: json['quietestMonth']?.toString(),
    );
  }
}

class TracearrMonthlyTrend {
  const TracearrMonthlyTrend({
    required this.month,
    required this.watchCount,
    required this.totalWatchMs,
    required this.uniqueItems,
    required this.avgWatchesPerDay,
  });

  final String month;
  final int watchCount;
  final int totalWatchMs;
  final int uniqueItems;
  final double avgWatchesPerDay;

  factory TracearrMonthlyTrend.fromJson(Map<String, dynamic> json) {
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

    return TracearrMonthlyTrend(
      month: json['month']?.toString() ?? '',
      watchCount: parseInt(json['watchCount']),
      totalWatchMs: parseInt(json['totalWatchMs']),
      uniqueItems: parseInt(json['uniqueItems']),
      avgWatchesPerDay: parseDouble(json['avgWatchesPerDay']),
    );
  }
}

class TracearrPatternsSummary {
  const TracearrPatternsSummary({
    required this.totalWatchSessions,
    required this.avgSessionsPerDay,
    required this.bingeSessionsPct,
  });

  final int totalWatchSessions;
  final double avgSessionsPerDay;
  final double bingeSessionsPct;

  factory TracearrPatternsSummary.fromJson(Map<String, dynamic> json) {
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

    return TracearrPatternsSummary(
      totalWatchSessions: parseInt(json['totalWatchSessions']),
      avgSessionsPerDay: parseDouble(json['avgSessionsPerDay']),
      bingeSessionsPct: parseDouble(json['bingeSessionsPct']),
    );
  }
}
