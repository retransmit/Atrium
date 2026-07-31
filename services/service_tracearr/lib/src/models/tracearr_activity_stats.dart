import 'package:freezed_annotation/freezed_annotation.dart';

import 'tracearr_activity_platform.dart';
import 'tracearr_activity_play.dart';
import 'tracearr_activity_play_dow.dart';
import 'tracearr_activity_play_hod.dart';
import 'tracearr_activity_quality.dart';
import 'tracearr_activity_concurrent.dart';
import 'tracearr_activity_engagement.dart';

part 'tracearr_activity_stats.freezed.dart';

@freezed
abstract class TracearrActivityStats with _$TracearrActivityStats {
  const TracearrActivityStats._();

  const factory TracearrActivityStats({
    @Default(<TracearrActivityPlay>[]) List<TracearrActivityPlay> plays,
    @Default(<TracearrActivityPlayDow>[]) List<TracearrActivityPlayDow> playsByDayOfWeek,
    @Default(<TracearrActivityPlayHod>[]) List<TracearrActivityPlayHod> playsByHourOfDay,
    @Default(<TracearrActivityPlatform>[]) List<TracearrActivityPlatform> platforms,
    required TracearrActivityQuality quality,
    required List<TracearrActivityConcurrent> concurrentPlays,
    required TracearrActivityEngagement engagement,
  }) = _TracearrActivityStats;
}
