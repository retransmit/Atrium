import 'package:freezed_annotation/freezed_annotation.dart';

part 'sab_stats.freezed.dart';
part 'sab_stats.g.dart';

/// `GET /api?mode=server_stats&output=json`. Totals are bytes downloaded over
/// each window (plus a per-server breakdown that is not modeled here).
@freezed
abstract class SabServerStats with _$SabServerStats {
  const factory SabServerStats({
    @Default(0) int total,
    @Default(0) int month,
    @Default(0) int week,
    @Default(0) int day,
  }) = _SabServerStats;

  factory SabServerStats.fromJson(Map<String, dynamic> json) =>
      _$SabServerStatsFromJson(json);
}
