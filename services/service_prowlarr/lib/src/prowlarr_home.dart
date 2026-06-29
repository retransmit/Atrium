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
          return ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.lg,
              vertical: Insets.sm,
            ),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: Insets.sm),
            itemBuilder: (BuildContext context, int index) {
              final ProwlarrIndexer ix = list[index];
              return _IndexerCard(
                indexer: ix,
                stat: stats[ix.id],
                onTap: () => onEdit(ix.id),
              );
            },
          );
        },
      ),
    );
  }
}

/// A single indexer row: enable badge, name, and grab / query stat pills.
class _IndexerCard extends StatelessWidget {
  const _IndexerCard({
    required this.indexer,
    required this.stat,
    required this.onTap,
  });

  final ProwlarrIndexer indexer;
  final ProwlarrIndexerStat? stat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color accent = indexer.enable ? cs.tertiary : cs.outline;
    final String? protocol = indexer.protocol;
    final bool isTorrent = protocol?.toLowerCase() == 'torrent';

    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  indexer.enable ? Icons.check_rounded : Icons.cancel_outlined,
                  color: accent,
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      indexer.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (protocol != null || stat != null) ...<Widget>[
                      const SizedBox(height: Insets.xs),
                      Wrap(
                        spacing: Insets.xs,
                        runSpacing: Insets.xs,
                        children: <Widget>[
                          if (protocol != null)
                            _MetaPill(
                              icon: isTorrent
                                  ? Icons.swap_vert
                                  : Icons.newspaper_outlined,
                              label: protocol,
                              color: isTorrent ? cs.primary : cs.tertiary,
                            ),
                          if (stat != null)
                            _MetaPill(
                              icon: Icons.download_done_outlined,
                              label: '${stat!.numberOfGrabs} grabs',
                              color: cs.tertiary,
                            ),
                          if (stat != null)
                            _MetaPill(
                              icon: Icons.search,
                              label: '${stat!.numberOfQueries} queries',
                              color: cs.primary,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Insets.sm),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact tonal metadata pill: icon + short label in a single accent color.
class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
