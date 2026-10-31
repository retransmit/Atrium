import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/slskd_system_models.dart';
import '../slskd_providers.dart';
import '../system/slskd_daemon_card.dart';
import '../system/slskd_disk_files_sheet.dart';
import '../system/slskd_logs_view.dart';
import '../system/slskd_options_sheet.dart';
import '../system/slskd_server_card.dart';
import '../system/slskd_shares_view.dart';
import '../system/slskd_user_card.dart';
import '../system/slskd_vpn_card.dart';
import '../transfers/slskd_analytics_sheet.dart';

/// Tab 4: System & Health — Soulseek connection health, user stats, daemon controls, local shares, and live logs.
class SlskdSystemTab extends ConsumerStatefulWidget {
  const SlskdSystemTab({
    required this.instance,
    this.onOpenDrawer,
    super.key,
  });

  final Instance instance;
  final VoidCallback? onOpenDrawer;

  @override
  ConsumerState<SlskdSystemTab> createState() => _SlskdSystemTabState();
}

class _SlskdSystemTabState extends ConsumerState<SlskdSystemTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final ScrollController _healthScrollController;

  @override
  void initState() {
    super.initState();
    final int initialTab = ref.read(slskdSystemSegmentProvider(widget.instance));
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: initialTab.clamp(0, 2).toInt(),
    );
    _tabController.addListener(_handleTabChanged);
    _healthScrollController = ScrollController();
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) return;
    ref.read(slskdSystemSegmentProvider(widget.instance).notifier).state =
        _tabController.index;
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    _healthScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final stateAsync = ref.watch(slskdApplicationStateProvider(widget.instance));

    ref.listen<int>(
      slskdSystemSegmentProvider(widget.instance),
      (previous, next) {
        if (_tabController.index != next && next >= 0 && next < 3) {
          _tabController.animateTo(next);
        }
      },
    );

    ref.listen<int>(
      slskdScrollToTopProvider((widget.instance, 4)),
      (previous, next) {
        if (next > 0 && _healthScrollController.hasClients) {
          _healthScrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        leading: widget.onOpenDrawer != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: widget.onOpenDrawer,
              )
            : null,
        title: const Text('System & Health'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh system info',
            onPressed: () {
              ref.invalidate(slskdApplicationStateProvider(widget.instance));
              ref.invalidate(slskdSharesProvider(widget.instance));
              ref.invalidate(slskdLogsProvider(widget.instance));
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (String val) {
              if (val == 'analytics') {
                SlskdAnalyticsSheet.show(context, instance: widget.instance);
              } else if (val == 'storage') {
                SlskdDiskFilesSheet.show(context, instance: widget.instance);
              } else if (val == 'options') {
                SlskdOptionsSheet.show(context, instance: widget.instance);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'analytics',
                child: ListTile(
                  leading: Icon(Icons.analytics_outlined),
                  title: Text('Transfer analytics & KPIs'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'storage',
                child: ListTile(
                  leading: Icon(Icons.folder_open_rounded),
                  title: Text('Host storage explorer'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'options',
                child: ListTile(
                  leading: Icon(Icons.settings_suggest_rounded),
                  title: Text('Configuration & diagnostics'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          indicatorColor: colorScheme.primary,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: const <Widget>[
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.health_and_safety_outlined, size: 18),
                  SizedBox(width: Insets.xs),
                  Text('Health'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.folder_shared_outlined, size: 18),
                  SizedBox(width: Insets.xs),
                  Text('Shares'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.article_outlined, size: 18),
                  SizedBox(width: Insets.xs),
                  Text('Logs'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          _buildHealthTab(context, colorScheme, stateAsync),
          _buildSharesTab(context, colorScheme, stateAsync),
          _buildLogsTab(context),
        ],
      ),
    );
  }

  Widget _buildHealthTab(
    BuildContext context,
    ColorScheme colorScheme,
    AsyncValue<SlskdApplicationState> stateAsync,
  ) {
    return EasyRefresh(
      onRefresh: () async {
        try {
          ref.invalidate(slskdApplicationStateProvider(widget.instance));
          await ref.read(slskdApplicationStateProvider(widget.instance).future);
        } catch (_) {}
      },
      child: stateAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(Insets.xl),
            child: ExpressiveProgressIndicator(),
          ),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(Insets.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.error_outline_rounded,
                  size: 40,
                  color: colorScheme.error,
                ),
                const SizedBox(height: Insets.sm),
                Text(
                  'Failed to load system state',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: Insets.xs),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.error,
                      ),
                ),
              ],
            ),
          ),
        ),
        data: (state) {
          return ListView(
            controller: _healthScrollController,
            padding: const EdgeInsets.all(Insets.md),
            children: <Widget>[
              SlskdServerCard(
                instance: widget.instance,
                server: state.server,
                watchdog: state.connectionWatchdog,
              ),
              const SizedBox(height: Insets.sm),
              SlskdUserCard(user: state.user),
              const SizedBox(height: Insets.sm),
              SlskdDaemonCard(
                instance: widget.instance,
                version: state.version,
              ),
              if (state.vpn != null) ...<Widget>[
                const SizedBox(height: Insets.sm),
                SlskdVpnCard(vpn: state.vpn!),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSharesTab(
    BuildContext context,
    ColorScheme colorScheme,
    AsyncValue<SlskdApplicationState> stateAsync,
  ) {
    return EasyRefresh(
      onRefresh: () async {
        try {
          ref.invalidate(slskdApplicationStateProvider(widget.instance));
          ref.invalidate(slskdSharesProvider(widget.instance));
          await Future.wait(<Future<dynamic>>[
            ref.read(slskdApplicationStateProvider(widget.instance).future),
            ref.read(slskdSharesProvider(widget.instance).future),
          ]);
        } catch (_) {}
      },
      child: stateAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(Insets.xl),
            child: ExpressiveProgressIndicator(),
          ),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(Insets.xl),
            child: Text(
              'Failed to load shares: $error',
              style: TextStyle(color: colorScheme.error),
            ),
          ),
        ),
        data: (state) {
          return ListView(
            padding: const EdgeInsets.all(Insets.md),
            children: <Widget>[
              SlskdSharesView(
                instance: widget.instance,
                sharesState: state.shares,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLogsTab(BuildContext context) {
    return EasyRefresh(
      onRefresh: () async {
        try {
          ref.invalidate(slskdLogsProvider(widget.instance));
          ref.invalidate(slskdLogFilesProvider(widget.instance));
          await Future.wait(<Future<dynamic>>[
            ref.read(slskdLogsProvider(widget.instance).future),
            ref.read(slskdLogFilesProvider(widget.instance).future),
          ]);
        } catch (_) {}
      },
      child: ListView(
        padding: const EdgeInsets.all(Insets.md),
        children: <Widget>[
          SlskdLogsView(instance: widget.instance),
        ],
      ),
    );
  }
}
