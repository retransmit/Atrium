import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'aria2_providers.dart';
import 'home/aria2_downloads_tab.dart';
import 'home/aria2_settings_tab.dart';
import 'home/aria2_system_tab.dart';

/// aria2's top-level navigation shell:
/// 1. Downloads (unified transfer manager with fast status filtering)
/// 2. Settings (bandwidth, concurrency, storage, and BitTorrent)
/// 3. System (daemon status, telemetry, session flush, and maintenance)
///
/// Implements full stack unwinding on back press:
/// Drawer -> Active Search -> Selection -> Tab 0 -> Dashboard.
class Aria2Home extends ConsumerWidget {
  const Aria2Home({required this.instance, this.drawer, super.key});

  final Instance instance;

  /// The app's services drawer. Shell passes it; tests can leave it out.
  final Widget? drawer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int currentIndex = ref.watch(aria2ActiveTabProvider(instance));
    final bool isNavbarVisible = ref.watch(
      aria2BottomNavVisibleProvider(instance),
    );

    return Scaffold(
      drawerEdgeDragWidth: drawer != null
          ? MediaQuery.sizeOf(context).width * 0.15
          : null,
      drawer: drawer,
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
                  final bool currentVisible = ref.read(
                    aria2BottomNavVisibleProvider(instance),
                  );
                  if (isScrollingDown && currentVisible) {
                    ref
                            .read(
                              aria2BottomNavVisibleProvider(instance).notifier,
                            )
                            .state =
                        false;
                  } else if (!isScrollingDown &&
                      !currentVisible &&
                      !isAtBottom) {
                    ref
                            .read(
                              aria2BottomNavVisibleProvider(instance).notifier,
                            )
                            .state =
                        true;
                  }
                }
              } else if (pixels <= 0.0) {
                final bool currentVisible = ref.read(
                  aria2BottomNavVisibleProvider(instance),
                );
                if (!currentVisible) {
                  ref
                          .read(
                            aria2BottomNavVisibleProvider(instance).notifier,
                          )
                          .state =
                      true;
                }
              }
            }
          }
          return false;
        },
        child: Builder(
          builder: (BuildContext context) {
            void openDrawer() => Scaffold.of(context).openDrawer();
            final List<Widget> tabs = <Widget>[
              Aria2DownloadsTab(instance: instance, onOpenDrawer: openDrawer),
              Aria2SettingsTab(instance: instance, onOpenDrawer: openDrawer),
              Aria2SystemTab(instance: instance, onOpenDrawer: openDrawer),
            ];

            return PopScope<Object?>(
              canPop: false,
              onPopInvokedWithResult: (bool didPop, Object? result) {
                if (didPop) return;

                // 1. Close drawer if open
                if (Scaffold.of(context).isDrawerOpen) {
                  Navigator.of(context).pop();
                  return;
                }

                // 2. Clear search if active
                final bool isSearchActive = ref.read(
                  aria2SearchActiveProvider(instance),
                );
                if (isSearchActive) {
                  ref
                          .read(aria2SearchActiveProvider(instance).notifier)
                          .state =
                      false;
                  ref.read(aria2SearchQueryProvider(instance).notifier).state =
                      '';
                  return;
                }

                // 3. Clear selection if active
                final Set<String> selection = ref.read(
                  aria2SelectionProvider(instance),
                );
                if (selection.isNotEmpty) {
                  ref.read(aria2SelectionProvider(instance).notifier).state =
                      <String>{};
                  return;
                }

                // 4. Return to Tab 0 if on another tab
                if (ref.read(aria2ActiveTabProvider(instance)) != 0) {
                  ref.read(aria2ActiveTabProvider(instance).notifier).state = 0;
                  return;
                }

                // 5. Exit to Dashboard
                GoRouter.of(context).go(AtriumRoutes.dashboard);
              },
              child: IndexedStack(index: currentIndex, children: tabs),
            );
          },
        ),
      ),
      bottomNavigationBar: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: isNavbarVisible ? 80 : 0,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: SizedBox(
            height: 80,
            child: NavigationBar(
              selectedIndex: currentIndex,
              onDestinationSelected: (int index) {
                if (index == currentIndex) {
                  ref
                      .read(
                        aria2ScrollToTopProvider((instance, index)).notifier,
                      )
                      .update((int state) => state + 1);
                } else {
                  ref.read(aria2ActiveTabProvider(instance).notifier).state =
                      index;
                }
              },
              destinations: const <NavigationDestination>[
                NavigationDestination(
                  icon: Icon(Icons.download_outlined),
                  selectedIcon: Icon(Icons.download),
                  label: 'Downloads',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
                NavigationDestination(
                  icon: Icon(Icons.computer_outlined),
                  selectedIcon: Icon(Icons.computer),
                  label: 'System',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
