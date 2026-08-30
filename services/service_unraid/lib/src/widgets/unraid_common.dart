import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../models/unraid_models.dart';

/// Pieces shared by more than one Unraid tab.
///
/// They were private to the single screen this module used to be. Splitting
/// that into tabs put them in different libraries, which is why they carry
/// names now rather than a leading underscore.

class UnraidUsageBar extends StatelessWidget {
  const UnraidUsageBar({
    required this.fraction,
    required this.label,
    this.caption,
    super.key,
  });

  final double fraction;
  final String label;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final String? cap = caption;

    // Unraid's own defaults warn at 70% and call it critical at 90%, so the
    // colour changes where the server would start emailing about it.
    final bool dark = cs.brightness == Brightness.dark;
    final Color fill = fraction >= 0.90
        ? (dark ? const Color(0xFFFF5252) : const Color(0xFFC62828))
        : fraction >= 0.70
            ? (dark ? const Color(0xFFFFA726) : const Color(0xFFE65100))
            : cs.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            if (cap != null)
              Text(
                cap,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            const Spacer(),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.sm),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: cs.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(fill),
          ),
        ),
      ],
    );
  }
}

Color unraidOkGreen(ColorScheme cs) => cs.brightness == Brightness.dark
    ? const Color(0xFF66BB6A)
    : const Color(0xFF2E7D32);

/// Cool blue through to hot red, deliberately not taken from the colour
/// scheme: the dark theme's error colour is a pale pink that reads cooler than
/// the orange one band below it, which would put the scale in the wrong order.
/// Each band is given a light and a dark variant so it stays legible either
/// way.
Color unraidHeatColor(DiskHeat heat, ColorScheme cs) {
  final bool dark = cs.brightness == Brightness.dark;
  return switch (heat) {
    DiskHeat.hot => dark ? const Color(0xFFFF5252) : const Color(0xFFC62828),
    DiskHeat.warm => dark ? const Color(0xFFFFA726) : const Color(0xFFE65100),
    DiskHeat.normal => dark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32),
    DiskHeat.cool => dark ? const Color(0xFF4FC3F7) : const Color(0xFF0277BD),
    DiskHeat.unknown => cs.outline,
  };
}

/// `2 days ago`, or an empty string when there is no date to place.
String unraidAgo(DateTime? when) {
  if (when == null) return '';
  final Duration d = DateTime.now().difference(when);
  if (d.isNegative) return '';
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) {
    final int m = d.inMinutes;
    return m == 1 ? '1 minute ago' : '$m minutes ago';
  }
  if (d.inDays < 1) {
    final int h = d.inHours;
    return h == 1 ? '1 hour ago' : '$h hours ago';
  }
  if (d.inDays < 30) {
    final int days = d.inDays;
    return days == 1 ? 'yesterday' : '$days days ago';
  }
  final int months = d.inDays ~/ 30;
  return months == 1 ? 'last month' : '$months months ago';
}

class UnraidSectionHeader extends StatelessWidget {
  const UnraidSectionHeader({required this.title, this.trailing, super.key});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final String? sub = trailing;

    return Row(
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        if (sub != null)
          Text(
            sub,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class UnraidStatBox extends StatelessWidget {
  const UnraidStatBox({
    required this.label,
    required this.value,
    required this.unit,
    required this.valueColor,
    super.key,
  });

  final String label;
  final String value;
  final String unit;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: Insets.md,
        horizontal: Insets.sm,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: Insets.xs),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
          ),
          const SizedBox(height: Insets.xxs),
          Text(
            unit,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class UnraidCardPlaceholder extends StatelessWidget {
  const UnraidCardPlaceholder({required this.height, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: const Center(child: ExpressiveProgressIndicator()),
    );
  }
}
/// The frame every tab sits in: page padding, pull to refresh, and a scroll
/// view that can always be dragged even when its content is short.
class UnraidTabScaffold extends StatelessWidget {
  const UnraidTabScaffold({
    required this.onRefresh,
    required this.children,
    super.key,
  });

  final VoidCallback onRefresh;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return EasyRefresh(
      header: const ClassicHeader(
        dragText: 'Pull to refresh',
        armedText: 'Release ready',
        readyText: 'Refreshing...',
        processingText: 'Refreshing...',
        processedText: 'Updated',
        failedText: 'Failed',
        messageText: 'Last updated at %T',
      ),
      onRefresh: onRefresh,
      child: ListView(
        padding: Insets.page,
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          ...children,
          // Clears the bottom navigation bar so the last row is reachable.
          const SizedBox(height: 96),
        ],
      ),
    );
  }
}
