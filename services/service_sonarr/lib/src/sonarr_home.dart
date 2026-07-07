import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../service_sonarr.dart';
import 'home/activity_tab.dart';
import 'home/series_tab.dart';
import 'home/settings_tab.dart';
import 'home/system_tab.dart';
import 'home/wanted_tab.dart';

class SonarrHome extends ConsumerWidget {
  const SonarrHome({
    required this.instance,
    this.onEdit,
    this.drawer,
    super.key,
  });

  final Instance instance;
  final VoidCallback? onEdit;
  final Widget? drawer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(sonarrActiveTabBarIndexProvider(instance));
    final isNavbarVisible = ref.watch(sonarrBottomNavVisibleProvider(instance));

    final List<Widget> tabs = [
      SeriesTab(instance: instance),
      ActivityTab(instance: instance),
      WantedTab(instance: instance),
      SettingsTab(instance: instance),
      SystemTab(instance: instance),
    ];

    return Scaffold(
      drawer: drawer,
      body: NotificationListener<UserScrollNotification>(
        onNotification: (UserScrollNotification notification) {
          final ScrollDirection direction = notification.direction;
          if (direction == ScrollDirection.reverse) {
            ref.read(sonarrBottomNavVisibleProvider(instance).notifier).state =
                false;
          } else if (direction == ScrollDirection.forward) {
            ref.read(sonarrBottomNavVisibleProvider(instance).notifier).state =
                true;
          }
          return false;
        },
        child: Builder(
          builder: (BuildContext context) {
            return PopScope<Object?>(
              canPop: false,
              onPopInvokedWithResult: (bool didPop, Object? result) {
                if (didPop) return;

                final bool isSearchActive =
                    ref.read(sonarrSearchActiveProvider(instance));
                if (isSearchActive && currentIndex == 0) {
                  return;
                }

                if (Scaffold.of(context).isDrawerOpen) {
                  Navigator.of(context).pop();
                  return;
                }

                if (currentIndex != 0) {
                  ref
                      .read(sonarrActiveTabBarIndexProvider(instance).notifier)
                      .state = 0;
                } else {
                  Scaffold.of(context).openDrawer();
                }
              },
              child: IndexedStack(
                index: currentIndex,
                children: tabs,
              ),
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
              onDestinationSelected: (index) {
                if (index == 0 && currentIndex == 0) {
                  ref
                      .read(
                        sonarrSeriesScrollToTopProvider(instance).notifier,
                      )
                      .update((state) => state + 1);
                } else {
                  ref
                      .read(
                        sonarrActiveTabBarIndexProvider(instance).notifier,
                      )
                      .state = index;
                }
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.tv_outlined),
                  selectedIcon: Icon(Icons.tv),
                  label: 'Series',
                ),
                NavigationDestination(
                  icon: Icon(Icons.swap_vert_outlined),
                  selectedIcon: Icon(Icons.swap_vert),
                  label: 'Activity',
                ),
                NavigationDestination(
                  icon: Icon(Icons.running_with_errors_outlined),
                  selectedIcon: Icon(Icons.running_with_errors),
                  label: 'Wanted',
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
