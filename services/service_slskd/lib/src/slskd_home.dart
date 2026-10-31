import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'slskd_providers.dart';
import 'tabs/slskd_browse_tab.dart';
import 'tabs/slskd_community_tab.dart';
import 'tabs/slskd_search_tab.dart';
import 'tabs/slskd_system_tab.dart';
import 'tabs/slskd_transfers_tab.dart';

/// slskd's top-level navigation shell:
/// 1. Transfers (Downloads & Uploads queue, speeds, remote queue positions)
/// 2. Search (P2P file search, bitrate/quality filters, download batches)
/// 3. Browse (Explore peer shared libraries & user profiles)
/// 4. Community (Public chat rooms & 1-on-1 direct messages)
/// 5. System (Daemon health, local shares scanner, logs, storage)
///
/// Implements full stack unwinding on back press:
/// Drawer -> Active Search -> Tab 0 -> Dashboard.
class SlskdHome extends ConsumerWidget {
  const SlskdHome({required this.instance, this.drawer, super.key});

  final Instance instance;

  /// The app's services drawer. Shell passes it; tests can leave it out.
  final Widget? drawer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int currentIndex = ref.watch(slskdActiveTabProvider(instance));
    final bool isNavbarVisible = ref.watch(
      slskdBottomNavVisibleProvider(instance),
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
                    slskdBottomNavVisibleProvider(instance),
                  );
                  if (isScrollingDown && currentVisible) {
                    ref
                        .read(slskdBottomNavVisibleProvider(instance).notifier)
                        .state = false;
                  } else if (!isScrollingDown &&
                      !currentVisible &&
                      !isAtBottom) {
                    ref
                        .read(slskdBottomNavVisibleProvider(instance).notifier)
                        .state = true;
                  }
                }
              } else if (pixels <= 0.0) {
                final bool currentVisible = ref.read(
                  slskdBottomNavVisibleProvider(instance),
                );
                if (!currentVisible) {
                  ref
                      .read(slskdBottomNavVisibleProvider(instance).notifier)
                      .state = true;
                }
              }
            }
          }
          return false;
        },
        child: Builder(
          builder: (BuildContext context) {
            void openDrawer() {
              if (Scaffold.of(context).hasDrawer) {
                Scaffold.of(context).openDrawer();
              }
            }
            final List<Widget> tabs = <Widget>[
              SlskdTransfersTab(instance: instance, onOpenDrawer: openDrawer),
              SlskdSearchTab(instance: instance, onOpenDrawer: openDrawer),
              SlskdBrowseTab(instance: instance, onOpenDrawer: openDrawer),
              SlskdCommunityTab(instance: instance, onOpenDrawer: openDrawer),
              SlskdSystemTab(instance: instance, onOpenDrawer: openDrawer),
            ];

            return PopScope<Object?>(
              canPop: false,
              onPopInvokedWithResult: (bool didPop, Object? result) {
                if (didPop) return;

                // 1. Close drawer if open
                if (Scaffold.of(context).isDrawerOpen) {
                  Scaffold.of(context).closeDrawer();
                  return;
                }

                // 2. Unwind tab-specific active subviews
                if (currentIndex == 1 &&
                    ref.read(slskdSelectedSearchIdProvider(instance)) != null) {
                  ref
                      .read(slskdSelectedSearchIdProvider(instance).notifier)
                      .state = null;
                  return;
                }

                if (currentIndex == 2) {
                  final segments =
                      ref.read(slskdBrowsePathSegmentsProvider(instance));
                  if (segments.isNotEmpty) {
                    ref
                        .read(
                          slskdBrowsePathSegmentsProvider(instance).notifier,
                        )
                        .state = segments.sublist(0, segments.length - 1);
                    return;
                  }
                  if (ref.read(slskdBrowseUsernameProvider(instance)) != null) {
                    ref
                        .read(slskdBrowseUsernameProvider(instance).notifier)
                        .state = null;
                    return;
                  }
                }

                if (currentIndex == 3) {
                  if (ref.read(slskdActiveRoomNameProvider(instance)) != null) {
                    ref
                        .read(slskdActiveRoomNameProvider(instance).notifier)
                        .state = null;
                    return;
                  }
                  if (ref.read(
                        slskdActiveConversationUsernameProvider(instance),
                      ) !=
                      null) {
                    ref
                        .read(
                          slskdActiveConversationUsernameProvider(
                            instance,
                          ).notifier,
                        )
                        .state = null;
                    return;
                  }
                }

                if (currentIndex == 4) {
                  if (ref.read(slskdSystemSegmentProvider(instance)) != 0) {
                    ref.read(slskdSystemSegmentProvider(instance).notifier).state =
                        0;
                    return;
                  }
                }

                // 3. Return to Tab 0 if on another tab
                if (currentIndex != 0) {
                  ref.read(slskdBottomNavVisibleProvider(instance).notifier).state = true;
                  ref.read(slskdActiveTabProvider(instance).notifier).state = 0;
                  return;
                }

                // 4. Exit to Dashboard
                GoRouter.of(context).go(AtriumRoutes.dashboard);
              },
              child: IndexedStack(index: currentIndex, children: tabs),
            );
          },
        ),
      ),
      bottomNavigationBar: AtriumBottomNav(
        visible: isNavbarVisible,
        selectedIndex: currentIndex,
        onDestinationSelected: (int index) {
          if (index == currentIndex) {
            ref
                .read(slskdBottomNavVisibleProvider(instance).notifier)
                .state = true;
            ref
                .read(slskdScrollToTopProvider((instance, index)).notifier)
                .update((int state) => state + 1);
          } else {
            ref.read(slskdBottomNavVisibleProvider(instance).notifier).state = true;
            ref.read(slskdActiveTabProvider(instance).notifier).state =
                index;
          }
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.swap_vert_rounded),
            selectedIcon: Icon(Icons.swap_vert_rounded),
            label: 'Transfers',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_rounded),
            selectedIcon: Icon(Icons.search_rounded),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder_rounded),
            label: 'Browse',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum_rounded),
            label: 'Community',
          ),
          NavigationDestination(
            icon: Icon(Icons.dns_outlined),
            selectedIcon: Icon(Icons.dns_rounded),
            label: 'System',
          ),
        ],
      ),
    );
  }
}
