import 'package:freezed_annotation/freezed_annotation.dart';

part 'plex_session.freezed.dart';
part 'plex_session.g.dart';

/// `GET /status/sessions` wraps the active sessions in a MediaContainer.
@freezed
abstract class PlexSessionsResponse with _$PlexSessionsResponse {
  const factory PlexSessionsResponse({
    @JsonKey(name: 'MediaContainer') PlexSessionsContainer? mediaContainer,
  }) = _PlexSessionsResponse;

  factory PlexSessionsResponse.fromJson(Map<String, dynamic> json) =>
      _$PlexSessionsResponseFromJson(json);
}

@freezed
abstract class PlexSessionsContainer with _$PlexSessionsContainer {
  const factory PlexSessionsContainer({
    @JsonKey(name: 'Metadata')
    @Default(<PlexSession>[])
    List<PlexSession> metadata,
  }) = _PlexSessionsContainer;

  factory PlexSessionsContainer.fromJson(Map<String, dynamic> json) =>
      _$PlexSessionsContainerFromJson(json);
}

/// One active playback session.
@freezed
abstract class PlexSession with _$PlexSession {
  const PlexSession._();

  const factory PlexSession({
    @Default('') String title,
    String? grandparentTitle,
    String? thumb,
    String? art,
    @JsonKey(name: 'viewOffset') int? viewOffset,
    @JsonKey(name: 'duration') int? duration,
    @JsonKey(name: 'User') PlexSessionUser? user,
    @JsonKey(name: 'Player') PlexSessionPlayer? player,
    @JsonKey(name: 'TranscodeSession') PlexTranscodeSession? transcode,
    @JsonKey(name: 'Session') PlexSessionInfo? session,
  }) = _PlexSession;

  factory PlexSession.fromJson(Map<String, dynamic> json) =>
      _$PlexSessionFromJson(json);

  String get sessionId => session?.id ?? '';
  int? get bandwidth => session?.bandwidth;
  String? get location => session?.location;

  double get progress {
    final int d = duration ?? 0;
    if (d <= 0) {
      return 0;
    }
    return ((viewOffset ?? 0) / d).clamp(0.0, 1.0);
  }

  bool get isTranscode =>
      transcode != null &&
      (transcode!.videoDecision == 'transcode' ||
          transcode!.audioDecision == 'transcode');

  String get decisionLabel => isTranscode ? 'Transcode' : 'Direct Play';
}

@freezed
abstract class PlexSessionInfo with _$PlexSessionInfo {
  const factory PlexSessionInfo({
    @Default('') String id,
    int? bandwidth,
    String? location,
  }) = _PlexSessionInfo;

  factory PlexSessionInfo.fromJson(Map<String, dynamic> json) =>
      _$PlexSessionInfoFromJson(json);
}

@freezed
abstract class PlexSessionUser with _$PlexSessionUser {
  const factory PlexSessionUser({
    @Default('') String title,
    String? thumb,
  }) = _PlexSessionUser;

  factory PlexSessionUser.fromJson(Map<String, dynamic> json) =>
      _$PlexSessionUserFromJson(json);
}

@freezed
abstract class PlexSessionPlayer with _$PlexSessionPlayer {
  const PlexSessionPlayer._();

  const factory PlexSessionPlayer({
    @Default('') String title,
    String? product,
    String? platform,
    @Default('') String machineIdentifier,
    @Default('') String state,
    String? address,
    @Default(false) bool local,
    @Default('') String protocolCapabilities,
  }) = _PlexSessionPlayer;

  factory PlexSessionPlayer.fromJson(Map<String, dynamic> json) =>
      _$PlexSessionPlayerFromJson(json);

  /// A player is remotely controllable when it advertises both the playback
  /// and timeline protocol capabilities (Plex Companion). Absent for most
  /// non-Plex-Pass / passive clients.
  bool get controllable =>
      protocolCapabilities.contains('playback') &&
      protocolCapabilities.contains('timeline');
}

@freezed
abstract class PlexTranscodeSession with _$PlexTranscodeSession {
  const factory PlexTranscodeSession({
    String? videoDecision,
    String? audioDecision,
    @Default(false) bool throttled,
  }) = _PlexTranscodeSession;

  factory PlexTranscodeSession.fromJson(Map<String, dynamic> json) =>
      _$PlexTranscodeSessionFromJson(json);
}
