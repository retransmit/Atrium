import 'package:flutter/material.dart';

/// One live rate as a small tinted pill; muted while that direction is idle.
///
/// Shared by the torrent cards, the detail hero and the peer rows.
class DelugeSpeedPill extends StatelessWidget {
  const DelugeSpeedPill({
    required this.icon,
    required this.label,
    required this.color,
    this.active = true,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color foreground = active ? color : scheme.onSurfaceVariant;
    final Color background = active
        ? color.withValues(alpha: 0.12)
        : scheme.surfaceContainerHighest;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
