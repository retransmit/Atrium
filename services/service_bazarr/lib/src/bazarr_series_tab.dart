import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bazarr_providers.dart';
import 'bazarr_series_detail_screen.dart';
import 'models/bazarr_models.dart';

/// The Series tab: all Sonarr-backed series with their subtitle status. Tapping
/// a row opens the per-episode subtitle view.
class BazarrSeriesTab extends ConsumerWidget {
  const BazarrSeriesTab({required this.instance, super.key});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<BazarrSeries>> series =
        ref.watch(bazarrSeriesProvider(instance));
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(bazarrSeriesProvider(instance)),
      child: AsyncValueView<List<BazarrSeries>>(
        value: series,
        onRetry: () => ref.invalidate(bazarrSeriesProvider(instance)),
        data: (List<BazarrSeries> list) {
          if (list.isEmpty) {
            return const EmptyView(
              icon: Icons.live_tv_outlined,
              title: 'No series',
              message: 'Bazarr has no series from Sonarr yet.',
            );
          }
          return ListView.separated(
            padding: Insets.page,
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: Insets.sm),
            itemBuilder: (BuildContext context, int index) =>
                _SeriesCard(instance: instance, series: list[index]),
          );
        },
      ),
    );
  }
}

class _SeriesCard extends StatelessWidget {
  const _SeriesCard({required this.instance, required this.series});

  final Instance instance;
  final BazarrSeries series;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final bool allDone = series.episodeMissingCount == 0;

    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (_) => BazarrSeriesDetailScreen(
              instance: instance,
              series: series,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.live_tv_outlined, color: cs.primary),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      series.year != null
                          ? '${series.title} (${series.year})'
                          : series.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: Insets.xs),
                    allDone
                        ? _Pill(
                            icon: Icons.check_circle_outline,
                            label:
                                '${series.episodeFileCount} episodes, all subtitled',
                            color: cs.tertiary,
                          )
                        : _Pill(
                            icon: Icons.subtitles_off_outlined,
                            label:
                                '${series.episodeMissingCount} missing subtitles',
                            color: cs.secondary,
                          ),
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

/// A small tonal metadata pill: a colored icon and label on a faint tint.
class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.color});

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
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
