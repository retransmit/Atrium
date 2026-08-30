import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tabs/unraid_array_tab.dart';
import 'tabs/unraid_docker_tab.dart';
import 'tabs/unraid_system_tab.dart';
import 'tabs/unraid_vms_tab.dart';
import 'unraid_providers.dart';

/// Unraid: the array, how hard the machine is working, its containers and its
/// virtual machines.
///
/// Four tabs rather than one long scroll, matching the other services with
/// this much to show. Containers and VMs can be started and stopped from
/// here. The array cannot: stopping it unmounts every share and takes down
/// every container at once, which is not something to put one mistaken tap
/// away on a phone.
class UnraidHome extends ConsumerWidget {
  const UnraidHome({required this.instance, this.drawer, super.key});

  final Instance instance;
  final Widget? drawer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int index = ref.watch(tabIndexProvider(instance));
    final bool navVisible = ref.watch(bottomNavVisibleProvider(instance));

    final List<Widget> tabs = <Widget>[
      UnraidArrayTab(instance: instance),
      UnraidSystemTab(instance: instance),
      UnraidDockerTab(instance: instance),
      UnraidVmsTab(instance: instance),
    ];

    return PopScope(
      // Back returns to the first tab before it leaves the screen, so a stray
      // press does not throw away where you were.
      canPop: index == 0,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        ref.read(tabIndexProvider(instance).notifier).state = 0;
      },
      child: Scaffold(
        drawerEdgeDragWidth:
            drawer != null ? MediaQuery.sizeOf(context).width * 0.15 : null,
        drawer: drawer,
        appBar: AppBar(
          leading: drawer == null
              ? null
              : Builder(
                  builder: (BuildContext context) => IconButton(
                    icon: const Icon(Icons.menu),
                    tooltip: 'Open menu',
                    onPressed: Scaffold.of(context).openDrawer,
                  ),
                ),
          title: Text(instance.name),
        ),
        body: NotificationListener<ScrollNotification>(
          onNotification: (ScrollNotification notification) {
            _onScroll(ref, notification);
            return false;
          },
          child: IndexedStack(index: index, children: tabs),
        ),
        bottomNavigationBar: AtriumBottomNav(
          visible: navVisible,
          selectedIndex: index,
          onDestinationSelected: (int next) =>
              ref.read(tabIndexProvider(instance).notifier).state = next,
          destinations: const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.dns_outlined),
              selectedIcon: Icon(Icons.dns),
              label: 'Array',
            ),
            NavigationDestination(
              icon: Icon(Icons.speed_outlined),
              selectedIcon: Icon(Icons.speed),
              label: 'System',
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2),
              label: 'Docker',
            ),
            NavigationDestination(
              icon: Icon(Icons.desktop_windows_outlined),
              selectedIcon: Icon(Icons.desktop_windows),
              label: 'VMs',
            ),
          ],
        ),
      ),
    );
  }

  /// Hides the bar while scrolling down and brings it back on the way up, so a
  /// long disk list is not read through it.
  void _onScroll(WidgetRef ref, ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return;
    if (notification is! ScrollUpdateNotification) return;
    final double delta = notification.scrollDelta ?? 0;
    if (delta == 0) return;

    final double pixels = notification.metrics.pixels;
    final bool visible = ref.read(bottomNavVisibleProvider(instance));
    // Near the top the bar always belongs on screen; a short list would
    // otherwise be able to hide it with nowhere to scroll back to.
    if (pixels <= 0) {
      if (!visible) {
        ref.read(bottomNavVisibleProvider(instance).notifier).state = true;
      }
      return;
    }
    if (pixels <= 10) return;

    final bool atBottom = pixels >= notification.metrics.maxScrollExtent - 10.0;
    if (delta > 0 && visible) {
      ref.read(bottomNavVisibleProvider(instance).notifier).state = false;
    } else if (delta < 0 && !visible && !atBottom) {
      ref.read(bottomNavVisibleProvider(instance).notifier).state = true;
    }
  }
}
