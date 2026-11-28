import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import 'tabs/technitium_blocked_zones_tab.dart';
import 'tabs/technitium_overview_tab.dart';
import 'tabs/technitium_query_log_tab.dart';
import 'tabs/technitium_settings_tab.dart';

/// Currently active tab for a Technitium shell session.
final technitiumTabProvider =
    StateProvider.family<int, Instance>((Ref ref, Instance _) => 0);

/// Main shell scaffold for Technitium DNS Server.
class TechnitiumShell extends ConsumerStatefulWidget {
  const TechnitiumShell({
    required this.instance,
    this.drawer,
    this.now = DateTime.now,
    super.key,
  });

  final Instance instance;
  final Widget? drawer;
  final DateTime Function() now;

  @override
  ConsumerState<TechnitiumShell> createState() => _TechnitiumShellState();
}

class _TechnitiumShellState extends ConsumerState<TechnitiumShell> {
  static const int _overview = 0;
  static const int _queryLog = 1;
  static const int _blockedZones = 2;
  static const int _settings = 3;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Set<int> _shown = <int>{0};

  Instance get _instance => widget.instance;

  void _show(int tab) =>
      ref.read(technitiumTabProvider(_instance).notifier).state = tab;

  @override
  Widget build(BuildContext context) {
    final int tab = ref.watch(technitiumTabProvider(_instance));
    _shown.add(tab);

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        final ScaffoldState? scaffold = _scaffoldKey.currentState;
        if (scaffold?.isDrawerOpen ?? false) {
          scaffold!.closeDrawer();
          return;
        }
        if (ref.read(technitiumTabProvider(_instance)) != _overview) {
          _show(_overview);
          return;
        }
        GoRouter.of(context).go(AtriumRoutes.dashboard);
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawerEdgeDragWidth: widget.drawer != null ? 32 : null,
        drawer: widget.drawer,
        appBar: AppBar(
          leading: widget.drawer == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.menu),
                  tooltip: 'Services',
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
          title: Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  _instance.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_instance.kind.isBeta) ...<Widget>[
                const SizedBox(width: Insets.sm),
                const BetaBadge(),
              ],
            ],
          ),
        ),
        body: IndexedStack(
          index: tab,
          children: <Widget>[
            TechnitiumOverviewTab(instance: _instance, now: widget.now),
            if (_shown.contains(_queryLog))
              TechnitiumQueryLogTab(instance: _instance)
            else
              const SizedBox.shrink(),
            if (_shown.contains(_blockedZones))
              TechnitiumBlockedZonesTab(instance: _instance)
            else
              const SizedBox.shrink(),
            if (_shown.contains(_settings))
              TechnitiumSettingsTab(instance: _instance)
            else
              const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: AtriumBottomNav(
          visible: true,
          selectedIndex: tab,
          onDestinationSelected: _show,
          destinations: const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Overview',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Query log',
            ),
            NavigationDestination(
              icon: Icon(Icons.block_outlined),
              selectedIcon: Icon(Icons.block_rounded),
              label: 'Blocked zones',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
