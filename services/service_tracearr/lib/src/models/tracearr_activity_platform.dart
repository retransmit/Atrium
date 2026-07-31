import 'package:freezed_annotation/freezed_annotation.dart';

part 'tracearr_activity_platform.freezed.dart';
part 'tracearr_activity_platform.g.dart';

@freezed
abstract class TracearrActivityPlatform with _$TracearrActivityPlatform {
  const TracearrActivityPlatform._();

  const factory TracearrActivityPlatform({
    required String platform,
    @Default(0) int count,
  }) = _TracearrActivityPlatform;

  factory TracearrActivityPlatform.fromJson(Map<String, dynamic> json) =>
      _$TracearrActivityPlatformFromJson(json);
}
