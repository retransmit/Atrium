import 'package:flutter/material.dart';

/// A small status pill shown on Seerr poster cards while browsing, derived from
/// a media item's [status] (Seerr's `mediaInfo.status`):
/// 2 = pending, 3 = processing, 4 = partially available, 5 = available.
///
/// Renders nothing for unknown / not-yet-requested items (null or 1), so it can
/// be dropped onto every card unconditionally.
class SeerrStatusBadge extends StatelessWidget {
  const SeerrStatusBadge({required this.status, super.key});

  final int? status;

  @override
  Widget build(BuildContext context) {
    final _BadgeStyle? style = switch (status) {
      5 =>
        const _BadgeStyle(Color(0xFF22C55E), Icons.check_circle, 'Available'),
      4 => const _BadgeStyle(
          Color(0xFF14B8A6),
          Icons.check_circle_outline,
          'Partial',
        ),
      3 =>
        const _BadgeStyle(Color(0xFF3B82F6), Icons.downloading, 'Processing'),
      2 => const _BadgeStyle(Color(0xFFF59E0B), Icons.hourglass_top, 'Pending'),
      _ => null,
    };
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

class _BadgeStyle {
  const _BadgeStyle(this.color, this.icon, this.label);

  final Color color;
  final IconData icon;
  final String label;
}
