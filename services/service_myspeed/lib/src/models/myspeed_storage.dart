import 'package:flutter/foundation.dart';

/// Represents storage and database information from MySpeed (`GET /api/storage`).
@immutable
class MySpeedStorage {
  const MySpeedStorage({
    this.size = 0,
    this.testCount,
  });

  /// Size of the database/storage in bytes.
  final num size;

  /// Total count of tests stored in the database.
  final int? testCount;

  factory MySpeedStorage.fromJson(dynamic json) {
    if (json is Map) {
      final dynamic rawSize = json['size'];
      final num sizeNum;
      if (rawSize is num) {
        sizeNum = rawSize;
      } else if (rawSize is String) {
        sizeNum = num.tryParse(rawSize) ?? 0;
      } else {
        sizeNum = 0;
      }

      final dynamic rawCount = json['testCount'];
      final int? countInt;
      if (rawCount is int) {
        countInt = rawCount;
      } else if (rawCount is num) {
        countInt = rawCount.toInt();
      } else if (rawCount is String) {
        countInt = int.tryParse(rawCount);
      } else {
        countInt = null;
      }

      return MySpeedStorage(
        size: sizeNum,
        testCount: countInt,
      );
    }
    return const MySpeedStorage();
  }

  /// Formatted storage size string (e.g., '1.2 MB', '500 KB', '0 B').
  String get formattedSize {
    if (size <= 0) return '0 B';
    const List<String> units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
    int unitIndex = 0;
    double current = size.toDouble();
    while (current >= 1024 && unitIndex < units.length - 1) {
      current /= 1024;
      unitIndex++;
    }
    return '${current.toStringAsFixed(current >= 100 ? 0 : 1)} ${units[unitIndex]}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MySpeedStorage &&
          runtimeType == other.runtimeType &&
          size == other.size &&
          testCount == other.testCount;

  @override
  int get hashCode => Object.hash(size, testCount);
}
