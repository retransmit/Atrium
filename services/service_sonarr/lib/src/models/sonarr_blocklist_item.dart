import 'package:freezed_annotation/freezed_annotation.dart';

import 'sonarr_series.dart';

part 'sonarr_blocklist_item.freezed.dart';
part 'sonarr_blocklist_item.g.dart';

@freezed
abstract class SonarrBlocklistItem with _$SonarrBlocklistItem {
  const factory SonarrBlocklistItem({
    required int id,
    required int seriesId,
    List<int>? episodeIds,
    String? sourceTitle,
    List<Map<String, dynamic>>? languages,
    Map<String, dynamic>? quality,
    List<Map<String, dynamic>>? customFormats,
    String? date,
    String? protocol,
    String? indexer,
    String? message,
    SonarrSeries? series,
  }) = _SonarrBlocklistItem;

  factory SonarrBlocklistItem.fromJson(Map<String, dynamic> json) =>
      _$SonarrBlocklistItemFromJson(json);
}
