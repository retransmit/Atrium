import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import 'release_notes.dart';

/// The label shown for a change category.
String categoryLabel(ChangeCategory category) => switch (category) {
      ChangeCategory.added => 'New',
      ChangeCategory.improved => 'Improved',
      ChangeCategory.fixed => 'Fixed',
    };

/// The dynamic color for a change category, taken from the color scheme.
Color categoryColor(ChangeCategory category, ColorScheme scheme) =>
    switch (category) {
      ChangeCategory.added => scheme.tertiary,
      ChangeCategory.improved => scheme.secondary,
      ChangeCategory.fixed => scheme.primary,
    };

/// One release as a card: version, date, an Installed pill when it is the
/// running version, and its changes grouped by category.
class ReleaseCard extends StatelessWidget {
  const ReleaseCard({
    required this.note,
    required this.installed,
    super.key,
  });

  final ReleaseNote note;
  final bool installed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: Insets.md),
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: installed
            ? scheme.surfaceContainerHighest
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border:
            installed ? Border.all(color: scheme.primary, width: 1.5) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'v${note.version}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              if (installed) ...<Widget>[
                const SizedBox(width: Insets.sm),
                _InstalledPill(scheme: scheme, textTheme: theme.textTheme),
              ],
              const Spacer(),
              Text(
                note.date,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          Divider(height: 1, color: scheme.outlineVariant),
          const SizedBox(height: Insets.sm),
          for (final ChangeGroup group in note.groups) ...<Widget>[
            Padding(
              padding: const EdgeInsets.only(top: Insets.sm, bottom: 4),
              child: Text(
                categoryLabel(group.category),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: categoryColor(group.category, scheme),
                ),
              ),
            ),
            for (final String item in group.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 7, right: Insets.sm),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: scheme.onSurfaceVariant,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: scheme.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _InstalledPill extends StatelessWidget {
  const _InstalledPill({required this.scheme, required this.textTheme});

  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Installed',
        style: textTheme.labelSmall?.copyWith(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
