import 'package:freezed_annotation/freezed_annotation.dart';

part 'tracearr_activity_play_hod.freezed.dart';
part 'tracearr_activity_play_hod.g.dart';

@freezed
abstract class TracearrActivityPlayHod with _$TracearrActivityPlayHod {
  const TracearrActivityPlayHod._();

  const factory TracearrActivityPlayHod({
    @Default(0) int hour,
    @Default(0) int count,
  }) = _TracearrActivityPlayHod;

  factory TracearrActivityPlayHod.fromJson(Map<String, dynamic> json) =>
      _$TracearrActivityPlayHodFromJson(json);
}
