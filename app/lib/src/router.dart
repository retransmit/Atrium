import 'package:core_router/core_router.dart';
import 'package:core_profile/core_profile.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/activity_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/instance_form_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/profiles_screen.dart';
import 'screens/service_detail_screen.dart';
import 'screens/service_grid_screen.dart';
import 'screens/settings_screen.dart';

/// The root navigator. Public so code living above the router - the torrent
/// share intake, which is mounted in `MaterialApp.builder` - can reach a
/// context that is able to present routes.
final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

final GlobalKey<NavigatorState> _rootNavigatorKey = rootNavigatorKey;

/// The add form for the service named in the route's `kind`, or an error
/// page when no service has that name. Public so tests route through it.
Widget addInstanceFormPage(BuildContext context, GoRouterState state) {
  final String? kindStr = state.pathParameters['kind'];
  final ServiceKind? kind =
      kindStr != null ? ServiceKind.values.asNameMap()[kindStr] : null;
  if (kind == null) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unknown service'),
      ),
      body: EmptyView(
        icon: Icons.error_outline,
        title: 'Unknown service',
        message: 'No service matching "$kindStr" was found.',
        action: FilledButton(
          onPressed: () => context.goNamed(AtriumRoutes.addInstanceName),
          child: const Text('Select a service'),
        ),
      ),
    );
  }
  return InstanceFormScreen(initialKind: kind);
}

/// The app [GoRouter]. A stateful shell hosts the four bottom-nav branches;
/// instance-management and service-detail screens push over the Dashboard
/// branch.
final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AtriumRoutes.dashboard,
    routes: <RouteBase>[
      GoRoute(
        path: AtriumRoutes.service,
        parentNavigatorKey: _rootNavigatorKey,
        name: AtriumRoutes.serviceName,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            NoTransitionPage<void>(
          key: state.pageKey,
          child: ServiceDetailScreen(
            kindName: state.pathParameters['kind'] ?? '',
            instanceId: state.pathParameters['instanceId'] ?? '',
          ),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell shell,
        ) =>
            Consumer(
          builder: (BuildContext context, WidgetRef ref, Widget? child) {
            final List<Instance> instances = ref.watch(activeInstancesProvider);
            final Profile? profile = ref.watch(activeProfileProvider);
            return ScaffoldWithNavBar(
              navigationShell: shell,
              drawer: ServicesDrawer(instances: instances, profile: profile),
            );
          },
        ),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AtriumRoutes.dashboard,
                name: AtriumRoutes.dashboardName,
                builder: (BuildContext context, GoRouterState state) =>
                    const DashboardScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: AtriumRoutes.addInstance,
                    parentNavigatorKey: _rootNavigatorKey,
                    name: AtriumRoutes.addInstanceName,
                    builder: (BuildContext context, GoRouterState state) =>
                        const ServiceGridScreen(),
                    routes: <RouteBase>[
                      GoRoute(
                        path: AtriumRoutes.addInstanceForm,
                        parentNavigatorKey: _rootNavigatorKey,
                        name: AtriumRoutes.addInstanceFormName,
                        builder: addInstanceFormPage,
                      ),
                    ],
                  ),
                  GoRoute(
                    path: AtriumRoutes.editInstance,
                    parentNavigatorKey: _rootNavigatorKey,
                    name: AtriumRoutes.editInstanceName,
                    builder: (BuildContext context, GoRouterState state) =>
                        InstanceFormScreen(
                      instanceId: state.pathParameters['instanceId'],
                    ),
                  ),
                  GoRoute(
                    path: AtriumRoutes.profiles,
                    parentNavigatorKey: _rootNavigatorKey,
                    name: AtriumRoutes.profilesName,
                    builder: (BuildContext context, GoRouterState state) =>
                        const ProfilesScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AtriumRoutes.calendar,
                name: AtriumRoutes.calendarName,
                builder: (BuildContext context, GoRouterState state) =>
                    const CalendarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AtriumRoutes.activity,
                name: AtriumRoutes.activityName,
                builder: (BuildContext context, GoRouterState state) =>
                    const ActivityScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AtriumRoutes.settings,
                name: AtriumRoutes.settingsName,
                builder: (BuildContext context, GoRouterState state) =>
                    const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
