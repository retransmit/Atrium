import 'package:freezed_annotation/freezed_annotation.dart';

import 'aria2_json.dart';

part 'aria2_global_stat.freezed.dart';
part 'aria2_global_stat.g.dart';

/// `aria2.getGlobalStat`: the daemon's own totals.
@freezed
abstract class Aria2GlobalStat with _$Aria2GlobalStat {
  const factory Aria2GlobalStat({
    @JsonKey(fromJson: aria2Int) @Default(0) int downloadSpeed,
    @JsonKey(fromJson: aria2Int) @Default(0) int uploadSpeed,
    @JsonKey(fromJson: aria2Int) @Default(0) int numActive,
    @JsonKey(fromJson: aria2Int) @Default(0) int numWaiting,
    @JsonKey(fromJson: aria2Int) @Default(0) int numStopped,
    @JsonKey(fromJson: aria2Int) @Default(0) int numStoppedTotal,
  }) = _Aria2GlobalStat;

  factory Aria2GlobalStat.fromJson(Map<String, dynamic> json) =>
      _$Aria2GlobalStatFromJson(json);
}
