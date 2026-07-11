import 'package:core_models/core_models.dart';
import 'package:core_profile/core_profile.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core_router/core_router.dart';
import 'package:service_bazarr/service_bazarr.dart';
import 'package:service_emby/service_emby.dart';
import 'package:service_jellyfin/service_jellyfin.dart';
import 'package:service_seerr/service_seerr.dart';
import 'package:service_plex/service_plex.dart';
import 'package:service_prowlarr/service_prowlarr.dart';
import 'package:service_qbittorrent/service_qbittorrent.dart';
import 'package:service_radarr/service_radarr.dart';
import 'package:service_sabnzbd/service_sabnzbd.dart';
import 'package:service_glances/service_glances.dart';
import 'package:service_sonarr/service_sonarr.dart';
import 'package:service_tautulli/service_tautulli.dart';

import 'dashboard_screen.dart';

/// Routes an instance to its service-specific screen, dispatching on
/// [ServiceKind]. The switch is exhaustive - every service has a UI module.
class ServiceDetailScreen extends ConsumerStatefulWidget {
  const ServiceDetailScreen({
    required this.kindName,
    required this.instanceId,
    super.key,
  });

  final String kindName;
  final String instanceId;

  @override
  ConsumerState<ServiceDetailScreen> createState() =>
      _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends ConsumerState<ServiceDetailScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final Instance? instance =
        ref.watch(instanceByIdProvider(widget.instanceId));
    if (instance == null) {
      return const _NotFound();
    }
    if (instance.kind == ServiceKind.sonarr) {
      return SonarrHome(
        instance: instance,
        drawer: ServicesDrawer(
          instances: ref.watch(activeInstancesProvider),
          profile: ref.watch(activeProfileProvider),
        ),
      );
    }
    if (instance.kind == ServiceKind.radarr) {
      return RadarrHome(
        instance: instance,
        drawer: ServicesDrawer(
          instances: ref.watch(activeInstancesProvider),
          profile: ref.watch(activeProfileProvider),
        ),
      );
    }
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        // A back press while a drawer is open only closes that drawer.
        final ScaffoldState? scaffold = _scaffoldKey.currentState;
        if (scaffold?.isDrawerOpen ?? false) {
          scaffold!.closeDrawer();
          return;
        }
        if (scaffold?.isEndDrawerOpen ?? false) {
          scaffold!.closeEndDrawer();
          return;
        }
        context.goNamed(AtriumRoutes.dashboardName);
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawerEdgeDragWidth: MediaQuery.sizeOf(context).width * 0.15,
        drawer: ServicesDrawer(
          instances: ref.watch(activeInstancesProvider),
          profile: ref.watch(activeProfileProvider),
        ),
        endDrawer: instance.kind == ServiceKind.qbittorrent
            ? QbittorrentFilterDrawer(instance: instance)
            : null,
      appBar: AppBar(
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
        title: instance.kind == ServiceKind.emby
            ? TextField(
                readOnly: true,
                onTap: () {
                  showSearch<void>(
                    context: context,
                    useRootNavigator: true,
                    delegate: EmbySearchDelegate(instance: instance),
                  );
                },
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                decoration: InputDecoration(
                  hintText: 'Search Emby...',
                  hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 16,
                        color: Theme.of(context)
                            .colorScheme
                            .onSecondaryContainer
                            .withValues(alpha: 0.7),
                      ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 10.0,
                    horizontal: 20.0,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(32),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(32),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.secondaryContainer,
                ),
              )
            : Text(instance.name),
        actions: <Widget>[
          if (instance.kind == ServiceKind.jellyfin ||
              instance.kind == ServiceKind.plex ||
              instance.kind == ServiceKind.seerr)
            IconButton(
              tooltip: 'Search',
              icon: const Icon(Icons.search),
              onPressed: () {
                showSearch<void>(
                  context: context,
                  // Root navigator: the search page is pushed imperatively,
                  // so it must not ride the branch navigator (GoRouter shell
                  // rebuilds sweep it).
                  useRootNavigator: true,
                  delegate: switch (instance.kind) {
                    ServiceKind.emby => EmbySearchDelegate(instance: instance),
                    ServiceKind.plex => PlexSearchDelegate(instance: instance),
                    ServiceKind.seerr =>
                      SeerrSearchDelegate(instance: instance),
                    _ => JellyfinSearchDelegate(instance: instance),
                  },
                );
              },
            ),
          if (instance.kind == ServiceKind.emby)
            Consumer(
              builder: (BuildContext context, WidgetRef ref, Widget? child) {
                final int activeTab =
                    ref.watch(embyActiveTabBarIndexProvider(instance));
                if (activeTab == 0) {
                  return const SizedBox.shrink();
                }
                final EmbyViewMode viewMode =
                    ref.watch(embyViewModeProvider(instance));
                return IconButton(
                  tooltip: viewMode == EmbyViewMode.grid
                      ? 'Switch to List View'
                      : 'Switch to Grid View',
                  icon: Icon(viewMode == EmbyViewMode.grid
                      ? Icons.view_headline
                      : Icons.grid_view),
                  onPressed: () {
                    ref.read(embyViewModeProvider(instance).notifier).state =
                        viewMode == EmbyViewMode.grid
                            ? EmbyViewMode.list
                            : EmbyViewMode.grid;
                  },
                );
              },
            ),
          if (instance.kind == ServiceKind.qbittorrent)
            QbittorrentAppBarActions(instance: instance),

          if (instance.kind == ServiceKind.emby ||
              instance.kind == ServiceKind.jellyfin)
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings),
              onPressed: () => pushScreen<void>(
                context,
                instance.kind == ServiceKind.emby
                    ? EmbySettingsScreen(instance: instance)
                    : JellyfinSettingsScreen(instance: instance),
              ),
            ),


        ],
      ),
      body: _bodyFor(instance),
    ));
  }

  Widget _bodyFor(Instance instance) {
    return switch (instance.kind) {
      // Sonarr and Radarr never reach here: build() returns early.
      ServiceKind.sonarr => const SizedBox.shrink(),
      ServiceKind.radarr => const SizedBox.shrink(),
      ServiceKind.prowlarr => ProwlarrHome(instance: instance),
      ServiceKind.bazarr => BazarrHome(instance: instance),
      ServiceKind.seerr => SeerrHome(instance: instance),
      ServiceKind.tautulli => TautulliHome(instance: instance),
      ServiceKind.jellyfin => JellyfinHome(instance: instance),
      ServiceKind.emby => EmbyHome(instance: instance),
      ServiceKind.plex => PlexHome(instance: instance),
      ServiceKind.qbittorrent => QbittorrentHome(instance: instance),
      ServiceKind.sabnzbd => SabnzbdHome(instance: instance),
      ServiceKind.glances => GlancesHome(instance: instance),
    };
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    // The service route is top-level, so there is nothing beneath it to pop
    // to; route back presses to the dashboard instead of backgrounding the
    // app.
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        context.goNamed(AtriumRoutes.dashboardName);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.goNamed(AtriumRoutes.dashboardName),
          ),
        ),
        body: const ErrorView(
          title: 'Service not found',
          message: 'This instance may have been deleted.',
        ),
      ),
    );
  }
}
