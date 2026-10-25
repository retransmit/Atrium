/// A download item currently holding strikes in Cleanuparr.
class CleanuparrStrikeItem {
  const CleanuparrStrikeItem({
    required this.id,
    required this.title,
    this.hash,
    this.strikeCount = 1,
    this.isMarkedForRemoval = false,
    this.isRemoved = false,
    this.hasDryRunStrikes = false,
    this.strikes = const <CleanuparrStrikeDetail>[],
  });

  /// The Guid identifier for the download item in Cleanuparr.
  final String id;

  /// Human-readable title of the release or torrent.
  final String title;

  /// The torrent info-hash or download client identifier (wire key: downloadId).
  final String? hash;

  /// Total strikes accumulated (wire key: totalStrikes).
  final int strikeCount;

  /// Whether the item has met the strike threshold and is marked for deletion.
  final bool isMarkedForRemoval;

  /// Whether the item has already been removed by Cleanuparr.
  final bool isRemoved;

  /// Whether this item has dry-run strikes.
  final bool hasDryRunStrikes;

  /// Details of individual strikes recorded against this item.
  final List<CleanuparrStrikeDetail> strikes;

  factory CleanuparrStrikeItem.fromJson(Map<String, dynamic> json) {
    final String id = json['downloadItemId']?.toString() ??
        json['id']?.toString() ??
        json['hash']?.toString() ??
        '';
    final String title = json['title']?.toString() ??
        json['name']?.toString() ??
        'Unknown Item';
    final String? h = json['downloadId']?.toString() ??
        json['hash']?.toString() ??
        json['infoHash']?.toString();
    final int count = _asInt(
      json['totalStrikes'] ??
          json['strikeCount'] ??
          json['strikesCount'] ??
          1,
    );
    final bool marked = json['isMarkedForRemoval'] as bool? ?? false;
    final bool removed = json['isRemoved'] as bool? ?? false;
    final bool dryRun = json['hasDryRunStrikes'] as bool? ?? false;

    final List<CleanuparrStrikeDetail> details = <CleanuparrStrikeDetail>[];
    final dynamic rawDetails = json['strikes'] ?? json['strikeDetails'];
    if (rawDetails is List) {
      for (final dynamic d in rawDetails) {
        if (d is Map<String, dynamic>) {
          details.add(CleanuparrStrikeDetail.fromJson(d));
        }
      }
    }

    return CleanuparrStrikeItem(
      id: id,
      title: title,
      hash: h,
      strikeCount: count > 0 ? count : (details.isNotEmpty ? details.length : 1),
      isMarkedForRemoval: marked,
      isRemoved: removed,
      hasDryRunStrikes: dryRun,
      strikes: List<CleanuparrStrikeDetail>.unmodifiable(details),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value != null) return int.tryParse(value.toString()) ?? 0;
    return 0;
  }
}

class CleanuparrStrikeDetail {
  const CleanuparrStrikeDetail({
    required this.type,
    this.reason,
    this.createdAt,
    this.isDryRun = false,
  });

  final String type;
  final String? reason;
  final DateTime? createdAt;
  final bool isDryRun;

  factory CleanuparrStrikeDetail.fromJson(Map<String, dynamic> json) {
    DateTime? created;
    final dynamic rawDate = json['createdAt'] ?? json['timestamp'];
    if (rawDate != null) {
      created = DateTime.tryParse(rawDate.toString());
    }

    return CleanuparrStrikeDetail(
      type: json['type']?.toString() ?? 'Strike',
      reason: json['reason']?.toString() ?? json['message']?.toString(),
      createdAt: created,
      isDryRun: json['isDryRun'] as bool? ?? false,
    );
  }
}
