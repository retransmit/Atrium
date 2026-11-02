import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'deluge_format.dart';
import 'deluge_providers.dart';
import 'models/deluge_filter_tree.dart';

/// The right-hand filter sidebar for Deluge's torrent list.
///
/// It carries the state buckets; label filtering stays on the list itself
/// because it is a separate, plugin-dependent facet.
class DelugeFilterDrawer extends ConsumerWidget {
  const DelugeFilterDrawer({required this.instance, super.key});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<DelugeFilterTree> treeAsync =
        ref.watch(delugeFilterTreeProvider(instance));
    final DelugeFilterTree tree =
        treeAsync.value ?? const DelugeFilterTree();
    final DelugeFilter filter = ref.watch(delugeFilterProvider(instance));
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: Insets.md),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.xl,
                Insets.sm,
                Insets.xl,
                Insets.md,
              ),
              child: Text(
                'Filters',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            if (treeAsync.isLoading && !treeAsync.hasValue)
              const Padding(
                padding: EdgeInsets.all(Insets.xl),
                child: Center(child: ExpressiveProgressIndicator()),
              )
            else if (tree.states.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: Insets.xl),
                child: Text('No filters available.'),
              )
            else
              for (final DelugeFilterBucket bucket in tree.states)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Insets.md),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                    leading: Icon(_stateIcon(bucket.name)),
                    title: Text(
                      '${bucket.name.isEmpty ? 'None' : bucket.name} '
                      '(${bucket.count})',
                      style: TextStyle(
                        fontWeight: bucket.name == filter.state
                            ? FontWeight.bold
                            : null,
                      ),
                    ),
                    selected: bucket.name == filter.state,
                    selectedColor: scheme.onSecondaryContainer,
                    selectedTileColor: scheme.secondaryContainer,
                    onTap: () {
                      ref
                          .read(delugeFilterProvider(instance).notifier)
                          .update(
                            (DelugeFilter f) => f.copyWith(state: bucket.name),
                          );
                      Scaffold.of(context).closeEndDrawer();
                    },
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// App-bar button that opens [DelugeFilterDrawer].
///
/// The page's Scaffold owns the drawer, so the fallback is what the AppBar
/// resolves to when this sits in its actions.
class DelugeFilterAppBarAction extends StatelessWidget {
  const DelugeFilterAppBarAction({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Filters',
      icon: const Icon(Icons.view_sidebar_outlined),
      onPressed: () => Scaffold.of(context).openEndDrawer(),
    );
  }
}

IconData _stateIcon(String state) => switch (state) {
      'All' => Icons.filter_alt_outlined,
      'Active' => Icons.bolt_outlined,
      _ => delugeStateIcon(state),
    };
