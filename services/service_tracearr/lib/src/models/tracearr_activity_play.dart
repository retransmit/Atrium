import 'package:freezed_annotation/freezed_annotation.dart';

part 'tracearr_activity_play.freezed.dart';
part 'tracearr_activity_play.g.dart';

@freezed
abstract class TracearrActivityPlay with _$TracearrActivityPlay {
  const TracearrActivityPlay._();

  const factory TracearrActivityPlay({
    required String date,
    required String serverId,
    @Default(0) int count,
  }) = _TracearrActivityPlay;

  factory TracearrActivityPlay.fromJson(Map<String, dynamic> json) =>
      _$TracearrActivityPlayFromJson(json);
}
