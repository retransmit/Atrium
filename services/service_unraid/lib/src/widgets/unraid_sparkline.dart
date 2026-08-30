import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// A small filled line chart for a rolling window of samples.
///
/// Deliberately bare: no axes, no labels, no grid. The number it sits under
/// says what the value is; this only has to say which way it has been going,
/// and chart furniture at this size costs more room than it repays.
class UnraidSparkline extends StatelessWidget {
  const UnraidSparkline({
    required this.values,
    required this.color,
    this.maxY,
    this.secondaryValues,
    this.secondaryColor,
    this.height = 48,
    super.key,
  });

  /// Samples, oldest first.
  final List<double> values;

  final Color color;

  /// Fixed upper bound, for a percentage. Null scales to whatever has been
  /// seen, which is what a rate needs.
  final double? maxY;

  /// A second line on the same axes, for send against receive.
  final List<double>? secondaryValues;
  final Color? secondaryColor;

  final double height;

  /// The window is drawn against a fixed width so a half-full one fills the
  /// left and grows rightwards, rather than stretching two points across the
  /// whole card and implying a history that is not there.
  static const double _window = 59;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final List<double>? second = secondaryValues;

    double top = maxY ??
        <double>[
          ...values,
          ...?second,
        ].fold<double>(0, (double a, double b) => a > b ? a : b);
    // A flat line at zero would otherwise be drawn against a zero-height axis.
    if (top <= 0) top = 1;

    List<FlSpot> spots(List<double> source) => <FlSpot>[
          for (int i = 0; i < source.length; i++)
            FlSpot(i.toDouble(), source[i].clamp(0, top)),
        ];

    LineChartBarData bar(List<double> source, Color c) => LineChartBarData(
          spots: spots(source),
          color: c,
          barWidth: 1.8,
          isCurved: true,
          // Curved lines can overshoot into negative space on a sharp drop,
          // which draws a dip below zero that never happened.
          preventCurveOverShooting: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: c.withValues(alpha: 0.30),
          ),
        );

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: _window,
          minY: 0,
          maxY: top,
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.18),
          lineBarsData: <LineChartBarData>[
            bar(values, color),
            if (second != null && secondaryColor != null)
              bar(second, secondaryColor!),
          ],
        ),
        duration: Duration.zero,
      ),
    );
  }
}
