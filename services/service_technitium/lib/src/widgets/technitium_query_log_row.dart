import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/technitium_query_log.dart';

final DateFormat _timeFormat = DateFormat.Hms();

/// A single row in the Technitium query log list.
class TechnitiumQueryLogRow extends StatelessWidget {
  const TechnitiumQueryLogRow({
    required this.entry,
    required this.onTap,
    super.key,
  });

  final TechnitiumQueryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    final Color statusColor;
    if (entry.isBlocked) {
      statusColor = cs.error;
    } else if (entry.responseType.toLowerCase().contains('cache')) {
      statusColor = cs.primary;
    } else {
      statusColor = cs.secondary;
    }

    final String timeStr =
        entry.timestamp != null ? _timeFormat.format(entry.timestamp!) : '';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.sm,
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.xs,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                entry.qtype,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    entry.qname,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: <Widget>[
                      if (timeStr.isNotEmpty) ...<Widget>[
                        Text(
                          timeStr,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: Insets.xs),
                        Text(
                          '•',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: Insets.xs),
                      ],
                      Expanded(
                        child: Text(
                          entry.clientName ?? entry.clientIp,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: Insets.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                entry.responseType,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
