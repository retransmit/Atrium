import 'technitium_json.dart';

/// Server settings from `/api/settings/get`.
class TechnitiumSettings {
  const TechnitiumSettings({
    this.enableBlocking = true,
    this.blockingType = 'NxDomain',
    this.blockListUpdateIntervalHours = 24,
    this.blockLists = const <String>[],
    this.dnsServerDomain = '',
    this.temporaryDisableBlockingTill,
    this.allowTxtBlockingReport = false,
  });

  factory TechnitiumSettings.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> response =
        json['response'] is Map<String, dynamic>
            ? json['response'] as Map<String, dynamic>
            : json;

    final Object? rawBlockLists =
        response['blockLists'] ?? response['blockListUrls'];
    final List<String> urls = <String>[];
    if (rawBlockLists is List) {
      for (final Object? item in rawBlockLists) {
        if (item is String) {
          urls.add(item);
        } else if (item is Map && item['url'] is String) {
          urls.add(item['url'] as String);
        }
      }
    }

    return TechnitiumSettings(
      enableBlocking: response.containsKey('enableBlocking')
          ? readBool(response['enableBlocking'])
          : true,
      blockingType: readString(response['blockingType'] ?? 'NxDomain'),
      blockListUpdateIntervalHours: readInt(
        response['blockListUpdateIntervalHours'] ?? 24,
      ),
      blockLists: urls,
      dnsServerDomain: readString(
        response['dnsServerDomain'] ?? response['serverDomain'] ?? '',
      ),
      temporaryDisableBlockingTill: parseTechnitiumDate(
        response['temporaryDisableBlockingTill'],
      ),
      allowTxtBlockingReport: readBool(response['allowTxtBlockingReport']),
    );
  }

  final bool enableBlocking;
  final String blockingType;
  final int blockListUpdateIntervalHours;
  final List<String> blockLists;
  final String dnsServerDomain;
  final DateTime? temporaryDisableBlockingTill;
  final bool allowTxtBlockingReport;
}
