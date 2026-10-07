import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';

import '../adguard_home_top_lists.dart';
import '../models/adguard_home_stats.dart';

/// The largest figure among [rows], which a row's bar is drawn against.
num adguardHomeHighest(List<AdguardHomeCount> rows) => rows.fold<num>(
      0,
      (num top, AdguardHomeCount row) => row.value > top ? row.value : top,
    );

/// One of the "top" lists as a card: its first few rows, the rest added up,
/// and a way to see them all.
class AdguardHomeTopList extends StatelessWidget {
  const AdguardHomeTopList({
    required this.kind,
    required this.rows,
    this.onBlocking,
    this.onViewAll,
    this.limit = 5,
    super.key,
  });

  final AdguardHomeTopListKind kind;
  final List<AdguardHomeCount> rows;

  /// Blocks or unblocks a row's domain. Only the lists of domains use it.
  final void Function(String domain, {required bool block})? onBlocking;

  /// Opens the whole list. Offered only when there are more rows than the
  /// card shows.
  final VoidCallback? onViewAll;

  /// How many rows the card shows. The server sends up to a hundred.
  final int limit;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final List<AdguardHomeCount> shown = rows.take(limit).toList();
    final List<AdguardHomeCount> rest = rows.skip(limit).toList();
    final num highest = adguardHomeHighest(rows);
    final bool hasButtons = kind.blocks != null && onBlocking != null;

    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              kind.title,
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
              AdguardHomeTopRow(
                kind: kind,
                row: row,
                highest: highest,
                onBlocking: onBlocking,
              ),
            if (rest.isNotEmpty && kind.addsUp)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Insets.xs),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Others',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(width: Insets.md),
                    _Figure(
                      kind.format(
                        rest.fold<num>(
                          0,
                          (num sum, AdguardHomeCount row) => sum + row.value,
                        ),
                      ),
                      color: cs.onSurfaceVariant,
                    ),
                    // Keeps this figure under the others when the rows above
                    // end in a button.
                    if (hasButtons) const SizedBox(width: _buttonWidth),
                  ],
                ),
              ),
            if (rest.isNotEmpty && onViewAll != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onViewAll,
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  iconAlignment: IconAlignment.end,
                  label: const Text('View all'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The width a row's compact button takes.
const double _buttonWidth = 40;

/// One row of a "top" list: a name, a bar for scale, a figure, and for a
/// domain the button that blocks or unblocks it.
class AdguardHomeTopRow extends StatelessWidget {
  const AdguardHomeTopRow({
    required this.kind,
    required this.row,
    required this.highest,
    this.onBlocking,
    super.key,
  });

  final AdguardHomeTopListKind kind;
  final AdguardHomeCount row;

  /// The largest figure of the list, for the bar's scale.
  final num highest;

  /// Blocks or unblocks the row's domain. Only the lists of domains use it.
  final void Function(String domain, {required bool block})? onBlocking;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool? blocks = kind.blocks;
    final void Function(String domain, {required bool block})? onBlocking =
        this.onBlocking;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xs),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        row.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: Insets.md),
                    _Figure(kind.format(row.value)),
                  ],
                ),
                const SizedBox(height: Insets.xs),
                // Under the name and the figure both, so that the bars of a
                // list are all as long and can be read against each other
                // whatever the length of the figures.
                LinearProgressIndicatorM3E(
                  value: highest <= 0 ? 0 : row.value / highest,
                  size: LinearProgressM3ESize.s,
                  shape: ProgressM3EShape.flat,
                  activeColor: theme.colorScheme.primary,
                  trackColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ],
            ),
          ),
          if (blocks != null && onBlocking != null)
            IconButton(
              icon: Icon(blocks ? Icons.block : Icons.check_circle_outline),
              tooltip: '${blocks ? 'Block' : 'Unblock'} ${row.name}',
              visualDensity: VisualDensity.compact,
              onPressed: () => onBlocking(row.name, block: blocks),
            ),
        ],
      ),
    );
  }
}

/// A row's figure. A long one shrinks rather than push the row past its
/// width on a narrow screen at large text.
class _Figure extends StatelessWidget {
  const _Figure(this.text, {this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 120),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
        ),
      ),
    );
  }
}
