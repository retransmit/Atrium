import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'cleanuparr_providers.dart';
import 'tabs/cleanuparr_events_tab.dart';
import 'tabs/cleanuparr_overview_tab.dart';
import 'tabs/cleanuparr_strikes_tab.dart';

/// Top-level shell for Cleanuparr:
/// 1. Overview (System health, metric cards, background jobs)
/// 2. Strikes (Active strike items, ledger, reset operations)
/// 3. Events (Audit log feed, severity filters, diagnostics)
class CleanuparrHome extends ConsumerWidget {
  const CleanuparrHome({
    required this.instance,
    this.drawer,
    super.key,
  });

  final Instance instance;
  final Widget? drawer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int currentTab = ref.watch(cleanuparrTabProvider(instance));
    final int activeStrikesCount =
        ref.watch(cleanuparrActiveStrikesCountProvider(instance));

    return Scaffold(
      drawerEdgeDragWidth: drawer != null ? 32 : null,
      drawer: drawer,
      body: Builder(
        builder: (BuildContext scaffoldCtx) {
          final List<Widget> tabs = <Widget>[
            CleanuparrOverviewTab(
              instance: instance,
              onOpenDrawer: drawer != null
                  ? () => Scaffold.of(scaffoldCtx).openDrawer()
                  : null,
            ),
            CleanuparrStrikesTab(
              instance: instance,
              onOpenDrawer: drawer != null
                  ? () => Scaffold.of(scaffoldCtx).openDrawer()
                  : null,
            ),
            CleanuparrEventsTab(
              instance: instance,
              onOpenDrawer: drawer != null
                  ? () => Scaffold.of(scaffoldCtx).openDrawer()
                  : null,
            ),
          ];

          return PopScope<Object?>(
            canPop: false,
            onPopInvokedWithResult: (bool didPop, Object? result) {
              if (didPop) return;

              // 1. Close drawer if open
              if (Scaffold.of(scaffoldCtx).isDrawerOpen) {
                Scaffold.of(scaffoldCtx).closeDrawer();
                return;
              }

              // 2. Unwind search if active
              final String strikeSearch =
                  ref.read(cleanuparrStrikesSearchProvider(instance));
              if (strikeSearch.isNotEmpty && currentTab == 1) {
                ref
                    .read(cleanuparrStrikesSearchProvider(instance).notifier)
                    .state = '';
                return;
              }

              final String eventSearch =
                  ref.read(cleanuparrEventsSearchProvider(instance));
              if (eventSearch.isNotEmpty && currentTab == 2) {
                ref
                    .read(cleanuparrEventsSearchProvider(instance).notifier)
                    .state = '';
                return;
              }

              // 3. Return to Tab 0 if on another tab
              if (currentTab != 0) {
                ref.read(cleanuparrTabProvider(instance).notifier).state = 0;
                return;
              }

              // 4. Return to Dashboard
              GoRouter.of(context).go(AtriumRoutes.dashboard);
            },
            child: IndexedStack(
              index: currentTab,
              children: tabs,
            ),
          );
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentTab,
        onDestinationSelected: (int index) {
          ref.read(cleanuparrTabProvider(instance).notifier).state = index;
        },
        destinations: <NavigationDestination>[
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: activeStrikesCount > 0,
              label: Text('$activeStrikesCount'),
              child: const Icon(Icons.gavel_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: activeStrikesCount > 0,
              label: Text('$activeStrikesCount'),
              child: const Icon(Icons.gavel),
            ),
            label: 'Strikes',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Events',
          ),
        ],
      ),
    );
  }
}
