import 'package:freezed_annotation/freezed_annotation.dart';
import 'tracearr_session.dart';

part 'tracearr_active_sessions.freezed.dart';
part 'tracearr_active_sessions.g.dart';

@freezed
abstract class TracearrActiveSessions with _$TracearrActiveSessions {
  const TracearrActiveSessions._();

  const factory TracearrActiveSessions({
    @JsonKey(name: 'data', defaultValue: <TracearrSession>[])
    required List<TracearrSession> sessions,
  }) = _TracearrActiveSessions;

  factory TracearrActiveSessions.fromJson(Map<String, dynamic> json) =>
      _$TracearrActiveSessionsFromJson(json);
}
