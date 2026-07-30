import 'package:freezed_annotation/freezed_annotation.dart';

part 'deluge_session_status.freezed.dart';
part 'deluge_session_status.g.dart';

/// Session-wide counters from `core.get_session_status`.
///
/// Deluge hands the rates back as floats (`"download_rate": 0.0`), so they are
/// modeled as [double] even though the UI renders whole bytes per second.
@freezed
abstract class DelugeSessionStatus with _$DelugeSessionStatus {
  const factory DelugeSessionStatus({
    @JsonKey(name: 'download_rate') @Default(0) double downloadRate,
    @JsonKey(name: 'upload_rate') @Default(0) double uploadRate,
    @JsonKey(name: 'payload_download_rate') @Default(0) double payloadDownRate,
    @JsonKey(name: 'payload_upload_rate') @Default(0) double payloadUpRate,
    @JsonKey(name: 'num_peers') @Default(0) int numPeers,
    @JsonKey(name: 'dht_nodes') @Default(0) int dhtNodes,
  }) = _DelugeSessionStatus;

  factory DelugeSessionStatus.fromJson(Map<String, dynamic> json) =>
      _$DelugeSessionStatusFromJson(json);

  /// The keys to ask `core.get_session_status` for.
  static const List<String> keys = <String>[
    'download_rate',
    'upload_rate',
    'payload_download_rate',
    'payload_upload_rate',
    'num_peers',
    'dht_nodes',
  ];
}

/// Global bandwidth caps from `core.get_config`, in KiB/s.
///
/// Deluge stores `-1` for "unlimited" and expresses these in **KiB/s**, unlike
/// the byte-per-second rates everywhere else in its API.
@freezed
abstract class DelugeSpeedLimits with _$DelugeSpeedLimits {
  const factory DelugeSpeedLimits({
    @JsonKey(name: 'max_download_speed') @Default(-1) double maxDownloadKib,
    @JsonKey(name: 'max_upload_speed') @Default(-1) double maxUploadKib,
  }) = _DelugeSpeedLimits;

  factory DelugeSpeedLimits.fromJson(Map<String, dynamic> json) =>
      _$DelugeSpeedLimitsFromJson(json);

  static const List<String> keys = <String>[
    'max_download_speed',
    'max_upload_speed',
  ];
}
