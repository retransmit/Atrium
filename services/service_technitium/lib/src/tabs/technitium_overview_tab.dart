import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/technitium_stats.dart';
import '../models/technitium_status.dart';
import '../technitium_format.dart';
import '../technitium_providers.dart';
import '../widgets/technitium_protection_card.dart';
import '../widgets/technitium_series_chart.dart';
import '../widgets/technitium_stat_tile.dart';
import '../widgets/technitium_top_list.dart';

/// Overview tab displaying server protection, metrics, charts, and top lists.
class TechnitiumOverviewTab extends ConsumerStatefulWidget {
  const TechnitiumOverviewTab({
    required this.instance,
    this.now = DateTime.now,
    super.key,
  });

  final Instance instance;
  final DateTime Function() now;

  @override
  ConsumerState<TechnitiumOverviewTab> createState() =>
      _TechnitiumOverviewTabState();
}

class _TechnitiumOverviewTabState extends ConsumerState<TechnitiumOverviewTab> {
  bool _busy = false;

  Instance get _instance => widget.instance;
  TechnitiumActions get _actions =>
      ref.read(technitiumActionsProvider(_instance));

  Future<void> _setProtection({required bool enabled, Duration? pause}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _actions.setProtection(enabled: enabled, pause: pause);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update protection: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    final AsyncValue<TechnitiumStatus> statusAsync =
        ref.watch(technitiumStatusProvider(_instance));
    final AsyncValue<TechnitiumStats> statsAsync =
        ref.watch(technitiumStatsProvider(_instance));
    final String activePeriod =
        ref.watch(technitiumStatsPeriodProvider(_instance));

    return RefreshIndicator(
      onRefresh: () async => _actions.refresh(),
      child: ListView(
        padding: const EdgeInsets.all(Insets.md),
        children: <Widget>[
          // 1. Protection Card
          statusAsync.when(
            data: (TechnitiumStatus status) => TechnitiumProtectionCard(
              status: status,
              busy: _busy,
              onSet: _setProtection,
              onPauseEnded: () =>
                  ref.invalidate(technitiumStatusProvider(_instance)),
              now: widget.now,
            ),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(Insets.lg),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (Object e, _) => Material(
              color: cs.errorContainer,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.error_outline, color: cs.onErrorContainer),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: Text(
                        'Failed to load status: $e',
                        style: TextStyle(color: cs.onErrorContainer),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () =>
                          ref.invalidate(technitiumStatusProvider(_instance)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: Insets.md),

          // 2. Time Range Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Statistics',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              DropdownButton<String>(
                value: activePeriod,
                underline: const SizedBox.shrink(),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(
                    value: 'LastHour',
                    child: Text('Last Hour'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'LastDay',
                    child: Text('Last 24 Hours'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'LastWeek',
                    child: Text('Last 7 Days'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'LastMonth',
                    child: Text('Last 30 Days'),
                  ),
                ],
                onChanged: (String? val) {
                  if (val != null) {
                    ref
                        .read(technitiumStatsPeriodProvider(_instance).notifier)
                        .state = val;
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: Insets.xs),

          // 3. Stats Row
          statsAsync.when(
            data: (TechnitiumStats stats) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TechnitiumStatTile(
                        label: 'Total Queries',
                        value: formatTechnitiumCompact(stats.totalQueries),
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: TechnitiumStatTile(
                        label: 'Blocked',
                        value: formatTechnitiumCompact(stats.blockedQueries),
                        subValue: formatTechnitiumPercent(stats.blockedPercent),
                        color: cs.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.sm),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TechnitiumStatTile(
                        label: 'Cached',
                        value: formatTechnitiumCompact(stats.cachedQueries),
                        subValue: formatTechnitiumPercent(stats.cachedPercent),
                        color: cs.tertiary,
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: TechnitiumStatTile(
                        label: 'Clients',
                        value: '${stats.clientsCount}',
                        color: cs.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.md),

                // 4. Query Rate Chart
                if (stats.queriesSeries.length > 1) ...<Widget>[
                  Material(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(Insets.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(
                                'Query Rate Over Time',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                children: <Widget>[
                                  _legendDot(cs.primary, 'Total'),
                                  const SizedBox(width: Insets.sm),
                                  _legendDot(cs.error, 'Blocked'),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: Insets.md),
                          SizedBox(
                            height: 120,
                            child: TechnitiumSeriesChart(
                              series: stats.queriesSeries,
                              color: cs.primary,
                              over: stats.blockedSeries,
                              overColor: cs.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.md),
                ],

                // 5. Top Lists
                TechnitiumTopListCard(
                  title: 'Top Clients',
                  items: stats.topClients,
                  icon: Icons.devices_outlined,
                  accent: cs.secondary,
                ),
                const SizedBox(height: Insets.md),
                TechnitiumTopListCard(
                  title: 'Top Domains',
                  items: stats.topDomains,
                  icon: Icons.language_outlined,
                  accent: cs.primary,
                ),
                const SizedBox(height: Insets.md),
                TechnitiumTopListCard(
                  title: 'Top Blocked Domains',
                  items: stats.topBlockedDomains,
                  icon: Icons.block_outlined,
                  accent: cs.error,
                ),
              ],
            ),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(Insets.lg),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (Object e, _) => Text('Error loading stats: $e'),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
