import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cleanuparr_errors.dart';
import '../cleanuparr_providers.dart';
import '../models/cleanuparr_strike.dart';

/// Card representing a download accumulating strikes, with reasons and reset action.
class CleanuparrStrikeCard extends ConsumerWidget {
  const CleanuparrStrikeCard({
    required this.strikeItem,
    required this.instance,
    super.key,
  });

  final CleanuparrStrikeItem strikeItem;
  final Instance instance;

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        final ColorScheme cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('Reset Strikes?'),
          content: Text(
            'Clear all accumulated strikes for "${strikeItem.title}"?\n\n'
            'This removes the item from the strike list and resets its counter.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: cs.errorContainer,
                foregroundColor: cs.onErrorContainer,
              ),
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final api = await ref.read(cleanuparrApiProvider(instance).future);
      await api.deleteStrike(strikeItem.id);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Strikes reset successfully'),
          duration: Duration(seconds: 2),
        ),
      );
      ref.invalidate(cleanuparrStrikesProvider(instance));
      ref.invalidate(cleanuparrStrikesCountProvider(instance));
      ref.invalidate(cleanuparrStatsProvider(instance));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to reset strikes: ${describeCleanuparrError(e)}',
            style: TextStyle(color: Theme.of(context).colorScheme.onError),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final bool isRemoval = strikeItem.isMarkedForRemoval || strikeItem.isRemoved;
    final String strikes =
        '${strikeItem.strikeCount} ${strikeItem.strikeCount == 1 ? 'strike' : 'strikes'}';
    final Color badgeBg = isRemoval
        ? colorScheme.errorContainer
        : colorScheme.tertiaryContainer;
    final Color badgeFg = isRemoval
        ? colorScheme.onErrorContainer
        : colorScheme.onTertiaryContainer;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(borderRadius: Radii.card),
      margin: const EdgeInsets.only(bottom: Insets.sm),
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    strikeItem.title,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.sm,
                    vertical: Insets.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: Radii.chip,
                  ),
                  child: Text(
                    // The ledger keeps an item after Cleanuparr removes it,
                    // until its strikes age out.
                    strikeItem.isRemoved
                        ? '$strikes • Removed'
                        : strikeItem.isMarkedForRemoval
                            ? '$strikes • Removal Pending'
                            : strikes,
                    style: textTheme.labelSmall?.copyWith(
                      color: badgeFg,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.sm),
            Row(
              children: <Widget>[
                if (strikeItem.hash != null && strikeItem.hash!.isNotEmpty) ...<Widget>[
                  Tooltip(
                    message: 'Torrent Info-Hash: ${strikeItem.hash}',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.xs + 2,
                        vertical: Insets.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: Radii.chip,
                      ),
                      child: Text(
                        strikeItem.hash!.length > 8
                            ? strikeItem.hash!.substring(0, 8).toUpperCase()
                            : strikeItem.hash!.toUpperCase(),
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontFamily: 'monospace',
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: Insets.xs),
                ],
                if (strikeItem.strikes.isNotEmpty) ...<Widget>[
                  Flexible(
                    child: Text(
                      strikeItem.strikes.map((s) => s.type).toSet().join(', '),
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.outline,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const Spacer(),
                IconButton(
                  tooltip: 'Reset strikes',
                  icon: Icon(
                    Icons.delete_sweep_outlined,
                    color: colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  // Without an id there is nothing to send, so the button
                  // is off rather than asking and then doing nothing.
                  onPressed: strikeItem.id.isEmpty
                      ? null
                      : () => _confirmClear(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
