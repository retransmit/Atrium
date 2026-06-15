import 'package:freezed_annotation/freezed_annotation.dart';

part 'seerr_service.freezed.dart';
part 'seerr_service.g.dart';

/// A Radarr/Sonarr server configured in Seerr, from
/// `GET /api/v1/service/{radarr|sonarr}`. The active profile/directory are the
/// server's configured defaults, used to pre-select the request options.
@freezed
abstract class SeerrServer with _$SeerrServer {
  const factory SeerrServer({
    required int id,
    @Default('') String name,
    @Default(false) bool is4k,
    @Default(false) bool isDefault,
    int? activeProfileId,
    String? activeDirectory,
  }) = _SeerrServer;

  factory SeerrServer.fromJson(Map<String, dynamic> json) =>
      _$SeerrServerFromJson(json);
}

/// Quality profiles and root folders for one server, from
/// `GET /api/v1/service/{radarr|sonarr}/{id}`.
@freezed
abstract class SeerrServerDetails with _$SeerrServerDetails {
  const factory SeerrServerDetails({
    @Default(<SeerrProfile>[]) List<SeerrProfile> profiles,
    @Default(<SeerrRootFolder>[]) List<SeerrRootFolder> rootFolders,
  }) = _SeerrServerDetails;

  factory SeerrServerDetails.fromJson(Map<String, dynamic> json) =>
      _$SeerrServerDetailsFromJson(json);
}

/// A quality profile (`id` is what the request POST wants as `profileId`).
@freezed
abstract class SeerrProfile with _$SeerrProfile {
  const factory SeerrProfile({
    required int id,
    @Default('') String name,
  }) = _SeerrProfile;

  factory SeerrProfile.fromJson(Map<String, dynamic> json) =>
      _$SeerrProfileFromJson(json);
}

/// A root folder (`path` is what the request POST wants as `rootFolder`).
@freezed
abstract class SeerrRootFolder with _$SeerrRootFolder {
  const factory SeerrRootFolder({
    required int id,
    @Default('') String path,
  }) = _SeerrRootFolder;

  factory SeerrRootFolder.fromJson(Map<String, dynamic> json) =>
      _$SeerrRootFolderFromJson(json);
}
