import 'package:atrium/src/router.dart';
import 'package:atrium/src/screens/instance_form_screen.dart';
import 'package:atrium/src/screens/service_grid_screen.dart';
import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
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

  testWidgets('ServiceGridScreen shows a section for every category',
      (WidgetTester tester) async {
    // Tall enough that the list builds every section.
    tester.view.physicalSize = const Size(1000, 8000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('service_search_bar')), findsOneWidget);
    for (final ServiceRole role in ServiceRole.values) {
      final Finder section = find.byKey(Key('service_section_${role.name}'));
      expect(section, findsOneWidget);
      // At least one: Ombi and Seerr's tagline is also "Requests".
      expect(
        find.descendant(
          of: section,
          matching: find.text(ServiceVisuals.roleLabel(role)),
        ),
        findsAtLeastNWidgets(1),
      );
    }
  });

  testWidgets('every service sits under its own category',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 8000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    for (final ServiceKind kind in ServiceKind.values) {
      expect(
        find.descendant(
          of: find.byKey(Key('service_section_${kind.role.name}')),
          matching: find.byKey(ValueKey<String>('service_card_${kind.name}')),
        ),
        findsOneWidget,
        reason: '${kind.name} belongs under ${kind.role.name}',
      );
    }
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

  testWidgets('a search leaves out categories with no match',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('service_search_bar')),
      'plex',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('service_section_mediaServer')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('service_section_automation')), findsNothing);
  });

  testWidgets('a search with no match offers to clear it',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('service_search_bar')),
      'zzzz',
    );
    await tester.pumpAndSettle();
    expect(find.text('No services found'), findsOneWidget);

    await tester.tap(find.text('Clear search'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('service_card_adguardHome')),
      findsOneWidget,
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
