import 'package:freezed_annotation/freezed_annotation.dart';

import 'sonarr_episode.dart';
import 'sonarr_series.dart';

part 'sonarr_manual_import.freezed.dart';
part 'sonarr_manual_import.g.dart';

@freezed
class SonarrQuality with _$SonarrQuality {
  const factory SonarrQuality({
    required int id,
    String? name,
  }) = _SonarrQuality;

  factory SonarrQuality.fromJson(Map<String, dynamic> json) =>
      _$SonarrQualityFromJson(json);
}

@freezed
class SonarrRevision with _$SonarrRevision {
  const factory SonarrRevision({
    required int version,
    required int real,
    @Default(false) bool isRepack,
  }) = _SonarrRevision;

  factory SonarrRevision.fromJson(Map<String, dynamic> json) =>
      _$SonarrRevisionFromJson(json);
}

@freezed
class SonarrQualityModel with _$SonarrQualityModel {
  const factory SonarrQualityModel({
    SonarrQuality? quality,
    SonarrRevision? revision,
  }) = _SonarrQualityModel;

  factory SonarrQualityModel.fromJson(Map<String, dynamic> json) =>
      _$SonarrQualityModelFromJson(json);
}

@freezed
class SonarrLanguage with _$SonarrLanguage {
  const factory SonarrLanguage({
    required int id,
    String? name,
  }) = _SonarrLanguage;

  factory SonarrLanguage.fromJson(Map<String, dynamic> json) =>
      _$SonarrLanguageFromJson(json);
}

@freezed
class SonarrImportRejection with _$SonarrImportRejection {
  const factory SonarrImportRejection({
    String? reason,
    String? type,
  }) = _SonarrImportRejection;

  factory SonarrImportRejection.fromJson(Map<String, dynamic> json) =>
      _$SonarrImportRejectionFromJson(json);
}

@freezed
class SonarrCustomFormatResource with _$SonarrCustomFormatResource {
  const factory SonarrCustomFormatResource({
    required int id,
    String? name,
  }) = _SonarrCustomFormatResource;

  factory SonarrCustomFormatResource.fromJson(Map<String, dynamic> json) =>
      _$SonarrCustomFormatResourceFromJson(json);
}

@freezed
class SonarrManualImport with _$SonarrManualImport {
  const factory SonarrManualImport({
    required int id,
    String? path,
    String? relativePath,
    String? folderName,
    String? name,
    required int size,
    SonarrSeries? series,
    int? seasonNumber,
    List<SonarrEpisode>? episodes,
    int? episodeFileId,
    String? releaseGroup,
    SonarrQualityModel? quality,
    List<SonarrLanguage>? languages,
    required int qualityWeight,
    String? downloadId,
    List<SonarrCustomFormatResource>? customFormats,
    required int customFormatScore,
    required int indexerFlags,
    String? releaseType,
    List<SonarrImportRejection>? rejections,
  }) = _SonarrManualImport;

  factory SonarrManualImport.fromJson(Map<String, dynamic> json) =>
      _$SonarrManualImportFromJson(json);
}

@freezed
class SonarrManualImportReprocess with _$SonarrManualImportReprocess {
  const factory SonarrManualImportReprocess({
    required int id,
    String? path,
    required int seriesId,
    int? seasonNumber,
    List<SonarrEpisode>? episodes,
    List<int>? episodeIds,
    SonarrQualityModel? quality,
    List<SonarrLanguage>? languages,
    String? releaseGroup,
    String? downloadId,
    List<SonarrCustomFormatResource>? customFormats,
    required int customFormatScore,
    required int indexerFlags,
    String? releaseType,
    List<SonarrImportRejection>? rejections,
  }) = _SonarrManualImportReprocess;

  factory SonarrManualImportReprocess.fromJson(Map<String, dynamic> json) =>
      _$SonarrManualImportReprocessFromJson(json);
}
