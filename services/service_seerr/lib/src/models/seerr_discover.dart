import 'package:freezed_annotation/freezed_annotation.dart';

import 'seerr_request.dart';

part 'seerr_discover.freezed.dart';
part 'seerr_discover.g.dart';

@freezed
abstract class SeerrDiscoverPage with _$SeerrDiscoverPage {
  const factory SeerrDiscoverPage({
    @Default(1) int page,
    @Default(1) int totalPages,
    @Default(0) int totalResults,
    @Default(<SeerrDiscoverResult>[]) List<SeerrDiscoverResult> results,
  }) = _SeerrDiscoverPage;

  factory SeerrDiscoverPage.fromJson(Map<String, dynamic> json) =>
      _$SeerrDiscoverPageFromJson(json);
}

@freezed
abstract class SeerrDiscoverResult with _$SeerrDiscoverResult {
  const SeerrDiscoverResult._();

  const factory SeerrDiscoverResult({
    required int id,
    @Default('movie') String mediaType,
    String? title,
    String? name,
    String? overview,
    String? originalLanguage,
    String? originalTitle,
    String? imdbId,
    double? voteAverage,
    String? releaseDate,
    String? firstAirDate,
    bool? adult,
    String? posterPath,
    SeerrMedia? mediaInfo,
  }) = _SeerrDiscoverResult;

  factory SeerrDiscoverResult.fromJson(Map<String, dynamic> json) =>
      _$SeerrDiscoverResultFromJson(json);

  String get displayTitle => title ?? name ?? originalTitle ?? 'Unknown';
  String? get displayDate => releaseDate ?? firstAirDate;
}

@freezed
abstract class SeerrGenre with _$SeerrGenre {
  const factory SeerrGenre({
    required int id,
    required String name,
  }) = _SeerrGenre;

  factory SeerrGenre.fromJson(Map<String, dynamic> json) =>
      _$SeerrGenreFromJson(json);
}
