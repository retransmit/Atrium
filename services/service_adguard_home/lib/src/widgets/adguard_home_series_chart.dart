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
    super.key,
  });

  /// One point per hour or per day, oldest first.
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
