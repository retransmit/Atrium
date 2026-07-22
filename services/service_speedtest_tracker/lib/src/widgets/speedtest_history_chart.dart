import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/speedtest_tracker_models.dart';

class SpeedtestHistoryChart extends StatelessWidget {
  const SpeedtestHistoryChart({required this.results, super.key});

  final List<SpeedtestResult> results;

  @override
  Widget build(BuildContext context) {
    final List<SpeedtestResult> points = <SpeedtestResult>[
      for (final SpeedtestResult result in results.reversed)
        if (_isUsableSpeed(result.downloadBitsPerSecond) ||
            _isUsableSpeed(result.uploadBitsPerSecond))
          result,
    ];
    if (points.length < 2) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('Run at least two tests to draw a history.')),
      );
    }

    final DateFormat dateFormat = DateFormat.MMMd();
    final String startDate = _dateLabel(points.first.completedAt, dateFormat);
    final String endDate = _dateLabel(points.last.completedAt, dateFormat);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SeriesChart(
          metric: _HistoryMetric.download,
          results: points,
          color: Theme.of(context).colorScheme.primary,
          gridColor: Theme.of(context).colorScheme.outlineVariant,
          startDate: startDate,
          endDate: endDate,
        ),
        const SizedBox(height: 20),
        _SeriesChart(
          metric: _HistoryMetric.upload,
          results: points,
          color: Theme.of(context).colorScheme.tertiary,
          gridColor: Theme.of(context).colorScheme.outlineVariant,
          startDate: startDate,
          endDate: endDate,
        ),
      ],
    );
  }

  String _dateLabel(DateTime? date, DateFormat format) =>
      date == null ? 'Unknown' : format.format(date);
}

enum _HistoryMetric { download, upload }

extension on _HistoryMetric {
  String get title => switch (this) {
        _HistoryMetric.download => 'Download history',
        _HistoryMetric.upload => 'Upload history',
      };

  double? valueOf(SpeedtestResult result) => switch (this) {
        _HistoryMetric.download => result.downloadBitsPerSecond,
        _HistoryMetric.upload => result.uploadBitsPerSecond,
      };
}

class _SeriesChart extends StatelessWidget {
  const _SeriesChart({
    required this.metric,
    required this.results,
    required this.color,
    required this.gridColor,
    required this.startDate,
    required this.endDate,
  });

  static const double _axisWidth = 48;
  static const double _axisGap = 8;

  final _HistoryMetric metric;
  final List<SpeedtestResult> results;
  final Color color;
  final Color gridColor;
  final String startDate;
  final String endDate;

  @override
  Widget build(BuildContext context) {
    final _SeriesScale scale = _SeriesScale.fromResults(results, metric);
    final TextStyle? axisStyle = Theme.of(context).textTheme.labelSmall;
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: scale.hasValues
          ? '${metric.title} chart from $startDate to $endDate, scale zero, '
              'midpoint ${scale.midpointLabel}, maximum '
              '${scale.maximumLabel} ${scale.unit}'
          : 'No usable ${metric.title.toLowerCase()} data',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                metric.title,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(scale.unit, style: axisStyle),
            ],
          ),
          const SizedBox(height: 8),
          if (scale.hasValues) ...<Widget>[
            SizedBox(
              height: 112,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(
                    width: _axisWidth,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        _AxisLabel(scale.maximumLabel, style: axisStyle),
                        _AxisLabel(scale.midpointLabel, style: axisStyle),
                        _AxisLabel('0', style: axisStyle),
                      ],
                    ),
                  ),
                  const SizedBox(width: _axisGap),
                  Expanded(
                    child: CustomPaint(
                      painter: _SeriesPainter(
                        results: results,
                        metric: metric,
                        maximumBitsPerSecond: scale.maximumBitsPerSecond,
                        color: color,
                        gridColor: gridColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: _axisWidth + _axisGap),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      startDate,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: axisStyle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      endDate,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: axisStyle,
                    ),
                  ),
                ],
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child:
                  Center(child: Text('No ${metric.title.toLowerCase()} data')),
            ),
        ],
      ),
    );
  }
}

class _AxisLabel extends StatelessWidget {
  const _AxisLabel(this.value, {required this.style});

  final String value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(value, maxLines: 1, style: style),
        ),
      );
}

class _SeriesPainter extends CustomPainter {
  const _SeriesPainter({
    required this.results,
    required this.metric,
    required this.maximumBitsPerSecond,
    required this.color,
    required this.gridColor,
  });

  final List<SpeedtestResult> results;
  final _HistoryMetric metric;
  final double maximumBitsPerSecond;
  final Color color;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (maximumBitsPerSecond <= 0 || size.width <= 0 || size.height <= 0) {
      return;
    }

    final Paint grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (int i = 0; i <= 2; i++) {
      final double y = (size.height - 1) * i / 2 + 0.5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final Paint line = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final Paint dot = Paint()..color = color;
    final Path path = Path();
    bool started = false;
    for (int i = 0; i < results.length; i++) {
      final double? raw = metric.valueOf(results[i]);
      if (!_isUsableSpeed(raw)) {
        started = false;
        continue;
      }
      final double x = size.width * i / (results.length - 1);
      final double normalized = (raw! / maximumBitsPerSecond).clamp(0, 1);
      final double y = size.height - (normalized * (size.height - 4)) - 2;
      if (started) {
        path.lineTo(x, y);
      } else {
        path.moveTo(x, y);
        started = true;
      }
      canvas.drawCircle(Offset(x, y), 2.5, dot);
    }
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(_SeriesPainter oldDelegate) =>
      oldDelegate.results != results ||
      oldDelegate.metric != metric ||
      oldDelegate.maximumBitsPerSecond != maximumBitsPerSecond ||
      oldDelegate.color != color ||
      oldDelegate.gridColor != gridColor;
}

class _SeriesScale {
  const _SeriesScale({
    required this.hasValues,
    required this.unit,
    required this.maximumDisplayValue,
    required this.maximumBitsPerSecond,
  });

  factory _SeriesScale.fromResults(
    List<SpeedtestResult> results,
    _HistoryMetric metric,
  ) {
    bool hasValues = false;
    double maximum = 0;
    for (final SpeedtestResult result in results) {
      final double? value = metric.valueOf(result);
      if (_isUsableSpeed(value)) {
        hasValues = true;
        maximum = math.max(maximum, value!);
      }
    }
    final bool useGbps = maximum >= 1000000000;
    final double divisor = useGbps ? 1000000000 : 1000000;
    final double roundedMaximum = _roundedUpperBound(maximum / divisor);
    return _SeriesScale(
      hasValues: hasValues,
      unit: useGbps ? 'Gbps' : 'Mbps',
      maximumDisplayValue: roundedMaximum,
      maximumBitsPerSecond: roundedMaximum * divisor,
    );
  }

  final bool hasValues;
  final String unit;
  final double maximumDisplayValue;
  final double maximumBitsPerSecond;

  String get maximumLabel => _formatAxisValue(maximumDisplayValue);
  String get midpointLabel => _formatAxisValue(maximumDisplayValue / 2);
}

bool _isUsableSpeed(double? value) =>
    value != null && value.isFinite && value >= 0;

double _roundedUpperBound(double value) {
  if (!value.isFinite || value <= 0) {
    return 1;
  }
  final double magnitude = math
      .pow(
        10,
        (math.log(value) / math.ln10).floor(),
      )
      .toDouble();
  final double fraction = value / magnitude;
  const List<double> preferredFractions = <double>[
    1,
    1.25,
    1.5,
    2,
    2.5,
    3,
    4,
    5,
  ];
  for (final double preferred in preferredFractions) {
    if (fraction <= preferred) {
      return preferred * magnitude;
    }
  }
  return fraction.ceilToDouble() * magnitude;
}

String _formatAxisValue(double value) {
  final int decimals = value >= 100
      ? 0
      : value >= 10
          ? 1
          : 2;
  final String fixed = value.toStringAsFixed(decimals);
  if (!fixed.contains('.')) {
    return fixed;
  }
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}
