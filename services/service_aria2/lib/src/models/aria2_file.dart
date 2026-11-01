import 'package:freezed_annotation/freezed_annotation.dart';

import 'aria2_json.dart';

part 'aria2_file.freezed.dart';
part 'aria2_file.g.dart';

/// One file inside a download, as `aria2.getFiles` and the `files` key of
/// `aria2.tellStatus` report it.
@freezed
abstract class Aria2File with _$Aria2File {
  const Aria2File._();

  const factory Aria2File({
    @JsonKey(fromJson: aria2Int) @Default(0) int index,
    @Default('') String path,
    @JsonKey(fromJson: aria2Int) @Default(0) int length,
    @JsonKey(fromJson: aria2Int) @Default(0) int completedLength,
    @JsonKey(fromJson: aria2Bool) @Default(true) bool selected,
    @Default(<Aria2Uri>[]) List<Aria2Uri> uris,
  }) = _Aria2File;

  factory Aria2File.fromJson(Map<String, dynamic> json) =>
      _$Aria2FileFromJson(json);

  /// The file's name without its directory.
  String get name => aria2BaseName(path);

  /// Completion 0..1 for this one file.
  double get progress =>
      length <= 0 ? 0 : (completedLength / length).clamp(0.0, 1.0);
}

/// One source URI behind a file.
@freezed
abstract class Aria2Uri with _$Aria2Uri {
  const factory Aria2Uri({
    @Default('') String uri,
    @Default('') String status,
  }) = _Aria2Uri;

  factory Aria2Uri.fromJson(Map<String, dynamic> json) =>
      _$Aria2UriFromJson(json);
}
