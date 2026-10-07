import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../models/adguard_home_stats.dart';

/// One of the "top" lists: names with a figure each and a bar for scale.
class AdguardHomeTopList extends StatelessWidget {
  const AdguardHomeTopList({
    required this.title,
    required this.rows,
    required this.format,
    this.actionIcon,
    this.actionLabel,
    this.onAction,
    this.limit = 10,
    super.key,
  });

  final String title;
  final List<AdguardHomeCount> rows;

  /// How a row's figure is written.
  final String Function(num value) format;

  /// With [actionLabel] and [onAction], a button on each row. Its tooltip
  /// is the label followed by the row's name, "Block example.com".
  final IconData? actionIcon;
  final String? actionLabel;
  final void Function(String name)? onAction;

  /// The server sends up to a hundred rows. A phone shows the first few.
  final int limit;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final List<AdguardHomeCount> shown = rows.take(limit).toList();
    final num highest = shown.fold<num>(
      0,
      (num top, AdguardHomeCount row) => row.value > top ? row.value : top,
    );

    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: Insets.sm),
            if (shown.isEmpty)
              Text(
                'Nothing yet',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            for (final AdguardHomeCount row in shown)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Insets.xs),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            row.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: Insets.xs),
                          LinearProgressIndicator(
                            value: highest <= 0 ? 0 : row.value / highest,
                            minHeight: 4,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Insets.md),
                    // A long figure shrinks rather than push the row past
                    // its width on a narrow screen at large text.
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          format(row.value),
                          style: theme.textTheme.labelLarge,
                        ),
                      ),
                    ),
                    if (onAction != null)
                      IconButton(
                        icon: Icon(actionIcon),
                        tooltip: '$actionLabel ${row.name}',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onAction!(row.name),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
