import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import 'adguard_home_series_chart.dart';

/// One figure of the statistics, with its series drawn small beneath it
/// where the server sends one.
class AdguardHomeStatTile extends StatelessWidget {
  const AdguardHomeStatTile({
    required this.label,
    required this.value,
    required this.color,
    this.detail,
    this.series = const <int>[],
    super.key,
  });

  final String label;
  final String value;

  /// A second, smaller figure, such as the share of all queries.
  final String? detail;
  final Color color;
  final List<int> series;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final TextStyle? valueStyle = theme.textTheme.headlineSmall
        ?.copyWith(fontWeight: FontWeight.w700);
    // One line of the figure at the current text size.
    final double valueHeight = (MediaQuery.textScalerOf(context)
                .scale(valueStyle?.fontSize ?? 24) *
            (valueStyle?.height ?? 1.33))
        .ceilToDouble();
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          // Beside a taller tile this one is stretched to match, and the
          // chart then goes to the bottom, so the two charts line up.
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: Insets.xs),
                // A count in the hundreds of millions has to fit half a
                // narrow screen at any text size, so it shrinks to fit. The
                // box keeps the height of one full-size line whatever the
                // figure shrinks to: a row sizes its tiles before the
                // shrinking, and would otherwise leave a gap above the chart.
                SizedBox(
                  height: valueHeight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      maxLines: 1,
                      softWrap: false,
                      style: valueStyle,
                    ),
                  ),
                ),
                if (detail != null)
                  Text(
                    detail!,
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: color, fontWeight: FontWeight.w700),
                  ),
              ],
            ),
            if (series.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: Insets.sm),
                child: SizedBox(
                  height: 36,
                  child: AdguardHomeSeriesChart(series: series, color: color),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
