import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'tabs/adguard_home_home_tab.dart';

/// The AdGuard Home screen: its own scaffold, app bar and back handling.
///
/// It owns the scaffold because back has to mean something of its own here:
/// close the drawer if it is open, otherwise leave for the dashboard. The
/// app's generic service scaffold would leave on every press.
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        final ScaffoldState? scaffold = _scaffoldKey.currentState;
        if (scaffold?.isDrawerOpen ?? false) {
          scaffold!.closeDrawer();
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
        body: AdguardHomeHomeTab(instance: widget.instance),
      ),
    );
  }
}
