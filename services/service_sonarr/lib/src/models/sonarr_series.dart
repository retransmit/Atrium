import 'package:freezed_annotation/freezed_annotation.dart';

part 'sonarr_series.freezed.dart';
part 'sonarr_series.g.dart';

@freezed
abstract class SonarrSeries with _$SonarrSeries {
  const factory SonarrSeries({
    @Default(0) int id,
    required String title,
    String? sortTitle,
    String? status,
    String? overview,
    String? network,
    int? year,
    @Default(false) bool monitored,
    @Default(<SonarrImage>[]) List<SonarrImage> images,
    @Default(<SonarrSeason>[]) List<SonarrSeason> seasons,
    SonarrSeriesStatistics? statistics,
    String? seriesType,
    int? runtime,
    String? certification,
    @Default(<String>[]) List<String> genres,
    String? path,
    String? nextAiring,
    String? previousAiring,
    int? tvdbId,
    String? titleSlug,
    String? added,
    int? qualityProfileId,
    String? rootFolderPath,
    @Default(<int>[]) List<int> tags,
    bool? useSceneNumbering,
    SonarrRatings? ratings,
    SonarrLanguage? originalLanguage,
  }) = _SonarrSeries;

  factory SonarrSeries.fromJson(Map<String, dynamic> json) =>
      _$SonarrSeriesFromJson(json);
}

@freezed
abstract class SonarrRatings with _$SonarrRatings {
  const factory SonarrRatings({
    @Default(0) int votes,
    @Default(0) double value,
  }) = _SonarrRatings;

  factory SonarrRatings.fromJson(Map<String, dynamic> json) =>
      _$SonarrRatingsFromJson(json);
}

@freezed
abstract class SonarrLanguage with _$SonarrLanguage {
  const factory SonarrLanguage({
    @Default(0) int id,
    String? name,
  }) = _SonarrLanguage;

  factory SonarrLanguage.fromJson(Map<String, dynamic> json) =>
      _$SonarrLanguageFromJson(json);
}

@freezed
abstract class SonarrImage with _$SonarrImage {
  const factory SonarrImage({
    required String coverType,
    String? remoteUrl,
    String? url,
  }) = _SonarrImage;

  factory SonarrImage.fromJson(Map<String, dynamic> json) =>
      _$SonarrImageFromJson(json);
}

@freezed
abstract class SonarrSeason with _$SonarrSeason {
  const factory SonarrSeason({
    @Default(0) int seasonNumber,
    @Default(false) bool monitored,
    SonarrSeasonStatistics? statistics,
  }) = _SonarrSeason;

  factory SonarrSeason.fromJson(Map<String, dynamic> json) =>
      _$SonarrSeasonFromJson(json);
}

@freezed
abstract class SonarrSeasonStatistics with _$SonarrSeasonStatistics {
  const factory SonarrSeasonStatistics({
    @Default(0) int episodeFileCount,
    @Default(0) int episodeCount,
    @Default(0) int totalEpisodeCount,
    @Default(0) int sizeOnDisk,
  }) = _SonarrSeasonStatistics;

  factory SonarrSeasonStatistics.fromJson(Map<String, dynamic> json) =>
      _$SonarrSeasonStatisticsFromJson(json);
}

@freezed
abstract class SonarrSeriesStatistics with _$SonarrSeriesStatistics {
  const factory SonarrSeriesStatistics({
    @Default(0) int seasonCount,
    @Default(0) int episodeFileCount,
    @Default(0) int episodeCount,
    @Default(0) int totalEpisodeCount,
    @Default(0) int sizeOnDisk,
    @Default(<String>[]) List<String> releaseGroups,
  }) = _SonarrSeriesStatistics;

  factory SonarrSeriesStatistics.fromJson(Map<String, dynamic> json) =>
      _$SonarrSeriesStatisticsFromJson(json);
}
