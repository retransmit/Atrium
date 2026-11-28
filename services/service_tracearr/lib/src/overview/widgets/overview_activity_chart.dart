import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/tracearr_models.dart';
import '../daily_plays.dart';

/// 7-day activity trend histogram visualizing playback session counts over time.
class OverviewActivityChart extends StatelessWidget {
  const OverviewActivityChart({
    required this.activityAsync,
    this.onRetry,
    super.key,
  });

  final AsyncValue<TracearrActivityTrend> activityAsync;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '7-DAY PLAYBACK ACTIVITY',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Text(
                'Past Week',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.sm),
        activityAsync.when(
          loading: () => Container(
            height: 160,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: const Center(child: ExpressiveProgressIndicator()),
          ),
          error: (err, _) => Container(
            padding: const EdgeInsets.all(Insets.md),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Row(
              children: [
                Icon(Icons.timeline, color: colorScheme.error),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Text(
                    'Failed to load playback trend history',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                if (onRetry != null)
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: onRetry,
                  ),
              ],
            ),
          ),
          data: (trend) {
            final buckets = dailyPlays(trend);

            if (buckets.every((b) => b.count == 0)) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Insets.lg),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: Center(
                  child: Text(
                    'No playback activity recorded in the past 7 days.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }

            final maxCount =
                buckets.fold(0, (max, b) => b.count > max ? b.count : max);
            final effectiveMax = maxCount > 0 ? maxCount : 1;

            return Container(
              padding: const EdgeInsets.all(Insets.md),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 110,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: buckets.map((bucket) {
                        final double factor = bucket.count / effectiveMax;
                        final double barHeight = (factor * 85).clamp(4.0, 85.0);

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2.0,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (bucket.count > 0)
                                  Text(
                                    '${bucket.count}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontSize: 10,
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                const SizedBox(height: 2),
                                Container(
                                  height: barHeight,
                                  decoration: BoxDecoration(
                                    color: bucket.count > 0
                                        ? colorScheme.primary
                                        : colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: Insets.xs),
                  const Divider(height: 1),
                  const SizedBox(height: Insets.xs),
                  Row(
                    children: buckets.map((bucket) {
                      final label = bucket.date != null
                          ? DateFormat('E').format(bucket.date!)
                          : '-';

                      return Expanded(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
