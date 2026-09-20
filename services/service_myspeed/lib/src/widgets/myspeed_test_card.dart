import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../models/myspeed_test.dart';

/// Card displaying a single speedtest result with dedicated metric boxes,
/// dynamic colors, ID badge, and elevated highlights.
class MySpeedTestCard extends StatelessWidget {
  const MySpeedTestCard({
    required this.test,
    this.isHighlighted = false,
    super.key,
  });

  final MySpeedTest test;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    final String timeStr = test.formattedDate.isNotEmpty
        ? test.formattedDate
        : 'Recent test';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isHighlighted
              ? colors.primary.withValues(alpha: 0.6)
              : colors.outlineVariant.withValues(alpha: 0.6),
          width: isHighlighted ? 1.5 : 1.0,
        ),
      ),
      color: colors.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    if (test.id.isNotEmpty) ...<Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: colors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '#${test.id}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: Insets.xs),
                    ],
                    Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timeStr,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                    ),
                  ],
                ),
                if (test.server != null && test.server!.isNotEmpty)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        test.server!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Insets.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: MySpeedMetricBox(
                    icon: Icons.arrow_downward_rounded,
                    label: 'DOWN',
                    value: test.download.toStringAsFixed(1),
                    unit: 'Mbps',
                    iconColor: colors.primary,
                    boxColor: colors.primaryContainer.withValues(alpha: 0.25),
                    borderColor: colors.primary.withValues(alpha: 0.25),
                  ),
                ),
                const SizedBox(width: Insets.xs),
                Expanded(
                  child: MySpeedMetricBox(
                    icon: Icons.arrow_upward_rounded,
                    label: 'UP',
                    value: test.upload.toStringAsFixed(1),
                    unit: 'Mbps',
                    iconColor: colors.tertiary,
                    boxColor: colors.tertiaryContainer.withValues(alpha: 0.25),
                    borderColor: colors.tertiary.withValues(alpha: 0.25),
                  ),
                ),
                const SizedBox(width: Insets.xs),
                Expanded(
                  child: MySpeedMetricBox(
                    icon: Icons.timer_outlined,
                    label: 'PING',
                    value: test.ping.toStringAsFixed(0),
                    unit: 'ms',
                    iconColor: colors.secondary,
                    boxColor: colors.secondaryContainer.withValues(alpha: 0.25),
                    borderColor: colors.secondary.withValues(alpha: 0.25),
                  ),
                ),
                if (test.jitter != null) ...<Widget>[
                  const SizedBox(width: Insets.xs),
                  Expanded(
                    child: MySpeedMetricBox(
                      icon: Icons.graphic_eq_rounded,
                      label: 'JITTER',
                      value: test.jitter!.toStringAsFixed(0),
                      unit: 'ms',
                      iconColor: colors.onSurfaceVariant,
                      boxColor: colors.surfaceContainerHighest.withValues(alpha: 0.35),
                      borderColor: colors.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dedicated box for a single speedtest metric with dynamic icon, color, and border.
class MySpeedMetricBox extends StatelessWidget {
  const MySpeedMetricBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.iconColor,
    required this.boxColor,
    required this.borderColor,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color iconColor;
  final Color boxColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: boxColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            unit,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
