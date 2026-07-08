class EmbyRemoteImage {
  const EmbyRemoteImage({
    required this.providerName,
    required this.url,
    required this.thumbnailUrl,
    required this.height,
    required this.width,
    required this.communityRating,
    required this.voteCount,
    required this.language,
    required this.type,
  });

  factory EmbyRemoteImage.fromJson(Map<String, dynamic> json) {
    return EmbyRemoteImage(
      providerName: json['ProviderName'] as String?,
      url: json['Url'] as String?,
      thumbnailUrl: json['ThumbnailUrl'] as String?,
      height: json['Height'] as int?,
      width: json['Width'] as int?,
      communityRating: (json['CommunityRating'] as num?)?.toDouble(),
      voteCount: json['VoteCount'] as int?,
      language: json['Language'] as String?,
      type: json['Type'] as String?,
    );
  }

  final String? providerName;
  final String? url;
  final String? thumbnailUrl;
  final int? height;
  final int? width;
  final double? communityRating;
  final int? voteCount;
  final String? language;
  final String? type;
}

class EmbyRemoteImagesResult {
  const EmbyRemoteImagesResult({
    required this.images,
    required this.totalRecordCount,
    required this.providers,
  });

  factory EmbyRemoteImagesResult.fromJson(Map<String, dynamic> json) {
    final List<dynamic>? imagesList = json['Images'] as List<dynamic>?;
    final List<dynamic>? providersList = json['Providers'] as List<dynamic>?;

    return EmbyRemoteImagesResult(
      images: imagesList
              ?.map(
                (dynamic e) =>
                    EmbyRemoteImage.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          <EmbyRemoteImage>[],
      totalRecordCount: json['TotalRecordCount'] as int? ?? 0,
      providers:
          providersList?.map((dynamic e) => e as String).toList() ?? <String>[],
    );
  }

  final List<EmbyRemoteImage> images;
  final int totalRecordCount;
  final List<String> providers;
}
