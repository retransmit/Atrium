import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'transmission_providers.dart';
import 'transmission_settings_tab.dart';
import 'transmission_torrents_tab.dart';

/// Transmission's per-instance UI: the torrent list and the settings, under
/// a bottom bar, the shape qBittorrent's screen has.
///
/// The screen owns its scaffold so that it also owns the back press: the
/// app's service shell would otherwise leave for the dashboard on the first
/// press, and a long-press selection or a switch to Settings would be lost
/// to a reflex back. Back unwinds one thing at a time, the drawer, then the
/// selection, then the tab, and only then leaves.
class TransmissionHome extends ConsumerWidget {
  const TransmissionHome({required this.instance, this.drawer, super.key});

  final Instance instance;

  /// The app's services drawer. The shell passes it; tests leave it out.
  final Widget? drawer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int tab = ref.watch(transmissionTabProvider(instance));
    return Scaffold(
      drawer: drawer,
      appBar: AppBar(
        title: Text(instance.name, overflow: TextOverflow.ellipsis),
      ),
      body: Builder(
        builder: (BuildContext context) => PopScope<Object?>(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, Object? _) {
            if (didPop) return;
            final ScaffoldState scaffold = Scaffold.of(context);
            if (scaffold.isDrawerOpen) {
              scaffold.closeDrawer();
              return;
            }
            if (ref.read(transmissionSelectionProvider(instance)).isNotEmpty) {
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
              TransmissionTorrentsTab(instance: instance),
              TransmissionSettingsTab(instance: instance),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AtriumBottomNav(
        visible: true,
        selectedIndex: tab,
        onDestinationSelected: (int i) =>
            ref.read(transmissionTabProvider(instance).notifier).state = i,
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
