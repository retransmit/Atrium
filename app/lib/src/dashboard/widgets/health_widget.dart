import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../health_providers.dart';
import '../dashboard_widget_card.dart';
import '../dashboard_widget_kind.dart';

/// Live status of every configured instance, as a chip grid with a summary.
class DashboardHealthWidget extends ConsumerWidget {
  const DashboardHealthWidget({required this.instances, super.key});

  final List<Instance> instances;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    final Map<Instance, Health> health = <Instance, Health>{
      for (final Instance i in instances)
        i: ref.watch(instanceHealthProvider(i)).maybeWhen(
              data: (Health h) => h,
              orElse: () => Health.unknown,
            ),
    };
    final int issues = health.values
        .where((Health h) => h == Health.warning || h == Health.error)
        .length;

    return DashboardWidgetCard(
      kind: DashboardWidgetKind.health,
      accent: issues > 0 ? cs.error : cs.tertiary,
      trailing: DashboardPill(
        icon: issues > 0 ? Icons.warning_amber_rounded : Icons.check_rounded,
        label:
            issues > 0 ? '$issues issue${issues == 1 ? '' : 's'}' : 'All online',
        color: issues > 0 ? cs.error : cs.tertiary,
      ),
      child: Wrap(
        spacing: Insets.sm,
        runSpacing: Insets.sm,
        children: <Widget>[
          for (final MapEntry<Instance, Health> e in health.entries)
            _HealthChip(instance: e.key, health: e.value),
        ],
      ),
    );
  }
}

class _HealthChip extends StatelessWidget {
  const _HealthChip({required this.instance, required this.health});

  final Instance instance;
  final Health health;

  Color _dot(ColorScheme cs) => switch (health) {
        Health.ok => cs.tertiary,
        Health.warning => cs.secondary,
        Health.error => cs.error,
        _ => cs.outline,
      };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => context.go(
        AtriumRoutes.servicePath(instance.kind.name, instance.id),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: _dot(cs), shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(instance.name, style: theme.textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}
