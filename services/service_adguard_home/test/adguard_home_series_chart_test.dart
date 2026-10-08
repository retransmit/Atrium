import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

void main() {
  const Color queries = Color(0xFF2196F3);
  const Color blocked = Color(0xFFF44336);

  /// Pumps [chart] in a box and hands back what it asked the chart
  /// library to draw.
  Future<LineChartData> pump(WidgetTester tester, Widget chart) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: 300, height: 60, child: chart)),
        ),
      ),
    );
    return tester.widget<LineChart>(find.byType(LineChart)).data;
  }

  testWidgets('a second series is drawn over the first on the same scale',
      (WidgetTester tester) async {
    final LineChartData data = await pump(
      tester,
      const AdguardHomeSeriesChart(
        series: <int>[0, 4, 10, 2],
        color: queries,
        over: <int>[0, 1, 3, 0],
        overColor: blocked,
      ),
    );

    expect(data.lineBarsData, hasLength(2));
    expect(data.lineBarsData.first.color, queries);
    expect(data.lineBarsData.last.color, blocked);
    expect(
      data.lineBarsData.last.spots.map((FlSpot spot) => spot.y),
      <double>[0, 1, 3, 0],
    );
    // The first series sets the scale, so the second reads as its share.
    expect(data.maxY, 10);
    expect(data.maxX, 3);
  });

  testWidgets('the scale covers a second series that rises above the first',
      (WidgetTester tester) async {
    final LineChartData data = await pump(
      tester,
      const AdguardHomeSeriesChart(
        series: <int>[0, 4],
        color: queries,
        over: <int>[0, 30],
        overColor: blocked,
      ),
    );

    expect(data.maxY, 30);
  });

  testWidgets('with no second series there is one line',
      (WidgetTester tester) async {
    final LineChartData data = await pump(
      tester,
      const AdguardHomeSeriesChart(series: <int>[0, 4, 10, 2], color: queries),
    );

    expect(data.lineBarsData, hasLength(1));
    expect(data.maxY, 10);
  });
}
