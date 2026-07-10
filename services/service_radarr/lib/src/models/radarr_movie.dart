import 'package:freezed_annotation/freezed_annotation.dart';

part 'radarr_movie.freezed.dart';
part 'radarr_movie.g.dart';

@freezed
abstract class RadarrMovie with _$RadarrMovie {
  const factory RadarrMovie({
    @Default(0) int id,
    required String title,
    String? sortTitle,
    int? year,
    String? overview,
    String? status,
    String? studio,
    int? runtime,
    String? inCinemas,
    String? physicalRelease,
    String? digitalRelease,
    String? releaseDate,
    @Default(false) bool monitored,
    @Default(false) bool hasFile,
    @Default(0) int sizeOnDisk,
    RadarrRatings? ratings,
    @Default(<RadarrImage>[]) List<RadarrImage> images,
    String? path,
    String? added,
    int? tmdbId,
    String? imdbId,
    String? titleSlug,
    int? movieFileId,
    @Default(<String>[]) List<String> genres,
    String? certification,
    RadarrCollection? collection,
    RadarrLanguage? originalLanguage,
  }) = _RadarrMovie;

  factory RadarrMovie.fromJson(Map<String, dynamic> json) =>
      _$RadarrMovieFromJson(json);
}

@freezed
abstract class RadarrRatings with _$RadarrRatings {
  const factory RadarrRatings({
    RadarrRatingValue? imdb,
    RadarrRatingValue? tmdb,
    RadarrRatingValue? rottenTomatoes,
  }) = _RadarrRatings;

  factory RadarrRatings.fromJson(Map<String, dynamic> json) =>
      _$RadarrRatingsFromJson(json);
}

@freezed
abstract class RadarrRatingValue with _$RadarrRatingValue {
  const factory RadarrRatingValue({
    @Default(0) double value,
    @Default(0) int votes,
    String? type,
  }) = _RadarrRatingValue;

  factory RadarrRatingValue.fromJson(Map<String, dynamic> json) =>
      _$RadarrRatingValueFromJson(json);
}

@freezed
abstract class RadarrImage with _$RadarrImage {
  const factory RadarrImage({
    required String coverType,
    String? remoteUrl,
    String? url,
  }) = _RadarrImage;

  factory RadarrImage.fromJson(Map<String, dynamic> json) =>
      _$RadarrImageFromJson(json);
}

@freezed
abstract class RadarrCollection with _$RadarrCollection {
  const factory RadarrCollection({
    String? title,
    int? tmdbId,
    @Default(<RadarrImage>[]) List<RadarrImage> images,
  }) = _RadarrCollection;

  factory RadarrCollection.fromJson(Map<String, dynamic> json) =>
      _$RadarrCollectionFromJson(json);
}

@freezed
abstract class RadarrLanguage with _$RadarrLanguage {
  const factory RadarrLanguage({
    required int id,
    String? name,
  }) = _RadarrLanguage;

  factory RadarrLanguage.fromJson(Map<String, dynamic> json) =>
      _$RadarrLanguageFromJson(json);
}
