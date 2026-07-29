import 'package:freezed_annotation/freezed_annotation.dart';

part 'nzbget_history_entry.freezed.dart';
part 'nzbget_history_entry.g.dart';

/// One entry from JSON-RPC `history`. Status is "SUCCESS/...", "WARNING/..."
/// or "FAILURE/..." plus a detail suffix.
@freezed
abstract class NzbgetHistoryEntry with _$NzbgetHistoryEntry {
  const NzbgetHistoryEntry._();

  const factory NzbgetHistoryEntry({
    @JsonKey(name: 'NZBID') @Default(0) int nzbId,
    @JsonKey(name: 'Name') @Default('') String name,
    @JsonKey(name: 'Status') @Default('') String status,
    @JsonKey(name: 'HistoryTime') @Default(0) int historyTime,
    @JsonKey(name: 'FileSizeMB') @Default(0) int fileSizeMb,
    @JsonKey(name: 'Category') @Default('') String category,
  }) = _NzbgetHistoryEntry;

  factory NzbgetHistoryEntry.fromJson(Map<String, dynamic> json) =>
      _$NzbgetHistoryEntryFromJson(json);

  bool get isSuccess => status.startsWith('SUCCESS');
  bool get isFailure => status.startsWith('FAILURE');
  bool get isWarning => status.startsWith('WARNING');
}
