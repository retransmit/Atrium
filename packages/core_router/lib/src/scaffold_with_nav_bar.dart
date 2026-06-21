import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'routes.dart';

/// The bottom-navigation shell that hosts the four top-level branches.
///
/// Wraps go_router's [StatefulNavigationShell] so each branch keeps its own
/// navigation stack (tapping away from a deep screen and back returns you
/// where you were). Used as the builder for a `StatefulShellRoute`.
class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    final bool showNavBar = !location.contains('/service/');
    final bool isDashboardRoot = navigationShell.currentIndex == 0 && location == AtriumRoutes.dashboard;

    return PopScope(
      canPop: isDashboardRoot,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;

        if (navigationShell.currentIndex != 0) {
          // Pressing back from any other tab goes to Dashboard
          navigationShell.goBranch(0);
        } else {
          // Pressing back from any sub-page under Dashboard goes back to Dashboard root
          context.go(AtriumRoutes.dashboard);
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: navigationShell,
        bottomNavigationBar: showNavBar && MediaQuery.of(context).viewInsets.bottom == 0
            ? _buildBottomNavigationBar(context)
            : null,
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      margin: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding > 0 ? bottomPadding : 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: theme.brightness == Brightness.dark
            ? Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.4),
              )
            : null,
        boxShadow: theme.brightness == Brightness.dark
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          color: colors.surfaceContainer.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.92 : 0.96,
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              _buildNavItem(context, 0, Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
              _buildNavItem(context, 1, Icons.calendar_today_outlined, Icons.calendar_today, 'Calendar'),
              _buildNavItem(context, 2, Icons.swap_vert_outlined, Icons.swap_vert, 'Activity'),
              _buildNavItem(context, 3, Icons.settings_outlined, Icons.settings, 'Settings'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData inactiveIcon, IconData activeIcon, String label) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isSelected = navigationShell.currentIndex == index;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        _onTap(index);
      },
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? colors.primaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isSelected ? activeIcon : inactiveIcon,
                color: isSelected ? colors.onPrimaryContainer : colors.onSurfaceVariant,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isSelected ? colors.primary : colors.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 11,
              ),
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
