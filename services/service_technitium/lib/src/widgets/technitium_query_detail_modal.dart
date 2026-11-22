import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../models/technitium_query_log.dart';

/// Modal bottom sheet showing query details with a one-tap block action.
class TechnitiumQueryDetailModal extends StatelessWidget {
  const TechnitiumQueryDetailModal({
    required this.entry,
    required this.onBlockDomain,
    super.key,
  });

  final TechnitiumQueryEntry entry;
  final Future<void> Function(String domain) onBlockDomain;

  static Future<void> show(
    BuildContext context, {
    required TechnitiumQueryEntry entry,
    required Future<void> Function(String domain) onBlockDomain,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext ctx) => TechnitiumQueryDetailModal(
        entry: entry,
        onBlockDomain: onBlockDomain,
      ),
    );
  }

  Widget _row(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.sm,
                    vertical: Insets.xs,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    entry.qtype,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(
                    entry.qname,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.md),
            const Divider(),
            const SizedBox(height: Insets.xs),
            _row(theme, 'Client IP', entry.clientIp),
            if (entry.clientName != null)
              _row(theme, 'Client name', entry.clientName!),
            _row(theme, 'Response type', entry.responseType),
            _row(theme, 'RCODE', entry.rcode),
            _row(theme, 'Protocol', entry.protocol),
            if (entry.roundTripTimeMs > 0)
              _row(theme, 'Round trip time', '${entry.roundTripTimeMs} ms'),
            if (entry.answer.isNotEmpty) _row(theme, 'Answer', entry.answer),
            const SizedBox(height: Insets.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: entry.isBlocked ? cs.secondary : cs.error,
                  foregroundColor:
                      entry.isBlocked ? cs.onSecondary : cs.onError,
                  padding: const EdgeInsets.symmetric(vertical: Insets.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () async {
                  Navigator.of(context).pop();
                  await onBlockDomain(entry.qname);
                },
                icon: Icon(
                  entry.isBlocked ? Icons.check_circle_outline : Icons.block,
                ),
                label: Text(
                  entry.isBlocked ? 'Already Blocked (Re-add)' : 'Block domain',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
