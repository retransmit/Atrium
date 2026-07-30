import 'package:freezed_annotation/freezed_annotation.dart';

part 'deluge_torrent_detail.freezed.dart';
part 'deluge_torrent_detail.g.dart';

/// One file inside a torrent.
///
/// Deluge splits this across three parallel arrays - `files` (index, path,
/// size, offset), `file_progress`, and `file_priorities` - so [progress] and
/// [priority] are stitched in by [DelugeTorrentDetail.fromStatus] rather than
/// parsed from the `files` entry itself.
@freezed
abstract class DelugeFile with _$DelugeFile {
  const DelugeFile._();

  const factory DelugeFile({
    required int index,
    @Default('') String path,
    @Default(0) int size,
    @Default(0) int offset,

    /// 0 - 1.
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(0)
    double progress,

    /// libtorrent file priority: 0 skips the file, 1 is normal, 7 is highest.
    /// Deluge's own UI writes 4 for "normal" on a fresh add.
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(4)
    int priority,
  }) = _DelugeFile;

  factory DelugeFile.fromJson(Map<String, dynamic> json) =>
      _$DelugeFileFromJson(json);

  /// Last path segment, for a compact list row.
  String get displayName =>
      path.contains('/') ? path.split('/').last : path;
}

/// One tracker of a torrent. `last_error` is deliberately not modeled - it is
/// a nested libtorrent error object that Atrium never renders.
@freezed
abstract class DelugeTracker with _$DelugeTracker {
  const factory DelugeTracker({
    @Default('') String url,
    @Default(0) int tier,
    @Default('') String message,
    @Default(false) bool verified,
  }) = _DelugeTracker;

  factory DelugeTracker.fromJson(Map<String, dynamic> json) =>
      _$DelugeTrackerFromJson(json);
}

/// One connected peer.
@freezed
abstract class DelugePeer with _$DelugePeer {
  const factory DelugePeer({
    @Default('') String ip,
    @Default('') String client,
    @Default('') String country,
    @JsonKey(name: 'down_speed') @Default(0) int downSpeed,
    @JsonKey(name: 'up_speed') @Default(0) int upSpeed,

    /// 0 - 1.
    @Default(0) double progress,
    @Default(false) bool seed,
  }) = _DelugePeer;

  factory DelugePeer.fromJson(Map<String, dynamic> json) =>
      _$DelugePeerFromJson(json);
}

/// The extra per-torrent detail behind the detail screen's tabs.
@freezed
abstract class DelugeTorrentDetail with _$DelugeTorrentDetail {
  const factory DelugeTorrentDetail({
    @Default('') String comment,
    @Default(false) bool private,
    @JsonKey(name: 'num_files') @Default(0) int numFiles,
    @JsonKey(name: 'total_size') @Default(0) int totalSize,

    /// Per-torrent caps in KiB/s; -1 means "use the global limit".
    @JsonKey(name: 'max_download_speed') @Default(-1) double maxDownloadKib,
    @JsonKey(name: 'max_upload_speed') @Default(-1) double maxUploadKib,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(<DelugeFile>[])
    List<DelugeFile> files,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(<DelugeTracker>[])
    List<DelugeTracker> trackers,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(<DelugePeer>[])
    List<DelugePeer> peers,
  }) = _DelugeTorrentDetail;

  factory DelugeTorrentDetail.fromJson(Map<String, dynamic> json) =>
      _$DelugeTorrentDetailFromJson(json);

  /// Builds a detail object from one `core.get_torrent_status` map, zipping the
  /// parallel file arrays together.
  ///
  /// A daemon may return fewer progress/priority entries than files (or none at
  /// all, for a torrent whose metadata has not arrived yet), so each lookup is
  /// bounds-checked instead of indexed blindly.
  factory DelugeTorrentDetail.fromStatus(Map<String, dynamic> status) {
    final List<dynamic> rawFiles =
        (status['files'] as List<dynamic>?) ?? const <dynamic>[];
    final List<dynamic> rawProgress =
        (status['file_progress'] as List<dynamic>?) ?? const <dynamic>[];
    final List<dynamic> rawPriorities =
        (status['file_priorities'] as List<dynamic>?) ?? const <dynamic>[];

    final List<DelugeFile> files = <DelugeFile>[];
    for (int i = 0; i < rawFiles.length; i++) {
      final DelugeFile base =
          DelugeFile.fromJson(rawFiles[i] as Map<String, dynamic>);
      files.add(
        base.copyWith(
          progress: i < rawProgress.length
              ? (rawProgress[i] as num).toDouble()
              : base.progress,
          priority: i < rawPriorities.length
              ? (rawPriorities[i] as num).toInt()
              : base.priority,
        ),
      );
    }

    return DelugeTorrentDetail.fromJson(status).copyWith(
      files: files,
      trackers: ((status['trackers'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic e) => DelugeTracker.fromJson(e as Map<String, dynamic>))
          .toList(),
      peers: ((status['peers'] as List<dynamic>?) ?? const <dynamic>[])
          .map((dynamic e) => DelugePeer.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// The keys the detail screen needs from `core.get_torrent_status`.
  static const List<String> keys = <String>[
    'comment',
    'private',
    'num_files',
    'total_size',
    'max_download_speed',
    'max_upload_speed',
    'files',
    'file_progress',
    'file_priorities',
    'trackers',
    'peers',
  ];
}
