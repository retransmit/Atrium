import 'package:freezed_annotation/freezed_annotation.dart';

part 'rtorrent_torrent.freezed.dart';

/// What a torrent is doing, derived from rTorrent's several separate flags.
///
/// rTorrent has no single status field. It exposes `d.state`, `d.is_active`,
/// `d.is_open`, `d.complete`, `d.hashing` and `d.message` independently, and
/// the UI is expected to combine them - which is what ruTorrent does too.
enum RtorrentStatus {
  error('Error'),
  checking('Checking'),
  stopped('Stopped'),
  paused('Paused'),
  seeding('Seeding'),
  downloading('Downloading'),
  queued('Queued');

  const RtorrentStatus(this.label);

  final String label;

  bool get isStopped => this == stopped;
  bool get isSeeding => this == seeding;
  bool get isDownloading => this == downloading;
}

/// One torrent, built from a `d.multicall2` row.
///
/// rTorrent returns multicall results as **positional arrays** in the order the
/// commands were requested, not as maps, so this is constructed from a row plus
/// [fields] rather than from JSON. Keep the two in step.
@freezed
abstract class RtorrentTorrent with _$RtorrentTorrent {
  const RtorrentTorrent._();

  const factory RtorrentTorrent({
    required String hash,
    @Default('') String name,
    @Default(0) int sizeBytes,
    @Default(0) int completedBytes,
    @Default(0) int leftBytes,
    @Default(0) int downRate,
    @Default(0) int upRate,
    @Default(0) int uploadedTotal,

    /// rTorrent reports the ratio in **per-mille**: 1000 means 1.0.
    @Default(0) int ratioPerMille,
    @Default(false) bool isActive,
    @Default(false) bool isOpen,
    @Default(false) bool isComplete,

    /// 0 when not hashing; otherwise which hashing pass is running.
    @Default(0) int hashing,
    @Default('') String message,
    @Default(0) int peersConnected,
    @Default(0) int peersComplete,
    @Default('') String directory,

    /// ruTorrent stores its label here, so it is empty on a plain rTorrent.
    @Default('') String label,

    /// 0 off, 1 low, 2 normal, 3 high.
    @Default(2) int priority,

    /// 0 stopped, 1 started.
    @Default(0) int state,
  }) = _RtorrentTorrent;

  /// The `d.*` commands requested, in the order [fromRow] expects them.
  static const List<String> fields = <String>[
    'd.hash=',
    'd.name=',
    'd.size_bytes=',
    'd.completed_bytes=',
    'd.left_bytes=',
    'd.down.rate=',
    'd.up.rate=',
    'd.up.total=',
    'd.ratio=',
    'd.is_active=',
    'd.is_open=',
    'd.complete=',
    'd.hashing=',
    'd.message=',
    'd.peers_connected=',
    'd.peers_complete=',
    'd.directory=',
    'd.custom1=',
    'd.priority=',
    'd.state=',
  ];

  /// Builds a torrent from one multicall row.
  ///
  /// Short rows are tolerated: an rTorrent build missing a command returns
  /// fewer values rather than failing the whole call, and losing one field
  /// should not blank the entire list.
  factory RtorrentTorrent.fromRow(List<Object?> row) {
    String str(int i) => i < row.length ? (row[i]?.toString() ?? '') : '';
    int intAt(int i) {
      if (i >= row.length) return 0;
      final Object? v = row[i];
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse('$v') ?? 0;
    }

    bool flag(int i) => intAt(i) != 0;

    return RtorrentTorrent(
      hash: str(0),
      name: str(1),
      sizeBytes: intAt(2),
      completedBytes: intAt(3),
      leftBytes: intAt(4),
      downRate: intAt(5),
      upRate: intAt(6),
      uploadedTotal: intAt(7),
      ratioPerMille: intAt(8),
      isActive: flag(9),
      isOpen: flag(10),
      isComplete: flag(11),
      hashing: intAt(12),
      message: str(13),
      peersConnected: intAt(14),
      peersComplete: intAt(15),
      directory: str(16),
      label: str(17),
      priority: intAt(18),
      state: intAt(19),
    );
  }

  /// 0 - 1.
  double get progress =>
      sizeBytes <= 0 ? 0 : (completedBytes / sizeBytes).clamp(0, 1).toDouble();

  double get ratio => ratioPerMille / 1000;

  bool get hasError => message.isNotEmpty;

  /// Folds rTorrent's separate flags into one status, in priority order: an
  /// error outranks everything, then a hash check, then whether the torrent is
  /// even running.
  RtorrentStatus get status {
    if (hasError) return RtorrentStatus.error;
    if (hashing > 0) return RtorrentStatus.checking;
    if (state == 0) return RtorrentStatus.stopped;
    if (!isOpen) return RtorrentStatus.paused;
    if (isComplete) {
      return isActive ? RtorrentStatus.seeding : RtorrentStatus.queued;
    }
    return isActive ? RtorrentStatus.downloading : RtorrentStatus.queued;
  }

  String get priorityLabel => switch (priority) {
        0 => 'Off',
        1 => 'Low',
        3 => 'High',
        _ => 'Normal',
      };
}
