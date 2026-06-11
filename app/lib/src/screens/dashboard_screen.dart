import 'package:collection/collection.dart';
import 'package:core_models/core_models.dart';
import 'package:core_profile/core_profile.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../health_providers.dart';

/// Home screen: every configured instance, grouped by role, each with a live
/// health dot. Empty state guides the user to add their first instance.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Instance> instances = ref.watch(activeInstancesProvider);
    final Profile? profile = ref.watch(activeProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(profile == null ? 'Atrium' : profile.name),
        actions: <Widget>[
          IconButton(
            tooltip: 'Profiles',
            icon: const Icon(Icons.switch_account_outlined),
            onPressed: () =>
                context.goNamed(AtriumRoutes.profilesName),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.goNamed(AtriumRoutes.addInstanceName),
        icon: const Icon(Icons.add),
        label: const Text('Add service'),
      ),
      body: instances.isEmpty
          ? EmptyView(
              icon: Icons.dns_outlined,
              title: 'No services yet',
              message:
                  'Add your first service - a Sonarr, qBittorrent, Jellyfin, '
                  'anything in your stack.',
              action: FilledButton.icon(
                onPressed: () =>
                    context.goNamed(AtriumRoutes.addInstanceName),
                icon: const Icon(Icons.add),
                label: const Text('Add service'),
              ),
            )
          : _DashboardList(instances: instances),
    );
  }
}

class _DashboardList extends StatelessWidget {
  const _DashboardList({required this.instances});

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
      padding: const EdgeInsets.fromLTRB(
        Insets.lg,
        Insets.lg,
        Insets.lg,
        // leave room for the FAB
        Insets.xxl * 2,
      ),
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
                bottom: Insets.sm,
                left: Insets.xs,
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
                padding: const EdgeInsets.only(bottom: Insets.sm),
                child: _HealthAwareTile(instance: instance),
              ),
          ],
        );
      },
    );
  }
}

/// A [ServiceTile] whose health dot reflects a live probe.
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
      onTap: () => context.go(
        AtriumRoutes.servicePath(instance.kind.name, instance.id),
      ),
    );
  }
}
