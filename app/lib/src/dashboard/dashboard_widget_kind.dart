import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';

/// The widget types the dashboard board can show, in default display order.
enum DashboardWidgetKind {
  downloads,
  streams,
  upcoming,
  recentlyAdded,
  health,
  requests,
  serverInfo,
  diskSpace,
}

extension DashboardWidgetKindX on DashboardWidgetKind {
  String get label => switch (this) {
        DashboardWidgetKind.downloads => 'Active downloads',
        DashboardWidgetKind.streams => 'Now streaming',
        DashboardWidgetKind.upcoming => 'Upcoming releases',
        DashboardWidgetKind.recentlyAdded => 'Recently added',
        DashboardWidgetKind.health => 'Service health',
        DashboardWidgetKind.requests => 'Requests',
        DashboardWidgetKind.serverInfo => 'Server info',
        DashboardWidgetKind.diskSpace => 'Disk space',
      };

  IconData get icon => switch (this) {
        DashboardWidgetKind.downloads => Icons.download_rounded,
        DashboardWidgetKind.streams => Icons.play_circle_outline,
        DashboardWidgetKind.upcoming => Icons.event_outlined,
        DashboardWidgetKind.recentlyAdded => Icons.new_releases_outlined,
        DashboardWidgetKind.health => Icons.monitor_heart_outlined,
        DashboardWidgetKind.requests => Icons.bookmark_added_outlined,
        DashboardWidgetKind.serverInfo => Icons.memory,
        DashboardWidgetKind.diskSpace => Icons.storage_outlined,
      };

  /// Service kinds whose presence makes this widget "configured". The health
  /// widget is configured whenever ANY instance exists.
  List<ServiceKind> get serviceKinds => switch (this) {
        DashboardWidgetKind.downloads => const <ServiceKind>[
            ServiceKind.qbittorrent,
            ServiceKind.sabnzbd
          ],
        DashboardWidgetKind.streams => const <ServiceKind>[
            ServiceKind.tautulli,
            ServiceKind.jellyfin,
            ServiceKind.emby,
          ],
        DashboardWidgetKind.upcoming => const <ServiceKind>[
            ServiceKind.sonarr,
            ServiceKind.radarr
          ],
        DashboardWidgetKind.recentlyAdded => const <ServiceKind>[
            ServiceKind.sonarr,
            ServiceKind.radarr
          ],
        DashboardWidgetKind.health => ServiceKind.values,
        DashboardWidgetKind.requests => const <ServiceKind>[ServiceKind.seerr],
        DashboardWidgetKind.serverInfo => const <ServiceKind>[
            ServiceKind.glances
          ],
        DashboardWidgetKind.diskSpace => const <ServiceKind>[
            ServiceKind.sabnzbd,
            ServiceKind.glances
          ],
      };
}
