import 'package:core_ui/core_ui.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';

import 'models/prowlarr_category.dart';
import 'models/prowlarr_indexer.dart';

/// Prowlarr's ids for "every usenet indexer" and "every torrent indexer".
/// Sent as indexer ids, they cover indexers added later too.
const int prowlarrAllUsenet = -1;
const int prowlarrAllTorrents = -2;

/// What a search is narrowed to. Empty means all, as in Prowlarr.
@immutable
class ProwlarrSearchFilter {
  const ProwlarrSearchFilter({
    this.indexerIds = const <int>{},
    this.categories = const <int>{},
  });

  final Set<int> indexerIds;
  final Set<int> categories;

  bool get isEmpty => indexerIds.isEmpty && categories.isEmpty;

  /// How many things are picked, for the filter button's badge.
  int get count => indexerIds.length + categories.length;

  ProwlarrSearchFilter copyWith({Set<int>? indexerIds, Set<int>? categories}) =>
      ProwlarrSearchFilter(
        indexerIds: indexerIds ?? this.indexerIds,
        categories: categories ?? this.categories,
      );

  @override
  bool operator ==(Object other) =>
      other is ProwlarrSearchFilter &&
      setEquals(other.indexerIds, indexerIds) &&
      setEquals(other.categories, categories);

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(indexerIds),
        Object.hashAllUnordered(categories),
      );
}

/// The search field's hint: what a search with [filter] will reach.
String prowlarrSearchHint(ProwlarrSearchFilter filter) {
  final Set<int> ids = filter.indexerIds;
  final bool torrents = ids.contains(prowlarrAllTorrents);
  final bool usenet = ids.contains(prowlarrAllUsenet);
  final int others = ids
      .where((int id) => id != prowlarrAllTorrents && id != prowlarrAllUsenet)
      .length;
  final String count = '$others ${others == 1 ? 'indexer' : 'indexers'}';
  if (ids.isEmpty || (torrents && usenet)) {
    return 'Search all indexers...';
  }
  if (!torrents && !usenet) {
    return 'Search $count...';
  }
  final String group = torrents ? 'all torrents' : 'all usenet';
  return others == 0 ? 'Search $group...' : 'Search $group and $count...';
}

/// Indexers grouped by protocol, as on Prowlarr's search page. Ticking a
/// group searches every indexer of that protocol, and stands in for any of
/// them that were ticked one by one.
class ProwlarrIndexerPicker extends StatelessWidget {
  const ProwlarrIndexerPicker({
    required this.indexers,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<ProwlarrIndexer> indexers;
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = <Widget>[];
    for (final (String protocol, int groupId, String label)
        in <(String, int, String)>[
      ('torrent', prowlarrAllTorrents, 'Torrents'),
      ('usenet', prowlarrAllUsenet, 'Usenet'),
    ]) {
      final List<ProwlarrIndexer> group = indexers
          .where((ProwlarrIndexer i) => i.protocol == protocol)
          .toList();
      if (group.isEmpty) {
        continue;
      }
      final bool groupOn = selected.contains(groupId);
      rows.add(
        CheckboxListTile(
          value: groupOn,
          title: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text('Every $protocol indexer'),
          onChanged: (bool? on) {
            final Set<int> next = Set<int>.of(selected);
            if (on ?? false) {
              next
                ..removeAll(group.map((ProwlarrIndexer i) => i.id))
                ..add(groupId);
            } else {
              next.remove(groupId);
            }
            onChanged(next);
          },
        ),
      );
      for (final ProwlarrIndexer i in group) {
        rows.add(
          CheckboxListTile(
            contentPadding:
                const EdgeInsets.only(left: Insets.xl, right: Insets.lg),
            dense: true,
            value: groupOn || selected.contains(i.id),
            title: Text(i.name),
            subtitle: i.enable ? null : const Text('Disabled'),
            onChanged: groupOn || !i.enable
                ? null
                : (bool? on) => onChanged(_toggled(selected, i.id, on)),
          ),
        );
      }
    }
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(Insets.lg),
        child: Text('No indexers set up in Prowlarr.'),
      );
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

/// Prowlarr's category tree. Ticking a parent such as Movies covers all of
/// its subcategories, and stands in for any that were ticked one by one.
class ProwlarrCategoryPicker extends StatelessWidget {
  const ProwlarrCategoryPicker({
    required this.categories,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<ProwlarrCategory> categories;
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final ProwlarrCategory parent in categories)
          ExpansionTile(
            key: PageStorageKey<int>(parent.id),
            initiallyExpanded: parent.subCategories
                .any((ProwlarrCategory s) => selected.contains(s.id)),
            leading: Checkbox(
              value: selected.contains(parent.id),
              onChanged: (bool? on) {
                final Set<int> next = Set<int>.of(selected);
                if (on ?? false) {
                  next
                    ..removeAll(
                      parent.subCategories.map((ProwlarrCategory s) => s.id),
                    )
                    ..add(parent.id);
                } else {
                  next.remove(parent.id);
                }
                onChanged(next);
              },
            ),
            title: Text(parent.name),
            children: <Widget>[
              for (final ProwlarrCategory sub in parent.subCategories)
                CheckboxListTile(
                  contentPadding: const EdgeInsets.only(
                    left: Insets.xl * 2,
                    right: Insets.lg,
                  ),
                  dense: true,
                  value: selected.contains(parent.id) ||
                      selected.contains(sub.id),
                  title: Text(sub.shortName),
                  onChanged: selected.contains(parent.id)
                      ? null
                      : (bool? on) => onChanged(_toggled(selected, sub.id, on)),
                ),
            ],
          ),
      ],
    );
  }
}

Set<int> _toggled(Set<int> selected, int id, bool? on) {
  final Set<int> next = Set<int>.of(selected);
  (on ?? false) ? next.add(id) : next.remove(id);
  return next;
}
