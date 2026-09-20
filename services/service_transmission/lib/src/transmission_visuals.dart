import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import 'models/transmission_torrent.dart';

/// The expressive vocabulary the torrent screens share: rounded panels,
/// tinted state visuals, and small pills. One place, so the list, the detail
/// screen and the settings read as one screen family.

/// A state's colour, its container tint and its icon, from the scheme so the
/// palette follows the device's dynamic colour.
class TransmissionVisual {
  const TransmissionVisual({
    required this.color,
    required this.container,
    required this.onContainer,
    required this.icon,
  });

  final Color color;
  final Color container;
  final Color onContainer;
  final IconData icon;
}

TransmissionVisual transmissionVisualFor(
  ColorScheme cs,
  TransmissionTorrent t,
) {
  if (t.hasError) {
    return TransmissionVisual(
      color: cs.error,
      container: cs.errorContainer,
      onContainer: cs.onErrorContainer,
      icon: Icons.error_outline_rounded,
    );
  }
  return switch (t.status) {
    TransmissionStatus.downloading => TransmissionVisual(
        color: cs.primary,
        container: cs.primaryContainer,
        onContainer: cs.onPrimaryContainer,
        icon: Icons.download_rounded,
      ),
    TransmissionStatus.seeding => TransmissionVisual(
        color: cs.tertiary,
        container: cs.tertiaryContainer,
        onContainer: cs.onTertiaryContainer,
        icon: Icons.upload_rounded,
      ),
    TransmissionStatus.checking => TransmissionVisual(
        color: cs.secondary,
        container: cs.secondaryContainer,
        onContainer: cs.onSecondaryContainer,
        icon: Icons.fact_check_outlined,
      ),
    TransmissionStatus.checkWait ||
    TransmissionStatus.downloadWait ||
    TransmissionStatus.seedWait =>
      TransmissionVisual(
        color: cs.secondary,
        container: cs.secondaryContainer,
        onContainer: cs.onSecondaryContainer,
        icon: Icons.hourglass_empty_rounded,
      ),
    TransmissionStatus.stopped => TransmissionVisual(
        color: cs.outline,
        container: cs.surfaceContainerHighest,
        onContainer: cs.onSurfaceVariant,
        icon: t.isFinished ? Icons.check_rounded : Icons.pause_rounded,
      ),
    TransmissionStatus.unknown => TransmissionVisual(
        color: cs.outline,
        container: cs.surfaceContainerHighest,
        onContainer: cs.onSurfaceVariant,
        icon: Icons.help_outline_rounded,
      ),
  };
}

/// The rounded surface every group of content sits on.
class TransmissionPanel extends StatelessWidget {
  const TransmissionPanel({
    required this.child,
    this.padding = const EdgeInsets.all(Insets.md),
    this.margin = EdgeInsets.zero,
    this.color,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;

  static const double radius = 20;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
}

/// A panel's title, set inside it above its rows.
class TransmissionPanelTitle extends StatelessWidget {
  const TransmissionPanelTitle(this.title, {this.trailing, super.key});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// A 44 px tinted block holding one icon: the row's state at a glance.
class TransmissionIconBlock extends StatelessWidget {
  const TransmissionIconBlock({
    required this.icon,
    required this.background,
    required this.foreground,
    this.size = 44,
    super.key,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, size: size * 0.5, color: foreground),
    );
  }
}

/// A small tinted label: a state, a count, a flag string.
class TransmissionPill extends StatelessWidget {
  const TransmissionPill({
    required this.label,
    required this.foreground,
    required this.background,
    this.icon,
    this.monospace = false,
    super.key,
  });

  final String label;
  final Color foreground;
  final Color background;
  final IconData? icon;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                  fontFamily: monospace ? 'monospace' : null,
                ),
          ),
        ],
      ),
    );
  }
}

/// A rate, tinted while it moves and quiet while it does not.
class TransmissionSpeedPill extends StatelessWidget {
  const TransmissionSpeedPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.active,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return TransmissionPill(
      icon: icon,
      label: label,
      foreground: active ? color : cs.onSurfaceVariant,
      background:
          active ? color.withValues(alpha: 0.12) : cs.surfaceContainerHighest,
    );
  }
}

/// One figure with its label and a line under it, three of which make the
/// header of the list and the statistics card.
class TransmissionStatBadge extends StatelessWidget {
  const TransmissionStatBadge({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.detail,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          if (detail != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              detail!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The rounded, filled text field the search box and the sheet use.
InputDecoration transmissionFieldDecoration(
  BuildContext context, {
  String? hint,
  String? label,
  String? helper,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  final ColorScheme cs = Theme.of(context).colorScheme;
  return InputDecoration(
    hintText: hint,
    labelText: label,
    helperText: helper,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.7),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );
}
