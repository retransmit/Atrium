import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/prowlarr_indexer.dart';
import 'models/prowlarr_indexer_stats.dart';
import 'prowlarr_history_tab.dart';
import 'prowlarr_indexer_form_screen.dart';
import 'prowlarr_providers.dart';
import 'prowlarr_search_screen.dart';
import 'prowlarr_settings_tab.dart';
import 'prowlarr_system_tab.dart';

/// Prowlarr's per-instance UI: a tabbed Indexers / History / Settings / System
/// view mirroring Prowlarr's own navigation. The Indexers tab lists indexers
/// (tap to edit) with FABs to add one or search across all; Settings is a menu
/// of provider/config screens; System surfaces health, tasks, and status.
class ProwlarrHome extends StatefulWidget {
  const ProwlarrHome({required this.instance, super.key});

  final Instance instance;

  @override
  State<ProwlarrHome> createState() => _ProwlarrHomeState();
}

class _ProwlarrHomeState extends State<ProwlarrHome>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _tab.addListener(() {
      // Rebuild so the FABs show only on the Indexers tab.
      if (!_tab.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          TabBar(
            controller: _tab,
            tabs: const <Widget>[
              Tab(text: 'Indexers'),
              Tab(text: 'History'),
              Tab(text: 'Settings'),
              Tab(text: 'System'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: <Widget>[
                _IndexersTab(
                  instance: widget.instance,
                  onEdit: _openForm,
                ),
                ProwlarrHistoryTab(instance: widget.instance),
                ProwlarrSettingsTab(instance: widget.instance),
                ProwlarrSystemTab(instance: widget.instance),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton:
          _tab.index == 0 ? _indexerFabs(context) : null,
    );
  }

  Widget _indexerFabs(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        FloatingActionButton.small(
          heroTag: 'prowlarr-search',
          tooltip: 'Search',
          onPressed: () => Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute<void>(
              builder: (_) => ProwlarrSearchScreen(instance: widget.instance),
            ),
          ),
          child: const Icon(Icons.search),
        ),
        const SizedBox(height: Insets.sm),
        FloatingActionButton.extended(
          heroTag: 'prowlarr-add',
          onPressed: _openForm,
          icon: const Icon(Icons.add),
          label: const Text('Add indexer'),
        ),
      ],
    );
  }

  // Root navigator: branch-navigator pushes get swept by GoRouter shell
  // rebuilds (see qBit detail/add history).
  void _openForm([int? indexerId]) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => ProwlarrIndexerFormScreen(
          instance: widget.instance,
          indexerId: indexerId,
        ),
      ),
    );
  }
}

/// The Indexers tab: the indexer list with enable status and grab / query
/// counts. Tapping a row opens its config form.
class _IndexersTab extends ConsumerWidget {
  const _IndexersTab({required this.instance, required this.onEdit});

  final Instance instance;
  final ValueChanged<int> onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ProwlarrIndexer>> indexers =
        ref.watch(prowlarrIndexersProvider(instance));
    final Map<int, ProwlarrIndexerStat> stats =
        ref.watch(prowlarrStatsByIdProvider(instance)).valueOrNull ??
            const <int, ProwlarrIndexerStat>{};

    return RefreshIndicator(
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
                onTap: () => onEdit(ix.id),
              );
            },
          );
        },
      ),
    );
  }
}
