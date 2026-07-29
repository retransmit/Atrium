import 'package:freezed_annotation/freezed_annotation.dart';

part 'nzbget_group.freezed.dart';
part 'nzbget_group.g.dart';

/// One queue entry from JSON-RPC `listgroups`.
@freezed
abstract class NzbgetGroup with _$NzbgetGroup {
  const NzbgetGroup._();

  const factory NzbgetGroup({
    @JsonKey(name: 'NZBID') @Default(0) int nzbId,
    @JsonKey(name: 'NZBName') @Default('') String name,
    @JsonKey(name: 'Status') @Default('') String status,
    @JsonKey(name: 'FileSizeMB') @Default(0) int fileSizeMb,
    @JsonKey(name: 'RemainingSizeMB') @Default(0) int remainingSizeMb,
    @JsonKey(name: 'DownloadedSizeMB') @Default(0) int downloadedSizeMb,
    @JsonKey(name: 'Category') @Default('') String category,
    @JsonKey(name: 'MaxPriority') @Default(0) int priority,
    @JsonKey(name: 'Health') @Default(1000) int health,
  }) = _NzbgetGroup;

  factory NzbgetGroup.fromJson(Map<String, dynamic> json) =>
      _$NzbgetGroupFromJson(json);

  /// Completion 0..1 from the MB counters (0 when the size is unknown).
  double get progress =>
      fileSizeMb <= 0 ? 0 : (downloadedSizeMb / fileSizeMb).clamp(0.0, 1.0);

  bool get isPaused => status == 'PAUSED';
}
