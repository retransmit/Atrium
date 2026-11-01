import 'package:freezed_annotation/freezed_annotation.dart';

import 'aria2_file.dart';
import 'aria2_json.dart';

part 'aria2_download.freezed.dart';
part 'aria2_download.g.dart';

/// One download as `aria2.tellStatus` reports it.
///
/// The same struct comes back from `tellActive`, `tellWaiting` and
/// `tellStopped`, so this is the one model the whole module reads.
@freezed
abstract class Aria2Download with _$Aria2Download {
  const Aria2Download._();

  const factory Aria2Download({
    @Default('') String gid,

    /// `active`, `waiting`, `paused`, `error`, `complete` or `removed`.
    @Default('') String status,

    @JsonKey(fromJson: aria2Int) @Default(0) int totalLength,
    @JsonKey(fromJson: aria2Int) @Default(0) int completedLength,
    @JsonKey(fromJson: aria2Int) @Default(0) int uploadLength,
    @JsonKey(fromJson: aria2Int) @Default(0) int downloadSpeed,
    @JsonKey(fromJson: aria2Int) @Default(0) int uploadSpeed,
    @JsonKey(fromJson: aria2Int) @Default(0) int connections,
    @JsonKey(fromJson: aria2Int) @Default(0) int numSeeders,
    @JsonKey(fromJson: aria2Bool) @Default(false) bool seeder,
    @JsonKey(fromJson: aria2Int) @Default(0) int numPieces,
    @JsonKey(fromJson: aria2Int) @Default(0) int pieceLength,
    @JsonKey(fromJson: aria2Int) @Default(0) int errorCode,
    @Default('') String errorMessage,
    @Default('') String dir,
    @Default('') String infoHash,

    /// The torrent's name, when this download is a torrent.
    @JsonKey(name: 'bittorrent', fromJson: aria2TorrentName)
    @Default('')
    String torrentName,

    @Default(<Aria2File>[]) List<Aria2File> files,
    @JsonKey(name: 'followedBy', fromJson: aria2StringList)
    @Default(<String>[])
    List<String> followedBy,
  }) = _Aria2Download;

  factory Aria2Download.fromJson(Map<String, dynamic> json) =>
      _$Aria2DownloadFromJson(json);

  /// Completion 0..1.
  ///
  /// A magnet that has not fetched its metadata yet reports a total length of
  /// zero, which is "unknown", not "done" - so the progress reads 0 rather
  /// than dividing by zero.
  double get progress {
    if (totalLength <= 0) {
      return 0;
    }
    return (completedLength / totalLength).clamp(0.0, 1.0);
  }

  /// The name to show.
  ///
  /// aria2 has no name of its own for a plain HTTP download: the file name
  /// comes from the path, and a torrent carries its own name in the info
  /// dictionary. The GID is the last resort, so a row is never blank.
  String get displayName {
    if (torrentName.isNotEmpty) {
      return torrentName;
    }
    for (final Aria2File file in files) {
      final String name = file.name;
      if (name.isNotEmpty) {
        return name;
      }
    }
    return gid;
  }

  /// The first file's path, which is the download's own name on disk.
  String get path => files.isEmpty ? '' : files.first.path;

  bool get isActive => status == 'active';
  bool get isPaused => status == 'paused';

  /// In the queue but not started - and not paused either.
  bool get isWaiting => status == 'waiting';

  /// A completed torrent that remains active in the daemon for seeding.
  bool get isSeeding =>
      seeder ||
      (status == 'active' && totalLength > 0 && completedLength >= totalLength);

  bool get isComplete => status == 'complete';
  bool get isError => status == 'error';
  bool get isRemoved => status == 'removed';

  /// Stopped, one way or another: finished, failed or removed.
  bool get isStopped => isComplete || isError || isRemoved;

  /// Whether this download is still doing something, or about to.
  bool get isLive => isActive || isWaiting || isPaused;

  /// Whether the pause button applies.
  bool get canPause => isActive || isWaiting;

  /// Whether the resume button applies.
  bool get canResume => isPaused;

  /// Bytes still to fetch.
  int get remainingLength =>
      totalLength <= completedLength ? 0 : totalLength - completedLength;

  /// Seconds left, estimated from the current rate.
  ///
  /// aria2 publishes no ETA field, so this is arithmetic on its own numbers
  /// and is null whenever the rate or the total is missing. A magnet that has
  /// no metadata yet has no total and therefore no estimate either.
  int? get etaSeconds {
    if (downloadSpeed <= 0 || totalLength <= 0) {
      return null;
    }
    final int remaining = totalLength - completedLength;
    if (remaining <= 0) {
      return 0;
    }
    return remaining ~/ downloadSpeed;
  }

  /// The selected files, which are the ones aria2 will actually fetch.
  List<Aria2File> get selectedFiles =>
      files.where((Aria2File f) => f.selected).toList(growable: false);
}
