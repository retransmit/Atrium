import 'adguard_home_format.dart';
import 'models/adguard_home_stats.dart';

/// The "top" lists of the statistics.
enum AdguardHomeTopListKind {
  clients('Top clients'),
  queriedDomains('Top queried domains'),
  blockedDomains('Top blocked domains'),
  upstreams('Top upstreams'),
  upstreamTimes('Average upstream response time');

  const AdguardHomeTopListKind(this.title);

  final String title;

  /// This list's rows in [stats], largest first.
  List<AdguardHomeCount> rows(AdguardHomeStats stats) => switch (this) {
        AdguardHomeTopListKind.clients => stats.topClients,
        AdguardHomeTopListKind.queriedDomains => stats.topQueriedDomains,
        AdguardHomeTopListKind.blockedDomains => stats.topBlockedDomains,
        AdguardHomeTopListKind.upstreams => stats.topUpstreams,
        AdguardHomeTopListKind.upstreamTimes => stats.topUpstreamTimes,
      };

  /// How a row's figure is written. Response times arrive in seconds.
  String format(num value) => switch (this) {
        AdguardHomeTopListKind.upstreamTimes => '${(value * 1000).round()} ms',
        _ => formatAdguardHomeCount(value),
      };

  /// Whether rows can be added up. Counts can, averages cannot.
  bool get addsUp => this != AdguardHomeTopListKind.upstreamTimes;

  /// What the button on a row does to its domain: true blocks it, false
  /// unblocks it. Null for the lists whose rows are not domains.
  bool? get blocks => switch (this) {
        AdguardHomeTopListKind.queriedDomains => true,
        AdguardHomeTopListKind.blockedDomains => false,
        _ => null,
      };
}
