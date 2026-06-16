import 'package:freezed_annotation/freezed_annotation.dart';

part 'prowlarr_history.freezed.dart';
part 'prowlarr_history.g.dart';

/// One entry from `GET /api/v1/history`.
///
/// [eventType] is one of `indexerQuery`, `indexerRss`, `releaseGrabbed`,
/// `indexerAuth`, ... and [data] is a loose bag whose keys vary by event
/// (query, source, host, elapsedTime, grabTitle, ...).
@freezed
abstract class ProwlarrHistoryRecord with _$ProwlarrHistoryRecord {
  const factory ProwlarrHistoryRecord({
    required int id,
    int? indexerId,
    @Default('') String eventType,
    DateTime? date,
    bool? successful,
    @Default(<String, dynamic>{}) Map<String, dynamic> data,
  }) = _ProwlarrHistoryRecord;

  factory ProwlarrHistoryRecord.fromJson(Map<String, dynamic> json) =>
      _$ProwlarrHistoryRecordFromJson(json);
}

/// `GET /api/v1/history` -> `{ page, pageSize, totalRecords, records: [...] }`.
@freezed
abstract class ProwlarrHistoryPage with _$ProwlarrHistoryPage {
  const factory ProwlarrHistoryPage({
    @Default(1) int page,
    @Default(50) int pageSize,
    @Default(0) int totalRecords,
    @Default(<ProwlarrHistoryRecord>[]) List<ProwlarrHistoryRecord> records,
  }) = _ProwlarrHistoryPage;

  factory ProwlarrHistoryPage.fromJson(Map<String, dynamic> json) =>
      _$ProwlarrHistoryPageFromJson(json);
}
