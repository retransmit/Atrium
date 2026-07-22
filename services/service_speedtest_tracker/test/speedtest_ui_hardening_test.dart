import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_speedtest_tracker/service_speedtest_tracker.dart';
import 'package:service_speedtest_tracker/src/widgets/speedtest_history_chart.dart';
import 'package:service_speedtest_tracker/src/widgets/speedtest_result_views.dart';

void main() {
  testWidgets('stacked charts fit a narrow large-text layout',
      (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(240, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(240, 600),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: SpeedtestHistoryChart(
              results: <SpeedtestResult>[
                _result(1, 900000000, 100000000),
                _result(2, 1500000000, 200000000),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Download history'), findsOneWidget);
    expect(find.text('Upload history'), findsOneWidget);
    expect(find.text('Gbps'), findsOneWidget);
    expect(find.text('Mbps'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('download and upload use independent rounded Mbps scales',
      (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpeedtestHistoryChart(
            results: <SpeedtestResult>[
              _result(1, 650000000, 175000000),
              _result(2, 687000000, 188000000),
            ],
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Download history chart.*midpoint 350, maximum 700 Mbps'),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        RegExp(r'Upload history chart.*midpoint 100, maximum 200 Mbps'),
      ),
      findsOneWidget,
    );
    expect(find.text('700'), findsOneWidget);
    expect(find.text('350'), findsOneWidget);
    expect(find.text('200'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(2));
    semantics.dispose();
  });

  testWidgets('large download values use a rounded Gbps scale',
      (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpeedtestHistoryChart(
            results: <SpeedtestResult>[
              _result(1, 1250000000, 90000000),
              _result(2, 1420000000, 100000000),
            ],
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp(r'Download history chart.*midpoint 0.75, maximum 1.5 Gbps'),
      ),
      findsOneWidget,
    );
    expect(find.text('1.5'), findsOneWidget);
    expect(find.text('0.75'), findsOneWidget);
    expect(find.text('Gbps'), findsOneWidget);
    expect(find.text('Mbps'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('empty and single-result chart behavior remains explicit',
      (WidgetTester tester) async {
    for (final List<SpeedtestResult> results in <List<SpeedtestResult>>[
      const <SpeedtestResult>[],
      <SpeedtestResult>[_result(1, 100000000, 50000000)],
    ]) {
      await tester.pumpWidget(
        MaterialApp(home: SpeedtestHistoryChart(results: results)),
      );
      expect(
        find.text('Run at least two tests to draw a history.'),
        findsOneWidget,
      );
    }
  });

  testWidgets('chart omits manually constructed invalid speed values',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SpeedtestHistoryChart(
          results: <SpeedtestResult>[
            _result(1, double.nan, -1),
            _result(2, double.infinity, -2),
          ],
        ),
      ),
    );

    expect(
      find.text('Run at least two tests to draw a history.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('latest card does not render an empty metadata text row',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpeedtestLatestCard(
            result: _result(1, 100000000, 50000000),
          ),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (Widget widget) => widget is Text && widget.data == '',
      ),
      findsNothing,
    );
  });
}

SpeedtestResult _result(int id, double download, double upload) =>
    SpeedtestResult(
      id: id,
      status: SpeedtestResultStatus.completed,
      downloadBitsPerSecond: download,
      uploadBitsPerSecond: upload,
      measuredAt: DateTime.utc(2026, 7, 20 + id),
    );
