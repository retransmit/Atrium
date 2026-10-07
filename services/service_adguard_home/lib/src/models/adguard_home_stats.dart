import 'adguard_home_json.dart';

/// One row of a "top" list: a name and how much of something it has.
class AdguardHomeCount {
  const AdguardHomeCount(this.name, this.value);

  final String name;

  /// A count for most lists. Seconds for the upstream response times.
  final num value;
}

/// What `GET control/stats` says: the totals for the period the server
/// keeps, a series for four of them, and the top lists.
class AdguardHomeStats {
  const AdguardHomeStats({
    this.byDay = false,
    this.queries = 0,
    this.blockedByFilters = 0,
    this.blockedThreats = 0,
    this.blockedAdult = 0,
    this.safeSearchEnforced = 0,
    this.averageProcessingTime = Duration.zero,
    this.queriesSeries = const <int>[],
    this.blockedSeries = const <int>[],
    this.threatsSeries = const <int>[],
    this.adultSeries = const <int>[],
    this.topQueriedDomains = const <AdguardHomeCount>[],
    this.topBlockedDomains = const <AdguardHomeCount>[],
    this.topClients = const <AdguardHomeCount>[],
    this.topUpstreams = const <AdguardHomeCount>[],
    this.topUpstreamTimes = const <AdguardHomeCount>[],
  });

  factory AdguardHomeStats.fromJson(Map<String, dynamic> json) {
    return AdguardHomeStats(
      byDay: json['time_units'] == 'days',
      queries: readInt(json['num_dns_queries']),
      blockedByFilters: readInt(json['num_blocked_filtering']),
      blockedThreats: readInt(json['num_replaced_safebrowsing']),
      blockedAdult: readInt(json['num_replaced_parental']),
      safeSearchEnforced: readInt(json['num_replaced_safesearch']),
      // Seconds, as a fraction.
      averageProcessingTime: Duration(
        microseconds:
            (readDouble(json['avg_processing_time']) * 1000000).round(),
      ),
      queriesSeries: readInts(json['dns_queries']),
      blockedSeries: readInts(json['blocked_filtering']),
      threatsSeries: readInts(json['replaced_safebrowsing']),
      adultSeries: readInts(json['replaced_parental']),
      topQueriedDomains: _counts(json['top_queried_domains']),
      topBlockedDomains: _counts(json['top_blocked_domains']),
      topClients: _counts(json['top_clients']),
      topUpstreams: _counts(json['top_upstreams_responses']),
      topUpstreamTimes: _counts(json['top_upstreams_avg_time']),
    );
  }

  /// Whether each point of a series is a day rather than an hour.
  final bool byDay;
  final int queries;
  final int blockedByFilters;

  /// Blocked by safe browsing: malware and phishing.
  final int blockedThreats;

  /// Blocked by parental control.
  final int blockedAdult;
  final int safeSearchEnforced;
  final Duration averageProcessingTime;
  final List<int> queriesSeries;
  final List<int> blockedSeries;
  final List<int> threatsSeries;
  final List<int> adultSeries;
  final List<AdguardHomeCount> topQueriedDomains;
  final List<AdguardHomeCount> topBlockedDomains;
  final List<AdguardHomeCount> topClients;

  /// Upstream servers by how many responses each gave.
  final List<AdguardHomeCount> topUpstreams;

  /// Upstream servers by average response time, in seconds.
  final List<AdguardHomeCount> topUpstreamTimes;

  /// Blocked by filters as a share of all queries, from 0 to 100. Zero when
  /// nothing has been asked yet.
  double get blockedPercent =>
      queries == 0 ? 0 : blockedByFilters / queries * 100;
}

/// A top list arrives as a list of objects with one entry each,
/// `[{"example.com": 12}, {"example.org": 3}]`, in the server's order.
List<AdguardHomeCount> _counts(Object? value) {
  if (value is! List) return const <AdguardHomeCount>[];
  return <AdguardHomeCount>[
    for (final Object? row in value)
      if (row is Map<Object?, Object?>)
        for (final MapEntry<Object?, Object?> entry in row.entries)
          if (entry.key case final String name)
            if (entry.value case final num amount)
              AdguardHomeCount(name, amount),
  ];
}
