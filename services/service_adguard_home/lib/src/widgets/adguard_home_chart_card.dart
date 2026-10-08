import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import 'adguard_home_series_chart.dart';

/// One of the two figures the Home tab leads with, on a card as wide as the
/// tab: its name, the total with a second figure under it, and its series
/// drawn large enough to read.
class AdguardHomeChartCard extends StatelessWidget {
  const AdguardHomeChartCard({
    required this.label,
    required this.value,
    required this.color,
    required this.series,
    this.detail,
    super.key,
  });

  final String label;
  final String value;

  /// A second, smaller figure under the total, such as its share of all
  /// queries.
  final String? detail;
  final Color color;
  final List<int> series;

  /// How tall the chart is drawn.
  static const double chartHeight = 120;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final TextStyle? valueStyle = theme.textTheme.headlineSmall
        ?.copyWith(fontWeight: FontWeight.w700);
    // One line of the total at the current text size.
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
          children: <Widget>[
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        label,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: Insets.md),
                    // The total takes what it needs up to three fifths of
                    // the card and shrinks past that, so the name beside it
                    // always keeps room.
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth * 0.6,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          SizedBox(
                            height: valueHeight,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
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
                              textAlign: TextAlign.end,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            if (series.length > 1) ...<Widget>[
              const SizedBox(height: Insets.md),
              SizedBox(
                height: chartHeight,
                child: AdguardHomeSeriesChart(series: series, color: color),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
