import 'package:freezed_annotation/freezed_annotation.dart';

part 'transmission_torrent.freezed.dart';
part 'transmission_torrent.g.dart';

/// Transmission's `status` field, which arrives as a bare integer.
enum TransmissionStatus {
  stopped(0, 'Stopped'),
  checkWait(1, 'Queued to verify'),
  checking(2, 'Verifying'),
  downloadWait(3, 'Queued to download'),
  downloading(4, 'Downloading'),
  seedWait(5, 'Queued to seed'),
  seeding(6, 'Seeding'),
  unknown(-1, 'Unknown');

  const TransmissionStatus(this.code, this.label);

  final int code;
  final String label;

  /// Maps a raw status int, falling back to [unknown] rather than throwing so a
  /// future Transmission release cannot break the list.
  static TransmissionStatus fromCode(int code) {
    for (final TransmissionStatus s in values) {
      if (s.code == code) return s;
    }
    return unknown;
  }

  bool get isStopped => this == stopped;
  bool get isSeeding => this == seeding;
  bool get isDownloading => this == downloading;
  bool get isQueued =>
      this == checkWait || this == downloadWait || this == seedWait;
}

/// One torrent from `torrent-get`.
///
/// Two identifiers matter and they are not interchangeable: [id] is a small
/// integer that Transmission reuses and **reassigns across daemon restarts**,
/// while [hashString] is the infohash and is stable forever. RPC calls accept
/// either, so [id] is used for commands within a session and [hashString] is
/// used anywhere a torrent has to be recognised later (screen arguments,
/// provider keys).
@freezed
abstract class TransmissionTorrent with _$TransmissionTorrent {
  const TransmissionTorrent._();

  const factory TransmissionTorrent({
    required int id,
    @Default('') String hashString,
    @Default('') String name,

    /// Raw status code; read [status] instead.
    @JsonKey(name: 'status') @Default(-1) int statusCode,

    /// **0.0 - 1.0**, unlike Deluge's 0 - 100 percent.
    @JsonKey(name: 'percentDone') @Default(0) double percentDone,
    @JsonKey(name: 'rateDownload') @Default(0) int downloadRate,
    @JsonKey(name: 'rateUpload') @Default(0) int uploadRate,

    /// Seconds remaining, or a negative sentinel: -1 means "not available"
    /// and -2 means "unknown". Never treat this as a duration without
    /// checking [hasEta] first.
    @Default(-1) int eta,

    /// Total size of the torrent, and of just the wanted files.
    @Default(0) int totalSize,
    @JsonKey(name: 'sizeWhenDone') @Default(0) int sizeWhenDone,
    @JsonKey(name: 'leftUntilDone') @Default(0) int leftUntilDone,
    @JsonKey(name: 'uploadedEver') @Default(0) int uploadedEver,

    /// Share ratio, or -1 when nothing has been uploaded yet.
    @JsonKey(name: 'uploadRatio') @Default(0) double uploadRatio,
    @JsonKey(name: 'peersConnected') @Default(0) int peersConnected,
    @JsonKey(name: 'peersSendingToUs') @Default(0) int peersSendingToUs,
    @JsonKey(name: 'peersGettingFromUs') @Default(0) int peersGettingFromUs,
    @JsonKey(name: 'downloadDir') @Default('') String downloadDir,

    /// Unix seconds.
    @JsonKey(name: 'addedDate') @Default(0) int addedDate,
    @Default(<String>[]) List<String> labels,
    @JsonKey(name: 'queuePosition') @Default(-1) int queuePosition,
    @JsonKey(name: 'isFinished') @Default(false) bool isFinished,

    /// True when the torrent is running but has seen no traffic for a while.
    @JsonKey(name: 'isStalled') @Default(false) bool isStalled,

    /// 0 when healthy; anything else means [errorString] is worth showing.
    @Default(0) int error,
    @JsonKey(name: 'errorString') @Default('') String errorString,

    /// 0.0 - 1.0 while [TransmissionStatus.checking].
    @JsonKey(name: 'recheckProgress') @Default(0) double recheckProgress,
  }) = _TransmissionTorrent;

  factory TransmissionTorrent.fromJson(Map<String, dynamic> json) =>
      _$TransmissionTorrentFromJson(json);

  TransmissionStatus get status => TransmissionStatus.fromCode(statusCode);

  bool get hasError => error != 0 && errorString.isNotEmpty;

  /// Whether [eta] is a real duration rather than one of Transmission's
  /// negative sentinels.
  bool get hasEta => eta > 0;

  /// Bytes actually on disk for the wanted files.
  int get doneBytes =>
      (sizeWhenDone - leftUntilDone).clamp(0, sizeWhenDone);

  /// Ratio for display, treating Transmission's -1 as zero.
  double get ratio => uploadRatio < 0 ? 0 : uploadRatio;

  /// A short line describing what the torrent is doing, folding in the
  /// stalled and error cases that the bare status code cannot express.
  String get statusLabel {
    if (hasError) return 'Error';
    if (status == TransmissionStatus.checking) {
      return 'Verifying ${(recheckProgress * 100).toStringAsFixed(0)}%';
    }
    if (isStalled && !status.isStopped) return '${status.label} (idle)';
    return status.label;
  }
}
