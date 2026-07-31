import 'package:freezed_annotation/freezed_annotation.dart';

part 'tracearr_activity_concurrent.freezed.dart';
part 'tracearr_activity_concurrent.g.dart';

@freezed
abstract class TracearrActivityConcurrent with _$TracearrActivityConcurrent {
  const TracearrActivityConcurrent._();

  const factory TracearrActivityConcurrent({
    required String hour,
    @Default(0) int total,
    @Default(0) int direct,
    @Default(0) int directStream,
    @Default(0) int transcode,
  }) = _TracearrActivityConcurrent;

  factory TracearrActivityConcurrent.fromJson(Map<String, dynamic> json) =>
      _$TracearrActivityConcurrentFromJson(json);
}
