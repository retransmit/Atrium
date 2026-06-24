import 'package:freezed_annotation/freezed_annotation.dart';

part 'radarr_blocklist.freezed.dart';
part 'radarr_blocklist.g.dart';

/// A blocklisted release from `GET /api/v3/blocklist`.
@freezed
abstract class RadarrBlocklistRecord with _$RadarrBlocklistRecord {
  const factory RadarrBlocklistRecord({
    required int id,
    @Default(0) int movieId,
    String? sourceTitle,
    String? indexer,
    String? message,
    DateTime? date,
    String? protocol,
  }) = _RadarrBlocklistRecord;

  factory RadarrBlocklistRecord.fromJson(Map<String, dynamic> json) =>
      _$RadarrBlocklistRecordFromJson(json);
}

@freezed
abstract class RadarrBlocklistPage with _$RadarrBlocklistPage {
  const factory RadarrBlocklistPage({
    @Default(1) int page,
    @Default(0) int pageSize,
    @Default(0) int totalRecords,
    @Default(<RadarrBlocklistRecord>[]) List<RadarrBlocklistRecord> records,
  }) = _RadarrBlocklistPage;

  factory RadarrBlocklistPage.fromJson(Map<String, dynamic> json) =>
      _$RadarrBlocklistPageFromJson(json);
}
