import 'package:core_models/core_models.dart';
import 'package:core_profile/core_profile.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:service_emby/service_emby.dart' as emby;
import 'package:service_glances/service_glances.dart';
import 'package:service_jellyfin/service_jellyfin.dart' as jf;
import 'package:service_qbittorrent/service_qbittorrent.dart';
import 'package:service_radarr/service_radarr.dart';
import 'package:service_sabnzbd/service_sabnzbd.dart';
import 'package:service_seerr/service_seerr.dart';
import 'package:service_sonarr/service_sonarr.dart';
import 'package:service_tautulli/service_tautulli.dart';

import '../health_providers.dart';
import '../screens/calendar_screen.dart';
import 'dashboard_layout.dart';
import 'dashboard_widget_kind.dart';
import 'widgets/disk_widget.dart';
import 'widgets/downloads_widget.dart';
import 'widgets/health_widget.dart';
import 'widgets/recently_added_widget.dart';
import 'widgets/requests_widget.dart';
import 'widgets/server_info_widget.dart';
import 'widgets/streams_widget.dart';
import 'widgets/upcoming_widget.dart';

/// Whether the board is in inline edit (reorder / hide) mode. Toggled from
/// the dashboard app bar; ephemeral by design (resets on app restart).
final StateProvider<bool> dashboardEditModeProvider =
    StateProvider<bool>((Ref ref) => false);

/// The dashboard widget board: at-a-glance cards in the user's saved order,
/// with an inline edit mode for reordering and hiding.
class DashboardBoard extends ConsumerWidget {
  const DashboardBoard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Instance> instances = ref.watch(activeInstancesProvider);
    final List<DashboardWidgetConfig> layout =
        ref.watch(dashboardLayoutProvider);
    final bool editing = ref.watch(dashboardEditModeProvider);

    if (editing) {
      return _EditBoard(layout: layout, instances: instances);
    }

    final List<DashboardWidgetConfig> visible = <DashboardWidgetConfig>[
      for (final DashboardWidgetConfig c in layout)
        if (c.enabled &&
            _configured(c.kind, instances) &&
            _hasLiveContent(ref, c.kind))
          c,
    ];

    if (visible.isEmpty) {
      return const EmptyView(
        icon: Icons.dashboard_customize_outlined,
        title: 'No widgets to show',
        message: 'Use the customize button (top right) to add widgets.',
      );
    }

    return M3RefreshIndicator(
      onRefresh: () async => _refreshAll(ref, instances),
      child: ListView.separated(
        padding: Insets.page,
        itemCount: visible.length,
        separatorBuilder: (_, __) => const SizedBox(height: Insets.md),
        itemBuilder: (BuildContext context, int index) =>
            _buildWidget(visible[index].kind, instances),
      ),
    );
  }

  static bool _configured(DashboardWidgetKind kind, List<Instance> instances) {
    if (kind == DashboardWidgetKind.health) {
      return instances.isNotEmpty;
    }
    return instances.any((Instance i) => kind.serviceKinds.contains(i.kind));
  }

  /// Downloads and streams are activity-gated: they only appear on the board
  /// while something is actually downloading / streaming, instead of sitting
  /// there with an idle row. Every other widget shows whenever its service is
  /// configured.
  static bool _hasLiveContent(WidgetRef ref, DashboardWidgetKind kind) {
    return switch (kind) {
      DashboardWidgetKind.downloads => ref.watch(activeDownloadCountProvider) > 0,
      DashboardWidgetKind.streams => ref.watch(activeStreamCountProvider) > 0,
      _ => true,
    };
  }

  static List<Instance> _byKind(List<Instance> instances, ServiceKind kind) =>
      <Instance>[
        for (final Instance i in instances)
          if (i.kind == kind) i,
      ];

  Widget _buildWidget(DashboardWidgetKind kind, List<Instance> instances) {
    switch (kind) {
      case DashboardWidgetKind.downloads:
        return DashboardDownloadsWidget(
          qbitInstances: _byKind(instances, ServiceKind.qbittorrent),
          sabInstances: _byKind(instances, ServiceKind.sabnzbd),
        );
      case DashboardWidgetKind.streams:
        return DashboardStreamsWidget(
          tautulliInstances: _byKind(instances, ServiceKind.tautulli),
          jellyfinInstances: _byKind(instances, ServiceKind.jellyfin),
          embyInstances: _byKind(instances, ServiceKind.emby),
        );
      case DashboardWidgetKind.upcoming:
        return const DashboardUpcomingWidget();
      case DashboardWidgetKind.recentlyAdded:
        return DashboardRecentlyAddedWidget(
          sonarrInstances: _byKind(instances, ServiceKind.sonarr),
          radarrInstances: _byKind(instances, ServiceKind.radarr),
        );
      case DashboardWidgetKind.health:
        return DashboardHealthWidget(instances: instances);
      case DashboardWidgetKind.requests:
        return DashboardRequestsWidget(
          instances: _byKind(instances, ServiceKind.seerr),
        );
      case DashboardWidgetKind.serverInfo:
        return DashboardServerInfoWidget(
          instances: _byKind(instances, ServiceKind.glances),
        );
      case DashboardWidgetKind.diskSpace:
        return DashboardDiskWidget(
          sabInstances: _byKind(instances, ServiceKind.sabnzbd),
          glancesInstances: _byKind(instances, ServiceKind.glances),
        );
    }
  }

  void _refreshAll(WidgetRef ref, List<Instance> instances) {
    for (final Instance i in instances) {
      ref.invalidate(instanceHealthProvider(i));
      switch (i.kind) {
        case ServiceKind.sonarr:
          ref.invalidate(sonarrSeriesProvider(i));
        case ServiceKind.radarr:
          ref.invalidate(radarrMoviesProvider(i));
        case ServiceKind.qbittorrent:
          ref.invalidate(qbitRawTorrentsProvider(i));
          ref.invalidate(qbitTransferProvider(i));
        case ServiceKind.sabnzbd:
          ref.invalidate(sabQueueProvider(i));
        case ServiceKind.tautulli:
          ref.invalidate(tautulliActivityProvider(i));
        case ServiceKind.jellyfin:
          ref.invalidate(jf.jellyfinSessionsProvider(i));
        case ServiceKind.emby:
          ref.invalidate(emby.embySessionsProvider(i));
        case ServiceKind.seerr:
          ref.invalidate(seerrRequestCountsProvider(i));
          ref.invalidate(seerrRequestsProvider(i));
        case ServiceKind.glances:
          ref.invalidate(glancesStatsProvider(i));
        default:
          break;
      }
    }
    for (final DateTime m in upcomingWindowMonths(DateTime.now())) {
      ref.invalidate(globalCalendarProvider(m));
    }
  }
}

/// Edit mode: enabled widgets as a reorderable list of header tiles, hidden
/// widgets greyed out below with a re-add button.
class _EditBoard extends ConsumerWidget {
  const _EditBoard({required this.layout, required this.instances});

  final List<DashboardWidgetConfig> layout;
  final List<Instance> instances;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<DashboardWidgetConfig> enabled = <DashboardWidgetConfig>[
      for (final DashboardWidgetConfig c in layout)
        if (c.enabled) c,
    ];
    final List<DashboardWidgetConfig> hidden = <DashboardWidgetConfig>[
      for (final DashboardWidgetConfig c in layout)
        if (!c.enabled) c,
    ];

    return ReorderableListView(
      padding: Insets.page,
      buildDefaultDragHandles: false,
      onReorder: (int oldIndex, int newIndex) => ref
          .read(dashboardLayoutProvider.notifier)
          .moveEnabled(oldIndex, newIndex),
      footer: hidden.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Insets.md),
                  child: Text(
                    'Hidden',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                for (final DashboardWidgetConfig c in hidden)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Insets.sm),
                    child: Opacity(
                      opacity: 0.6,
                      child: _EditTile(
                        config: c,
                        instances: instances,
                        trailing: IconButton(
                          tooltip: 'Show widget',
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => ref
                              .read(dashboardLayoutProvider.notifier)
                              .setEnabled(c.kind, true),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
      children: <Widget>[
        for (int index = 0; index < enabled.length; index++)
          Padding(
            key: ValueKey<DashboardWidgetKind>(enabled[index].kind),
            padding: const EdgeInsets.only(bottom: Insets.sm),
            child: _EditTile(
              config: enabled[index],
              instances: instances,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    tooltip: 'Hide widget',
                    icon: const Icon(Icons.visibility_off_outlined),
                    onPressed: () => ref
                        .read(dashboardLayoutProvider.notifier)
                        .setEnabled(enabled[index].kind, false),
                  ),
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.drag_indicator),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _EditTile extends StatelessWidget {
  const _EditTile({
    required this.config,
    required this.instances,
    required this.trailing,
  });

  final DashboardWidgetConfig config;
  final List<Instance> instances;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final bool configured = DashboardBoard._configured(config.kind, instances);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.sm,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(config.kind.icon, size: 20, color: cs.primary),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  config.kind.label,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (!configured)
                  Text(
                    'Not configured',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
