import 'technitium_json.dart';

/// An entry in a top-N list (top clients, top domains, top blocked).
class TechnitiumTopItem {
  const TechnitiumTopItem({
    required this.name,
    required this.hits,
    this.domain,
  });

  factory TechnitiumTopItem.fromJson(Map<String, dynamic> json) {
    return TechnitiumTopItem(
      name: readString(json['name'] ?? json['client'] ?? json['domain']),
      hits: readInt(json['hits'] ?? json['count'] ?? json['queries']),
      domain: json['domain'] is String ? json['domain'] as String : null,
    );
  }

  final String name;
  final int hits;
  final String? domain;
}

/// Statistics returned by `/api/dashboard/stats/get`.
class TechnitiumStats {
  const TechnitiumStats({
    this.totalQueries = 0,
    this.blockedQueries = 0,
    this.cachedQueries = 0,
    this.clientsCount = 0,
    this.forwardedQueries = 0,
    this.authoritativeQueries = 0,
    this.recursiveQueries = 0,
    this.queriesSeries = const <int>[],
    this.blockedSeries = const <int>[],
    this.cachedSeries = const <int>[],
    this.chartLabels = const <String>[],
    this.topClients = const <TechnitiumTopItem>[],
    this.topDomains = const <TechnitiumTopItem>[],
    this.topBlockedDomains = const <TechnitiumTopItem>[],
  });

  factory TechnitiumStats.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> response =
        json['response'] is Map<String, dynamic>
            ? json['response'] as Map<String, dynamic>
            : json;

    final Map<String, dynamic> stats = response['stats'] is Map<String, dynamic>
        ? response['stats'] as Map<String, dynamic>
        : response;

    final Map<String, dynamic> chartData =
        response['mainChartData'] is Map<String, dynamic>
            ? response['mainChartData'] as Map<String, dynamic>
            : (response['chartData'] is Map<String, dynamic>
                ? response['chartData'] as Map<String, dynamic>
                : <String, dynamic>{});

    final List<TechnitiumTopItem> clients =
        parseTopList(response['topClients']);
    final List<TechnitiumTopItem> domains =
        parseTopList(response['topDomains']);
    final List<TechnitiumTopItem> blocked = parseTopList(
      response['topBlockedDomains'] ?? response['topBlocked'],
    );

    final int totalQ = readInt(stats['totalQueries'] ?? stats['queries']);
    final int blockedQ = readInt(
      stats['totalBlocked'] ?? stats['blockedQueries'] ?? stats['blocked'],
    );
    final int cachedQ = readInt(
      stats['totalCached'] ?? stats['cachedQueries'] ?? stats['cached'],
    );
    final int clientsC = readInt(
      stats['totalClients'] ?? stats['clientsCount'] ?? clients.length,
    );

    final List<int> directQueries = readInts(
      chartData['totalQueries'] ?? chartData['queries'],
    );
    final List<int> directBlocked = readInts(
      chartData['blockedQueries'] ?? chartData['blocked'],
    );
    final List<int> directCached = readInts(
      chartData['cachedQueries'] ?? chartData['cached'],
    );

    List<int> seriesQueries = directQueries;
    List<int> seriesBlocked = directBlocked;
    List<int> seriesCached = directCached;

    final Object? rawDatasets = chartData['datasets'];
    if (rawDatasets is List) {
      for (final Object? ds in rawDatasets) {
        if (ds is! Map) continue;
        final String label =
            readString(ds['label'] ?? ds['name']).toLowerCase();
        final List<int> values = readInts(ds['data']);
        if (values.isEmpty) continue;
        if (label.contains('block') && seriesBlocked.isEmpty) {
          seriesBlocked = values;
        } else if (label.contains('cach') && seriesCached.isEmpty) {
          seriesCached = values;
        } else if ((label == 'total' || label.contains('quer')) &&
            seriesQueries.isEmpty) {
          seriesQueries = values;
        }
      }
    }

    return TechnitiumStats(
      totalQueries: totalQ,
      blockedQueries: blockedQ,
      cachedQueries: cachedQ,
      clientsCount: clientsC,
      forwardedQueries:
          readInt(stats['forwardedQueries'] ?? stats['forwarded']),
      authoritativeQueries: readInt(
        stats['totalAuthoritative'] ??
            stats['authoritativeQueries'] ??
            stats['authoritative'],
      ),
      recursiveQueries: readInt(
        stats['totalRecursive'] ??
            stats['recursiveQueries'] ??
            stats['recursive'],
      ),
      queriesSeries: seriesQueries,
      blockedSeries: seriesBlocked,
      cachedSeries: seriesCached,
      chartLabels: readStrings(chartData['labels']),
      topClients: clients,
      topDomains: domains,
      topBlockedDomains: blocked,
    );
  }

  final int totalQueries;
  final int blockedQueries;
  final int cachedQueries;
  final int clientsCount;
  final int forwardedQueries;
  final int authoritativeQueries;
  final int recursiveQueries;
  final List<int> queriesSeries;
  final List<int> blockedSeries;
  final List<int> cachedSeries;
  final List<String> chartLabels;
  final List<TechnitiumTopItem> topClients;
  final List<TechnitiumTopItem> topDomains;
  final List<TechnitiumTopItem> topBlockedDomains;

  double get blockedPercent =>
      totalQueries == 0 ? 0.0 : (blockedQueries / totalQueries * 100);

  double get cachedPercent =>
      totalQueries == 0 ? 0.0 : (cachedQueries / totalQueries * 100);

  static List<TechnitiumTopItem> parseTopList(Object? list) {
    if (list is! List) return const <TechnitiumTopItem>[];
    return <TechnitiumTopItem>[
      for (final Object? item in list)
        if (item is Map<String, dynamic>)
          TechnitiumTopItem.fromJson(item)
        else if (item is Map)
          TechnitiumTopItem.fromJson(item.cast<String, dynamic>()),
    ];
  }
}
