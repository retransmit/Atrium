import 'package:freezed_annotation/freezed_annotation.dart';

part 'jellyfin_view.freezed.dart';
part 'jellyfin_view.g.dart';

/// A Jellyfin library/view from `GET /Users/{userId}/Views`.
@freezed
abstract class JellyfinView with _$JellyfinView {
  const factory JellyfinView({
    @JsonKey(name: 'Id') required String id,
    @JsonKey(name: 'Name') @Default('') String name,

    /// "movies", "tvshows", "music", "boxsets", "homevideos", … or null.
    @JsonKey(name: 'CollectionType') String? collectionType,
  }) = _JellyfinView;

  factory JellyfinView.fromJson(Map<String, dynamic> json) =>
      _$JellyfinViewFromJson(json);
}

/// A global virtual folder from `GET /Library/VirtualFolders`.
@freezed
abstract class JellyfinVirtualFolder with _$JellyfinVirtualFolder {
  const factory JellyfinVirtualFolder({
    @JsonKey(name: 'ItemId') required String itemId,
    @JsonKey(name: 'Name') @Default('') String name,
    @JsonKey(name: 'CollectionType') String? collectionType,
  }) = _JellyfinVirtualFolder;

  factory JellyfinVirtualFolder.fromJson(Map<String, dynamic> json) =>
      _$JellyfinVirtualFolderFromJson(json);
}
