import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:service_cleanuparr/service_cleanuparr.dart';

import '../dashboard_widget_card.dart';
import '../dashboard_widget_kind.dart';

/// Compact dashboard board widget for Cleanuparr.
///
/// Displays active strikes, malware blocked counter, and quick queue hygiene state.
class DashboardCleanuparrWidget extends StatelessWidget {
  const DashboardCleanuparrWidget({
    required this.instances,
    super.key,
  });

  final List<Instance> instances;

  @override
  Widget build(BuildContext context) {
    final Color accent = ServiceVisuals.accent(ServiceKind.cleanuparr);

    return DashboardWidgetCard(
      kind: DashboardWidgetKind.cleanuparr,
      accent: accent,
      onTap: instances.length == 1
          ? () => _open(context, instances.first)
          : null,
      child: instances.isEmpty
          ? const DashboardIdleRow(
              text: 'No Cleanuparr instances configured',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (int index = 0; index < instances.length; index++) ...<Widget>[
                  if (index > 0) const Divider(height: Insets.lg),
                  _CleanuparrInstanceBlock(
                    instance: instances[index],
                    showName: instances.length > 1,
                    onTap: instances.length > 1
                        ? () => _open(context, instances[index])
                        : null,
                  ),
                ],
              ],
            ),
    );
  }

  void _open(BuildContext context, Instance instance) {
    context.go(
      AtriumRoutes.servicePath(instance.kind.name, instance.id),
    );
  }
}

class _CleanuparrInstanceBlock extends ConsumerWidget {
  const _CleanuparrInstanceBlock({
    required this.instance,
    required this.showName,
    required this.onTap,
  });

  final Instance instance;
  final bool showName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(cleanuparrStatsProvider(instance));
    final strikesAsync = ref.watch(cleanuparrStrikesProvider(instance));
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showName) ...<Widget>[
          Row(
            children: <Widget>[
              Text(
                instance.name,
                style: textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.xs),
        ],
        statsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: Insets.sm),
            child: SizedBox(
              height: 20,
              width: 20,
              child: ExpressiveProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (err, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: Insets.xs),
            child: Text(
              'Offline or unreachable',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
              ),
            ),
          ),
          data: (CleanuparrStats stats) {
            // Exact server-side ledger count, not the rendered (searched and
            // page-capped) list length, so the pill cannot report
            // search-filtered or truncated values.
            final int activeStrikes =
                ref.watch(cleanuparrActiveStrikesCountProvider(instance));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Metrics row: Malware Blocked, Active Strikes, Cleaned.
                // Wrap keeps the pills intact on narrow tiles and
                // multi-column dashboard layouts instead of overflowing.
                Wrap(
                  spacing: Insets.xs,
                  runSpacing: Insets.xs,
                  children: <Widget>[
                    _MiniStatPill(
                      icon: Icons.shield_outlined,
                      label: '${stats.malwareBlocked} blocked',
                      color: stats.malwareBlocked > 0
                          ? colorScheme.errorContainer
                          : colorScheme.surfaceContainerHighest,
                      textColor: stats.malwareBlocked > 0
                          ? colorScheme.onErrorContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                    _MiniStatPill(
                      icon: Icons.gavel_outlined,
                      label: '$activeStrikes strikes',
                      color: activeStrikes > 0
                          ? colorScheme.tertiaryContainer
                          : colorScheme.surfaceContainerHighest,
                      textColor: activeStrikes > 0
                          ? colorScheme.onTertiaryContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                    _MiniStatPill(
                      icon: Icons.cleaning_services_outlined,
                      label: '${stats.totalCleaned} cleaned',
                      color: colorScheme.surfaceContainerHighest,
                      textColor: colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: Insets.sm),

                // Top active strike or all clean indicator. Gated on the same
                // ledger count the pill uses so the two can never contradict.
                strikesAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (List<CleanuparrStrikeItem> strikes) {
                    // Removed items stay in the ledger until their strikes
                    // age out, and are not counted as active.
                    final List<CleanuparrStrikeItem> active = strikes
                        .where((CleanuparrStrikeItem s) => !s.isRemoved)
                        .toList();
                    // The count and the list are separate requests, so they
                    // can disagree for a moment; an empty list shows no alert.
                    if (active.isEmpty) {
                      if (activeStrikes > 0) return const SizedBox.shrink();
                      return Row(
                        children: <Widget>[
                          Icon(
                            Icons.check_circle_outline_rounded,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: Insets.xs),
                          Text(
                            'All queues clean',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      );
                    }

                    final CleanuparrStrikeItem topStrike = active.first;
                    return Row(
                      children: <Widget>[
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: colorScheme.tertiary,
                        ),
                        const SizedBox(width: Insets.xs),
                        Expanded(
                          child: Text(
                            topStrike.title,
                            style: textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: Insets.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Insets.xs + 2,
                            vertical: Insets.xxs,
                          ),
                          decoration: BoxDecoration(
                            color: topStrike.isMarkedForRemoval
                                ? colorScheme.errorContainer
                                : colorScheme.tertiaryContainer,
                            borderRadius: Radii.chip,
                          ),
                          child: Text(
                            topStrike.isMarkedForRemoval
                                ? '${topStrike.strikeCount} strikes • removal'
                                : '${topStrike.strikeCount} ${topStrike.strikeCount == 1 ? 'strike' : 'strikes'}',
                            style: textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: topStrike.isMarkedForRemoval
                                  ? colorScheme.onErrorContainer
                                  : colorScheme.onTertiaryContainer,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ],
    );

    if (onTap == null) return content;

    return InkWell(
      onTap: onTap,
      borderRadius: Radii.card,
      child: content,
    );
  }
}

class _MiniStatPill extends StatelessWidget {
  const _MiniStatPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.xs + 2,
        vertical: Insets.xxs,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: Radii.chip,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: Insets.xxs + 1),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
