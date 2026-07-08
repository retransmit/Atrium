import 'package:freezed_annotation/freezed_annotation.dart';

import 'sonarr_episode.dart';
import 'sonarr_series.dart';

part 'sonarr_history_item.freezed.dart';
part 'sonarr_history_item.g.dart';

@freezed
abstract class SonarrHistoryItem with _$SonarrHistoryItem {
  const factory SonarrHistoryItem({
    required int id,
    int? episodeId,
    int? seriesId,
    String? sourceTitle,
    String? date,
    String? downloadId,
    String? eventType,
    Map<String, String?>? data,
    SonarrEpisode? episode,
    SonarrSeries? series,
  }) = _SonarrHistoryItem;

  factory SonarrHistoryItem.fromJson(Map<String, dynamic> json) =>
      _$SonarrHistoryItemFromJson(json);
}
