import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'transmission_filter_drawer.dart';
import 'transmission_providers.dart';
import 'transmission_settings_tab.dart';
import 'transmission_torrents_tab.dart';

/// Transmission's per-instance UI: the torrent list and the settings, under
/// a bottom bar, the shape qBittorrent's screen has.
///
/// Two things are deliberately not qBittorrent's. There is no Logs tab -
/// Transmission's RPC has no log call to fill one - so the bar has two
/// destinations rather than three. And the filter drawer sits behind an icon
/// in the list's own app bar rather than a fixed button, because Transmission
/// has no category tree to give a drawer a reason to stay open.
///
/// The screen owns its scaffold so that it also owns the back press: the
/// app's service shell would otherwise leave for the dashboard on the first
/// press, and a long-press selection or a switch to Settings would be lost
/// to a reflex back. Back unwinds one thing at a time, the drawers, then the
/// search, then the selection, then the tab, and only then leaves.
class TransmissionHome extends ConsumerWidget {
  const TransmissionHome({required this.instance, this.drawer, super.key});

  final Instance instance;

  /// The app's services drawer. The shell passes it; tests leave it out.
  final Widget? drawer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int tab = ref.watch(transmissionTabProvider(instance));
    final bool navbarVisible =
        ref.watch(transmissionBottomNavVisibleProvider(instance));

    void selectTab(int index) {
      final int current = ref.read(transmissionTabProvider(instance));
      if (index == current) {
        // Tapping the tab already showing scrolls it back to its top, which
        // is what the bar's other clients do and the only cheap way back up a
        // long list.
        ref
            .read(transmissionScrollToTopProvider((instance, index)).notifier)
            .update((int state) => state + 1);
        return;
      }
      ref.read(transmissionTabProvider(instance).notifier).state = index;
    }

    return Scaffold(
      drawerEdgeDragWidth:
          drawer != null ? MediaQuery.sizeOf(context).width * 0.15 : null,
      drawer: drawer,
      // Only the torrent list has a filter drawer; Settings has no list to
      // narrow, so the edge gesture is off there rather than opening a
      // drawer whose controls would do nothing.
      endDrawer: tab == 0 ? TransmissionFilterDrawer(instance: instance) : null,
      endDrawerEnableOpenDragGesture: tab == 0,
      body: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification notification) {
          if (notification.metrics.axis == Axis.vertical &&
              notification is ScrollUpdateNotification) {
            final double pixels = notification.metrics.pixels;
            if (pixels > 10.0) {
              final double maxExtent = notification.metrics.maxScrollExtent;
              final bool isAtBottom = pixels >= maxExtent - 10.0;
              final double? delta = notification.scrollDelta;
              if (delta != null && delta != 0.0) {
                final bool isScrollingDown = delta > 0.0;
                final bool currentVisible =
                    ref.read(transmissionBottomNavVisibleProvider(instance));
                if (isScrollingDown && currentVisible) {
                  ref
                      .read(
                        transmissionBottomNavVisibleProvider(instance).notifier,
                      )
                      .state = false;
                } else if (!isScrollingDown && !currentVisible && !isAtBottom) {
                  ref
                      .read(
                        transmissionBottomNavVisibleProvider(instance).notifier,
                      )
                      .state = true;
                }
              }
            } else if (pixels <= 0.0) {
              if (!ref.read(transmissionBottomNavVisibleProvider(instance))) {
                ref
                    .read(
                      transmissionBottomNavVisibleProvider(instance).notifier,
                    )
                    .state = true;
              }
            }
          }
          return false;
        },
        child: Builder(
          builder: (BuildContext context) => PopScope<Object?>(
            canPop: false,
            onPopInvokedWithResult: (bool didPop, Object? _) {
              if (didPop) return;
              final ScaffoldState scaffold = Scaffold.of(context);
              if (scaffold.isDrawerOpen) {
                scaffold.closeDrawer();
                return;
              }
              if (scaffold.isEndDrawerOpen) {
                scaffold.closeEndDrawer();
                return;
              }
              if (ref.read(transmissionSearchProvider(instance)).isNotEmpty) {
                ref.read(transmissionSearchProvider(instance).notifier).state =
                    '';
                return;
              }
              if (ref
                  .read(transmissionSelectionProvider(instance))
                  .isNotEmpty) {
                ref.invalidate(transmissionSelectionProvider(instance));
                return;
              }
              if (ref.read(transmissionTabProvider(instance)) != 0) {
                ref.read(transmissionTabProvider(instance).notifier).state = 0;
                return;
              }
              GoRouter.of(context).goNamed(AtriumRoutes.dashboardName);
            },
            child: IndexedStack(
              index: tab,
              children: <Widget>[
                // The torrents tab owns the drawer-opening button in its own
                // app bar, so it is handed the callback rather than reaching
                // for the outer Scaffold itself.
                TransmissionTorrentsTab(
                  instance: instance,
                  onOpenDrawer: () => Scaffold.of(context).openDrawer(),
                  onOpenFilters: () => Scaffold.of(context).openEndDrawer(),
                ),
                TransmissionSettingsTab(
                  instance: instance,
                  onOpenDrawer: () => Scaffold.of(context).openDrawer(),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: AtriumBottomNav(
        visible: navbarVisible,
        selectedIndex: tab,
        onDestinationSelected: selectTab,
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.download_outlined),
            selectedIcon: Icon(Icons.download),
            label: 'Torrents',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
