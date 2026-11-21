import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/prowlarr_category.dart';
import 'models/prowlarr_indexer.dart';
import 'prowlarr_providers.dart';

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
            // A disabled indexer can't be picked, but one picked before it
            // was disabled can still be let go of.
            onChanged: groupOn || (!i.enable && !selected.contains(i.id))
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

/// The search screen's filter button: a badge with how many things are
/// picked, opening one sheet with the indexer and category pickers.
class ProwlarrFilterButton extends StatelessWidget {
  const ProwlarrFilterButton({
    required this.instance,
    required this.filter,
    this.onClosed,
    super.key,
  });

  final Instance instance;
  final ValueNotifier<ProwlarrSearchFilter> filter;

  /// Called once each time the sheet is dismissed, however it was closed.
  final VoidCallback? onClosed;

  Future<void> _open(BuildContext context) async {
    // With nothing focused, closing the sheet has no focus to give back,
    // so the keyboard stays down.
    FocusManager.instance.primaryFocus?.unfocus();
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext sheet) =>
          _FilterSheet(instance: instance, filter: filter),
    );
    onClosed?.call();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ProwlarrSearchFilter>(
      valueListenable: filter,
      builder: (BuildContext context, ProwlarrSearchFilter value, _) =>
          IconButton(
        tooltip: 'Filters',
        icon: Badge(
          isLabelVisible: value.count > 0,
          label: Text('${value.count}'),
          child: const Icon(Icons.tune),
        ),
        onPressed: () => _open(context),
      ),
    );
  }
}

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet({required this.instance, required this.filter});

  final Instance instance;
  final ValueNotifier<ProwlarrSearchFilter> filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ProwlarrIndexer>> indexers =
        ref.watch(prowlarrIndexersProvider(instance));
    final AsyncValue<List<ProwlarrCategory>> categories =
        ref.watch(prowlarrCategoriesProvider(instance));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (BuildContext context, ScrollController scroll) =>
          ValueListenableBuilder<ProwlarrSearchFilter>(
        valueListenable: filter,
        builder: (BuildContext context, ProwlarrSearchFilter value, _) =>
            Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.lg,
                0,
                Insets.sm,
                Insets.sm,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Search filters',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        filter.value = const ProwlarrSearchFilter(),
                    child: const Text('Clear'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: scroll,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const _SectionHeader('Indexers'),
                    _loaded(
                      indexers,
                      what: 'indexers',
                      onRetry: () =>
                          ref.invalidate(prowlarrIndexersProvider(instance)),
                      data: (List<ProwlarrIndexer> list) =>
                          ProwlarrIndexerPicker(
                        indexers: list,
                        selected: value.indexerIds,
                        onChanged: (Set<int> ids) =>
                            filter.value = value.copyWith(indexerIds: ids),
                      ),
                    ),
                    const Divider(),
                    const _SectionHeader('Categories'),
                    _loaded(
                      categories,
                      what: 'categories',
                      onRetry: () =>
                          ref.invalidate(prowlarrCategoriesProvider(instance)),
                      data: (List<ProwlarrCategory> list) =>
                          ProwlarrCategoryPicker(
                        categories: list,
                        selected: value.categories,
                        onChanged: (Set<int> ids) =>
                            filter.value = value.copyWith(categories: ids),
                      ),
                    ),
                    const SizedBox(height: Insets.xl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [data] once [value] has loaded; a spinner before, and a retry after a
/// failure, so one section failing leaves the other usable.
Widget _loaded<T>(
  AsyncValue<T> value, {
  required String what,
  required VoidCallback onRetry,
  required Widget Function(T data) data,
}) =>
    value.when(
      data: data,
      loading: () => const Padding(
        padding: EdgeInsets.all(Insets.xl),
        child: Center(child: ExpressiveProgressIndicator()),
      ),
      error: (Object e, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
        child: Row(
          children: <Widget>[
            Expanded(child: Text('Could not load $what')),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          Insets.lg,
          Insets.md,
          Insets.lg,
          Insets.xs,
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      );
}
