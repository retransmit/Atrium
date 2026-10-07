import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../adguard_home_format.dart';
import '../models/adguard_home_query_log.dart';
import 'adguard_home_result_chip.dart';

/// One query of the log: the name and when on the first line, what came of
/// it, the record type, the client and how long it took on the second.
class AdguardHomeQueryLogRow extends StatelessWidget {
  const AdguardHomeQueryLogRow({
    required this.entry,
    required this.now,
    this.onTap,
    super.key,
  });

  final AdguardHomeQueryLogEntry entry;

  /// The moment the row is drawn at, which decides whether its time needs a
  /// date in front.
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final TextStyle? muted =
        theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant);
    final String client = entry.clientLabel;
    final String who =
        client.isEmpty ? entry.type : '${entry.type} · $client';
    final String elapsed = formatAdguardHomeElapsed(entry.elapsed);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: 10,
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double width = constraints.maxWidth;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        entry.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    // A date and a time at large text would take the line
                    // from the name, so they shrink past half of it.
                    _Shrinking(
                      maxWidth: width * 0.5,
                      child: Text(
                        formatAdguardHomeLogTime(entry.time, now),
                        style: muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: width * 0.5),
                      child: AdguardHomeResultChip(
                        label: entry.resultLabel,
                        tone: entry.result.tone,
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    if (entry.clientDisallowed) ...<Widget>[
                      Icon(
                        Icons.block,
                        size: 14,
                        color: cs.error,
                        semanticLabel: 'Disallowed client',
                      ),
                      const SizedBox(width: Insets.xs),
                    ],
                    Expanded(
                      child: Text(
                        who,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: muted,
                      ),
                    ),
                    if (elapsed.isNotEmpty) ...<Widget>[
                      const SizedBox(width: Insets.sm),
                      _Shrinking(
                        maxWidth: width * 0.25,
                        child: Text(elapsed, style: muted),
                      ),
                    ],
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Lets [child] take the width it needs up to [maxWidth], and draws it
/// smaller past that instead of cutting it off.
class _Shrinking extends StatelessWidget {
  const _Shrinking({required this.maxWidth, required this.child});

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: child,
      ),
    );
  }
}
