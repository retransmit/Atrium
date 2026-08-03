import 'package:freezed_annotation/freezed_annotation.dart';

part 'deluge_torrent.freezed.dart';
part 'deluge_torrent.g.dart';

/// One torrent from `core.get_torrents_status`.
///
/// Deluge returns a map of `{infohash: {..status..}}` rather than a list, so
/// the hash is not part of the value object - [DelugeTorrent.fromStatus] folds
/// it in as `id`.
///
/// Every field except [id] carries a default: Deluge silently omits any key it
/// does not recognise (a `label` request against a daemon without the Label
/// plugin comes back with no `label` at all) so the model has to tolerate a
/// partial map rather than assume the keys it asked for.
@freezed
abstract class DelugeTorrent with _$DelugeTorrent {
  const DelugeTorrent._();

  const factory DelugeTorrent({
    required String id,
    @Default('') String name,

    /// Deluge state string: Downloading, Seeding, Paused, Queued, Checking,
    /// Allocating, Moving, Error.
    @Default('') String state,

    /// Percent complete, **0 - 100** (not a 0 - 1 fraction like qBittorrent).
    @Default(0) double progress,
    @JsonKey(name: 'download_payload_rate') @Default(0) int downloadRate,
    @JsonKey(name: 'upload_payload_rate') @Default(0) int uploadRate,

    /// Seconds remaining. Deluge reports `0` when there is nothing to wait
    /// for (seeding, paused), not a sentinel like qBittorrent's 8640000.
    @Default(0) int eta,

    /// Bytes of the selected files, and how many of them are done.
    @JsonKey(name: 'total_wanted') @Default(0) int totalWanted,
    @JsonKey(name: 'total_done') @Default(0) int totalDone,
    @JsonKey(name: 'total_uploaded') @Default(0) int totalUploaded,
    @Default(0) double ratio,

    /// Connected vs total peers/seeds the tracker knows about.
    @JsonKey(name: 'num_peers') @Default(0) int numPeers,
    @JsonKey(name: 'num_seeds') @Default(0) int numSeeds,
    @JsonKey(name: 'total_peers') @Default(0) int totalPeers,
    @JsonKey(name: 'total_seeds') @Default(0) int totalSeeds,

    /// Empty unless the daemon has the Label plugin enabled.
    @Default('') String label,
    @JsonKey(name: 'save_path') @Default('') String savePath,
    @JsonKey(name: 'tracker_host') @Default('') String trackerHost,

    /// Unix seconds.
    @JsonKey(name: 'time_added') @Default(0) int timeAdded,

    /// Position in the queue, or -1 when the torrent is not queued.
    @Default(-1) int queue,
    @JsonKey(name: 'is_finished') @Default(false) bool isFinished,
  }) = _DelugeTorrent;

  factory DelugeTorrent.fromJson(Map<String, dynamic> json) =>
      _$DelugeTorrentFromJson(json);

  /// Builds a torrent from one `{infohash: {...}}` entry.
  factory DelugeTorrent.fromStatus(String id, Map<String, dynamic> status) =>
      DelugeTorrent.fromJson(<String, dynamic>{...status, 'id': id});

  bool get isPaused => state == 'Paused';
  bool get isSeeding => state == 'Seeding';
  bool get isDownloading => state == 'Downloading';
  bool get isError => state == 'Error';

  /// 0 - 1, for progress indicators that expect a fraction rather than
  /// Deluge's 0 - 100 percent.
  double get progressFraction => (progress / 100).clamp(0, 1).toDouble();
}
