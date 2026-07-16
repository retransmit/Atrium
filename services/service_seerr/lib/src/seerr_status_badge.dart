import 'package:flutter/material.dart';

// The color-coded status vocabulary shared by the Seerr module: poster-card
// availability badges, request-tile pills, and any future status chips all
// draw from the same mappings so one status always looks the same everywhere.
const Color _green = Color(0xFF22C55E);
const Color _teal = Color(0xFF14B8A6);
const Color _blue = Color(0xFF3B82F6);
const Color _amber = Color(0xFFF59E0B);
const Color _red = Color(0xFFEF4444);

/// One status rendering: its semantic color, icon, and label.
class SeerrStatusStyle {
  const SeerrStatusStyle(this.color, this.icon, this.label);

  final Color color;
  final IconData icon;
  final String label;
}

/// Style for a media item's availability (Seerr's `mediaInfo.status`):
/// 2 requested (amber), 3 processing (blue), 4 partially available (teal),
/// 5 available (green). Returns null for unknown / not-yet-requested items
/// (null or 1) so callers can simply render nothing.
SeerrStatusStyle? seerrMediaStatusStyle(int? status) => switch (status) {
      5 => const SeerrStatusStyle(_green, Icons.check_circle, 'Available'),
      4 => const SeerrStatusStyle(
          _teal,
          Icons.check_circle_outline,
          'Partial',
        ),
      3 => const SeerrStatusStyle(_blue, Icons.downloading, 'Processing'),
      2 => const SeerrStatusStyle(_amber, Icons.hourglass_top, 'Requested'),
      _ => null,
    };

/// Style for a request's approval status: 1 pending (amber), 2 approved
/// (green), 3 declined (red), 4 failed (red). Returns null otherwise.
SeerrStatusStyle? seerrRequestStatusStyle(int? status) => switch (status) {
      1 => const SeerrStatusStyle(_amber, Icons.pending, 'Pending'),
      2 => const SeerrStatusStyle(_green, Icons.check_circle, 'Approved'),
      3 => const SeerrStatusStyle(_red, Icons.cancel, 'Declined'),
      4 => const SeerrStatusStyle(_red, Icons.error_outline, 'Failed'),
      _ => null,
    };

/// A small availability pill overlaid on Seerr poster cards while browsing,
/// derived from a media item's [status] (Seerr's `mediaInfo.status`).
///
/// Renders nothing for unknown / not-yet-requested items (null or 1), so it
/// can be dropped onto every card unconditionally. Solid color + white text
/// because it sits over poster imagery.
class SeerrStatusBadge extends StatelessWidget {
  const SeerrStatusBadge({required this.status, super.key});

  final int? status;

  @override
  Widget build(BuildContext context) {
    final SeerrStatusStyle? style = seerrMediaStatusStyle(status);
    if (style == null) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: style.color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black45, blurRadius: 4),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(style.icon, size: 12, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            style.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// A color-coded status pill for tonal cards and tiles (requests, issues,
/// media headers), matching the issue pill's geometry: rounded-20, icon 14,
/// labelSmall w600.
///
/// The semantic color tints the pill background and is deepened (light theme)
/// or lightened (dark theme) for the foreground so it stays legible on tonal
/// surfaces in both themes.
class SeerrStatusPill extends StatelessWidget {
  const SeerrStatusPill({required this.style, super.key});

  final SeerrStatusStyle style;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final Color fg = Color.lerp(
      style.color,
      dark ? Colors.white : theme.colorScheme.onSurface,
      dark ? 0.35 : 0.45,
    )!;
    final Color bg = style.color.withValues(alpha: dark ? 0.26 : 0.16);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(style.icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            style.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
