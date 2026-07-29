import 'package:freezed_annotation/freezed_annotation.dart';

part 'nzbget_status.freezed.dart';
part 'nzbget_status.g.dart';

/// JSON-RPC `status` result. NZBGet PascalCases every field; rates are
/// bytes per second, sizes are whole megabytes.
@freezed
abstract class NzbgetStatus with _$NzbgetStatus {
  const factory NzbgetStatus({
    @JsonKey(name: 'DownloadRate') @Default(0) int downloadRate,
    @JsonKey(name: 'DownloadLimit') @Default(0) int downloadLimit,
    @JsonKey(name: 'DownloadPaused') @Default(false) bool downloadPaused,
    @JsonKey(name: 'RemainingSizeMB') @Default(0) int remainingSizeMb,
    @JsonKey(name: 'FreeDiskSpaceMB') @Default(0) int freeDiskSpaceMb,
    @JsonKey(name: 'UpTimeSec') @Default(0) int upTimeSec,
  }) = _NzbgetStatus;

  factory NzbgetStatus.fromJson(Map<String, dynamic> json) =>
      _$NzbgetStatusFromJson(json);
}
