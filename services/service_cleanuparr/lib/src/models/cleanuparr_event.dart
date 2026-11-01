/// An audit or operational event recorded by Cleanuparr.
class CleanuparrEvent {
  const CleanuparrEvent({
    required this.id,
    required this.timestamp,
    required this.eventType,
    required this.severity,
    required this.message,
    this.downloadItemTitle,
    this.downloadClientName,
    this.hash,
    this.deleteReason,
  });

  final String id;
  final DateTime timestamp;
  final String eventType;
  final String severity;
  final String message;
  final String? downloadItemTitle;
  final String? downloadClientName;
  final String? hash;
  final String? deleteReason;

  bool get isMalware {
    final String reason = (deleteReason ?? '').toLowerCase();
    final String ev = eventType.toLowerCase();
    return reason.contains('blocked') ||
        reason.contains('malware') ||
        ev.contains('malware');
  }

  /// Strike event types are exact enum members from the backend
  /// (e.g. StalledStrike, FailedImportStrike, DeadTorrentStrike).
  bool get isStrike => eventType.toLowerCase().endsWith('strike');

  /// Exact backend enum members that record a cleaned download
  /// (DownloadCleaned). Never overlaps with [isDeletion].
  bool get isCleaned => eventType.toLowerCase() == 'downloadcleaned';

  /// Deletion event types from the backend EventType enum. Deliberately
  /// excludes cleaning events so the "Deletions" chip stays pure.
  bool get isDeletion =>
      !isCleaned &&
      const <String>['queueitemdeleted', 'downloadmarkedfordeletion']
          .contains(eventType.toLowerCase());

  /// Whether this event represents any removal at all (deletion or cleanup).
  /// Kept for card iconography and generic coloring.
  bool get isRemoval => isDeletion || isCleaned;

  factory CleanuparrEvent.fromJson(Map<String, dynamic> json) {
    DateTime ts = DateTime.now();
    final dynamic rawTs = json['timestamp'] ?? json['createdAt'] ?? json['time'];
    if (rawTs != null) {
      ts = DateTime.tryParse(rawTs.toString()) ?? ts;
    }

    return CleanuparrEvent(
      id: json['id']?.toString() ?? '${ts.millisecondsSinceEpoch}',
      timestamp: ts,
      eventType: json['eventType']?.toString() ??
          json['type']?.toString() ??
          'Event',
      severity: json['severity']?.toString() ??
          (json['level']?.toString() ?? 'Info'),
      message: json['message']?.toString() ??
          (json['description']?.toString() ?? 'Operation completed'),
      downloadItemTitle: json['itemTitle']?.toString() ??
          json['downloadItemTitle']?.toString() ??
          json['title']?.toString() ??
          json['itemName']?.toString(),
      downloadClientName: json['downloadClientName']?.toString() ??
          json['client']?.toString(),
      hash: json['itemHash']?.toString() ??
          json['hash']?.toString() ??
          json['infoHash']?.toString(),
      deleteReason: json['deleteReason']?.toString() ??
          json['cleanReason']?.toString() ??
          json['reason']?.toString(),
    );
  }
}
