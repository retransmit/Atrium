import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// One of the statistics' series as a filled line, with no axes: the figure
/// beside it says how much, the line says when.
///
/// It fills whatever box it is given.
class AdguardHomeSeriesChart extends StatelessWidget {
  const AdguardHomeSeriesChart({
    required this.series,
    required this.color,
    this.over = const <int>[],
    this.overColor,
    super.key,
  });

  /// One point per hour or per day, oldest first.
  final List<int> series;
  final Color color;

  /// A second series drawn over the first on the same scale, such as the
  /// blocked queries over all of them. Empty for a chart of one line.
  final List<int> over;

  /// The colour of [over]. That of the first series when left out.
  final Color? overColor;

  @override
  Widget build(BuildContext context) {
    final int highest = <int>[...series, ...over].fold<int>(0, math.max);
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
          _line(series, color),
          if (over.isNotEmpty) _line(over, overColor ?? color),
        ],
      ),
    );
  }

  LineChartBarData _line(List<int> points, Color color) {
    return LineChartBarData(
      spots: <FlSpot>[
        for (int i = 0; i < points.length; i++)
          FlSpot(i.toDouble(), points[i].toDouble()),
      ],
      color: color,
      isCurved: true,
      preventCurveOverShooting: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.12),
      ),
    );
  }
}
