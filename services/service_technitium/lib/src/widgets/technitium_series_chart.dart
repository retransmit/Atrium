import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Renders a dual-line query trend chart over time.
class TechnitiumSeriesChart extends StatelessWidget {
  const TechnitiumSeriesChart({
    required this.series,
    required this.color,
    this.over = const <int>[],
    this.overColor,
    super.key,
  });

  final List<int> series;
  final Color color;
  final List<int> over;
  final Color? overColor;

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) {
      return const SizedBox.shrink();
    }
    final int highest = <int>[...series, ...over].fold<int>(0, math.max);
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (series.length - 1).toDouble(),
        minY: 0,
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
