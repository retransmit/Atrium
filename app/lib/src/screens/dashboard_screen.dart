import 'package:collection/collection.dart';
import 'package:core_models/core_models.dart';
import 'package:core_profile/core_profile.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../health_providers.dart';

/// Home screen. Services now live in the navigation drawer (the sidebar); the
/// dashboard body is reserved for at-a-glance widgets (added later). Until a
/// service exists, the body onboards the user to add their first one.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Instance> instances = ref.watch(activeInstancesProvider);
    final Profile? profile = ref.watch(activeProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(profile == null ? 'Atrium' : profile.name),
      ),
      drawer: _ServicesDrawer(instances: instances, profile: profile),
      // Wide left-edge drag zone so the sidebar opens with a swipe from well
      // inside the screen, clear of Android's system back-gesture strip - no
      // need to hit the hamburger.
      drawerEdgeDragWidth: MediaQuery.sizeOf(context).width * 0.5,
      body: instances.isEmpty
          ? EmptyView(
              icon: Icons.dns_outlined,
              title: 'No services yet',
              message:
                  'Add your first service - a Sonarr, qBittorrent, Jellyfin, '
                  'anything in your stack.',
              action: FilledButton.icon(
                onPressed: () => context.goNamed(AtriumRoutes.addInstanceName),
                icon: const Icon(Icons.add),
                label: const Text('Add service'),
              ),
            )
          : const _DashboardWidgets(),
    );
  }
}

/// Placeholder for the future widget grid. Kept deliberately simple until real
/// widgets land; points the user at the sidebar for services in the meantime.
class _DashboardWidgets extends StatelessWidget {
  const _DashboardWidgets();

  @override
  Widget build(BuildContext context) {
    return const EmptyView(
      icon: Icons.dashboard_customize_outlined,
      title: 'Dashboard widgets coming soon',
      message:
          'At-a-glance widgets will live here. Open the menu (top left) to jump '
          'to a service.',
    );
  }
}

/// The sidebar: configured services grouped by role (each with a live health
/// dot), plus add-service and profile management in the footer.
class _ServicesDrawer extends StatelessWidget {
  const _ServicesDrawer({required this.instances, required this.profile});

  final List<Instance> instances;
  final Profile? profile;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Drawer(
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.lg,
                Insets.lg,
                Insets.lg,
                Insets.md,
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.dns_rounded,
                      color: theme.colorScheme.primary, size: 28),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: Text(
                      profile == null ? 'Atrium' : profile!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: instances.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(Insets.lg),
                        child: Text(
                          'No services yet.\nAdd one below.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : _ServicesList(instances: instances),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Add service'),
              onTap: () => _navTo(context, AtriumRoutes.addInstanceName),
            ),
            ListTile(
              leading: const Icon(Icons.switch_account_outlined),
              title: const Text('Profiles'),
              onTap: () => _navTo(context, AtriumRoutes.profilesName),
            ),
            const SizedBox(height: Insets.sm),
          ],
        ),
      ),
    );
  }

  /// Capture the router before closing the drawer (popping invalidates the
  /// drawer's own context for navigation).
  void _navTo(BuildContext context, String routeName) {
    final GoRouter router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.goNamed(routeName);
  }
}

class _ServicesList extends StatelessWidget {
  const _ServicesList({required this.instances});

  final List<Instance> instances;

  @override
  Widget build(BuildContext context) {
    // Group by role, preserving the ServiceRole enum order.
    final Map<ServiceRole, List<Instance>> byRole =
        groupBy<Instance, ServiceRole>(
      instances,
      (Instance i) => i.kind.role,
    );
    final List<ServiceRole> roles = ServiceRole.values
        .where((ServiceRole r) => byRole.containsKey(r))
        .toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(Insets.sm, Insets.sm, Insets.sm, Insets.sm),
      itemCount: roles.length,
      itemBuilder: (BuildContext context, int index) {
        final ServiceRole role = roles[index];
        final List<Instance> group = byRole[role]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(
                top: Insets.md,
                bottom: Insets.xs,
                left: Insets.sm,
              ),
              child: Text(
                ServiceVisuals.roleLabel(role),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),
            for (final Instance instance in group)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.xs),
                child: _HealthAwareTile(instance: instance),
              ),
          ],
        );
      },
    );
  }
}

/// A [ServiceTile] whose health dot reflects a live probe. Tapping closes the
/// drawer and opens the service.
class _HealthAwareTile extends ConsumerWidget {
  const _HealthAwareTile({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Health health = ref.watch(instanceHealthProvider(instance)).maybeWhen(
          data: (Health h) => h,
          orElse: () => Health.unknown,
        );
    return ServiceTile(
      instance: instance,
      health: health,
      onTap: () {
        final GoRouter router = GoRouter.of(context);
        Navigator.of(context).pop();
        router.go(AtriumRoutes.servicePath(instance.kind.name, instance.id));
      },
    );
  }
}
