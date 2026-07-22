import 'dart:async';

import 'package:atrium/src/dashboard/dashboard_board.dart';
import 'package:atrium/src/dashboard/widgets/speedtest_results_widget.dart';
import 'package:core_profile/core_profile.dart';
import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:service_speedtest_tracker/service_speedtest_tracker.dart';

void main() {
  testWidgets('dashboard renders multiple instances and opens the tapped one',
      (WidgetTester tester) async {
    final Instance first = _instance('first', 'Home tracker');
    final Instance second = _instance('second', 'Remote tracker');
    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              DashboardSpeedtestResultsWidget(
            instances: <Instance>[first, second],
          ),
        ),
        GoRoute(
          path: AtriumRoutes.service,
          builder: (BuildContext context, GoRouterState state) => Text(
            'Opened ${state.pathParameters['instanceId']}',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          speedtestOverviewProvider(first).overrideWith(
            (Ref ref) async => _overview(1),
          ),
          speedtestOverviewProvider(second).overrideWith(
            (Ref ref) async => _overview(2),
          ),
        ],
        child: MaterialApp.router(
          theme: AtriumTheme.light(null),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Speedtest results'), findsOneWidget);
    expect(find.text('Home tracker'), findsOneWidget);
    expect(find.text('Remote tracker'), findsOneWidget);
    expect(find.text('800 Mbps'), findsNWidgets(2));
    expect(find.text('200 Mbps'), findsNWidgets(2));
    expect(find.text('12.4 ms'), findsNWidgets(2));
    expect(find.text('0.5%'), findsNWidgets(2));

    await tester.tap(find.text('Remote tracker'));
    await tester.pumpAndSettle();
    expect(find.text('Opened second'), findsOneWidget);
  });

  testWidgets('dashboard board registers the widget for a configured instance',
      (WidgetTester tester) async {
    final Instance instance = _instance('board', 'Board tracker');
    await _pumpWidget(
      tester,
      <Override>[
        activeInstancesProvider.overrideWithValue(<Instance>[instance]),
        speedtestOverviewProvider(instance).overrideWith(
          (Ref ref) async => _overview(1),
        ),
      ],
      const DashboardBoard(),
      pumps: 3,
    );

    expect(find.text('Speedtest results'), findsOneWidget);
    expect(find.text('800 Mbps'), findsOneWidget);
  });

  testWidgets('dashboard distinguishes auth and malformed response errors',
      (WidgetTester tester) async {
    final Instance auth = _instance('auth', 'Auth tracker');
    final Instance malformed = _instance('malformed', 'Malformed tracker');

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          speedtestOverviewProvider(auth).overrideWith(
            (Ref ref) async => throw const SpeedtestTrackerException(
              SpeedtestErrorKind.authentication,
              'The bearer token was rejected.',
            ),
          ),
          speedtestOverviewProvider(malformed).overrideWith(
            (Ref ref) async => throw const SpeedtestTrackerException(
              SpeedtestErrorKind.malformed,
              'The result history response is unsupported.',
            ),
          ),
        ],
        child: MaterialApp(
          theme: AtriumTheme.light(null),
          home: Scaffold(
            body: DashboardSpeedtestResultsWidget(
              instances: <Instance>[auth, malformed],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('The bearer token was rejected.'), findsOneWidget);
    expect(
      find.text('The result history response is unsupported.'),
      findsOneWidget,
    );
  });

  testWidgets('dashboard shows latest failed state over completed metrics',
      (WidgetTester tester) async {
    final Instance instance = _instance('failed', 'Failed tracker');
    final SpeedtestResult completed = _completed(1);
    final SpeedtestOverview overview = SpeedtestOverview(
      latestAny: const SpeedtestResult(
        id: 2,
        status: SpeedtestResultStatus.failed,
      ),
      completedResults: <SpeedtestResult>[completed],
    );

    await _pumpWidget(
      tester,
      <Override>[
        speedtestOverviewProvider(instance).overrideWith(
          (Ref ref) async => overview,
        ),
      ],
      DashboardSpeedtestResultsWidget(instances: <Instance>[instance]),
    );

    expect(find.text('Latest speed test failed'), findsOneWidget);
    expect(find.text('800 Mbps'), findsOneWidget);
  });

  testWidgets('dashboard renders loading, empty, running, and offline states',
      (WidgetTester tester) async {
    final Instance loading = _instance('loading', 'Loading tracker');
    final Instance empty = _instance('empty', 'Empty tracker');
    final Instance running = _instance('running', 'Running tracker');
    final Instance offline = _instance('offline', 'Offline tracker');
    final Completer<SpeedtestOverview> pending = Completer<SpeedtestOverview>();

    await _pumpWidget(
      tester,
      <Override>[
        speedtestOverviewProvider(loading).overrideWith(
          (Ref ref) => pending.future,
        ),
        speedtestOverviewProvider(empty).overrideWith(
          (Ref ref) async => const SpeedtestOverview(
            latestAny: null,
            completedResults: <SpeedtestResult>[],
          ),
        ),
        speedtestOverviewProvider(running).overrideWith(
          (Ref ref) async => const SpeedtestOverview(
            latestAny: SpeedtestResult(
              id: 9,
              status: SpeedtestResultStatus.running,
            ),
            completedResults: <SpeedtestResult>[],
          ),
        ),
        speedtestOverviewProvider(offline).overrideWith(
          (Ref ref) async => throw const SpeedtestTrackerException(
            SpeedtestErrorKind.offline,
            'Could not reach Speedtest Tracker.',
          ),
        ),
      ],
      DashboardSpeedtestResultsWidget(
        instances: <Instance>[loading, empty, running, offline],
      ),
      pumps: 2,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No completed results'), findsOneWidget);
    expect(find.text('Latest speed test is running'), findsOneWidget);
    expect(find.text('Could not reach Speedtest Tracker.'), findsOneWidget);
  });

  testWidgets('full service page renders latest, chart, and history',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final Instance instance = _instance('home', 'Home tracker');
    final List<SpeedtestResult> results = <SpeedtestResult>[
      _completed(2, measuredAt: DateTime(2026, 7, 20, 12)),
      _completed(1, measuredAt: DateTime(2026, 7, 19, 12)),
    ];

    await _pumpWidget(
      tester,
      <Override>[
        speedtestOverviewProvider(instance).overrideWith(
          (Ref ref) async => SpeedtestOverview(
            latestAny: results.first,
            completedResults: results,
          ),
        ),
        speedtestHistoryProvider(
          (instance: instance, page: 1, pageSize: 25),
        ).overrideWith(
          (Ref ref) async => SpeedtestResultsPage(
            results: results,
            page: 1,
            hasMore: false,
          ),
        ),
      ],
      SpeedtestTrackerHome(instance: instance),
      pumps: 3,
    );

    expect(find.text('Latest result'), findsOneWidget);
    expect(find.text('Download and upload history'), findsOneWidget);
    expect(find.text('Recent history'), findsOneWidget);
    expect(find.text('Download'), findsWidgets);
    expect(find.text('Upload'), findsWidgets);
    expect(find.text('Run test'), findsOneWidget);
  });
}

Instance _instance(String id, String name) => Instance(
      id: id,
      name: name,
      kind: ServiceKind.speedtestTracker,
      localUrl: 'https://tracker.example.test',
      externalUrl: '',
      urlMode: UrlMode.forceLocal,
      auth: const InstanceAuth.apiKey(apiKey: 'placeholder-token'),
    );

SpeedtestOverview _overview(int id) {
  final SpeedtestResult result = _completed(id);
  return SpeedtestOverview(
    latestAny: result,
    completedResults: <SpeedtestResult>[result],
  );
}

SpeedtestResult _completed(int id, {DateTime? measuredAt}) => SpeedtestResult(
      id: id,
      status: SpeedtestResultStatus.completed,
      downloadBitsPerSecond: 800000000,
      uploadBitsPerSecond: 200000000,
      pingMilliseconds: 12.4,
      packetLossPercent: 0.5,
      server: const SpeedtestServer(name: 'Example server'),
      isp: 'Example Fiber',
      measuredAt: measuredAt ?? DateTime(2026, 7, 20, 12),
    );

Future<void> _pumpWidget(
  WidgetTester tester,
  List<Override> overrides,
  Widget child, {
  int pumps = 2,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AtriumTheme.light(null),
        home: Scaffold(body: child),
      ),
    ),
  );
  for (int index = 0; index < pumps; index++) {
    await tester.pump();
  }
}
