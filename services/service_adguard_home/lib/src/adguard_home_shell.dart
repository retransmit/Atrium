import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import 'adguard_home_log_actions.dart';
import 'tabs/adguard_home_home_tab.dart';
import 'tabs/adguard_home_query_log_tab.dart';

/// Which of the screen's tabs is showing: 0 Home, 1 Query log. Kept for the
/// session, so the service opens where it was left.
final adguardHomeTabProvider =
    StateProvider.family<int, Instance>((Ref ref, Instance _) => 0);

/// The AdGuard Home screen: its own scaffold, app bar, bottom bar and back
/// handling.
///
/// It owns the scaffold because back has to mean something of its own here:
/// close the drawer if it is open, then go to Home from another tab, and
/// only then leave for the dashboard. The app's generic service scaffold
/// would leave on every press.
class AdguardHomeShell extends ConsumerStatefulWidget {
  const AdguardHomeShell({
    required this.instance,
    this.drawer,
    super.key,
  });

  final Instance instance;
  final Widget? drawer;

  @override
  ConsumerState<AdguardHomeShell> createState() => _AdguardHomeShellState();
}

class _AdguardHomeShellState extends ConsumerState<AdguardHomeShell> {
  static const int _queryLog = 1;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// The tabs that have been shown. A tab is built when it is first shown
  /// and then kept: opening the service must not read a query log nobody
  /// is looking at.
  final Set<int> _shown = <int>{0};

  Instance get _instance => widget.instance;

  void _show(int tab) =>
      ref.read(adguardHomeTabProvider(_instance).notifier).state = tab;

  @override
  Widget build(BuildContext context) {
    final int tab = ref.watch(adguardHomeTabProvider(_instance));
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
        if (ref.read(adguardHomeTabProvider(_instance)) != 0) {
          _show(0);
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
          actions: <Widget>[
            if (tab == _queryLog)
              PopupMenuButton<void>(
                tooltip: 'More',
                useRootNavigator: true,
                itemBuilder: (BuildContext _) => <PopupMenuEntry<void>>[
                  PopupMenuItem<void>(
                    onTap: () =>
                        adguardHomeClearQueryLog(context, ref, _instance),
                    child: const Text('Clear query log'),
                  ),
                ],
              ),
          ],
        ),
        body: IndexedStack(
          index: tab,
          children: <Widget>[
            AdguardHomeHomeTab(instance: _instance),
            if (_shown.contains(_queryLog))
              AdguardHomeQueryLogTab(instance: _instance)
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
              icon: Icon(Icons.shield_outlined),
              selectedIcon: Icon(Icons.shield),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Query log',
            ),
          ],
        ),
      ),
    );
  }
}
