import 'package:freezed_annotation/freezed_annotation.dart';
import 'radarr_movie.dart';

part 'radarr_history_item.freezed.dart';
part 'radarr_history_item.g.dart';

@freezed
abstract class RadarrHistoryItem with _$RadarrHistoryItem {
  const factory RadarrHistoryItem({
    required int id,
    int? movieId,
    String? sourceTitle,
    String? date,
    String? downloadId,
    String? eventType,
    Map<String, String?>? data,
    RadarrMovie? movie,
  }) = _RadarrHistoryItem;

  factory RadarrHistoryItem.fromJson(Map<String, dynamic> json) =>
      _$RadarrHistoryItemFromJson(json);
}
