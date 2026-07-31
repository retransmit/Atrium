import 'package:freezed_annotation/freezed_annotation.dart';

part 'tracearr_activity_quality.freezed.dart';
part 'tracearr_activity_quality.g.dart';

@freezed
abstract class TracearrActivityQuality with _$TracearrActivityQuality {
  const TracearrActivityQuality._();

  const factory TracearrActivityQuality({
    @Default(0) int directPlay,
    @Default(0) int directStream,
    @Default(0) int transcode,
    @Default(0) int total,
    @Default(0) double directPlayPercent,
    @Default(0) double directStreamPercent,
    @Default(0) double transcodePercent,
  }) = _TracearrActivityQuality;

  factory TracearrActivityQuality.fromJson(Map<String, dynamic> json) =>
      _$TracearrActivityQualityFromJson(json);
}
