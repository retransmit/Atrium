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
///
/// A [Material] rather than a decorated box: the settings panels and the
/// header hold [ListTile]s and chips, which paint their background and ink
/// splashes on the nearest Material ancestor. A `Container` with a
/// `BoxDecoration` between them and that ancestor hides both, and current
/// Flutter asserts on exactly that.
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
    return Padding(
      padding: margin,
      child: Material(
        color: color ?? Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
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
          // Flexible, so a long label (a torrent's name in a selection, a
          // tracker host) is ellipsised inside the pill instead of shoving
          // the pill wider than the row it sits in.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                    fontFamily: monospace ? 'monospace' : null,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The value style of a speed or ratio pill, shared so that
/// [TransmissionPillLine] measures a value the way the pill draws it.
TextStyle? _pillValueStyle(BuildContext context, Color color) =>
    Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        );

/// A pill that can say how wide it needs to be, so a [TransmissionPillLine]
/// can tell whether it fits its share of the line before laying it out.
abstract class TransmissionMeasuredPill extends StatelessWidget {
  const TransmissionMeasuredPill({super.key});

  /// The text the pill shows beside its icon.
  String get value;

  /// The width that shows [value] whole: padding, icon, gap and text.
  double naturalWidth(BuildContext context) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: value,
        style: _pillValueStyle(context, const Color(0xFF000000)),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final double width = painter.width;
    painter.dispose();
    return (16 + 14 + 4 + width).ceilToDouble();
  }
}

/// Speed and ratio pills across one line, sharing it evenly while every value
/// fits its share. When one does not, at a large text size or on a narrow
/// phone, they stack one per line at full width, so a rate is never cut short.
class TransmissionPillLine extends StatelessWidget {
  const TransmissionPillLine({required this.pills, super.key});

  final List<TransmissionMeasuredPill> pills;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double share =
            (constraints.maxWidth - Insets.sm * (pills.length - 1)) /
                pills.length;
        final bool fits = pills.every(
          (TransmissionMeasuredPill p) => p.naturalWidth(context) <= share,
        );
        if (fits) {
          return Row(
            children: <Widget>[
              for (int i = 0; i < pills.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: Insets.sm),
                Expanded(child: pills[i]),
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < pills.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: Insets.xs),
              pills[i],
            ],
          ],
        );
      },
    );
  }
}

/// A rate, tinted while it moves and quiet while it does not.
class TransmissionSpeedPill extends TransmissionMeasuredPill {
  const TransmissionSpeedPill({
    required this.icon,
    required this.label,
    required this.color,
    this.active = true,
    this.selected = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool active;
  final bool selected;

  @override
  String get value => label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color quietForeground = selected
        ? cs.onPrimaryContainer.withValues(alpha: 0.8)
        : cs.onSurfaceVariant;
    final Color quietBackground = selected
        ? cs.onPrimaryContainer.withValues(alpha: 0.12)
        : cs.surfaceContainerHighest;
    final Color fg = active ? color : quietForeground;
    final Color bg =
        active ? color.withValues(alpha: 0.12) : quietBackground;
    // A minimum height rather than a fixed one, so a large text size makes
    // the pill taller instead of clipping the value.
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _pillValueStyle(context, fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// A ratio badge styled consistently with the speed pills.
class TransmissionRatioPill extends TransmissionMeasuredPill {
  const TransmissionRatioPill({
    required this.ratio,
    this.selected = false,
    super.key,
  });

  final double ratio;
  final bool selected;

  @override
  String get value => ratio < 0 ? '0.00' : ratio.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color quietForeground = selected
        ? cs.onPrimaryContainer.withValues(alpha: 0.8)
        : cs.onSurfaceVariant;
    final Color quietBackground = selected
        ? cs.onPrimaryContainer.withValues(alpha: 0.12)
        : cs.surfaceContainerHighest;
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: quietBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.swap_vert, size: 14, color: quietForeground),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _pillValueStyle(context, quietForeground),
            ),
          ),
        ],
      ),
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
          const SizedBox(height: Insets.xs),
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
            const SizedBox(height: Insets.xs),
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

/// The rounded, filled text field the add sheet and the settings dialogs use.
///
/// Outlined as well as filled. A fill alone left these reading as floating
/// labels: `surfaceContainerHighest` at 0.7 alpha sits within a shade of the
/// sheet's own surface, so there was nothing to see but the text. The outline
/// is what makes it a box, and it follows the scheme so it works in both
/// themes and under dynamic colour.
InputDecoration transmissionFieldDecoration(
  BuildContext context, {
  String? hint,
  String? label,
  String? helper,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  final ColorScheme cs = Theme.of(context).colorScheme;
  // `outline`, not `outlineVariant`: the latter is nearly the fill's own value
  // in the light scheme (#CAC4CF on #E6E0E9), which is the same "nothing to
  // see" problem in a different place.
  final OutlineInputBorder border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: cs.outline),
  );
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
    border: border,
    enabledBorder: border,
    // A filled field's outline can all but vanish at rest, so focus says so
    // with the primary colour rather than only a thicker line.
    focusedBorder: border.copyWith(
      borderSide: BorderSide(color: cs.primary, width: 2),
    ),
  );
}
