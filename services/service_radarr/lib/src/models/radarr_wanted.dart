import 'package:freezed_annotation/freezed_annotation.dart';

import 'radarr_movie.dart';

part 'radarr_wanted.freezed.dart';
part 'radarr_wanted.g.dart';

/// A page of "wanted" movies (missing, or below quality cutoff). Records are
/// full movie objects, same shape as the library.
@freezed
abstract class RadarrWantedPage with _$RadarrWantedPage {
  const factory RadarrWantedPage({
    @Default(1) int page,
    @Default(0) int pageSize,
    @Default(0) int totalRecords,
    @Default(<RadarrMovie>[]) List<RadarrMovie> records,
  }) = _RadarrWantedPage;

  factory RadarrWantedPage.fromJson(Map<String, dynamic> json) =>
      _$RadarrWantedPageFromJson(json);
}
