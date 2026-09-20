import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:service_gluetun/service_gluetun.dart';

import '../dashboard_widget_card.dart';
import '../dashboard_widget_kind.dart';

class DashboardGluetunStatusWidget extends ConsumerWidget {
  const DashboardGluetunStatusWidget({
    required this.instances,
    super.key,
  });

  final List<Instance> instances;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Color accent = Theme.of(context).colorScheme.primary;
    return DashboardWidgetCard(
      kind: DashboardWidgetKind.gluetunStatus,
      accent: accent,
      onTap: instances.length == 1
          ? () => _open(context, instances.first)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int index = 0; index < instances.length; index++) ...<Widget>[
            if (index > 0) const Divider(height: Insets.lg),
            _GluetunInstanceBlock(
              instance: instances[index],
              showName: instances.length > 1,
              onTap: instances.length > 1
                  ? () => _open(context, instances[index])
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  void _open(BuildContext context, Instance instance) {
    context.go(
      AtriumRoutes.servicePath(instance.kind.name, instance.id),
    );
  }
}

class _GluetunInstanceBlock extends ConsumerWidget {
  const _GluetunInstanceBlock({
    required this.instance,
    required this.showName,
    required this.onTap,
  });

  final Instance instance;
  final bool showName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<GluetunVpnStatus> statusAsync =
        ref.watch(gluetunVpnStatusProvider(instance));
    final AsyncValue<GluetunPublicIp?> ipAsync =
        ref.watch(gluetunPublicIpProvider(instance));

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (showName)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.sm),
                child: Text(
                  instance.name,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            statusAsync.when(
              skipLoadingOnReload: true,
              skipLoadingOnRefresh: true,
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(Insets.sm),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              ),
              error: (Object error, StackTrace _) => _DashboardError(
                error: error,
                onRetry: () {
                  ref.invalidate(gluetunVpnStatusProvider(instance));
                  ref.invalidate(gluetunPublicIpProvider(instance));
                },
              ),
              data: (GluetunVpnStatus status) {
                final GluetunPublicIp? ipData = ipAsync.value;
                return _DashboardGluetunResult(
                  status: status,
                  ipData: ipData,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardGluetunResult extends StatelessWidget {
  const _DashboardGluetunResult({
    required this.status,
    required this.ipData,
  });

  final GluetunVpnStatus status;
  final GluetunPublicIp? ipData;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isRunning = status.isRunning;
    final Color statusColor = isRunning
        ? theme.colorScheme.primary
        : theme.colorScheme.error;

    final GluetunPlaces? places = ipData?.places;
    final List<String> locationParts = <String?>[
      places?.city,
      places?.region,
      places?.country,
    ].whereType<String>().toList();
    final String locationText = locationParts.isNotEmpty
        ? locationParts.join(', ')
        : (ipData?.organization ?? 'Unknown location');

    final String publicIpText =
        (ipData?.publicIp != null && ipData!.publicIp.isNotEmpty)
            ? ipData!.publicIp
            : 'No IP';

    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.sm,
            vertical: Insets.xs,
          ),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                isRunning ? Icons.check_circle_outline : Icons.error_outline,
                size: 14,
                color: statusColor,
              ),
              const SizedBox(width: Insets.xs),
              Text(
                status.status.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: Insets.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                publicIpText,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                locationText,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Icon(
          Icons.chevron_right,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Could not load Gluetun status. '
          '${describeGluetunFailure(error, 'GET /v1/vpn/status')}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: onRetry, child: const Text('Retry')),
        ),
      ],
    );
  }
}
