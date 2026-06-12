import 'package:core_router/core_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/activity_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/instance_form_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/profiles_screen.dart';
import 'screens/service_detail_screen.dart';
import 'screens/settings_screen.dart';

/// The app [GoRouter]. A stateful shell hosts the four bottom-nav branches;
/// instance-management and service-detail screens push over the Dashboard
/// branch.
final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  return GoRouter(
    initialLocation: AtriumRoutes.dashboard,
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell shell,
        ) =>
            ScaffoldWithNavBar(navigationShell: shell),
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
                    name: AtriumRoutes.addInstanceName,
                    builder: (BuildContext context, GoRouterState state) =>
                        const InstanceFormScreen(),
                  ),
                  GoRoute(
                    path: AtriumRoutes.editInstance,
                    name: AtriumRoutes.editInstanceName,
                    builder: (BuildContext context, GoRouterState state) =>
                        InstanceFormScreen(
                      instanceId: state.pathParameters['instanceId'],
                    ),
                  ),
                  GoRoute(
                    path: AtriumRoutes.profiles,
                    name: AtriumRoutes.profilesName,
                    builder: (BuildContext context, GoRouterState state) =>
                        const ProfilesScreen(),
                  ),
                  GoRoute(
                    path: AtriumRoutes.service,
                    name: AtriumRoutes.serviceName,
                    builder: (BuildContext context, GoRouterState state) =>
                        ServiceDetailScreen(
                      kindName: state.pathParameters['kind'] ?? '',
                      instanceId: state.pathParameters['instanceId'] ?? '',
                    ),
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
