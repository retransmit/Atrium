import 'dart:math';

class TracearrStorageResponse {
  const TracearrStorageResponse({
    required this.current,
    required this.history,
    required this.growthRate,
    required this.predictions,
  });

  factory TracearrStorageResponse.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> currentJson =
        json['current'] is Map ? Map<String, dynamic>.from(json['current'] as Map) : <String, dynamic>{};
    final List<dynamic> historyList = json['history'] is List ? json['history'] as List<dynamic> : <dynamic>[];
    final Map<String, dynamic> growthJson =
        json['growthRate'] is Map ? Map<String, dynamic>.from(json['growthRate'] as Map) : <String, dynamic>{};
    final Map<String, dynamic> predJson =
        json['predictions'] is Map ? Map<String, dynamic>.from(json['predictions'] as Map) : <String, dynamic>{};

    return TracearrStorageResponse(
      current: TracearrStorageCurrent.fromJson(currentJson),
      history: historyList
          .whereType<Map<dynamic, dynamic>>()
          .map((Map<dynamic, dynamic> item) => TracearrStorageHistoryItem.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      growthRate: TracearrStorageGrowthRate.fromJson(growthJson),
      predictions: TracearrStoragePredictions.fromJson(predJson),
    );
  }

  final TracearrStorageCurrent current;
  final List<TracearrStorageHistoryItem> history;
  final TracearrStorageGrowthRate growthRate;
  final TracearrStoragePredictions predictions;

  static TracearrStorageResponse aggregate(List<TracearrStorageResponse> responses) {
    if (responses.isEmpty) {
      return const TracearrStorageResponse(
        current: TracearrStorageCurrent(totalSizeBytes: 0, totalItems: 0, lastUpdated: ''),
        history: <TracearrStorageHistoryItem>[],
        growthRate: TracearrStorageGrowthRate(bytesPerDay: 0, bytesPerWeek: 0, bytesPerMonth: 0),
        predictions: TracearrStoragePredictions(
          day30: TracearrStoragePredictionPoint(predicted: 0, min: 0, max: 0),
          day90: TracearrStoragePredictionPoint(predicted: 0, min: 0, max: 0),
          day365: TracearrStoragePredictionPoint(predicted: 0, min: 0, max: 0),
          confidence: 'none',
          minDataDays: 0,
          currentDataDays: 0,
        ),
      );
    }
    if (responses.length == 1) {
      return responses.first;
    }

    double totalCurrentBytes = 0;
    int totalCurrentItems = 0;
    String lastUpdated = '';

    double totalDayBytes = 0;
    double totalWeekBytes = 0;
    double totalMonthBytes = 0;

    double pred30 = 0;
    double min30 = 0;
    double max30 = 0;

    double pred90 = 0;
    double min90 = 0;
    double max90 = 0;

    double pred365 = 0;
    double min365 = 0;
    double max365 = 0;

    int minDays = 0;
    int currentDays = 0;
    String? confidence;

    final Map<String, double> historyMap = <String, double>{};

    for (final TracearrStorageResponse res in responses) {
      totalCurrentBytes += res.current.totalSizeBytes;
      totalCurrentItems += res.current.totalItems;
      if (res.current.lastUpdated.isNotEmpty) {
        lastUpdated = res.current.lastUpdated;
      }

      totalDayBytes += res.growthRate.bytesPerDay;
      totalWeekBytes += res.growthRate.bytesPerWeek;
      totalMonthBytes += res.growthRate.bytesPerMonth;

      pred30 += res.predictions.day30.predicted;
      min30 += res.predictions.day30.min;
      max30 += res.predictions.day30.max;

      pred90 += res.predictions.day90.predicted;
      min90 += res.predictions.day90.min;
      max90 += res.predictions.day90.max;

      pred365 += res.predictions.day365.predicted;
      min365 += res.predictions.day365.min;
      max365 += res.predictions.day365.max;

      minDays = max(minDays, res.predictions.minDataDays);
      currentDays = max(currentDays, res.predictions.currentDataDays);
      if (confidence == null || res.predictions.confidence == 'low') {
        confidence = res.predictions.confidence;
      }

      for (final TracearrStorageHistoryItem item in res.history) {
        historyMap[item.day] = (historyMap[item.day] ?? 0) + item.totalSizeBytes;
      }
    }

    final List<String> sortedDays = historyMap.keys.toList()..sort();
    final List<TracearrStorageHistoryItem> aggregatedHistory = sortedDays
        .map((String d) => TracearrStorageHistoryItem(day: d, totalSizeBytes: historyMap[d]!))
        .toList();

    return TracearrStorageResponse(
      current: TracearrStorageCurrent(
        totalSizeBytes: totalCurrentBytes,
        totalItems: totalCurrentItems,
        lastUpdated: lastUpdated,
      ),
      history: aggregatedHistory,
      growthRate: TracearrStorageGrowthRate(
        bytesPerDay: totalDayBytes,
        bytesPerWeek: totalWeekBytes,
        bytesPerMonth: totalMonthBytes,
      ),
      predictions: TracearrStoragePredictions(
        day30: TracearrStoragePredictionPoint(predicted: pred30, min: min30, max: max30),
        day90: TracearrStoragePredictionPoint(predicted: pred90, min: min90, max: max90),
        day365: TracearrStoragePredictionPoint(predicted: pred365, min: min365, max: max365),
        confidence: confidence ?? 'low',
        minDataDays: minDays,
        currentDataDays: currentDays,
      ),
    );
  }
}

class TracearrStorageCurrent {
  const TracearrStorageCurrent({
    required this.totalSizeBytes,
    required this.totalItems,
    required this.lastUpdated,
  });

  factory TracearrStorageCurrent.fromJson(Map<String, dynamic> json) {
    return TracearrStorageCurrent(
      totalSizeBytes: _parseNumber(json['totalSizeBytes']),
      totalItems: _parseInt(json['totalItems']),
      lastUpdated: (json['lastUpdated'] ?? '') as String,
    );
  }

  final double totalSizeBytes;
  final int totalItems;
  final String lastUpdated;
}

class TracearrStorageHistoryItem {
  const TracearrStorageHistoryItem({
    required this.day,
    required this.totalSizeBytes,
  });

  factory TracearrStorageHistoryItem.fromJson(Map<String, dynamic> json) {
    return TracearrStorageHistoryItem(
      day: (json['day'] ?? '') as String,
      totalSizeBytes: _parseNumber(json['totalSizeBytes']),
    );
  }

  final String day;
  final double totalSizeBytes;
}

class TracearrStorageGrowthRate {
  const TracearrStorageGrowthRate({
    required this.bytesPerDay,
    required this.bytesPerWeek,
    required this.bytesPerMonth,
  });

  factory TracearrStorageGrowthRate.fromJson(Map<String, dynamic> json) {
    return TracearrStorageGrowthRate(
      bytesPerDay: _parseNumber(json['bytesPerDay']),
      bytesPerWeek: _parseNumber(json['bytesPerWeek']),
      bytesPerMonth: _parseNumber(json['bytesPerMonth']),
    );
  }

  final double bytesPerDay;
  final double bytesPerWeek;
  final double bytesPerMonth;
}

class TracearrStoragePredictions {
  const TracearrStoragePredictions({
    required this.day30,
    required this.day90,
    required this.day365,
    required this.confidence,
    required this.minDataDays,
    required this.currentDataDays,
  });

  factory TracearrStoragePredictions.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> d30 =
        json['day30'] is Map ? Map<String, dynamic>.from(json['day30'] as Map) : <String, dynamic>{};
    final Map<String, dynamic> d90 =
        json['day90'] is Map ? Map<String, dynamic>.from(json['day90'] as Map) : <String, dynamic>{};
    final Map<String, dynamic> d365 =
        json['day365'] is Map ? Map<String, dynamic>.from(json['day365'] as Map) : <String, dynamic>{};

    return TracearrStoragePredictions(
      day30: TracearrStoragePredictionPoint.fromJson(d30),
      day90: TracearrStoragePredictionPoint.fromJson(d90),
      day365: TracearrStoragePredictionPoint.fromJson(d365),
      confidence: (json['confidence'] ?? 'low') as String,
      minDataDays: _parseInt(json['minDataDays']),
      currentDataDays: _parseInt(json['currentDataDays']),
    );
  }

  final TracearrStoragePredictionPoint day30;
  final TracearrStoragePredictionPoint day90;
  final TracearrStoragePredictionPoint day365;
  final String confidence;
  final int minDataDays;
  final int currentDataDays;
}

class TracearrStoragePredictionPoint {
  const TracearrStoragePredictionPoint({
    required this.predicted,
    required this.min,
    required this.max,
  });

  factory TracearrStoragePredictionPoint.fromJson(Map<String, dynamic> json) {
    return TracearrStoragePredictionPoint(
      predicted: _parseNumber(json['predicted']),
      min: _parseNumber(json['min']),
      max: _parseNumber(json['max']),
    );
  }

  final double predicted;
  final double min;
  final double max;
}

double _parseNumber(dynamic val) {
  if (val == null) {
    return 0.0;
  }
  if (val is num) {
    return val.toDouble();
  }
  return double.tryParse(val.toString()) ?? 0.0;
}

int _parseInt(dynamic val) {
  if (val == null) {
    return 0;
  }
  if (val is int) {
    return val;
  }
  if (val is num) {
    return val.round();
  }
  return int.tryParse(val.toString()) ?? 0;
}
