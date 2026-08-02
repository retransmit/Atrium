import 'package:freezed_annotation/freezed_annotation.dart';

part 'rtorrent_detail.freezed.dart';

/// Session-wide counters and limits.
///
/// rTorrent has no single "session" call, so this is assembled from several
/// one-value commands via `system.multicall`. Limits are **bytes per second**
/// here, unlike Deluge (KiB/s) and Transmission (KB/s), and 0 means unlimited.
@freezed
abstract class RtorrentGlobal with _$RtorrentGlobal {
  const RtorrentGlobal._();

  const factory RtorrentGlobal({
    @Default('') String version,
    @Default(0) int downRate,
    @Default(0) int upRate,
    @Default(0) int downLimit,
    @Default(0) int upLimit,
    @Default(0) int listenPort,
  }) = _RtorrentGlobal;

  /// The commands fetched, in the order [fromRows] expects.
  static const List<String> commands = <String>[
    'system.client_version',
    'throttle.global_down.rate',
    'throttle.global_up.rate',
    'throttle.global_down.max_rate',
    'throttle.global_up.max_rate',
    'network.listen.port',
  ];

  factory RtorrentGlobal.fromRows(List<Object?> rows) {
    Object? at(int i) {
      if (i >= rows.length) return null;
      final Object? v = rows[i];
      // system.multicall wraps each result in a one-element array.
      return v is List<Object?> && v.isNotEmpty ? v.first : v;
    }

    int intAt(int i) {
      final Object? v = at(i);
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('$v') ?? 0;
    }

    return RtorrentGlobal(
      version: at(0)?.toString() ?? '',
      downRate: intAt(1),
      upRate: intAt(2),
      downLimit: intAt(3),
      upLimit: intAt(4),
      listenPort: intAt(5),
    );
  }

  bool get downLimited => downLimit > 0;
  bool get upLimited => upLimit > 0;
}

/// One file inside a torrent, from `f.multicall`.
@freezed
abstract class RtorrentFile with _$RtorrentFile {
  const RtorrentFile._();

  const factory RtorrentFile({
    @Default('') String path,
    @Default(0) int sizeBytes,
    @Default(0) int completedChunks,
    @Default(0) int sizeChunks,

    /// 0 off, 1 normal, 2 high.
    @Default(1) int priority,
  }) = _RtorrentFile;

  static const List<String> fields = <String>[
    'f.path=',
    'f.size_bytes=',
    'f.completed_chunks=',
    'f.size_chunks=',
    'f.priority=',
  ];

  factory RtorrentFile.fromRow(List<Object?> row) {
    int intAt(int i) {
      if (i >= row.length) return 0;
      final Object? v = row[i];
      return v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
    }

    return RtorrentFile(
      path: row.isNotEmpty ? (row[0]?.toString() ?? '') : '',
      sizeBytes: intAt(1),
      completedChunks: intAt(2),
      sizeChunks: intAt(3),
      priority: intAt(4),
    );
  }

  /// 0 - 1. rTorrent reports per-file progress in chunks, not bytes.
  double get progress => sizeChunks <= 0
      ? 0
      : (completedChunks / sizeChunks).clamp(0, 1).toDouble();

  String get displayName => path.contains('/') ? path.split('/').last : path;

  String get priorityLabel => switch (priority) {
        0 => 'Skip',
        2 => 'High',
        _ => 'Normal',
      };
}

/// One tracker, from `t.multicall`.
@freezed
abstract class RtorrentTracker with _$RtorrentTracker {
  const RtorrentTracker._();

  const factory RtorrentTracker({
    @Default('') String url,
    @Default(0) int group,
    @Default(false) bool isEnabled,
  }) = _RtorrentTracker;

  static const List<String> fields = <String>[
    't.url=',
    't.group=',
    't.is_enabled=',
  ];

  factory RtorrentTracker.fromRow(List<Object?> row) {
    int intAt(int i) {
      if (i >= row.length) return 0;
      final Object? v = row[i];
      return v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
    }

    return RtorrentTracker(
      url: row.isNotEmpty ? (row[0]?.toString() ?? '') : '',
      group: intAt(1),
      isEnabled: intAt(2) != 0,
    );
  }
}

/// One connected peer, from `p.multicall`.
@freezed
abstract class RtorrentPeer with _$RtorrentPeer {
  const RtorrentPeer._();

  const factory RtorrentPeer({
    @Default('') String address,
    @Default('') String client,
    @Default(0) int downRate,
    @Default(0) int upRate,
    @Default(0) int completedPercent,
    @Default(false) bool isEncrypted,
  }) = _RtorrentPeer;

  static const List<String> fields = <String>[
    'p.address=',
    'p.client_version=',
    'p.down_rate=',
    'p.up_rate=',
    'p.completed_percent=',
    'p.is_encrypted=',
  ];

  factory RtorrentPeer.fromRow(List<Object?> row) {
    int intAt(int i) {
      if (i >= row.length) return 0;
      final Object? v = row[i];
      return v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
    }

    return RtorrentPeer(
      address: row.isNotEmpty ? (row[0]?.toString() ?? '') : '',
      client: row.length > 1 ? (row[1]?.toString() ?? '') : '',
      downRate: intAt(2),
      upRate: intAt(3),
      completedPercent: intAt(4),
      isEncrypted: intAt(5) != 0,
    );
  }

  /// 0 - 1.
  double get progress => (completedPercent / 100).clamp(0, 1).toDouble();
}

/// Files, trackers and peers for one torrent.
@freezed
abstract class RtorrentDetail with _$RtorrentDetail {
  const factory RtorrentDetail({
    @Default(<RtorrentFile>[]) List<RtorrentFile> files,
    @Default(<RtorrentTracker>[]) List<RtorrentTracker> trackers,
    @Default(<RtorrentPeer>[]) List<RtorrentPeer> peers,
  }) = _RtorrentDetail;
}
