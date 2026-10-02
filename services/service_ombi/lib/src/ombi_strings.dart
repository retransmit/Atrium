import 'models/ombi_models.dart';

/// Which seasons a request asks for, or null when it lists none.
///
/// A run of seasons reads as a range. Anything else, a gap or specials
/// mixed in, reads as a count, since a range would claim seasons that were
/// not asked for.
String? ombiSeasonsLabel(List<int> seasons) {
  if (seasons.isEmpty) {
    return null;
  }
  if (seasons.length == 1) {
    return seasons.single == 0 ? 'Specials' : 'Season ${seasons.single}';
  }
  final bool run = seasons.first >= 1 &&
      seasons.last - seasons.first == seasons.length - 1;
  return run
      ? 'Seasons ${seasons.first}-${seasons.last}'
      : '${seasons.length} seasons';
}

/// What a TV request asks for and how much of it is in, or null when Ombi
/// listed no episodes for it.
///
/// How many are in is only said while it is some and not all: none in is
/// what a request starts as, and all in is what Available already says.
String? ombiEpisodesLine(OmbiRequest request) {
  final int total = request.episodes;
  if (total == 0) {
    return null;
  }
  final int available = request.episodesAvailable;
  final String episodes = (available > 0 && available < total)
      ? '$available of $total episodes available'
      : (total == 1 ? '1 episode' : '$total episodes');
  final String? seasons = ombiSeasonsLabel(request.seasons);
  return seasons == null ? episodes : '$seasons · $episodes';
}

/// A runtime in minutes as hours and minutes.
String ombiRuntime(int minutes) {
  final int hours = minutes ~/ 60;
  final int rest = minutes % 60;
  if (hours == 0) {
    return '${rest}m';
  }
  return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
}

/// The short facts under a title: what it is, when, how long, who airs it
/// and where it is in its release. Only what is known is included.
List<String> ombiTitleFacts({
  required OmbiMediaKind kind,
  int? year,
  int? runtimeMinutes,
  String? network,
  String? releaseStatus,
}) =>
    <String>[
      switch (kind) {
        OmbiMediaKind.movie => 'Movie',
        OmbiMediaKind.tv => 'TV show',
        OmbiMediaKind.music => 'Album',
      },
      if (year != null) '$year',
      if (runtimeMinutes != null) ombiRuntime(runtimeMinutes),
      if (network != null) network,
      if (releaseStatus != null) releaseStatus,
    ];
