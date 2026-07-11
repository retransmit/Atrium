class JellyfinRemoteSearchResult {
  const JellyfinRemoteSearchResult({
    this.Name,
    this.ProviderIds,
    this.ProductionYear,
    this.IndexNumber,
    this.IndexNumberEnd,
    this.ParentIndexNumber,
    this.PremiereDate,
    this.ImageUrl,
    this.SearchProviderName,
    this.Overview,
  });

  final String? Name;
  final Map<String, dynamic>? ProviderIds;
  final int? ProductionYear;
  final int? IndexNumber;
  final int? IndexNumberEnd;
  final int? ParentIndexNumber;
  final String? PremiereDate;
  final String? ImageUrl;
  final String? SearchProviderName;
  final String? Overview;

  factory JellyfinRemoteSearchResult.fromJson(Map<String, dynamic> json) {
    return JellyfinRemoteSearchResult(
      Name: json['Name'] as String?,
      ProviderIds: json['ProviderIds'] as Map<String, dynamic>?,
      ProductionYear: json['ProductionYear'] as int?,
      IndexNumber: json['IndexNumber'] as int?,
      IndexNumberEnd: json['IndexNumberEnd'] as int?,
      ParentIndexNumber: json['ParentIndexNumber'] as int?,
      PremiereDate: json['PremiereDate'] as String?,
      ImageUrl: json['ImageUrl'] as String?,
      SearchProviderName: json['SearchProviderName'] as String?,
      Overview: json['Overview'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (Name != null) 'Name': Name,
      if (ProviderIds != null) 'ProviderIds': ProviderIds,
      if (ProductionYear != null) 'ProductionYear': ProductionYear,
      if (IndexNumber != null) 'IndexNumber': IndexNumber,
      if (IndexNumberEnd != null) 'IndexNumberEnd': IndexNumberEnd,
      if (ParentIndexNumber != null) 'ParentIndexNumber': ParentIndexNumber,
      if (PremiereDate != null) 'PremiereDate': PremiereDate,
      if (ImageUrl != null) 'ImageUrl': ImageUrl,
      if (SearchProviderName != null) 'SearchProviderName': SearchProviderName,
      if (Overview != null) 'Overview': Overview,
    };
  }
}

class JellyfinRemoteSearchQuery {
  const JellyfinRemoteSearchQuery({
    required this.SearchInfo,
    required this.ItemId,
  });

  final JellyfinRemoteSearchInfo SearchInfo;
  final String ItemId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'SearchInfo': SearchInfo.toJson(),
      'ItemId': ItemId,
    };
  }
}

class JellyfinRemoteSearchInfo {
  const JellyfinRemoteSearchInfo({
    required this.Name,
    this.Year,
    this.ProviderIds,
    this.IndexNumber,
    this.ParentIndexNumber,
  });

  final String Name;
  final int? Year;
  final Map<String, dynamic>? ProviderIds;
  final int? IndexNumber;
  final int? ParentIndexNumber;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'Name': Name,
      if (Year != null) 'Year': Year,
      if (ProviderIds != null) 'ProviderIds': ProviderIds,
      if (IndexNumber != null) 'IndexNumber': IndexNumber,
      if (ParentIndexNumber != null) 'ParentIndexNumber': ParentIndexNumber,
    };
  }
}
