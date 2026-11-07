import 'models/qbit_detail.dart';

/// Whether [t] is a real tracker rather than one of qBittorrent's synthetic
/// `** [DHT] **`, `** [PeX] **` and `** [LSD] **` rows.
bool qbitIsRealTracker(QbitTracker t) => !t.url.startsWith('** ');

/// Whether [url] reads as a tracker announce URL.
///
/// HTTP(S) and UDP are BitTorrent's trackers; WS(S) are WebTorrent's, which
/// qBittorrent keeps too.
bool qbitIsTrackerUrl(String url) {
  final Uri? uri = Uri.tryParse(url);
  return uri != null &&
      const <String>{'http', 'https', 'udp', 'ws', 'wss'}
          .contains(uri.scheme.toLowerCase()) &&
      uri.host.isNotEmpty;
}

/// [trackers] as the text the editor starts from: the real trackers, one URL
/// per line, tier by tier, with a blank line between tiers.
String qbitTrackerText(List<QbitTracker> trackers) {
  final Map<int, List<String>> byTier = <int, List<String>>{};
  for (final QbitTracker t in trackers.where(qbitIsRealTracker)) {
    (byTier[t.tier] ??= <String>[]).add(t.url);
  }
  final List<int> tiers = byTier.keys.toList()..sort();
  return tiers.map((int tier) => byTier[tier]!.join('\n')).join('\n\n');
}

/// What saving edited tracker text changes.
class QbitTrackerEdit {
  const QbitTrackerEdit({
    required this.added,
    required this.removed,
    required this.invalid,
    required this.addText,
  });

  /// New URLs, in the order they were written.
  final List<String> added;

  /// URLs the torrent has that the text no longer lists.
  final List<String> removed;

  /// Lines that are not tracker URLs. Nothing is saved while there are any.
  final List<String> invalid;

  /// [added] as `addTrackers` text, each URL placed in its tier.
  final String addText;

  bool get changes => added.isNotEmpty || removed.isNotEmpty;
}

/// Compares [text] with the torrent's [current] trackers.
///
/// Blank lines split the text into groups, and each group is a tier. A group
/// holding an existing tracker stands for that tracker's tier, so a URL added
/// beside it joins it; a group of new URLs alone takes the tier after the
/// group before it. Existing trackers stay in their tiers whichever group
/// they are written in, since only qBittorrent 5.2 and later can move one.
QbitTrackerEdit qbitTrackerEdit(List<QbitTracker> current, String text) {
  final Map<String, int> tierOf = <String, int>{
    for (final QbitTracker t in current.where(qbitIsRealTracker)) t.url: t.tier,
  };

  final List<List<String>> groups = <List<String>>[<String>[]];
  for (final String raw in text.split('\n')) {
    final String line = raw.trim();
    if (line.isEmpty) {
      if (groups.last.isNotEmpty) {
        groups.add(<String>[]);
      }
    } else {
      groups.last.add(line);
    }
  }

  final Set<String> listed = <String>{};
  final List<String> invalid = <String>[];
  final List<String> added = <String>[];
  final Map<int, List<String>> addedByTier = <int, List<String>>{};
  int previousTier = -1;
  for (final List<String> group in groups.where((List<String> g) => g.isNotEmpty)) {
    final Iterable<int> known = group
        .where(tierOf.containsKey)
        .map((String url) => tierOf[url]!);
    final int tier = known.isEmpty
        ? previousTier + 1
        : known.reduce((int a, int b) => a < b ? a : b);
    previousTier = tier;
    for (final String url in group) {
      if (!listed.add(url)) {
        continue;
      }
      if (tierOf.containsKey(url)) {
        continue;
      }
      if (!qbitIsTrackerUrl(url)) {
        invalid.add(url);
        continue;
      }
      added.add(url);
      (addedByTier[tier] ??= <String>[]).add(url);
    }
  }

  // addTrackers counts tiers from 0 and moves one down at each empty line.
  final List<String> lines = <String>[];
  int at = 0;
  for (final int tier in addedByTier.keys.toList()..sort()) {
    for (; at < tier; at++) {
      lines.add('');
    }
    lines.addAll(addedByTier[tier]!);
  }

  return QbitTrackerEdit(
    added: added,
    removed: <String>[
      for (final String url in tierOf.keys)
        if (!listed.contains(url)) url,
    ],
    invalid: invalid,
    addText: lines.join('\n'),
  );
}
