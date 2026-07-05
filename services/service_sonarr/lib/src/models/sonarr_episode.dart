import 'package:freezed_annotation/freezed_annotation.dart';

part 'sonarr_episode.freezed.dart';
part 'sonarr_episode.g.dart';

@freezed
abstract class SonarrEpisode with _$SonarrEpisode {
  const factory SonarrEpisode({
    required int id,
    required int seriesId,
    required int seasonNumber,
    required int episodeNumber,
    required String title,
    String? overview,
    @Default(false) bool hasFile,
    @Default(false) bool monitored,
    String? airDate,
    String? airDateUtc,
    int? runtime,
    int? absoluteEpisodeNumber,
    int? episodeFileId,
  }) = _SonarrEpisode;

  factory SonarrEpisode.fromJson(Map<String, dynamic> json) =>
      _$SonarrEpisodeFromJson(json);
}
