import 'package:freezed_annotation/freezed_annotation.dart';

part 'tracearr_stats.freezed.dart';
part 'tracearr_stats.g.dart';

@freezed
abstract class TracearrStats with _$TracearrStats {
  const TracearrStats._();

  const factory TracearrStats({
    @Default(0) int totalItems,
    @Default('0') String totalSizeBytes,
    @Default(0) int movieCount,
    @Default(0) int episodeCount,
    @Default(0) int showCount,
    TracearrQualityBreakdown? qualityBreakdown,
    @Default('') String asOf,
  }) = _TracearrStats;

  factory TracearrStats.fromJson(Map<String, dynamic> json) =>
      _$TracearrStatsFromJson(json);
}

@freezed
abstract class TracearrQualityBreakdown with _$TracearrQualityBreakdown {
  const TracearrQualityBreakdown._();

  const factory TracearrQualityBreakdown({
    @Default(0) int count4k,
    @Default(0) int count1080p,
    @Default(0) int count720p,
    @Default(0) int countSd,
  }) = _TracearrQualityBreakdown;

  factory TracearrQualityBreakdown.fromJson(Map<String, dynamic> json) =>
      _$TracearrQualityBreakdownFromJson(json);
}
