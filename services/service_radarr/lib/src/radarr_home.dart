import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import '../service_radarr.dart';
import 'home/activity_tab.dart';
import 'home/movies_tab.dart';
import 'home/settings_tab.dart';
import 'home/system_tab.dart';
import 'home/wanted_tab.dart';

class RadarrHome extends ConsumerWidget {
  const RadarrHome({
    required this.instance,
    this.onEdit,
    this.drawer,
    super.key,
  });

  final Instance instance;
  final VoidCallback? onEdit;
  final Widget? drawer;

  /// The search query provider backing the given tab, if that tab has one.
  StateProvider<String>? _searchQueryProviderFor(int tabIndex) {
    return switch (tabIndex) {
      0 => radarrSearchQueryProvider(instance),
      1 => radarrActivitySearchQueryProvider(instance),
      2 => radarrWantedSearchQueryProvider(instance),
      _ => null,
    };
  }

  /// The selection providers backing the given tab, if that tab has any.
  List<StateProvider<Set<int>>> _selectionProvidersFor(int tabIndex) {
    return switch (tabIndex) {
      0 => <StateProvider<Set<int>>>[
          radarrMoviesSelectionProvider(instance),
        ],
      1 => <StateProvider<Set<int>>>[
          radarrQueueSelectionProvider(instance),
          radarrBlocklistSelectionProvider(instance),
        ],
      2 => <StateProvider<Set<int>>>[
          radarrWantedSelectionProvider(instance),
        ],
      _ => const <StateProvider<Set<int>>>[],
    };
  }

  /// Clears the active tab's search query. Returns true if there was one.
  bool _clearActiveSearch(WidgetRef ref) {
    final int index = ref.read(radarrActiveTabBarIndexProvider(instance));
    final StateProvider<String>? provider = _searchQueryProviderFor(index);
    if (provider == null || ref.read(provider).isEmpty) return false;
    ref.read(provider.notifier).state = '';
    return true;
  }

  /// Clears the active tab's selection. Returns true if there was one.
  bool _clearActiveSelection(WidgetRef ref) {
    final int index = ref.read(radarrActiveTabBarIndexProvider(instance));
    bool cleared = false;
    for (final provider in _selectionProvidersFor(index)) {
      if (ref.read(provider).isNotEmpty) {
        ref.read(provider.notifier).state = <int>{};
        cleared = true;
      }
    }
    return cleared;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(radarrActiveTabBarIndexProvider(instance));
    final isNavbarVisible = ref.watch(radarrBottomNavVisibleProvider(instance));

    final List<Widget> tabs = [
      MoviesTab(instance: instance),
      ActivityTab(instance: instance),
      WantedTab(instance: instance),
      SettingsTab(instance: instance),
      SystemTab(instance: instance),
    ];

    return Scaffold(
      drawerEdgeDragWidth:
          drawer != null ? MediaQuery.sizeOf(context).width * 0.15 : null,
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
                  final bool currentVisible =
                      ref.read(radarrBottomNavVisibleProvider(instance));
                  if (isScrollingDown && currentVisible) {
                    ref
                        .read(radarrBottomNavVisibleProvider(instance).notifier)
                        .state = false;
                  } else if (!isScrollingDown && !currentVisible && !isAtBottom) {
                    ref
                        .read(radarrBottomNavVisibleProvider(instance).notifier)
                        .state = true;
                  }
                }
              } else if (pixels <= 0.0) {
                final bool currentVisible =
                    ref.read(radarrBottomNavVisibleProvider(instance));
                if (!currentVisible) {
                  ref
                      .read(radarrBottomNavVisibleProvider(instance).notifier)
                      .state = true;
                }
              }
            }
          }
          return false;
        },
        child: Builder(
          builder: (BuildContext context) {
            return PopScope<Object?>(
              canPop: false,
              onPopInvokedWithResult: (bool didPop, Object? result) {
                if (didPop) return;

                // A back press while the drawer is open only closes it.
                if (Scaffold.of(context).isDrawerOpen) {
                  Navigator.of(context).pop();
                  return;
                }

                // Unwind one step per back press: search, then selection,
                // then return to the first tab. Once nothing is left to
                // unwind, canPop is true and the route pops normally.
                if (_clearActiveSearch(ref)) return;
                if (_clearActiveSelection(ref)) return;
                if (ref.read(radarrActiveTabBarIndexProvider(instance)) != 0) {
                  ref
                      .read(radarrActiveTabBarIndexProvider(instance).notifier)
                      .state = 0;
                  return;
                }

                // If nothing to unwind, go back to dashboard.
                GoRouter.of(context).go(AtriumRoutes.dashboard);
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
                        radarrMoviesScrollToTopProvider(instance).notifier,
                      )
                      .update((state) => state + 1);
                } else {
                  ref
                      .read(
                        radarrActiveTabBarIndexProvider(instance).notifier,
                      )
                      .state = index;
                }
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.movie_outlined),
                  selectedIcon: Icon(Icons.movie),
                  label: 'Movies',
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
