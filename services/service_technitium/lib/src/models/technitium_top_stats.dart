import 'technitium_stats.dart';

/// Top statistics (top clients, top domains, and top blocked domains)
/// returned by `/api/dashboard/stats/get` or `/api/dashboard/stats`.
class TechnitiumTopStats {
  const TechnitiumTopStats({
    this.topClients = const <TechnitiumTopItem>[],
    this.topDomains = const <TechnitiumTopItem>[],
    this.topBlockedDomains = const <TechnitiumTopItem>[],
  });

  factory TechnitiumTopStats.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> response =
        json['response'] is Map<String, dynamic>
            ? json['response'] as Map<String, dynamic>
            : json;

    return TechnitiumTopStats(
      topClients: TechnitiumStats.parseTopList(response['topClients']),
      topDomains: TechnitiumStats.parseTopList(response['topDomains']),
      topBlockedDomains: TechnitiumStats.parseTopList(
        response['topBlockedDomains'] ?? response['topBlocked'],
      ),
    );
  }

  final List<TechnitiumTopItem> topClients;
  final List<TechnitiumTopItem> topDomains;
  final List<TechnitiumTopItem> topBlockedDomains;
}
