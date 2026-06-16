import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/prowlarr_indexer.dart';
import 'models/prowlarr_indexer_stats.dart';
import 'prowlarr_indexer_form_screen.dart';
import 'prowlarr_providers.dart';
import 'prowlarr_search_screen.dart';

/// Prowlarr's per-instance UI: the indexer list with enable status and grab /
/// query counts. Tapping an indexer opens its config form (edit / test /
/// delete); the Add FAB creates one from a definition; the Search FAB runs a
/// manual search across all indexers.
class ProwlarrHome extends ConsumerWidget {
  const ProwlarrHome({required this.instance, super.key});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ProwlarrIndexer>> indexers =
        ref.watch(prowlarrIndexersProvider(instance));
    final Map<int, ProwlarrIndexerStat> stats =
        ref.watch(prowlarrStatsByIdProvider(instance)).valueOrNull ??
            const <int, ProwlarrIndexerStat>{};

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(prowlarrIndexersProvider(instance));
          ref.invalidate(prowlarrStatsByIdProvider(instance));
        },
        child: AsyncValueView<List<ProwlarrIndexer>>(
          value: indexers,
          onRetry: () => ref.invalidate(prowlarrIndexersProvider(instance)),
          data: (List<ProwlarrIndexer> list) {
            if (list.isEmpty) {
              return const EmptyView(
                icon: Icons.travel_explore_outlined,
                title: 'No indexers',
                message: 'Tap "Add indexer" to configure one.',
              );
            }
            return ListView.builder(
              padding: Insets.pageH,
              itemCount: list.length,
              itemBuilder: (BuildContext context, int index) {
                final ProwlarrIndexer ix = list[index];
                final ProwlarrIndexerStat? stat = stats[ix.id];
                return ListTile(
                  leading: Icon(
                    ix.enable ? Icons.check_circle : Icons.cancel_outlined,
                    color: ix.enable
                        ? Colors.green
                        : Theme.of(context).colorScheme.outline,
                  ),
                  title: Text(ix.name),
                  subtitle: Text(
                    <String>[
                      if (ix.protocol != null) ix.protocol!,
                      if (stat != null) '${stat.numberOfGrabs} grabs',
                      if (stat != null) '${stat.numberOfQueries} queries',
                    ].join(' • '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openForm(context, indexerId: ix.id),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          FloatingActionButton.small(
            heroTag: 'prowlarr-search',
            tooltip: 'Search',
            onPressed: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(
                builder: (_) => ProwlarrSearchScreen(instance: instance),
              ),
            ),
            child: const Icon(Icons.search),
          ),
          const SizedBox(height: Insets.sm),
          FloatingActionButton.extended(
            heroTag: 'prowlarr-add',
            onPressed: () => _openForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Add indexer'),
          ),
        ],
      ),
    );
  }

  // Root navigator: branch-navigator pushes get swept by GoRouter shell
  // rebuilds (see qBit detail/add history).
  void _openForm(BuildContext context, {int? indexerId}) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ProwlarrIndexerFormScreen(instance: instance, indexerId: indexerId),
      ),
    );
  }
}
