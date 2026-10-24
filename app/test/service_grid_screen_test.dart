import 'package:atrium/src/router.dart';
import 'package:atrium/src/screens/instance_form_screen.dart';
import 'package:atrium/src/screens/service_grid_screen.dart';
import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Widget buildApp({GoRouter? router}) {
    final GoRouter r = router ??
        GoRouter(
          initialLocation: '/add-instance',
          routes: <RouteBase>[
            GoRoute(
              path: '/add-instance',
              name: AtriumRoutes.addInstanceName,
              builder: (BuildContext context, GoRouterState state) =>
                  const ServiceGridScreen(),
              routes: <RouteBase>[
                GoRoute(
                  path: AtriumRoutes.addInstanceForm,
                  name: AtriumRoutes.addInstanceFormName,
                  builder: addInstanceFormPage,
                ),
              ],
            ),
          ],
        );
    addTearDown(r.dispose);

    return ProviderScope(
      child: MaterialApp.router(
        routerConfig: r,
      ),
    );
  }

  testWidgets('ServiceGridScreen renders search bar and category tabs',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('service_search_bar')), findsOneWidget);
    expect(find.byKey(const Key('category_tab_all')), findsOneWidget);
    expect(find.byKey(const Key('category_tab_automation')), findsOneWidget);
    expect(find.byKey(const Key('category_tab_mediaServer')), findsOneWidget);
    expect(find.byKey(const Key('category_tab_downloader')), findsOneWidget);

    // Initial state renders AdGuard Home card (first alphabetically)
    expect(
      find.byKey(const ValueKey<String>('service_card_adguardHome')),
      findsOneWidget,
    );
  });

  testWidgets('ServiceGridScreen search filter works',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('service_search_bar')),
      'qbittorrent',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('service_card_qbittorrent')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('service_card_sonarr')),
      findsNothing,
    );
  });

  testWidgets('ServiceGridScreen category filter works',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // Tap Media tab
    await tester.tap(find.byKey(const Key('category_tab_mediaServer')));
    await tester.pumpAndSettle();

    // Media servers like Plex/Jellyfin should be visible, Sonarr (automation) should not
    expect(
      find.byKey(const ValueKey<String>('service_card_plex')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('service_card_sonarr')),
      findsNothing,
    );
  });

  testWidgets('Tapping service card navigates to form with pre-selected kind',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('service_card_adguardHome')),
    );
    await tester.pumpAndSettle();

    // Should now be on InstanceFormScreen with AdGuard Home preselected
    expect(find.byType(InstanceFormScreen), findsOneWidget);
    expect(find.textContaining('Network-wide blocking'), findsWidgets);
    expect(find.text('AdGuard Home'), findsWidgets);
  });

  testWidgets('Category tabs are generated from all ServiceRole values',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    for (final ServiceRole role in ServiceRole.values) {
      expect(
        find.byKey(Key('category_tab_${role.name}')),
        findsOneWidget,
      );
    }
  });

  testWidgets('Swiping the grid pages moves to the next category tab',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(TabBarView),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();

    final TabBar tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.controller!.index, 1);
    // Automation grid: Sonarr present, a media server is not.
    expect(
      find.byKey(const ValueKey<String>('service_card_sonarr')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('service_card_plex')),
      findsNothing,
    );
  });

  testWidgets('Unknown service parameter renders error screen',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final GoRouter router = GoRouter(
      initialLocation: '/add-instance/form/nonexistent_service',
      routes: <RouteBase>[
        GoRoute(
          path: '/add-instance',
          name: AtriumRoutes.addInstanceName,
          builder: (BuildContext context, GoRouterState state) =>
              const ServiceGridScreen(),
          routes: <RouteBase>[
            GoRoute(
              path: AtriumRoutes.addInstanceForm,
              name: AtriumRoutes.addInstanceFormName,
              builder: addInstanceFormPage,
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Select a service'), findsOneWidget);
    expect(
      find.text('No service matching "nonexistent_service" was found.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'ServiceGridScreen renders without overflow on narrow screen and high text scale',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 600),
          textScaler: TextScaler.linear(1.3),
        ),
        child: buildApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ServiceGridScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'InstanceFormScreen renders without overflow on narrow screen and high text scale',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final GoRouter router = GoRouter(
      initialLocation: '/add-instance/form/sonarr',
      routes: <RouteBase>[
        GoRoute(
          path: '/add-instance/form/:kind',
          builder: (BuildContext context, GoRouterState state) =>
              const InstanceFormScreen(initialKind: ServiceKind.sonarr),
        ),
      ],
    );
    addTearDown(router.dispose);

    FlutterErrorDetails? errorDetails;
    final void Function(FlutterErrorDetails)? originalOnError =
        FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      errorDetails = details;
    };
    addTearDown(() {
      FlutterError.onError = originalOnError;
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 600),
            textScaler: TextScaler.linear(1.3),
          ),
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    FlutterError.onError = originalOnError;
    expect(errorDetails, isNull);
  });
}
