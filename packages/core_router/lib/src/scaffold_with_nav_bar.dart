import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The bottom-navigation shell that hosts the four top-level branches.
///
/// Wraps go_router's [StatefulNavigationShell] so each branch keeps its own
/// navigation stack (tapping away from a deep screen and back returns you
/// where you were). Used as the builder for a `StatefulShellRoute`.
class ScaffoldWithNavBar extends StatefulWidget {
  const ScaffoldWithNavBar({
    required this.navigationShell,
    this.drawer,
    super.key,
  });

  final StatefulNavigationShell navigationShell;
  final Widget? drawer;

  @override
  State<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends State<ScaffoldWithNavBar> {
  bool _isNavbarVisible = true;

  @override
  void didUpdateWidget(covariant ScaffoldWithNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationShell.currentIndex !=
        widget.navigationShell.currentIndex) {
      _isNavbarVisible = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: widget.navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        widget.navigationShell.goBranch(0);
      },
      child: Scaffold(
        body: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification notification) {
          if (notification.metrics.axis == Axis.vertical) {
            if (notification is ScrollUpdateNotification) {
              final double pixels = notification.metrics.pixels;
              if (pixels > 10.0) {
                final double maxExtent = notification.metrics.maxScrollExtent;
                final bool isAtBottom = pixels >= maxExtent - 10.0;
                final double? delta = notification.scrollDelta;
                if (delta != null && delta != 0.0) {
                  final bool isScrollingDown = delta > 0.0;
                  if (isScrollingDown && _isNavbarVisible) {
                    setState(() {
                      _isNavbarVisible = false;
                    });
                  } else if (!isScrollingDown && !_isNavbarVisible && !isAtBottom) {
                    setState(() {
                      _isNavbarVisible = true;
                    });
                  }
                }
              } else if (pixels <= 0.0) {
                if (!_isNavbarVisible) {
                  setState(() {
                    _isNavbarVisible = true;
                  });
                }
              }
            }
          }
          return false;
        },
        child: widget.navigationShell,
      ),
      drawer: widget.drawer,
      drawerEdgeDragWidth: widget.drawer != null
          ? MediaQuery.sizeOf(context).width * 0.15
          : null,
      bottomNavigationBar: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: _isNavbarVisible ? 80.0 : 0.0,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: SizedBox(
            height: 80.0,
            child: NavigationBar(
              selectedIndex: widget.navigationShell.currentIndex,
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
        ),
      ),
    ),);
  }

  void _onTap(int index) {
    // `initialLocation: true` when re-tapping the current tab pops it back to
    // that branch's root - matches the platform convention.
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }
}
