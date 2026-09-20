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
    @JsonKey(name: 'start-added-torrents')
    @Default(true)
    bool startAddedTorrents,
    @JsonKey(name: 'seedRatioLimited') @Default(false) bool seedRatioLimited,
    @JsonKey(name: 'seedRatioLimit') @Default(2.0) double seedRatioLimit,
    @JsonKey(name: 'idle-seeding-limit-enabled')
    @Default(false)
    bool idleSeedingLimitEnabled,
    @JsonKey(name: 'idle-seeding-limit') @Default(30) int idleSeedingLimit,
    @JsonKey(name: 'incomplete-dir-enabled')
    @Default(false)
    bool incompleteDirEnabled,
    @JsonKey(name: 'incomplete-dir') @Default('') String incompleteDir,
    @JsonKey(name: 'rename-partial-files')
    @Default(true)
    bool renamePartialFiles,
    @JsonKey(name: 'download-queue-enabled')
    @Default(true)
    bool downloadQueueEnabled,
    @JsonKey(name: 'download-queue-size') @Default(5) int downloadQueueSize,
    @JsonKey(name: 'default-trackers') @Default('') String defaultTrackers,
    @JsonKey(name: 'alt-speed-time-enabled')
    @Default(false)
    bool altSpeedTimeEnabled,

    /// Minutes after midnight.
    @JsonKey(name: 'alt-speed-time-begin') @Default(540) int altSpeedTimeBegin,
    @JsonKey(name: 'alt-speed-time-end') @Default(1020) int altSpeedTimeEnd,

    /// A bitmask: Sunday 1, Monday 2 ... Saturday 64. 127 is every day.
    @JsonKey(name: 'alt-speed-time-day') @Default(127) int altSpeedTimeDay,
    @JsonKey(name: 'peer-limit-per-torrent')
    @Default(50)
    int peerLimitPerTorrent,
    @JsonKey(name: 'peer-limit-global') @Default(200) int peerLimitGlobal,

    /// `allowed` (read back as `tolerated`), `preferred` or `required`.
    @Default('preferred') String encryption,
    @JsonKey(name: 'pex-enabled') @Default(true) bool pexEnabled,
    @JsonKey(name: 'dht-enabled') @Default(true) bool dhtEnabled,
    @JsonKey(name: 'lpd-enabled') @Default(false) bool lpdEnabled,
    @JsonKey(name: 'blocklist-enabled') @Default(false) bool blocklistEnabled,
    @JsonKey(name: 'blocklist-url') @Default('') String blocklistUrl,
    @JsonKey(name: 'blocklist-size') @Default(0) int blocklistSize,
    @JsonKey(name: 'peer-port') @Default(51413) int peerPort,
    @JsonKey(name: 'peer-port-random-on-start')
    @Default(false)
    bool peerPortRandomOnStart,
    @JsonKey(name: 'port-forwarding-enabled')
    @Default(true)
    bool portForwardingEnabled,
    @JsonKey(name: 'utp-enabled') @Default(true) bool utpEnabled,
  }) = _TransmissionSession;

  factory TransmissionSession.fromJson(Map<String, dynamic> json) =>
      _$TransmissionSessionFromJson(json);

  bool get knowsFreeSpace => downloadDirFreeSpace >= 0;

  /// Labels arrived with Transmission 3.00.
  bool get supportsLabels => rpcVersion >= 16;

  /// Default public trackers and tracker site names arrived with 4.0.
  bool get supportsDefaultTrackers => rpcVersion >= 17;

  /// `port-test` takes `ipProtocol` from 4.1.
  bool get supportsPortTestPerProtocol => rpcVersion >= 18;

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
    'start-added-torrents',
    'seedRatioLimited',
    'seedRatioLimit',
    'idle-seeding-limit-enabled',
    'idle-seeding-limit',
    'incomplete-dir-enabled',
    'incomplete-dir',
    'rename-partial-files',
    'download-queue-enabled',
    'download-queue-size',
    'default-trackers',
    'alt-speed-time-enabled',
    'alt-speed-time-begin',
    'alt-speed-time-end',
    'alt-speed-time-day',
    'peer-limit-per-torrent',
    'peer-limit-global',
    'encryption',
    'pex-enabled',
    'dht-enabled',
    'lpd-enabled',
    'blocklist-enabled',
    'blocklist-url',
    'blocklist-size',
    'peer-port',
    'peer-port-random-on-start',
    'port-forwarding-enabled',
    'utp-enabled',
  ];
}

/// One of the two counters `session-stats` keeps: this session, and all time.
@freezed
abstract class TransmissionStatsBlock with _$TransmissionStatsBlock {
  const factory TransmissionStatsBlock({
    @JsonKey(name: 'uploadedBytes') @Default(0) int uploadedBytes,
    @JsonKey(name: 'downloadedBytes') @Default(0) int downloadedBytes,
    @JsonKey(name: 'filesAdded') @Default(0) int filesAdded,
    @JsonKey(name: 'secondsActive') @Default(0) int secondsActive,
    @JsonKey(name: 'sessionCount') @Default(0) int sessionCount,
  }) = _TransmissionStatsBlock;

  factory TransmissionStatsBlock.fromJson(Map<String, dynamic> json) =>
      _$TransmissionStatsBlockFromJson(json);
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
    @JsonKey(name: 'current-stats')
    @Default(TransmissionStatsBlock())
    TransmissionStatsBlock currentStats,
    @JsonKey(name: 'cumulative-stats')
    @Default(TransmissionStatsBlock())
    TransmissionStatsBlock cumulativeStats,
  }) = _TransmissionSessionStats;

  factory TransmissionSessionStats.fromJson(Map<String, dynamic> json) =>
      _$TransmissionSessionStatsFromJson(json);
}
