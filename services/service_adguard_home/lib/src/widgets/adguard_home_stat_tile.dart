import 'dart:math' as math;

import 'package:core_ui/core_ui.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

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
                // narrow screen at any text size.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
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
                child: SizedBox(height: 36, child: _Sparkline(series, color)),
              ),
          ],
        ),
      ),
    );
  }
}

class _Sparkline extends StatelessWidget {
  const _Sparkline(this.series, this.color);

  final List<int> series;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final int highest = series.fold<int>(0, math.max);
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (series.length - 1).toDouble(),
        minY: 0,
        // A flat line of zeros still needs some height to sit in.
        maxY: math.max(1, highest).toDouble(),
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: <LineChartBarData>[
          LineChartBarData(
            spots: <FlSpot>[
              for (int i = 0; i < series.length; i++)
                FlSpot(i.toDouble(), series[i].toDouble()),
            ],
            color: color,
            isCurved: true,
            preventCurveOverShooting: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}
