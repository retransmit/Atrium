import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The bottom-navigation shell that hosts the four top-level branches.
///
/// Wraps go_router's [StatefulNavigationShell] so each branch keeps its own
/// navigation stack (tapping away from a deep screen and back returns you
/// where you were). Used as the builder for a `StatefulShellRoute`.
class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({
    required this.navigationShell,
    this.drawer,
    super.key,
  });

  final StatefulNavigationShell navigationShell;
  final Widget? drawer;

  @override
  Widget build(BuildContext context) {
    final bool isDashboard = navigationShell.currentIndex == 0;
    return PopScope(
      canPop: isDashboard,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        navigationShell.goBranch(0);
      },
      child: Scaffold(
        body: navigationShell,
        drawer: drawer,
        drawerEdgeDragWidth:
            drawer != null ? MediaQuery.sizeOf(context).width * 0.15 : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _onTap,
          destinations: const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today),
              label: 'Calendar',
            ),
            NavigationDestination(
              icon: Icon(Icons.swap_vert_outlined),
              selectedIcon: Icon(Icons.swap_vert),
              label: 'Activity',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  void _onTap(int index) {
    // `initialLocation: true` when re-tapping the current tab pops it back to
    // that branch's root - matches the platform convention.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}
