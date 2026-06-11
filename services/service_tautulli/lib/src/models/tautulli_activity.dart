import 'package:freezed_annotation/freezed_annotation.dart';

part 'tautulli_activity.freezed.dart';
part 'tautulli_activity.g.dart';

/// Tautulli wraps responses as `{ "response": { "result": …, "data": … } }`.
@freezed
class TautulliActivityEnvelope with _$TautulliActivityEnvelope {
  const factory TautulliActivityEnvelope({
    required TautulliActivityBody response,
  }) = _TautulliActivityEnvelope;

  factory TautulliActivityEnvelope.fromJson(Map<String, dynamic> json) =>
      _$TautulliActivityEnvelopeFromJson(json);
}

@freezed
class TautulliActivityBody with _$TautulliActivityBody {
  const factory TautulliActivityBody({
    @Default('') String result,
    TautulliActivity? data,
  }) = _TautulliActivityBody;

  factory TautulliActivityBody.fromJson(Map<String, dynamic> json) =>
      _$TautulliActivityBodyFromJson(json);
}

@freezed
class TautulliActivity with _$TautulliActivity {
  const factory TautulliActivity({
    @JsonKey(name: 'stream_count') @Default('0') String streamCount,
    @Default(<TautulliSession>[]) List<TautulliSession> sessions,
  }) = _TautulliActivity;

  factory TautulliActivity.fromJson(Map<String, dynamic> json) =>
      _$TautulliActivityFromJson(json);
}

/// A single active stream.
@freezed
class TautulliSession with _$TautulliSession {
  const factory TautulliSession({
    @JsonKey(name: 'friendly_name') @Default('') String friendlyName,
    @JsonKey(name: 'full_title') @Default('') String fullTitle,
    @JsonKey(name: 'progress_percent') @Default('0') String progressPercent,
    @Default('') String state,
    @Default('') String player,
    @JsonKey(name: 'transcode_decision') @Default('') String transcodeDecision,
    @JsonKey(name: 'media_type') @Default('') String mediaType,
  }) = _TautulliSession;

  factory TautulliSession.fromJson(Map<String, dynamic> json) =>
      _$TautulliSessionFromJson(json);
}
