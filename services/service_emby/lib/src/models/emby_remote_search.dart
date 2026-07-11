import 'package:freezed_annotation/freezed_annotation.dart';

part 'emby_remote_search.freezed.dart';
part 'emby_remote_search.g.dart';

/// One provider match from `POST /Items/RemoteSearch/{type}`.
@freezed
abstract class EmbyRemoteSearchResult with _$EmbyRemoteSearchResult {
  const factory EmbyRemoteSearchResult({
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
  }) = _EmbyRemoteSearchResult;

  factory EmbyRemoteSearchResult.fromJson(Map<String, dynamic> json) =>
      _$EmbyRemoteSearchResultFromJson(json);
}

/// Request body for `POST /Items/RemoteSearch/{type}`.
@freezed
abstract class EmbyRemoteSearchQuery with _$EmbyRemoteSearchQuery {
  const factory EmbyRemoteSearchQuery({
    @JsonKey(name: 'SearchInfo') required EmbyRemoteSearchInfo searchInfo,
    @JsonKey(name: 'ItemId') required String itemId,
  }) = _EmbyRemoteSearchQuery;

  factory EmbyRemoteSearchQuery.fromJson(Map<String, dynamic> json) =>
      _$EmbyRemoteSearchQueryFromJson(json);
}

/// The user-editable search criteria inside [EmbyRemoteSearchQuery].
@freezed
abstract class EmbyRemoteSearchInfo with _$EmbyRemoteSearchInfo {
  const factory EmbyRemoteSearchInfo({
    @JsonKey(name: 'Name') required String name,
    @JsonKey(name: 'Year') int? year,
    @JsonKey(name: 'ProviderIds') Map<String, dynamic>? providerIds,
    @JsonKey(name: 'IndexNumber') int? indexNumber,
    @JsonKey(name: 'ParentIndexNumber') int? parentIndexNumber,
  }) = _EmbyRemoteSearchInfo;

  factory EmbyRemoteSearchInfo.fromJson(Map<String, dynamic> json) =>
      _$EmbyRemoteSearchInfoFromJson(json);
}
