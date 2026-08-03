import 'package:freezed_annotation/freezed_annotation.dart';

part 'transmission_session.freezed.dart';
part 'transmission_session.g.dart';

/// Session-wide settings and identity from `session-get`.
///
/// Transmission's bandwidth model has three moving parts, which is why this is
/// richer than a pair of numbers: each direction has a **limit value and a
/// separate enabled flag**, and on top of that sits "alt speed" (the turtle
/// button) which overrides both while it is on.
///
/// Limits are in **KB/s**, not bytes per second like the live rates.
@freezed
abstract class TransmissionSession with _$TransmissionSession {
  const TransmissionSession._();

  const factory TransmissionSession({
    @Default('') String version,
    @JsonKey(name: 'rpc-version') @Default(0) int rpcVersion,
    @JsonKey(name: 'download-dir') @Default('') String downloadDir,
    @JsonKey(name: 'speed-limit-down') @Default(0) int speedLimitDown,
    @JsonKey(name: 'speed-limit-down-enabled')
    @Default(false)
    bool speedLimitDownEnabled,
    @JsonKey(name: 'speed-limit-up') @Default(0) int speedLimitUp,
    @JsonKey(name: 'speed-limit-up-enabled')
    @Default(false)
    bool speedLimitUpEnabled,
    @JsonKey(name: 'alt-speed-enabled') @Default(false) bool altSpeedEnabled,
    @JsonKey(name: 'alt-speed-down') @Default(0) int altSpeedDown,
    @JsonKey(name: 'alt-speed-up') @Default(0) int altSpeedUp,

    /// Bytes free at [downloadDir], or **-1 when the daemon cannot tell** -
    /// which is what a containerised Transmission commonly reports.
    @JsonKey(name: 'download-dir-free-space')
    @Default(-1)
    int downloadDirFreeSpace,
  }) = _TransmissionSession;

  factory TransmissionSession.fromJson(Map<String, dynamic> json) =>
      _$TransmissionSessionFromJson(json);

  bool get knowsFreeSpace => downloadDirFreeSpace >= 0;

  /// The fields worth asking `session-get` for.
  static const List<String> fields = <String>[
    'version',
    'rpc-version',
    'download-dir',
    'speed-limit-down',
    'speed-limit-down-enabled',
    'speed-limit-up',
    'speed-limit-up-enabled',
    'alt-speed-enabled',
    'alt-speed-down',
    'alt-speed-up',
    'download-dir-free-space',
  ];
}

/// Live session counters from `session-stats`.
@freezed
abstract class TransmissionSessionStats with _$TransmissionSessionStats {
  const factory TransmissionSessionStats({
    @JsonKey(name: 'downloadSpeed') @Default(0) int downloadSpeed,
    @JsonKey(name: 'uploadSpeed') @Default(0) int uploadSpeed,
    @JsonKey(name: 'activeTorrentCount') @Default(0) int activeTorrentCount,
    @JsonKey(name: 'pausedTorrentCount') @Default(0) int pausedTorrentCount,
    @JsonKey(name: 'torrentCount') @Default(0) int torrentCount,
  }) = _TransmissionSessionStats;

  factory TransmissionSessionStats.fromJson(Map<String, dynamic> json) =>
      _$TransmissionSessionStatsFromJson(json);
}
