import 'package:freezed_annotation/freezed_annotation.dart';

part 'emby_auth.freezed.dart';
part 'emby_auth.g.dart';

/// Result of Emby's `POST /Users/AuthenticateByName`. PascalCase keys mapped
/// via [JsonKey]. (Emby's auth shape matches Jellyfin's.)
@freezed
abstract class EmbyAuthResult with _$EmbyAuthResult {
  const factory EmbyAuthResult({
    @JsonKey(name: 'AccessToken') required String accessToken,
    @JsonKey(name: 'ServerId') String? serverId,
    @JsonKey(name: 'User') required EmbyUser user,
  }) = _EmbyAuthResult;

  factory EmbyAuthResult.fromJson(Map<String, dynamic> json) =>
      _$EmbyAuthResultFromJson(json);
}

@freezed
abstract class EmbyUser with _$EmbyUser {
  const factory EmbyUser({
    @JsonKey(name: 'Id') required String id,
    @JsonKey(name: 'Name') @Default('') String name,
    @JsonKey(name: 'HasPassword') @Default(false) bool hasPassword,
    @JsonKey(name: 'Policy') @Default(EmbyUserPolicy()) EmbyUserPolicy policy,
  }) = _EmbyUser;

  factory EmbyUser.fromJson(Map<String, dynamic> json) =>
      _$EmbyUserFromJson(json);
}

@freezed
abstract class EmbyUserPolicy with _$EmbyUserPolicy {
  const factory EmbyUserPolicy({
    @JsonKey(name: 'IsAdministrator') @Default(false) bool isAdministrator,
    @JsonKey(name: 'EnableAllFolders') @Default(true) bool enableAllFolders,
    @JsonKey(name: 'EnabledFolders') @Default(<String>[]) List<String> enabledFolders,
  }) = _EmbyUserPolicy;

  factory EmbyUserPolicy.fromJson(Map<String, dynamic> json) =>
      _$EmbyUserPolicyFromJson(json);
}
