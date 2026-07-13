import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import 'dashboard_widget_kind.dart';

/// Shared chrome for every dashboard widget: a single calm surface card with
/// an accent-tinted icon badge, optional trailing pill/text, and the body.
///
/// Every card uses the same neutral tone; colour is carried only by the icon
/// badge and the body's own pills/chips/bars, so the board reads as one system
/// and the artwork and data lead rather than competing tonal fills.
class DashboardWidgetCard extends StatelessWidget {
  const DashboardWidgetCard({
    required this.kind,
    required this.accent,
    required this.child,
    this.trailing,
    this.onTap,
    super.key,
  });

  final DashboardWidgetKind kind;

  /// Role colour for this widget - used for the icon badge only.
  final Color accent;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Insets.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(kind.icon, size: 24, color: accent),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Text(
                      kind.label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: Insets.md),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Small tonal metadata pill, matching the module screens.
class DashboardPill extends StatelessWidget {
  const DashboardPill({
    required this.icon,
    required this.label,
    required this.color,
    super.key,
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
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

/// Quiet single-line body used when a configured widget has nothing to show.
class DashboardIdleRow extends StatelessWidget {
  const DashboardIdleRow({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodySmall
          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
    );
  }
}

/// Compact inline error state with a retry action; the widget stays visible.
class DashboardErrorRow extends StatelessWidget {
  const DashboardErrorRow({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error),
        const SizedBox(width: Insets.sm),
        Expanded(
          child: Text(
            'Could not load',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}
