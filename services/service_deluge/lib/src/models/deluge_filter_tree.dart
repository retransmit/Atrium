import 'package:meta/meta.dart';

/// One filter bucket - a value plus how many torrents currently match it.
@immutable
class DelugeFilterBucket {
  const DelugeFilterBucket({required this.name, required this.count});

  final String name;
  final int count;

  @override
  bool operator ==(Object other) =>
      other is DelugeFilterBucket && other.name == name && other.count == count;

  @override
  int get hashCode => Object.hash(name, count);
}

/// The filter buckets Deluge offers for the current session
/// (`core.get_filter_tree`).
///
/// Read rather than hardcoded on purpose: which categories exist depends on the
/// daemon's plugins. A daemon without the Label plugin returns no `label` key
/// at all, so [labels] is empty and the UI hides that section instead of
/// showing a group that can never match.
@immutable
class DelugeFilterTree {
  const DelugeFilterTree({
    this.states = const <DelugeFilterBucket>[],
    this.trackerHosts = const <DelugeFilterBucket>[],
    this.labels = const <DelugeFilterBucket>[],
  });

  factory DelugeFilterTree.fromJson(Map<String, dynamic> json) {
    return DelugeFilterTree(
      states: _buckets(json['state']),
      trackerHosts: _buckets(json['tracker_host']),
      labels: _buckets(json['label']),
    );
  }

  final List<DelugeFilterBucket> states;
  final List<DelugeFilterBucket> trackerHosts;
  final List<DelugeFilterBucket> labels;

  bool get hasLabels => labels.isNotEmpty;

  /// Parses `[["All", 1], ["Downloading", 0], ...]`, skipping anything that is
  /// not a well-formed `[name, count]` pair.
  static List<DelugeFilterBucket> _buckets(Object? raw) {
    if (raw is! List<dynamic>) return const <DelugeFilterBucket>[];
    final List<DelugeFilterBucket> out = <DelugeFilterBucket>[];
    for (final dynamic entry in raw) {
      if (entry is! List<dynamic> || entry.length < 2) continue;
      final Object? name = entry[0];
      final Object? count = entry[1];
      if (name is! String || count is! num) continue;
      out.add(DelugeFilterBucket(name: name, count: count.toInt()));
    }
    return out;
  }
}
