import 'package:atrium/src/dashboard/widgets/adguard_home_widget.dart';
import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:service_adguard_home/service_adguard_home.dart';

/// Stands in for [AdguardHomeActions], noting what the widget asked for
/// instead of sending anything.
class _RecordingActions extends AdguardHomeActions {
  _RecordingActions(super.ref, super.instance);

  final List<String> calls = <String>[];

  @override
  Future<void> setProtection({required bool enabled, Duration? pause}) async {
    calls.add('protection enabled=$enabled pause=${pause?.inSeconds}');
  }

  @override
  void retrySignIn() => calls.add('retry');

  @override
  void refresh() => calls.add('refresh');
}

void main() {
  const Instance home = Instance(
    id: 'adguard-1',
    name: 'Home DNS',
    kind: ServiceKind.adguardHome,
    localUrl: 'http://192.168.1.2',
    externalUrl: '',
    urlMode: UrlMode.auto,
    auth: InstanceAuth.userPass(username: 'admin', password: 'not-a-secret'),
  );
  final DateTime readAt = DateTime(2026, 10, 7, 18, 30);

  AdguardHomeStatus statusWith({
    bool enabled = true,
    Duration pauseLeft = Duration.zero,
  }) =>
      AdguardHomeStatus(
        version: 'v0.107.79',
        running: true,
        protectionEnabled: enabled,
        pauseLeft: pauseLeft,
        readAt: readAt,
      );

  const AdguardHomeFiltering filtering = AdguardHomeFiltering(
    blocklists: <AdguardHomeFilterList>[
      AdguardHomeFilterList(
        id: 1,
        name: 'On',
        url: 'https://lists.example/1.txt',
        enabled: true,
        rulesCount: 724480,
      ),
      AdguardHomeFilterList(
        id: 2,
        name: 'Off',
        url: 'https://lists.example/2.txt',
        enabled: false,
        rulesCount: 99999,
      ),
    ],
  );

  /// The reads answered from fixed values, and the actions recorded.
  List<Override> overridesFor(
    List<Instance> instances, {
    AdguardHomeStatus? status,
    Object? statusError,
    Object? statsError,
  }) =>
      <Override>[
        for (final Instance instance in instances) ...<Override>[
          adguardHomeStatusProvider(instance).overrideWith((Ref ref) async {
            if (statusError != null) throw statusError;
            return status!;
          }),
          adguardHomeStatsProvider(instance).overrideWith((Ref ref) async {
            if (statsError != null) throw statsError;
            return const AdguardHomeStats(queries: 5690, blockedByFilters: 740);
          }),
          adguardHomeFilteringProvider(instance)
              .overrideWith((Ref ref) async => filtering),
          adguardHomeActionsProvider(instance)
              .overrideWith((Ref ref) => _RecordingActions(ref, instance)),
        ],
      ];

  /// Pumps the widget and hands back the first instance's recorded actions.
  Future<_RecordingActions> pumpWidget(
    WidgetTester tester, {
    List<Instance> instances = const <Instance>[home],
    AdguardHomeStatus? status,
    Object? statusError,
    Object? statsError,
    Size size = const Size(411, 900),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: overridesFor(
          instances,
          status: status,
          statusError: statusError,
          statsError: statsError,
        ),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DashboardAdguardHomeWidget(
                instances: instances,
                now: () => readAt,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return ProviderScope.containerOf(
      tester.element(find.byType(DashboardAdguardHomeWidget)),
      listen: false,
    ).read(adguardHomeActionsProvider(instances.first)) as _RecordingActions;
  }

  testWidgets('shows the state and the four figures the issue asks for',
      (WidgetTester tester) async {
    await pumpWidget(tester, status: statusWith());

    expect(find.text('AdGuard Home'), findsOneWidget);
    expect(find.text('PROTECTED'), findsOneWidget);
    expect(find.text('Queries'), findsOneWidget);
    expect(find.text('5.69K'), findsOneWidget);
    expect(find.text('Blocked'), findsOneWidget);
    expect(find.text('740'), findsOneWidget);
    expect(find.text('Blocked %'), findsOneWidget);
    expect(find.text('13.01%'), findsOneWidget);
    // Only the list that is switched on counts.
    expect(find.text('Rules'), findsOneWidget);
    expect(find.text('724K'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the pause menu offers the five pauses and plain off',
      (WidgetTester tester) async {
    final _RecordingActions actions =
        await pumpWidget(tester, status: statusWith());

    await tester.tap(find.byTooltip('Pause protection'));
    await tester.pumpAndSettle();
    for (final String label in <String>[
      '30 seconds',
      '1 minute',
      '10 minutes',
      '1 hour',
      'Until tomorrow',
      'Until turned back on',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('10 minutes'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Pause protection'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Until turned back on'));
    await tester.pumpAndSettle();

    expect(actions.calls, <String>[
      'protection enabled=false pause=600',
      'protection enabled=false pause=null',
    ]);
  });

  testWidgets('a paused server shows the time left and can be resumed',
      (WidgetTester tester) async {
    final _RecordingActions actions = await pumpWidget(
      tester,
      status: statusWith(
        enabled: false,
        pauseLeft: const Duration(minutes: 9, seconds: 41),
      ),
    );

    expect(find.text('PAUSED'), findsOneWidget);
    expect(find.text('9:41'), findsOneWidget);
    expect(find.byTooltip('Pause protection'), findsNothing);

    await tester.tap(find.text('Resume'));
    await tester.pump();
    await tester.pump();

    expect(actions.calls, <String>['protection enabled=true pause=null']);
  });

  testWidgets('a server that is off says so and can be resumed',
      (WidgetTester tester) async {
    await pumpWidget(tester, status: statusWith(enabled: false));

    expect(find.text('OFF'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
    expect(find.byType(AdguardHomeCountdown), findsNothing);
  });

  testWidgets('a refused sign-in is said plainly and retried only on request',
      (WidgetTester tester) async {
    final _RecordingActions actions = await pumpWidget(
      tester,
      statusError: const AdguardHomeSignInRefused(),
    );

    expect(find.textContaining('refused the sign-in'), findsOneWidget);
    expect(find.textContaining('15 minutes'), findsOneWidget);
    expect(find.text('Queries'), findsNothing);
    expect(actions.calls, isEmpty);

    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(actions.calls, <String>['retry']);
  });

  testWidgets('any other failure shows the usual error row of the board',
      (WidgetTester tester) async {
    final _RecordingActions actions = await pumpWidget(
      tester,
      statusError: const AdguardHomeUnexpectedAnswer(),
    );

    expect(find.text('Could not load'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();

    expect(actions.calls, <String>['refresh']);
  });

  testWidgets('statistics that fail leave dashes, not a broken card',
      (WidgetTester tester) async {
    await pumpWidget(
      tester,
      status: statusWith(),
      statsError: const AdguardHomeUnexpectedAnswer(),
    );

    expect(find.text('PROTECTED'), findsOneWidget);
    // Queries, Blocked and Blocked % wait. Rules comes from the filter lists.
    expect(find.text('-'), findsNWidgets(3));
    expect(find.text('724K'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('two instances are told apart by name',
      (WidgetTester tester) async {
    final Instance second = home.copyWith(id: 'adguard-2', name: 'Cabin DNS');
    await pumpWidget(
      tester,
      status: statusWith(),
      instances: <Instance>[home, second],
    );

    expect(find.text('Home DNS'), findsOneWidget);
    expect(find.text('Cabin DNS'), findsOneWidget);
    expect(find.text('PROTECTED'), findsNWidgets(2));
  });

  testWidgets('the layout holds on a narrow card at large text',
      (WidgetTester tester) async {
    await pumpWidget(
      tester,
      status: statusWith(
        enabled: false,
        pauseLeft: const Duration(hours: 23, minutes: 59, seconds: 59),
      ),
      size: const Size(320, 900),
      textScale: 2,
    );

    // An overflow would have been thrown as a layout error.
    expect(tester.takeException(), isNull);
    expect(find.text('PAUSED'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
  });

  testWidgets('a tap opens the service', (WidgetTester tester) async {
    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(
            body: DashboardAdguardHomeWidget(instances: <Instance>[home]),
          ),
        ),
        GoRoute(
          path: AtriumRoutes.service,
          builder: (BuildContext context, GoRouterState state) => Scaffold(
            body: Text(
              'Opened ${state.pathParameters['kind']} '
              '${state.pathParameters['instanceId']}',
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: overridesFor(const <Instance>[home], status: statusWith()),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('AdGuard Home'));
    await tester.pumpAndSettle();

    expect(find.text('Opened adguardHome adguard-1'), findsOneWidget);
  });
}
