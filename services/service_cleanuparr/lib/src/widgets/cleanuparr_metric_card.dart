import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// A Material 3 metric summary card with semantic icon badge and live counter.
class CleanuparrMetricCard extends StatelessWidget {
  const CleanuparrMetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.containerColor,
    required this.contentColor,
    this.subtitle,
    super.key,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color containerColor;
  final Color contentColor;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(borderRadius: Radii.card),
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Flexible(
                  child: Text(
                    title,
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(Insets.xs + 2),
                  decoration: BoxDecoration(
                    color: containerColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 16, color: contentColor),
                ),
              ],
            ),
            const SizedBox(height: Insets.sm),
            // FittedBox guards against headline-scale counts overflowing the
            // card at large accessibility text scales.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: Insets.xxs),
              Text(
                subtitle!,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.outline,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
