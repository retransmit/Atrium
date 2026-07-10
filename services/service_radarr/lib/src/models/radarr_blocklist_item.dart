import 'package:freezed_annotation/freezed_annotation.dart';
import 'radarr_movie.dart';

part 'radarr_blocklist_item.freezed.dart';
part 'radarr_blocklist_item.g.dart';

@freezed
abstract class RadarrBlocklistItem with _$RadarrBlocklistItem {
  const factory RadarrBlocklistItem({
    required int id,
    required int movieId,
    String? sourceTitle,
    List<Map<String, dynamic>>? languages,
    Map<String, dynamic>? quality,
    List<Map<String, dynamic>>? customFormats,
    String? date,
    String? protocol,
    String? indexer,
    String? message,
    RadarrMovie? movie,
  }) = _RadarrBlocklistItem;

  factory RadarrBlocklistItem.fromJson(Map<String, dynamic> json) =>
      _$RadarrBlocklistItemFromJson(json);
}
