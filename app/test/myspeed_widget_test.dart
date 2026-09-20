import 'package:atrium/src/dashboard/dashboard_widget_kind.dart';
import 'package:atrium/src/dashboard/widgets/myspeed_widget.dart';
import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:service_myspeed/service_myspeed.dart';

void main() {
  const Instance instance = Instance(
    id: 'myspeed-test-1',
    name: 'Home MySpeed',
    kind: ServiceKind.myspeed,
    localUrl: 'http://192.168.1.100:5216',
    externalUrl: '',
    urlMode: UrlMode.auto,
    auth: InstanceAuth.apiKey(apiKey: 'secret'),
  );

  final MySpeedTest sampleTest = MySpeedTest(
    id: '42',
    download: 350.5,
    upload: 85.2,
    ping: 15.0,
    jitter: 2.0,
    server: 'Cloudflare',
    createdAt: DateTime(2026, 9, 20, 10, 15),
  );

  testWidgets('renders compact MySpeed widget with down, up, and ping metrics',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          myspeedStatusProvider(instance).overrideWith(
            (Ref ref) async => const MySpeedStatus(isRunning: false),
          ),
          myspeedRecentTestsProvider(instance).overrideWith(
            (Ref ref) async => <MySpeedTest>[sampleTest],
          ),
        ],
        child: MaterialApp(
          theme: AtriumTheme.light(null),
          home: const Scaffold(
            body: DashboardMySpeedWidget(
              instances: <Instance>[instance],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('MySpeed'), findsOneWidget);
    expect(find.text('DOWN'), findsOneWidget);
    expect(find.text('350.5'), findsOneWidget);
    expect(find.text('UP'), findsOneWidget);
    expect(find.text('85.2'), findsOneWidget);
    expect(find.text('PING'), findsOneWidget);
    expect(find.text('15'), findsOneWidget);
    expect(find.text('Run test'), findsOneWidget);
    expect(find.textContaining('Cloudflare'), findsOneWidget);
    expect(find.byIcon(Icons.access_time_rounded), findsOneWidget);
    expect(find.text(sampleTest.formattedDate), findsOneWidget);
  });

  testWidgets('run test button displays confirmation dialog and triggers test',
      (WidgetTester tester) async {
    bool didRunSpeedtest = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          myspeedStatusProvider(instance).overrideWith(
            (Ref ref) async => const MySpeedStatus(isRunning: false),
          ),
          myspeedRecentTestsProvider(instance).overrideWith(
            (Ref ref) async => <MySpeedTest>[sampleTest],
          ),
          myspeedApiProvider(instance).overrideWith(
            (Ref ref) async => _MockMySpeedApi(
              onRun: () => didRunSpeedtest = true,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AtriumTheme.light(null),
          home: const Scaffold(
            body: DashboardMySpeedWidget(
              instances: <Instance>[instance],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    // Tap Run test button
    await tester.tap(find.text('Run test'));
    await tester.pumpAndSettle();

    // Dialog appears
    expect(find.text('Run speedtest'), findsOneWidget);
    expect(
      find.text('Start a new speedtest on Home MySpeed?'),
      findsOneWidget,
    );

    // Tap Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(didRunSpeedtest, isFalse);

    // Tap Run test again
    await tester.tap(find.text('Run test'));
    await tester.pumpAndSettle();

    // Tap Start
    await tester.tap(find.text('Start'));
    await tester.pump();

    expect(didRunSpeedtest, isTrue);
    expect(find.text('Speedtest triggered successfully'), findsOneWidget);
  });

  testWidgets('displays running spinner when speedtest is active',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          myspeedStatusProvider(instance).overrideWith(
            (Ref ref) async => const MySpeedStatus(isRunning: true),
          ),
          myspeedRecentTestsProvider(instance).overrideWith(
            (Ref ref) async => <MySpeedTest>[sampleTest],
          ),
        ],
        child: MaterialApp(
          theme: AtriumTheme.light(null),
          home: const Scaffold(
            body: DashboardMySpeedWidget(
              instances: <Instance>[instance],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    // Banner text is not displayed
    expect(find.text('Speedtest running...'), findsNothing);
    // Button shows loading spinner instead of 'Run test' text
    expect(find.text('Run test'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('tapping card opens service details route',
      (WidgetTester tester) async {
    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(
            body: DashboardMySpeedWidget(
              instances: <Instance>[instance],
            ),
          ),
        ),
        GoRoute(
          path: AtriumRoutes.service,
          builder: (BuildContext context, GoRouterState state) => Scaffold(
            body: Text(
              'Opened ${state.pathParameters['kind']} ${state.pathParameters['instanceId']}',
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          myspeedStatusProvider(instance).overrideWith(
            (Ref ref) async => const MySpeedStatus(isRunning: false),
          ),
          myspeedRecentTestsProvider(instance).overrideWith(
            (Ref ref) async => <MySpeedTest>[sampleTest],
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

    await tester.tap(find.text('MySpeed'));
    await tester.pumpAndSettle();

    expect(find.text('Opened myspeed myspeed-test-1'), findsOneWidget);
  });

  testWidgets('the badge and metric box icons follow dynamic theme colors',
      (WidgetTester tester) async {
    final ColorScheme scheme =
        ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4));

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          myspeedStatusProvider(instance).overrideWith(
            (Ref ref) async => const MySpeedStatus(isRunning: false),
          ),
          myspeedRecentTestsProvider(instance).overrideWith(
            (Ref ref) async => <MySpeedTest>[sampleTest],
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(colorScheme: scheme),
          home: const Scaffold(
            body: DashboardMySpeedWidget(
              instances: <Instance>[instance],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final Icon badge = tester.widget<Icon>(
      find.byIcon(DashboardWidgetKind.myspeed.icon),
    );
    expect(badge.color, scheme.primary);

    final Icon downIcon = tester.widget<Icon>(
      find.byIcon(Icons.arrow_downward_rounded),
    );
    expect(downIcon.color, scheme.primary);

    final Icon upIcon = tester.widget<Icon>(
      find.byIcon(Icons.arrow_upward_rounded),
    );
    expect(upIcon.color, scheme.tertiary);

    final Icon pingIcon = tester.widget<Icon>(
      find.byIcon(Icons.timer_outlined),
    );
    expect(pingIcon.color, scheme.secondary);
  });
}

class _MockMySpeedApi extends MySpeedApi {
  _MockMySpeedApi({required this.onRun}) : super(_FakeDio());

  final VoidCallback onRun;

  @override
  Future<bool> runSpeedtest() async {
    onRun();
    return true;
  }
}

class _FakeDio implements Dio {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
