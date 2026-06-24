import 'package:freezed_annotation/freezed_annotation.dart';

part 'radarr_settings_models.freezed.dart';
part 'radarr_settings_models.g.dart';

/// Configurable settings models for Radarr, all backed by `GET /api/v3/<resource>`.
///
/// Only the fields the settings UI renders are modeled; Radarr returns many
/// more. Write flows (create/update/test) round-trip the FULL raw object back
/// through the API layer, so these typed projections are read-only views and
/// deliberately do not try to capture every field.

/// One indexer connection from `GET /api/v3/indexer`.
@freezed
abstract class RadarrIndexer with _$RadarrIndexer {
  const factory RadarrIndexer({
    required int id,
    @Default('') String name,
    @Default(false) bool enableRss,
    @Default(false) bool enableAutomaticSearch,
    @Default(false) bool enableInteractiveSearch,
    @Default('') String protocol,
  }) = _RadarrIndexer;

  factory RadarrIndexer.fromJson(Map<String, dynamic> json) =>
      _$RadarrIndexerFromJson(json);
}

/// One download client from `GET /api/v3/downloadclient`.
@freezed
abstract class RadarrDownloadClient with _$RadarrDownloadClient {
  const factory RadarrDownloadClient({
    required int id,
    @Default('') String name,
    @Default(false) bool enable,
    @Default('') String protocol,
  }) = _RadarrDownloadClient;

  factory RadarrDownloadClient.fromJson(Map<String, dynamic> json) =>
      _$RadarrDownloadClientFromJson(json);
}

/// One notification connection from `GET /api/v3/notification`.
@freezed
abstract class RadarrNotification with _$RadarrNotification {
  const factory RadarrNotification({
    required int id,
    @Default('') String name,
    @Default(false) bool onGrab,
    @Default(false) bool onDownload,
    @Default(false) bool onUpgrade,
  }) = _RadarrNotification;

  factory RadarrNotification.fromJson(Map<String, dynamic> json) =>
      _$RadarrNotificationFromJson(json);
}

/// One import list from `GET /api/v3/importlist`.
@freezed
abstract class RadarrImportList with _$RadarrImportList {
  const factory RadarrImportList({
    required int id,
    @Default('') String name,
    @Default(false) bool enable,
  }) = _RadarrImportList;

  factory RadarrImportList.fromJson(Map<String, dynamic> json) =>
      _$RadarrImportListFromJson(json);
}

/// A label tag from `GET /api/v3/tag`.
@freezed
abstract class RadarrTag with _$RadarrTag {
  const factory RadarrTag({
    required int id,
    @Default('') String label,
  }) = _RadarrTag;

  factory RadarrTag.fromJson(Map<String, dynamic> json) =>
      _$RadarrTagFromJson(json);
}

/// Host configuration from `GET /api/v3/config/host`.
@freezed
abstract class RadarrHostConfig with _$RadarrHostConfig {
  const factory RadarrHostConfig({
    required int id,
    @Default('') String bindAddress,
    @Default(7878) int port,
    @Default(false) bool enableSsl,
    @Default('info') String logLevel,
    @Default('master') String branch,
    @Default(7) int backupInterval,
    @Default(28) int backupRetention,
  }) = _RadarrHostConfig;

  factory RadarrHostConfig.fromJson(Map<String, dynamic> json) =>
      _$RadarrHostConfigFromJson(json);
}

/// File and folder naming configuration from `GET /api/v3/config/naming`.
@freezed
abstract class RadarrNamingConfig with _$RadarrNamingConfig {
  const factory RadarrNamingConfig({
    required int id,
    @Default(false) bool renameMovies,
    @Default(false) bool replaceIllegalCharacters,
    @Default('') String standardMovieFormat,
    @Default('') String movieFolderFormat,
  }) = _RadarrNamingConfig;

  factory RadarrNamingConfig.fromJson(Map<String, dynamic> json) =>
      _$RadarrNamingConfigFromJson(json);
}

/// Media management configuration from `GET /api/v3/config/mediamanagement`.
@freezed
abstract class RadarrMediaManagementConfig with _$RadarrMediaManagementConfig {
  const factory RadarrMediaManagementConfig({
    required int id,
    @Default(false) bool autoUnmonitorPreviouslyDownloadedMovies,
    @JsonKey(fromJson: _recycleBinFromJson) @Default(false) bool recycleBin,
    @Default('preferAndUpgrade') String downloadPropersAndRepacks,
    @Default(false) bool createEmptyMovieFolders,
    @Default(false) bool deleteEmptyFolders,
    @Default(false) bool copyUsingHardlinks,
  }) = _RadarrMediaManagementConfig;

  factory RadarrMediaManagementConfig.fromJson(Map<String, dynamic> json) =>
      _$RadarrMediaManagementConfigFromJson(json);
}

/// Treats a non-empty recycle-bin path string as "enabled".
bool _recycleBinFromJson(dynamic value) =>
    value is String && value.isNotEmpty;

/// UI configuration from `GET /api/v3/config/ui`.
@freezed
abstract class RadarrUiConfig with _$RadarrUiConfig {
  const factory RadarrUiConfig({
    required int id,
    @Default(0) int firstDayOfWeek,
    @Default('dark') String theme,
    @Default('h:mm a') String timeFormat,
  }) = _RadarrUiConfig;

  factory RadarrUiConfig.fromJson(Map<String, dynamic> json) =>
      _$RadarrUiConfigFromJson(json);
}

/// One metadata consumer from `GET /api/v3/metadata`.
@freezed
abstract class RadarrMetadataProvider with _$RadarrMetadataProvider {
  const factory RadarrMetadataProvider({
    required int id,
    @Default('') String name,
    @Default(false) bool enable,
  }) = _RadarrMetadataProvider;

  factory RadarrMetadataProvider.fromJson(Map<String, dynamic> json) =>
      _$RadarrMetadataProviderFromJson(json);
}

/// One delay profile from `GET /api/v3/delayprofile`.
@freezed
abstract class RadarrDelayProfile with _$RadarrDelayProfile {
  const factory RadarrDelayProfile({
    required int id,
    @Default(false) bool enableUsenet,
    @Default(false) bool enableTorrent,
    @Default(0) int usenetDelay,
    @Default(0) int torrentDelay,
    @Default('usenet') String preferredProtocol,
  }) = _RadarrDelayProfile;

  factory RadarrDelayProfile.fromJson(Map<String, dynamic> json) =>
      _$RadarrDelayProfileFromJson(json);
}

/// One custom format from `GET /api/v3/customformat`.
@freezed
abstract class RadarrCustomFormat with _$RadarrCustomFormat {
  const factory RadarrCustomFormat({
    required int id,
    @Default('') String name,
  }) = _RadarrCustomFormat;

  factory RadarrCustomFormat.fromJson(Map<String, dynamic> json) =>
      _$RadarrCustomFormatFromJson(json);
}

/// One quality definition (size limits) from `GET /api/v3/qualitydefinition`.
@freezed
abstract class RadarrQualityDefinition with _$RadarrQualityDefinition {
  const factory RadarrQualityDefinition({
    required int id,
    @Default('') String title,
    @Default(0) double minSize,
    @Default(0) double maxSize,
    @Default(0) double preferredSize,
    @Default(<String, dynamic>{}) Map<String, dynamic> quality,
  }) = _RadarrQualityDefinition;

  factory RadarrQualityDefinition.fromJson(Map<String, dynamic> json) =>
      _$RadarrQualityDefinitionFromJson(json);

  const RadarrQualityDefinition._();

  /// Best available display label: explicit title, else the nested quality name.
  String get name {
    if (title.isNotEmpty) return title;
    final qName = quality['name'] as String?;
    if (qName != null && qName.isNotEmpty) return qName;
    return '';
  }
}

/// One release profile from `GET /api/v3/releaseprofile`.
@freezed
abstract class RadarrReleaseProfile with _$RadarrReleaseProfile {
  const factory RadarrReleaseProfile({
    required int id,
    @Default('') String name,
    @Default(false) bool enabled,
    @JsonKey(name: 'required')
    @Default(<String>[])
    List<String> requiredTerms,
    @JsonKey(name: 'ignored')
    @Default(<String>[])
    List<String> ignoredTerms,
    @JsonKey(name: 'preferred')
    @Default(<Map<String, dynamic>>[])
    List<Map<String, dynamic>> preferredTerms,
    @Default(<int>[]) List<int> indexerIds,
    @Default(<int>[]) List<int> tags,
  }) = _RadarrReleaseProfile;

  factory RadarrReleaseProfile.fromJson(Map<String, dynamic> json) =>
      _$RadarrReleaseProfileFromJson(json);
}

/// One import-list exclusion from `GET /api/v3/importlistexclusion`.
@freezed
abstract class RadarrImportListExclusion with _$RadarrImportListExclusion {
  const factory RadarrImportListExclusion({
    required int id,
    @JsonKey(name: 'movieTitle') @Default('') String title,
    @Default(0) int tmdbId,
  }) = _RadarrImportListExclusion;

  factory RadarrImportListExclusion.fromJson(Map<String, dynamic> json) =>
      _$RadarrImportListExclusionFromJson(json);
}

/// One auto-tagging rule from `GET /api/v3/autotagging`.
@freezed
abstract class RadarrAutoTaggingRule with _$RadarrAutoTaggingRule {
  const factory RadarrAutoTaggingRule({
    required int id,
    @Default('') String name,
    @Default(<int>[]) List<int> tags,
    @Default(<Map<String, dynamic>>[])
    List<Map<String, dynamic>> specifications,
  }) = _RadarrAutoTaggingRule;

  factory RadarrAutoTaggingRule.fromJson(Map<String, dynamic> json) =>
      _$RadarrAutoTaggingRuleFromJson(json);
}
