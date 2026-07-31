import 'package:freezed_annotation/freezed_annotation.dart';

part 'tracearr_dashboard_stats.freezed.dart';
part 'tracearr_dashboard_stats.g.dart';

@freezed
abstract class TracearrDashboardStats with _$TracearrDashboardStats {
  const factory TracearrDashboardStats({
    @JsonKey(defaultValue: 0) required int activeStreams,
    @JsonKey(defaultValue: 0) required int todayPlays,
    @JsonKey(defaultValue: 0) required int todaySessions,
    @JsonKey(defaultValue: 0.0) required double watchTimeHours,
    @JsonKey(defaultValue: 0) required int alertsLast24h,
    @JsonKey(defaultValue: 0) required int activeUsersToday,
  }) = _TracearrDashboardStats;

  factory TracearrDashboardStats.fromJson(Map<String, dynamic> json) =>
      _$TracearrDashboardStatsFromJson(json);
}
