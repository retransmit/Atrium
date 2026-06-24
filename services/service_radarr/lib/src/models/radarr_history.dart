import 'package:freezed_annotation/freezed_annotation.dart';

part 'radarr_history.freezed.dart';
part 'radarr_history.g.dart';

/// One Radarr history event (grab, import, upgrade, deletion, etc.) from
/// `GET /api/v3/history`.
@freezed
abstract class RadarrHistoryRecord with _$RadarrHistoryRecord {
  const factory RadarrHistoryRecord({
    required int id,
    @Default(0) int movieId,
    @Default('') String sourceTitle,
    @Default('') String eventType,
    DateTime? date,
    @Default(<String, dynamic>{}) Map<String, dynamic> data,
    Map<String, dynamic>? quality,
  }) = _RadarrHistoryRecord;

  factory RadarrHistoryRecord.fromJson(Map<String, dynamic> json) =>
      _$RadarrHistoryRecordFromJson(json);
}

@freezed
abstract class RadarrHistoryPage with _$RadarrHistoryPage {
  const factory RadarrHistoryPage({
    @Default(1) int page,
    @Default(0) int pageSize,
    @Default(0) int totalRecords,
    @Default(<RadarrHistoryRecord>[]) List<RadarrHistoryRecord> records,
  }) = _RadarrHistoryPage;

  factory RadarrHistoryPage.fromJson(Map<String, dynamic> json) =>
      _$RadarrHistoryPageFromJson(json);
}
