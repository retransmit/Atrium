import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'myspeed_providers.dart';
import 'tabs/myspeed_config_tab.dart';
import 'tabs/myspeed_history_tab.dart';
import 'tabs/myspeed_status_tab.dart';

/// MySpeed service home screen with bottom navigation bar (Status, History, Config).
class MySpeedHome extends ConsumerStatefulWidget {
  const MySpeedHome({
    required this.instance,
    this.drawer,
    this.onEdit,
    super.key,
  });

  final Instance instance;
  final Widget? drawer;
  final VoidCallback? onEdit;

  @override
  ConsumerState<MySpeedHome> createState() => _MySpeedHomeState();
}

class _MySpeedHomeState extends ConsumerState<MySpeedHome> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final int currentIndex =
        ref.watch(myspeedActiveTabBarIndexProvider(widget.instance));

    final List<Widget> tabs = <Widget>[
      MySpeedStatusTab(instance: widget.instance),
      MySpeedHistoryTab(instance: widget.instance),
      MySpeedConfigTab(instance: widget.instance),
    ];

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        final ScaffoldState? scaffold = _scaffoldKey.currentState;
        if (scaffold?.isDrawerOpen ?? false) {
          scaffold!.closeDrawer();
          return;
        }
        if (currentIndex != 0) {
          ref.read(myspeedActiveTabBarIndexProvider(widget.instance).notifier).state = 0;
          return;
        }
        GoRouter.of(context).go(AtriumRoutes.dashboard);
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawerEdgeDragWidth: widget.drawer != null ? 32 : null,
        drawer: widget.drawer,
        appBar: AppBar(
          leading: Builder(
            builder: (BuildContext ctx) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                if (widget.drawer != null) {
                  _scaffoldKey.currentState?.openDrawer();
                } else {
                  Scaffold.of(ctx).openDrawer();
                }
              },
            ),
          ),
          title: Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  widget.instance.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.instance.kind.isBeta) ...<Widget>[
                const SizedBox(width: Insets.sm),
                const BetaBadge(),
              ],
            ],
          ),
        ),
        body: IndexedStack(
          index: currentIndex,
          children: tabs,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (int index) {
            ref.read(myspeedActiveTabBarIndexProvider(widget.instance).notifier).state = index;
          },
          destinations: const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.speed_outlined),
              selectedIcon: Icon(Icons.speed),
              label: 'Status',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Config',
            ),
          ],
        ),
      ),
    );
  }
}
