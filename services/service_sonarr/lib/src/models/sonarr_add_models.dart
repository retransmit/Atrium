/// Lightweight views over raw JSON used by the add-series flow.
///
/// Deliberately NOT freezed: Sonarr's add POST must receive the complete
/// lookup object back (our typed models are trimmed projections), so we keep
/// the raw map and expose only the fields the UI renders.
class SonarrLookupResult {
  SonarrLookupResult(this.raw);

  final Map<String, dynamic> raw;

  String get title => (raw['title'] as String?) ?? '';
  int? get year => raw['year'] as int?;
  String? get overview => raw['overview'] as String?;

  /// Poster on the metadata provider's CDN; present for most results and
  /// needs no auth.
  String? get remotePoster => raw['remotePoster'] as String?;
  String? get network => raw['network'] as String?;
  String? get status => raw['status'] as String?;
  int get tvdbId => ((raw['tvdbId'] as num?) ?? 0).toInt();

  /// Seasons excluding specials.
  int get seasonCount => (raw['seasons'] as List<dynamic>? ?? const <dynamic>[])
      .where(
        (dynamic s) =>
            ((s as Map<String, dynamic>)['seasonNumber'] as num? ?? 0) > 0,
      )
      .length;

  /// Lookup returns library members with their real id; new items have 0.
  bool get inLibrary => ((raw['id'] as num?) ?? 0) > 0;
}

/// A Sonarr quality profile (id + display name).
class SonarrQualityProfile {
  const SonarrQualityProfile({required this.id, required this.name});

  factory SonarrQualityProfile.fromJson(Map<String, dynamic> json) =>
      SonarrQualityProfile(
        id: (json['id'] as num).toInt(),
        name: (json['name'] as String?) ?? 'Profile ${json['id']}',
      );

  final int id;
  final String name;
}

/// A Sonarr root folder (path + free space).
class SonarrRootFolder {
  const SonarrRootFolder({required this.path, required this.freeSpace});

  factory SonarrRootFolder.fromJson(Map<String, dynamic> json) =>
      SonarrRootFolder(
        path: (json['path'] as String?) ?? '',
        freeSpace: ((json['freeSpace'] as num?) ?? 0).toInt(),
      );

  final String path;
  final int freeSpace;
}
