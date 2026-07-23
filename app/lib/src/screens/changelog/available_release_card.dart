import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../external_links.dart';
import '../../update_check/update_checker.dart';
import 'notes_markdown.dart';

/// Pinned at the top of the Change log when an update is available: the new
/// version, its date, its "What's new" read inline, and a link to the full
/// release. Reads state only; never fetches.
class AvailableReleaseCard extends ConsumerWidget {
  const AvailableReleaseCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateCheckProvider);
    if (!state.hasNewer) return const SizedBox.shrink();
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String? notes = state.latestNotes;
    return Container(
      margin: const EdgeInsets.only(bottom: Insets.md),
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.tertiary, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'v${state.latestVersion}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(width: Insets.sm),
              _AvailablePill(scheme: scheme, textTheme: theme.textTheme),
              const Spacer(),
              if (state.latestDate != null)
                Text(
                  state.latestDate!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          Divider(height: 1, color: scheme.outlineVariant),
          const SizedBox(height: Insets.sm),
          if (notes != null) ...buildNotes(notes, theme),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => openExternal(
                ScaffoldMessenger.of(context),
                state.releaseUrl ?? AtriumLinks.releases,
              ),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('See full release'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailablePill extends StatelessWidget {
  const _AvailablePill({required this.scheme, required this.textTheme});

  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Available',
        style: textTheme.labelSmall?.copyWith(
          color: scheme.onTertiaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
