import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../models/technitium_stats.dart';
import '../technitium_format.dart';

/// Card showing ranked list of clients or domains.
class TechnitiumTopListCard extends StatelessWidget {
  const TechnitiumTopListCard({
    required this.title,
    required this.items,
    required this.icon,
    this.accent,
    this.onTapItem,
    super.key,
  });

  final String title;
  final List<TechnitiumTopItem> items;
  final IconData icon;
  final Color? accent;
  final void Function(TechnitiumTopItem item)? onTapItem;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color color = accent ?? cs.primary;

    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: 20, color: color),
                const SizedBox(width: Insets.sm),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.sm),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Insets.md),
                child: Center(
                  child: Text(
                    'No data for selected period',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              for (int i = 0; i < items.length && i < 10; i++) ...<Widget>[
                if (i > 0) const Divider(height: 1),
                InkWell(
                  onTap: onTapItem != null ? () => onTapItem!(items[i]) : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: Insets.xs,
                      horizontal: Insets.xs,
                    ),
                    child: Row(
                      children: <Widget>[
                        SizedBox(
                          width: 24,
                          child: Text(
                            '${i + 1}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                items[i].name,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (items[i].domain != null)
                                Text(
                                  items[i].domain!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: Insets.sm),
                        Text(
                          formatTechnitiumCompact(items[i].hits),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }
}
