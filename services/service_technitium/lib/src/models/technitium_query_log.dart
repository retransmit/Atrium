import 'technitium_json.dart';

/// Single DNS query log record from `/api/logs/query`.
class TechnitiumQueryEntry {
  const TechnitiumQueryEntry({
    required this.qname,
    required this.qtype,
    required this.clientIp,
    required this.responseType,
    required this.rcode,
    required this.protocol,
    required this.roundTripTimeMs,
    required this.answer,
    this.timestamp,
    this.clientName,
  });

  factory TechnitiumQueryEntry.fromJson(Map<String, dynamic> json) {
    final String qname = readString(
      json['qname'] ?? json['question'] ?? json['domain'] ?? json['query'],
    );
    final String qtype = readString(json['qtype'] ?? json['type'] ?? 'A');
    final String client = readString(
      json['clientIpAddress'] ?? json['clientIp'] ?? json['client'] ?? '',
    );
    final String respType = readString(
      json['responseType'] ?? json['status'] ?? 'Processed',
    );
    final String rcode = readString(json['rcode'] ?? 'NoError');
    final String protocol = readString(json['protocol'] ?? 'UDP');
    final double rtt = readDouble(json['roundTripTime'] ?? json['rtt'] ?? 0);
    final String answer = readString(json['answer'] ?? json['answers'] ?? '');
    final DateTime? ts = parseTechnitiumDate(json['timestamp'] ?? json['time']);
    final String? cName = json['clientName'] is String &&
            (json['clientName'] as String).isNotEmpty
        ? json['clientName'] as String
        : (json['clientDomain'] is String
            ? json['clientDomain'] as String
            : null);

    return TechnitiumQueryEntry(
      qname: qname,
      qtype: qtype,
      clientIp: client,
      responseType: respType,
      rcode: rcode,
      protocol: protocol,
      roundTripTimeMs: rtt,
      answer: answer,
      timestamp: ts,
      clientName: cName,
    );
  }

  final String qname;
  final String qtype;
  final String clientIp;
  final String responseType;
  final String rcode;
  final String protocol;
  final double roundTripTimeMs;
  final String answer;
  final DateTime? timestamp;
  final String? clientName;

  bool get isBlocked =>
      responseType.toLowerCase().contains('block') ||
      responseType.toLowerCase().contains('drop');
}

/// Paginated query log page.
class TechnitiumQueryLogPage {
  const TechnitiumQueryLogPage({
    required this.entries,
    this.pageNumber = 1,
    this.totalPages = 1,
    this.totalEntries = 0,
  });

  factory TechnitiumQueryLogPage.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> response =
        json['response'] is Map<String, dynamic>
            ? json['response'] as Map<String, dynamic>
            : json;

    final Object? rawEntries =
        response['entries'] ?? response['logs'] ?? response['queries'];
    final List<TechnitiumQueryEntry> list = <TechnitiumQueryEntry>[];

    if (rawEntries is List) {
      for (final Object? item in rawEntries) {
        if (item is Map<String, dynamic>) {
          list.add(TechnitiumQueryEntry.fromJson(item));
        } else if (item is Map) {
          list.add(TechnitiumQueryEntry.fromJson(item.cast<String, dynamic>()));
        }
      }
    } else if (json['response'] is List) {
      for (final Object? item in json['response'] as List) {
        if (item is Map<String, dynamic>) {
          list.add(TechnitiumQueryEntry.fromJson(item));
        } else if (item is Map) {
          list.add(TechnitiumQueryEntry.fromJson(item.cast<String, dynamic>()));
        }
      }
    }

    return TechnitiumQueryLogPage(
      entries: list,
      pageNumber: readInt(response['pageNumber'] ?? 1),
      totalPages: readInt(response['totalPages'] ?? 1),
      totalEntries: readInt(response['totalEntries'] ?? list.length),
    );
  }

  final List<TechnitiumQueryEntry> entries;
  final int pageNumber;
  final int totalPages;
  final int totalEntries;
}
