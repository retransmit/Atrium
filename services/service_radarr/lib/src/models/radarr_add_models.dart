/// Lightweight views over raw JSON used by the add-movie flow.
///
/// Deliberately NOT freezed: Radarr's add POST must receive the complete
/// lookup object back (our typed models are trimmed projections), so we keep
/// the raw map and expose only the fields the UI renders.
class RadarrLookupResult {
  RadarrLookupResult(this.raw);

  final Map<String, dynamic> raw;

  String get title => (raw['title'] as String?) ?? '';
  int? get year => raw['year'] as int?;
  String? get overview => raw['overview'] as String?;

  /// Poster on the metadata provider's CDN; present for most results and
  /// needs no auth.
  String? get remotePoster => raw['remotePoster'] as String?;
  String? get studio => raw['studio'] as String?;
  int get tmdbId => ((raw['tmdbId'] as num?) ?? 0).toInt();
  int get runtime => ((raw['runtime'] as num?) ?? 0).toInt();

  /// Lookup returns library members with their real id; new items have 0.
  bool get inLibrary => ((raw['id'] as num?) ?? 0) > 0;
}

/// A Radarr quality profile (id + display name).
class RadarrQualityProfile {
  const RadarrQualityProfile({required this.id, required this.name});

  factory RadarrQualityProfile.fromJson(Map<String, dynamic> json) =>
      RadarrQualityProfile(
        id: (json['id'] as num).toInt(),
        name: (json['name'] as String?) ?? 'Profile ${json['id']}',
      );

  final int id;
  final String name;
}

/// A Radarr root folder (path + free space).
class RadarrRootFolder {
  const RadarrRootFolder({required this.path, required this.freeSpace});

  factory RadarrRootFolder.fromJson(Map<String, dynamic> json) =>
      RadarrRootFolder(
        path: (json['path'] as String?) ?? '',
        freeSpace: ((json['freeSpace'] as num?) ?? 0).toInt(),
      );

  final String path;
  final int freeSpace;
}
