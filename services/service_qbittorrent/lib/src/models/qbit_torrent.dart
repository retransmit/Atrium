import 'package:freezed_annotation/freezed_annotation.dart';

part 'qbit_torrent.freezed.dart';
part 'qbit_torrent.g.dart';

/// A torrent as returned by `GET /api/v2/torrents/info`.
///
/// Only the fields Atrium renders are modeled. qBittorrent returns snake_case
/// keys; the snake_case ones are mapped with [JsonKey].
@freezed
abstract class QbitTorrent with _$QbitTorrent {
  const factory QbitTorrent({
    required String hash,
    required String name,

    /// Raw qBittorrent state string (downloading, stalledUP, pausedDL,
    /// stoppedUP, queuedDL, checkingUP, error, …).
    required String state,

    /// 0.0 - 1.0.
    @Default(0) double progress,

    /// Download speed, bytes/s.
    @Default(0) int dlspeed,

    /// Upload speed, bytes/s.
    @Default(0) int upspeed,

    /// Total size of selected files, bytes.
    @Default(0) int size,
    @Default(0) int downloaded,
    @Default(0) int uploaded,

    /// ETA in seconds; 8640000 means infinity / unknown.
    @Default(8640000) int eta,
    @JsonKey(name: 'magnet_uri') @Default('') String magnetUri,
    @Default('') String category,
    @Default(0) double ratio,
    @JsonKey(name: 'num_seeds') @Default(0) int numSeeds,
    @JsonKey(name: 'num_leechs') @Default(0) int numLeechs,
    @JsonKey(name: 'added_on') @Default(0) int addedOn,
    @Default(0) int priority,
    @JsonKey(name: 'completion_on') @Default(0) int completionOn,
    @JsonKey(name: 'downloaded_session') @Default(0) int downloadedSession,
    @JsonKey(name: 'uploaded_session') @Default(0) int uploadedSession,
  }) = _QbitTorrent;

  factory QbitTorrent.fromJson(Map<String, dynamic> json) =>
      _$QbitTorrentFromJson(json);
}
