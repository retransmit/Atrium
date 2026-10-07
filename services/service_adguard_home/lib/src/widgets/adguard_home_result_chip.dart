import 'package:flutter/material.dart';

import '../models/adguard_home_query_log.dart';

/// The colour of a result, after the web UI's: red for blocked, green for
/// allowed, yellow for the three protections, blue for a rewrite and the
/// muted text colour for an ordinary answer.
///
/// Red is the theme's own. The other three are fixed hues, a light shade on
/// a dark theme and a dark one on a light theme, so they stay readable as
/// small text.
Color adguardHomeToneColor(BuildContext context, AdguardHomeResultTone tone) {
  final ColorScheme cs = Theme.of(context).colorScheme;
  final bool dark = cs.brightness == Brightness.dark;
  return switch (tone) {
    AdguardHomeResultTone.plain => cs.onSurfaceVariant,
    AdguardHomeResultTone.blocked => cs.error,
    AdguardHomeResultTone.allowed =>
      dark ? Colors.green.shade300 : Colors.green.shade800,
    AdguardHomeResultTone.restricted =>
      dark ? Colors.amber.shade300 : Colors.orange.shade900,
    AdguardHomeResultTone.rewritten =>
      dark ? Colors.blue.shade300 : Colors.blue.shade800,
  };
}

/// What became of a query, as a small tinted pill.
class AdguardHomeResultChip extends StatelessWidget {
  const AdguardHomeResultChip({
    required this.label,
    required this.tone,
    super.key,
  });

  final String label;
  final AdguardHomeResultTone tone;

  @override
  Widget build(BuildContext context) {
    final Color color = adguardHomeToneColor(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
