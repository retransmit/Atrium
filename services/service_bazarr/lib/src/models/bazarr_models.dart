import 'package:freezed_annotation/freezed_annotation.dart';

part 'bazarr_models.freezed.dart';
part 'bazarr_models.g.dart';

/// `GET /api/badges` → summary counts shown in the header.
@freezed
abstract class BazarrBadges with _$BazarrBadges {
  const factory BazarrBadges({
    @Default(0) int episodes,
    @Default(0) int movies,
    @Default(0) int providers,
  }) = _BazarrBadges;

  factory BazarrBadges.fromJson(Map<String, dynamic> json) =>
      _$BazarrBadgesFromJson(json);
}

/// `GET /api/episodes/wanted` → `{ "data": [ … ], "total": N }`.
@freezed
abstract class BazarrWantedEpisodes with _$BazarrWantedEpisodes {
  const factory BazarrWantedEpisodes({
    @Default(<BazarrWantedEpisode>[]) List<BazarrWantedEpisode> data,
    @Default(0) int total,
  }) = _BazarrWantedEpisodes;

  factory BazarrWantedEpisodes.fromJson(Map<String, dynamic> json) =>
      _$BazarrWantedEpisodesFromJson(json);
}

@freezed
abstract class BazarrWantedEpisode with _$BazarrWantedEpisode {
  const factory BazarrWantedEpisode({
    @JsonKey(name: 'seriesTitle') @Default('') String seriesTitle,
    @JsonKey(name: 'episodeTitle') @Default('') String episodeTitle,
    @JsonKey(name: 'episode_number') @Default('') String episodeNumber,
    @JsonKey(name: 'sonarrSeriesId') @Default(0) int sonarrSeriesId,
    @JsonKey(name: 'sonarrEpisodeId') @Default(0) int sonarrEpisodeId,
    @JsonKey(name: 'missing_subtitles')
    @Default(<BazarrSubtitle>[])
    List<BazarrSubtitle> missingSubtitles,
  }) = _BazarrWantedEpisode;

  factory BazarrWantedEpisode.fromJson(Map<String, dynamic> json) =>
      _$BazarrWantedEpisodeFromJson(json);
}

/// `GET /api/movies/wanted` → `{ "data": [ … ], "total": N }`.
@freezed
abstract class BazarrWantedMovies with _$BazarrWantedMovies {
  const factory BazarrWantedMovies({
    @Default(<BazarrWantedMovie>[]) List<BazarrWantedMovie> data,
    @Default(0) int total,
  }) = _BazarrWantedMovies;

  factory BazarrWantedMovies.fromJson(Map<String, dynamic> json) =>
      _$BazarrWantedMoviesFromJson(json);
}

@freezed
abstract class BazarrWantedMovie with _$BazarrWantedMovie {
  const factory BazarrWantedMovie({
    @Default('') String title,
    @JsonKey(name: 'radarrId') @Default(0) int radarrId,
    @JsonKey(name: 'missing_subtitles')
    @Default(<BazarrSubtitle>[])
    List<BazarrSubtitle> missingSubtitles,
  }) = _BazarrWantedMovie;

  factory BazarrWantedMovie.fromJson(Map<String, dynamic> json) =>
      _$BazarrWantedMovieFromJson(json);
}

/// One subtitle entry, used for both present subtitles (carry a [path]) and
/// missing ones (no path). Bazarr returns these as objects with snake_case
/// language codes.
@freezed
abstract class BazarrSubtitle with _$BazarrSubtitle {
  const factory BazarrSubtitle({
    @Default('') String name,
    @Default('') String code2,
    @Default('') String code3,
    @Default(false) bool hi,
    @Default(false) bool forced,
    String? path,
  }) = _BazarrSubtitle;

  factory BazarrSubtitle.fromJson(Map<String, dynamic> json) =>
      _$BazarrSubtitleFromJson(json);
}

/// `GET /api/series` data item (Sonarr-backed). [episodeMissingCount] is the
/// number of episodes still missing subtitles.
@freezed
abstract class BazarrSeries with _$BazarrSeries {
  const factory BazarrSeries({
    @Default(0) int sonarrSeriesId,
    @Default('') String title,
    @JsonKey(fromJson: _yearFromJson) int? year,
    @Default(false) bool monitored,
    int? profileId,
    @Default(0) int episodeFileCount,
    @Default(0) int episodeMissingCount,
    String? poster,
    String? seriesType,
  }) = _BazarrSeries;

  factory BazarrSeries.fromJson(Map<String, dynamic> json) =>
      _$BazarrSeriesFromJson(json);
}

/// `GET /api/movies` data item (Radarr-backed), with its present and missing
/// subtitle lists inline.
@freezed
abstract class BazarrMovie with _$BazarrMovie {
  const factory BazarrMovie({
    @Default(0) int radarrId,
    @Default('') String title,
    @JsonKey(fromJson: _yearFromJson) int? year,
    @Default(false) bool monitored,
    int? profileId,
    String? poster,
    @Default(<BazarrSubtitle>[]) List<BazarrSubtitle> subtitles,
    @JsonKey(name: 'missing_subtitles')
    @Default(<BazarrSubtitle>[])
    List<BazarrSubtitle> missingSubtitles,
  }) = _BazarrMovie;

  factory BazarrMovie.fromJson(Map<String, dynamic> json) =>
      _$BazarrMovieFromJson(json);
}

/// `GET /api/episodes?seriesid[]=` data item, with present and missing subtitle
/// lists inline.
@freezed
abstract class BazarrEpisode with _$BazarrEpisode {
  const factory BazarrEpisode({
    @Default(0) int sonarrEpisodeId,
    @Default(0) int sonarrSeriesId,
    @Default('') String title,
    int? season,
    int? episode,
    @Default(false) bool monitored,
    @Default(<BazarrSubtitle>[]) List<BazarrSubtitle> subtitles,
    @JsonKey(name: 'missing_subtitles')
    @Default(<BazarrSubtitle>[])
    List<BazarrSubtitle> missingSubtitles,
  }) = _BazarrEpisode;

  factory BazarrEpisode.fromJson(Map<String, dynamic> json) =>
      _$BazarrEpisodeFromJson(json);
}

/// A flattened "needs subtitles" row, unifying episodes + movies for the UI.
class BazarrWantedRow {
  const BazarrWantedRow({
    required this.title,
    required this.subtitle,
    required this.missing,
    required this.isMovie,
  });

  final String title;
  final String subtitle;
  final List<BazarrSubtitle> missing;
  final bool isMovie;
}

/// Bazarr returns `year` as a string ("2026") for series and movies; parse it
/// leniently to an int so the UI can treat it as a number (null if blank).
int? _yearFromJson(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}
