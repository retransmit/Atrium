import 'package:freezed_annotation/freezed_annotation.dart';

part 'transmission_detail.freezed.dart';
part 'transmission_detail.g.dart';

/// One file inside a torrent.
///
/// Transmission splits this across two parallel arrays: `files` carries the
/// name and sizes, `fileStats` carries whether the file is wanted and at what
/// priority. [wanted] and [priority] are stitched in by
/// [TransmissionDetail.fromJson] rather than parsed from the `files` entry.
@freezed
abstract class TransmissionFile with _$TransmissionFile {
  const TransmissionFile._();

  const factory TransmissionFile({
    @Default('') String name,
    @Default(0) int length,
    @JsonKey(name: 'bytesCompleted') @Default(0) int bytesCompleted,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(true)
    bool wanted,

    /// -1 low, 0 normal, 1 high.
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(0)
    int priority,
  }) = _TransmissionFile;

  factory TransmissionFile.fromJson(Map<String, dynamic> json) =>
      _$TransmissionFileFromJson(json);

  /// Last path segment, for a compact row.
  String get displayName => name.contains('/') ? name.split('/').last : name;

  double get progress =>
      length <= 0 ? 0 : (bytesCompleted / length).clamp(0, 1).toDouble();

  String get priorityLabel => switch (priority) {
        -1 => 'Low',
        1 => 'High',
        _ => 'Normal',
      };
}

/// One connected peer.
@freezed
abstract class TransmissionPeer with _$TransmissionPeer {
  const factory TransmissionPeer({
    @Default('') String address,
    @Default(0) int port,

    /// The web UI's flag letters, such as `DEI`; see the legend sheet.
    @JsonKey(name: 'flagStr') @Default('') String flagStr,
    @JsonKey(name: 'clientName') @Default('') String clientName,

    /// 0.0 - 1.0.
    @Default(0) double progress,
    @JsonKey(name: 'rateToClient') @Default(0) int rateToClient,
    @JsonKey(name: 'rateToPeer') @Default(0) int rateToPeer,
    @JsonKey(name: 'isEncrypted') @Default(false) bool isEncrypted,
  }) = _TransmissionPeer;

  factory TransmissionPeer.fromJson(Map<String, dynamic> json) =>
      _$TransmissionPeerFromJson(json);
}

/// One tracker, from `trackerStats` (which is the richer of Transmission's two
/// tracker fields - `trackers` carries only the URLs).
@freezed
abstract class TransmissionTracker with _$TransmissionTracker {
  const factory TransmissionTracker({
    @Default('') String host,
    @Default('') String announce,
    @Default(0) int tier,

    /// Empty below RPC 17.
    @Default('') String sitename,

    /// 0 inactive, 1 waiting, 2 queued, 3 active.
    @JsonKey(name: 'announceState') @Default(0) int announceState,
    @JsonKey(name: 'hasAnnounced') @Default(false) bool hasAnnounced,
    @JsonKey(name: 'lastAnnounceTime') @Default(0) int lastAnnounceTime,
    @JsonKey(name: 'lastAnnouncePeerCount')
    @Default(0)
    int lastAnnouncePeerCount,
    @JsonKey(name: 'nextAnnounceTime') @Default(0) int nextAnnounceTime,
    @JsonKey(name: 'hasScraped') @Default(false) bool hasScraped,
    @JsonKey(name: 'lastScrapeSucceeded')
    @Default(false)
    bool lastScrapeSucceeded,
    @JsonKey(name: 'lastScrapeResult') @Default('') String lastScrapeResult,
    @JsonKey(name: 'lastScrapeTime') @Default(0) int lastScrapeTime,
    @JsonKey(name: 'downloadCount') @Default(-1) int downloadCount,
    @JsonKey(name: 'isBackup') @Default(false) bool isBackup,
    @JsonKey(name: 'lastAnnounceResult') @Default('') String lastAnnounceResult,
    @JsonKey(name: 'lastAnnounceSucceeded')
    @Default(false)
    bool lastAnnounceSucceeded,
    @JsonKey(name: 'seederCount') @Default(-1) int seederCount,
    @JsonKey(name: 'leecherCount') @Default(-1) int leecherCount,
  }) = _TransmissionTracker;

  factory TransmissionTracker.fromJson(Map<String, dynamic> json) =>
      _$TransmissionTrackerFromJson(json);
}

/// The per-torrent detail behind the detail screen's tabs.
@freezed
abstract class TransmissionDetail with _$TransmissionDetail {
  const factory TransmissionDetail({
    @Default('') String comment,
    @Default('') String creator,
    @JsonKey(name: 'isPrivate') @Default(false) bool isPrivate,
    @JsonKey(name: 'pieceCount') @Default(0) int pieceCount,
    @JsonKey(name: 'pieceSize') @Default(0) int pieceSize,
    @JsonKey(name: 'dateCreated') @Default(0) int dateCreated,
    @JsonKey(name: 'haveValid') @Default(0) int haveValid,
    @JsonKey(name: 'haveUnchecked') @Default(0) int haveUnchecked,
    @JsonKey(name: 'desiredAvailable') @Default(0) int desiredAvailable,
    @JsonKey(name: 'downloadedEver') @Default(0) int downloadedEver,
    @JsonKey(name: 'corruptEver') @Default(0) int corruptEver,

    /// Unix seconds the torrent was last started, 0 when never.
    @JsonKey(name: 'startDate') @Default(0) int startDate,
    @JsonKey(name: 'magnetLink') @Default('') String magnetLink,
    @Default(<String>[]) List<String> webseeds,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(<TransmissionFile>[])
    List<TransmissionFile> files,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(<TransmissionPeer>[])
    List<TransmissionPeer> peers,
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(<TransmissionTracker>[])
    List<TransmissionTracker> trackers,
  }) = _TransmissionDetail;

  factory TransmissionDetail.fromJson(Map<String, dynamic> json) =>
      _$TransmissionDetailFromJson(json);

  /// Builds a detail object from one `torrent-get` entry, zipping `files` with
  /// `fileStats`.
  ///
  /// The two arrays are supposed to be the same length, but a torrent whose
  /// metadata has not arrived can report one and not the other, so every
  /// lookup is bounds-checked instead of indexed blindly.
  factory TransmissionDetail.fromTorrentJson(Map<String, dynamic> json) {
    final List<dynamic> rawFiles =
        (json['files'] as List<dynamic>?) ?? const <dynamic>[];
    final List<dynamic> rawStats =
        (json['fileStats'] as List<dynamic>?) ?? const <dynamic>[];

    final List<TransmissionFile> files = <TransmissionFile>[];
    for (int i = 0; i < rawFiles.length; i++) {
      final TransmissionFile base =
          TransmissionFile.fromJson(rawFiles[i] as Map<String, dynamic>);
      if (i < rawStats.length) {
        final Map<String, dynamic> stat = rawStats[i] as Map<String, dynamic>;
        files.add(
          base.copyWith(
            wanted: stat['wanted'] as bool? ?? base.wanted,
            priority: (stat['priority'] as num?)?.toInt() ?? base.priority,
          ),
        );
      } else {
        files.add(base);
      }
    }

    return TransmissionDetail.fromJson(json).copyWith(
      files: files,
      peers: ((json['peers'] as List<dynamic>?) ?? const <dynamic>[])
          .map(
            (dynamic e) =>
                TransmissionPeer.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      trackers: ((json['trackerStats'] as List<dynamic>?) ?? const <dynamic>[])
          .map(
            (dynamic e) =>
                TransmissionTracker.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  /// The fields the detail screen needs from `torrent-get`.
  static const List<String> fields = <String>[
    'comment',
    'creator',
    'isPrivate',
    'pieceCount',
    'pieceSize',
    'dateCreated',
    'haveValid',
    'haveUnchecked',
    'desiredAvailable',
    'downloadedEver',
    'corruptEver',
    'startDate',
    'magnetLink',
    'webseeds',
    'files',
    'fileStats',
    'peers',
    'trackerStats',
  ];
}
