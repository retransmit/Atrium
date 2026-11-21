/// One of Prowlarr's standard Newznab categories, from
/// `GET /api/v1/indexer/categories`: a parent such as Movies (2000) with its
/// subcategories such as Movies/HD (2040).
class ProwlarrCategory {
  const ProwlarrCategory({
    required this.id,
    required this.name,
    this.subCategories = const <ProwlarrCategory>[],
  });

  factory ProwlarrCategory.fromJson(Map<String, dynamic> json) =>
      ProwlarrCategory(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: (json['name'] as String?) ?? '',
        subCategories: <ProwlarrCategory>[
          for (final Object? e
              in (json['subCategories'] as List<dynamic>?) ?? <dynamic>[])
            if (e is Map<String, dynamic>) ProwlarrCategory.fromJson(e),
        ],
      );

  final int id;
  final String name;
  final List<ProwlarrCategory> subCategories;

  /// The name without its parent's prefix: "HD" for "Movies/HD".
  String get shortName {
    final int slash = name.indexOf('/');
    return slash < 0 ? name : name.substring(slash + 1);
  }
}
