import 'package:freezed_annotation/freezed_annotation.dart';

part 'jellyfin_item.freezed.dart';
part 'jellyfin_item.g.dart';

/// A page of items from `GET /Users/{userId}/Items`.
@freezed
class JellyfinItemsResult with _$JellyfinItemsResult {
  const factory JellyfinItemsResult({
    @JsonKey(name: 'Items') @Default(<JellyfinItem>[]) List<JellyfinItem> items,
    @JsonKey(name: 'TotalRecordCount') @Default(0) int totalRecordCount,
  }) = _JellyfinItemsResult;

  factory JellyfinItemsResult.fromJson(Map<String, dynamic> json) =>
      _$JellyfinItemsResultFromJson(json);
}

/// A library item (movie, series, episode, album, …).
@freezed
class JellyfinItem with _$JellyfinItem {
  const factory JellyfinItem({
    @JsonKey(name: 'Id') required String id,
    @JsonKey(name: 'Name') @Default('') String name,
    @JsonKey(name: 'Type') @Default('') String type,
    @JsonKey(name: 'ProductionYear') int? productionYear,
    /// Image type → tag. We use the `Primary` tag to build the poster URL.
    @JsonKey(name: 'ImageTags')
    @Default(<String, String>{})
    Map<String, String> imageTags,
    @JsonKey(name: 'UserData') JellyfinUserData? userData,
  }) = _JellyfinItem;

  factory JellyfinItem.fromJson(Map<String, dynamic> json) =>
      _$JellyfinItemFromJson(json);
}

/// Per-user playback state for an item.
@freezed
class JellyfinUserData with _$JellyfinUserData {
  const factory JellyfinUserData({
    @JsonKey(name: 'PlayedPercentage') @Default(0.0) double playedPercentage,
    @JsonKey(name: 'Played') @Default(false) bool played,
    /// Resume point in Jellyfin ticks (100ns units). 0 = start from the top.
    @JsonKey(name: 'PlaybackPositionTicks') @Default(0) int positionTicks,
  }) = _JellyfinUserData;

  factory JellyfinUserData.fromJson(Map<String, dynamic> json) =>
      _$JellyfinUserDataFromJson(json);
}
