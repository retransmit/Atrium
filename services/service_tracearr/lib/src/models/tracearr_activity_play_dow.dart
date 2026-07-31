import 'package:freezed_annotation/freezed_annotation.dart';

part 'tracearr_activity_play_dow.freezed.dart';
part 'tracearr_activity_play_dow.g.dart';

@freezed
abstract class TracearrActivityPlayDow with _$TracearrActivityPlayDow {
  const TracearrActivityPlayDow._();

  const factory TracearrActivityPlayDow({
    @Default(0) int day,
    required String name,
    @Default(0) int count,
  }) = _TracearrActivityPlayDow;

  factory TracearrActivityPlayDow.fromJson(Map<String, dynamic> json) =>
      _$TracearrActivityPlayDowFromJson(json);
}
