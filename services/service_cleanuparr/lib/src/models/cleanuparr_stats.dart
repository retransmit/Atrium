/// Aggregated telemetry and operational metrics for a given timeframe.
class CleanuparrStats {
  const CleanuparrStats({
    required this.hours,
    this.totalEvents = 0,
    this.eventsWarning = 0,
    this.eventsError = 0,
    this.strikesIssued = 0,
    this.strikesRecovered = 0,
    this.activeStrikes = 0,
    this.malwareBlocked = 0,
    this.totalRemovals = 0,
    this.totalCleaned = 0,
    this.seekerTriggers = 0,
    this.seekerGrabbed = 0,
    this.strikesByType = const <String, int>{},
  });

  final int hours;
  final int totalEvents;
  final int eventsWarning;
  final int eventsError;
  final int strikesIssued;
  final int strikesRecovered;
  final int activeStrikes;
  final int malwareBlocked;
  final int totalRemovals;
  final int totalCleaned;
  final int seekerTriggers;
  final int seekerGrabbed;
  final Map<String, int> strikesByType;

  CleanuparrStats copyWith({
    int? hours,
    int? totalEvents,
    int? eventsWarning,
    int? eventsError,
    int? strikesIssued,
    int? strikesRecovered,
    int? activeStrikes,
    int? malwareBlocked,
    int? totalRemovals,
    int? totalCleaned,
    int? seekerTriggers,
    int? seekerGrabbed,
    Map<String, int>? strikesByType,
  }) {
    return CleanuparrStats(
      hours: hours ?? this.hours,
      totalEvents: totalEvents ?? this.totalEvents,
      eventsWarning: eventsWarning ?? this.eventsWarning,
      eventsError: eventsError ?? this.eventsError,
      strikesIssued: strikesIssued ?? this.strikesIssued,
      strikesRecovered: strikesRecovered ?? this.strikesRecovered,
      activeStrikes: activeStrikes ?? this.activeStrikes,
      malwareBlocked: malwareBlocked ?? this.malwareBlocked,
      totalRemovals: totalRemovals ?? this.totalRemovals,
      totalCleaned: totalCleaned ?? this.totalCleaned,
      seekerTriggers: seekerTriggers ?? this.seekerTriggers,
      seekerGrabbed: seekerGrabbed ?? this.seekerGrabbed,
      strikesByType: strikesByType ?? this.strikesByType,
    );
  }

  factory CleanuparrStats.fromJson(Map<String, dynamic> json, {int hours = 168}) {
    final Map<String, dynamic>? events =
        json['events'] is Map<String, dynamic>
            ? json['events'] as Map<String, dynamic>
            : null;
    final Map<String, dynamic>? strikes =
        json['strikes'] is Map<String, dynamic>
            ? json['strikes'] as Map<String, dynamic>
            : null;
    final Map<String, dynamic>? removals =
        json['removals'] is Map<String, dynamic>
            ? json['removals'] as Map<String, dynamic>
            : null;
    final Map<String, dynamic>? cleaned =
        json['cleaned'] is Map<String, dynamic>
            ? json['cleaned'] as Map<String, dynamic>
            : null;
    final Map<String, dynamic>? searches =
        json['searches'] is Map<String, dynamic>
            ? json['searches'] as Map<String, dynamic>
            : null;

    final int totalEv = _asInt(events?['total'] ?? json['totalEvents']);
    final int evWarn = _asInt(events?['warning'] ?? events?['warn'] ?? json['eventsWarning']);
    final int evErr = _asInt(events?['error'] ?? events?['critical'] ?? json['eventsError']);

    final int strIssued = _asInt(strikes?['total'] ?? strikes?['totalIssued'] ?? strikes?['issued'] ?? json['strikesIssued']);
    final int strRec = _asInt(strikes?['recovered'] ?? strikes?['totalRecovered'] ?? json['strikesRecovered']);

    // Only parse an explicitly provided active-strike value. The real backend
    // StatsV2Response never sends one, so this stays 0 there; the exact live
    // count is sourced from GET /api/strikes (CleanuparrApi.getActiveStrikesCount),
    // which counts the ledger items not yet removed. Deriving active as
    // (issued - recovered) was removed: strikes that ended in deletion rather
    // than recovery are not "recovered", so the derivation overcounted and
    // contradicted the empty-ledger "All queues clean" state.
    final int strActive = _asInt(strikes?['active'] ?? strikes?['current'] ?? json['activeStrikes']);

    // Malware blocked: sum of AllFilesBlocked + AtLeastOneFileBlocked inside removals.byReason
    int malware = 0;
    final dynamic byReason = removals?['byReason'];
    if (byReason is Map) {
      for (final MapEntry<dynamic, dynamic> entry in byReason.entries) {
        final String key = entry.key.toString().toLowerCase();
        if (key == 'allfilesblocked' || key == 'atleastonefileblocked') {
          malware += _asInt(entry.value);
        }
      }
    }
    if (malware == 0) {
      final int allBlocked = _asInt(removals?['allFilesBlocked']);
      final int partBlocked = _asInt(removals?['atLeastOneFileBlocked']);
      malware = (allBlocked + partBlocked > 0)
          ? (allBlocked + partBlocked)
          : _asInt(removals?['malware'] ?? json['malwareBlocked']);
    }

    final int remTotal = _asInt(removals?['total'] ?? json['totalRemovals']);
    final int cleanTotal = _asInt(cleaned?['total'] ?? json['totalCleaned']);
    final int seekTrig = _asInt(searches?['total'] ?? searches?['triggers'] ?? searches?['totalSearches'] ?? json['seekerTriggers']);
    final int seekGrab = _asInt(searches?['grabbed'] ?? searches?['itemsGrabbed'] ?? json['seekerGrabbed']);

    final Map<String, int> byType = <String, int>{};
    final dynamic rawByType = strikes?['byType'] ?? strikes?['types'];
    if (rawByType is Map) {
      for (final MapEntry<dynamic, dynamic> entry in rawByType.entries) {
        byType[entry.key.toString()] = _asInt(entry.value);
      }
    }

    return CleanuparrStats(
      hours: hours,
      totalEvents: totalEv,
      eventsWarning: evWarn,
      eventsError: evErr,
      strikesIssued: strIssued,
      strikesRecovered: strRec,
      activeStrikes: strActive,
      malwareBlocked: malware,
      totalRemovals: remTotal,
      totalCleaned: cleanTotal,
      seekerTriggers: seekTrig,
      seekerGrabbed: seekGrab,
      strikesByType: Map<String, int>.unmodifiable(byType),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value != null) return int.tryParse(value.toString()) ?? 0;
    return 0;
  }
}
