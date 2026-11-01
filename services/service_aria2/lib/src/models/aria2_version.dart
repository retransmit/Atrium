import 'package:freezed_annotation/freezed_annotation.dart';

import 'aria2_json.dart';

part 'aria2_version.freezed.dart';
part 'aria2_version.g.dart';

/// `aria2.getVersion`: the daemon's version and the features it was built
/// with.
@freezed
abstract class Aria2Version with _$Aria2Version {
  const factory Aria2Version({
    @Default('') String version,
    @JsonKey(name: 'enabledFeatures', fromJson: aria2StringList)
    @Default(<String>[])
    List<String> enabledFeatures,
  }) = _Aria2Version;

  factory Aria2Version.fromJson(Map<String, dynamic> json) =>
      _$Aria2VersionFromJson(json);
}
