import 'package:freezed_annotation/freezed_annotation.dart';
import 'radarr_movie.dart';

part 'radarr_queue_item.freezed.dart';
part 'radarr_queue_item.g.dart';

@freezed
abstract class RadarrQueueItem with _$RadarrQueueItem {
  const factory RadarrQueueItem({
    required int id,
    int? movieId,
    RadarrMovie? movie,
    double? size,
    String? title,
    String? estimatedCompletionTime,
    String? added,
    String? status,
    String? trackedDownloadStatus,
    String? trackedDownloadState,
    String? errorMessage,
    String? downloadId,
    String? downloadClient,
    String? indexer,
    String? outputPath,
    double? sizeleft,
    String? timeleft,
  }) = _RadarrQueueItem;

  factory RadarrQueueItem.fromJson(Map<String, dynamic> json) =>
      _$RadarrQueueItemFromJson(json);
}
