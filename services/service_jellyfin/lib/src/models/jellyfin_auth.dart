import 'package:freezed_annotation/freezed_annotation.dart';

part 'jellyfin_auth.freezed.dart';
part 'jellyfin_auth.g.dart';

/// Result of `POST /Users/AuthenticateByName`. Jellyfin returns PascalCase
/// keys, mapped explicitly with [JsonKey].
@freezed
abstract class JellyfinAuthResult with _$JellyfinAuthResult {
  const factory JellyfinAuthResult({
    @JsonKey(name: 'AccessToken') required String accessToken,
    @JsonKey(name: 'ServerId') String? serverId,
    @JsonKey(name: 'User') required JellyfinUser user,
  }) = _JellyfinAuthResult;

  factory JellyfinAuthResult.fromJson(Map<String, dynamic> json) =>
      _$JellyfinAuthResultFromJson(json);
}

@freezed
abstract class JellyfinUser with _$JellyfinUser {
  const factory JellyfinUser({
    @JsonKey(name: 'Id') required String id,
    @JsonKey(name: 'Name') @Default('') String name,
    @JsonKey(name: 'HasPassword') @Default(false) bool hasPassword,
    @JsonKey(name: 'Policy')
    @Default(JellyfinUserPolicy())
    JellyfinUserPolicy policy,
  }) = _JellyfinUser;

  factory JellyfinUser.fromJson(Map<String, dynamic> json) =>
      _$JellyfinUserFromJson(json);
}

@freezed
abstract class JellyfinUserPolicy with _$JellyfinUserPolicy {
  const factory JellyfinUserPolicy({
    @JsonKey(name: 'IsAdministrator') @Default(false) bool isAdministrator,
    @JsonKey(name: 'EnableAllFolders') @Default(true) bool enableAllFolders,
    @JsonKey(name: 'EnabledFolders')
    @Default(<String>[])
    List<String> enabledFolders,
  }) = _JellyfinUserPolicy;

  factory JellyfinUserPolicy.fromJson(Map<String, dynamic> json) =>
      _$JellyfinUserPolicyFromJson(json);
}
