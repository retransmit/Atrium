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
    // Detail-only fields (populated by GET /{movie|tv}/{id}).
    String? backdropPath,

    /// TMDB status, e.g. "Released", "Ended", "Returning Series".
    String? status,

    /// Movie runtime in minutes.
    int? runtime,

    /// TV total episode count.
    int? numberOfEpisodes,
    @Default(<SeerrGenre>[]) List<SeerrGenre> genres,

    /// Inline cast credits (returned by GET /{movie|tv}/{id}).
    @JsonKey(name: 'credits') SeerrCredits? credits,
  }) = _SeerrDiscoverResult;

  factory SeerrDiscoverResult.fromJson(Map<String, dynamic> json) =>
      _$SeerrDiscoverResultFromJson(json);

  String get displayTitle => title ?? name ?? originalTitle ?? 'Unknown';
  String? get displayDate => releaseDate ?? firstAirDate;

  /// Four-digit year from the release/air date, when present.
  String? get year {
    final String? d = displayDate;
    if (d == null || d.length < 4) {
      return null;
    }
    return d.substring(0, 4);
  }

  bool get isMovie => mediaType.toLowerCase() == 'movie';
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

/// Cast credits embedded in a media-detail response.
@freezed
abstract class SeerrCredits with _$SeerrCredits {
  const factory SeerrCredits({
    @Default(<SeerrCastMember>[]) List<SeerrCastMember> cast,
  }) = _SeerrCredits;

  factory SeerrCredits.fromJson(Map<String, dynamic> json) =>
      _$SeerrCreditsFromJson(json);
}

@freezed
abstract class SeerrCastMember with _$SeerrCastMember {
  const factory SeerrCastMember({
    required int id,
    @Default('') String name,
    String? character,
    String? profilePath,
  }) = _SeerrCastMember;

  factory SeerrCastMember.fromJson(Map<String, dynamic> json) =>
      _$SeerrCastMemberFromJson(json);
}
