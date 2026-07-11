import 'package:freezed_annotation/freezed_annotation.dart';

part 'jellyfin_remote_search.freezed.dart';
part 'jellyfin_remote_search.g.dart';

/// One provider match from `POST /Items/RemoteSearch/{type}`.
@freezed
abstract class JellyfinRemoteSearchResult with _$JellyfinRemoteSearchResult {
  const factory JellyfinRemoteSearchResult({
    @JsonKey(name: 'Name') String? name,
    @JsonKey(name: 'ProviderIds') Map<String, dynamic>? providerIds,
    @JsonKey(name: 'ProductionYear') int? productionYear,
    @JsonKey(name: 'IndexNumber') int? indexNumber,
    @JsonKey(name: 'IndexNumberEnd') int? indexNumberEnd,
    @JsonKey(name: 'ParentIndexNumber') int? parentIndexNumber,
    @JsonKey(name: 'PremiereDate') String? premiereDate,
    @JsonKey(name: 'ImageUrl') String? imageUrl,
    @JsonKey(name: 'SearchProviderName') String? searchProviderName,
    @JsonKey(name: 'Overview') String? overview,
  }) = _JellyfinRemoteSearchResult;

  factory JellyfinRemoteSearchResult.fromJson(Map<String, dynamic> json) =>
      _$JellyfinRemoteSearchResultFromJson(json);
}

/// Request body for `POST /Items/RemoteSearch/{type}`.
@freezed
abstract class JellyfinRemoteSearchQuery with _$JellyfinRemoteSearchQuery {
  const factory JellyfinRemoteSearchQuery({
    @JsonKey(name: 'SearchInfo') required JellyfinRemoteSearchInfo searchInfo,
    @JsonKey(name: 'ItemId') required String itemId,
  }) = _JellyfinRemoteSearchQuery;

  factory JellyfinRemoteSearchQuery.fromJson(Map<String, dynamic> json) =>
      _$JellyfinRemoteSearchQueryFromJson(json);
}

/// The user-editable search criteria inside [JellyfinRemoteSearchQuery].
@freezed
abstract class JellyfinRemoteSearchInfo with _$JellyfinRemoteSearchInfo {
  const factory JellyfinRemoteSearchInfo({
    @JsonKey(name: 'Name') required String name,
    @JsonKey(name: 'Year') int? year,
    @JsonKey(name: 'ProviderIds') Map<String, dynamic>? providerIds,
    @JsonKey(name: 'IndexNumber') int? indexNumber,
    @JsonKey(name: 'ParentIndexNumber') int? parentIndexNumber,
  }) = _JellyfinRemoteSearchInfo;

  factory JellyfinRemoteSearchInfo.fromJson(Map<String, dynamic> json) =>
      _$JellyfinRemoteSearchInfoFromJson(json);
}
