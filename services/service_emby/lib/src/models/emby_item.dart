import 'package:freezed_annotation/freezed_annotation.dart';

part 'emby_item.freezed.dart';
part 'emby_item.g.dart';

/// A page of items from `GET /Users/{userId}/Items`.
@freezed
class EmbyItemsResult with _$EmbyItemsResult {
  const factory EmbyItemsResult({
    @JsonKey(name: 'Items') @Default(<EmbyItem>[]) List<EmbyItem> items,
    @JsonKey(name: 'TotalRecordCount') @Default(0) int totalRecordCount,
  }) = _EmbyItemsResult;

  factory EmbyItemsResult.fromJson(Map<String, dynamic> json) =>
      _$EmbyItemsResultFromJson(json);
}

/// A library item (movie, series, episode, album, …).
@freezed
class EmbyItem with _$EmbyItem {
  const factory EmbyItem({
    @JsonKey(name: 'Id') required String id,
    @JsonKey(name: 'Name') @Default('') String name,
    @JsonKey(name: 'Type') @Default('') String type,
    @JsonKey(name: 'ProductionYear') int? productionYear,
    @JsonKey(name: 'ImageTags')
    @Default(<String, String>{})
    Map<String, String> imageTags,
    @JsonKey(name: 'UserData') EmbyUserData? userData,
  }) = _EmbyItem;

  factory EmbyItem.fromJson(Map<String, dynamic> json) =>
      _$EmbyItemFromJson(json);
}

/// Per-user playback state for an item.
@freezed
class EmbyUserData with _$EmbyUserData {
  const factory EmbyUserData({
    @JsonKey(name: 'PlayedPercentage') @Default(0.0) double playedPercentage,
    @JsonKey(name: 'Played') @Default(false) bool played,
    /// Resume point in Emby ticks (100ns units). 0 = start from the top.
    @JsonKey(name: 'PlaybackPositionTicks') @Default(0) int positionTicks,
  }) = _EmbyUserData;

  factory EmbyUserData.fromJson(Map<String, dynamic> json) =>
      _$EmbyUserDataFromJson(json);
}
