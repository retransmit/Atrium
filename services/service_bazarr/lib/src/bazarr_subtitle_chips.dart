import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import 'models/bazarr_models.dart';

/// Renders subtitle language chips: present subtitles as filled tertiary-tinted
/// chips, missing ones as outlined chips. When [onDeletePresent] is given, each
/// present chip shows a tappable delete (x) affordance. Shared by the
/// episode/movie detail views.
class BazarrSubtitleChips extends StatelessWidget {
  const BazarrSubtitleChips({
    this.present = const <BazarrSubtitle>[],
    this.missing = const <BazarrSubtitle>[],
    this.onDeletePresent,
    super.key,
  });

  final List<BazarrSubtitle> present;
  final List<BazarrSubtitle> missing;
  final ValueChanged<BazarrSubtitle>? onDeletePresent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (present.isEmpty && missing.isEmpty) {
      return Text(
        'No subtitles tracked',
        style: theme.textTheme.labelSmall
            ?.copyWith(color: theme.colorScheme.outline),
      );
    }
    return Wrap(
      spacing: Insets.xs,
      runSpacing: Insets.xs,
      children: <Widget>[
        for (final BazarrSubtitle s in present) _chip(context, s, present: true),
        for (final BazarrSubtitle s in missing)
          _chip(context, s, present: false),
      ],
    );
  }

  String _label(BazarrSubtitle s) {
    final String code = s.code2.isNotEmpty
        ? s.code2.toUpperCase()
        : (s.code3.isNotEmpty ? s.code3.toUpperCase() : s.name);
    final List<String> tags = <String>[
      if (s.hi) 'HI',
      if (s.forced) 'F',
    ];
    return tags.isEmpty ? code : '$code ${tags.join('/')}';
  }

  Widget _chip(BuildContext context, BazarrSubtitle s, {required bool present}) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    // Present subtitles read as a soft tertiary "have it" tone; missing ones as
    // a neutral outlined tone.
    final Color fg = present ? cs.onTertiaryContainer : cs.onSurfaceVariant;
    // External (downloaded) subtitles carry a path and can be deleted; embedded
    // subtitles (path null) cannot.
    final bool deletable = present && (s.path?.isNotEmpty ?? false);
    final Widget chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 4),
      decoration: BoxDecoration(
        color: present
            ? cs.tertiary.withValues(alpha: 0.16)
            : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: present ? null : Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            present ? Icons.check : Icons.remove,
            size: 12,
            color: present ? cs.tertiary : fg,
          ),
          const SizedBox(width: 4),
          Text(
            _label(s),
            style: theme.textTheme.labelSmall
                ?.copyWith(color: fg, fontWeight: FontWeight.w600),
          ),
          if (deletable) ...<Widget>[
            const SizedBox(width: 4),
            Icon(Icons.delete_outline, size: 15, color: fg),
          ],
        ],
      ),
    );
    if (present && onDeletePresent != null) {
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onDeletePresent!(s),
        child: chip,
      );
    }
    return chip;
  }
}
