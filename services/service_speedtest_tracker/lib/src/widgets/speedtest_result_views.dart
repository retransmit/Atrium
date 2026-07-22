import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/speedtest_tracker_models.dart';

class SpeedtestLatestCard extends StatelessWidget {
  const SpeedtestLatestCard({required this.result, super.key});

  final SpeedtestResult result;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String serverAndProvider = <String>[
      if (result.server?.displayName != null) result.server!.displayName!,
      if (result.server?.displayLocation != null)
        result.server!.displayLocation!,
      if (result.isp != null) result.isp!,
    ].join(' · ');
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child:
                      Text('Latest result', style: theme.textTheme.titleMedium),
                ),
                if (result.healthy != null)
                  Chip(
                    avatar: Icon(
                      result.healthy! ? Icons.check_circle : Icons.warning,
                      size: 17,
                    ),
                    label: Text(result.healthy! ? 'Healthy' : 'Unhealthy'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: Insets.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: _Metric(
                    icon: Icons.download,
                    label: 'Download',
                    value: formatSpeed(result.downloadBitsPerSecond),
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: _Metric(
                    icon: Icons.upload,
                    label: 'Upload',
                    value: formatSpeed(result.uploadBitsPerSecond),
                    color: theme.colorScheme.tertiary,
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: _Metric(
                    icon: Icons.network_ping,
                    label: 'Ping',
                    value: formatMilliseconds(result.pingMilliseconds),
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ],
            ),
            if (result.jitterMilliseconds != null ||
                result.packetLossPercent != null) ...<Widget>[
              const SizedBox(height: Insets.md),
              Wrap(
                spacing: Insets.sm,
                runSpacing: Insets.sm,
                children: <Widget>[
                  if (result.jitterMilliseconds != null)
                    _InfoChip(
                      icon: Icons.timeline,
                      text:
                          'Jitter ${formatMilliseconds(result.jitterMilliseconds)}',
                    ),
                  if (result.packetLossPercent != null)
                    _InfoChip(
                      icon: Icons.signal_wifi_bad,
                      text:
                          'Loss ${formatPacketLoss(result.packetLossPercent)}',
                    ),
                ],
              ),
            ],
            if (serverAndProvider.isNotEmpty) ...<Widget>[
              const SizedBox(height: Insets.md),
              Text(serverAndProvider, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 4),
            Text(
              formatResultTime(result.completedAt),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SpeedtestResultTile extends StatelessWidget {
  const SpeedtestResultTile({
    required this.result,
    required this.onTap,
    super.key,
  });

  final SpeedtestResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: Insets.sm),
        elevation: 0,
        child: ListTile(
          onTap: onTap,
          leading: const Icon(Icons.speed_outlined),
          title: Text(
            '${formatSpeed(result.downloadBitsPerSecond)} ↓  '
            '${formatSpeed(result.uploadBitsPerSecond)} ↑',
          ),
          subtitle: Text(
            <String>[
              formatMilliseconds(result.pingMilliseconds),
              if (result.serverOrProvider != null) result.serverOrProvider!,
              formatResultTime(result.completedAt),
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.chevron_right),
        ),
      );
}

class SpeedtestRunBanner extends StatelessWidget {
  const SpeedtestRunBanner({
    required this.icon,
    required this.message,
    required this.color,
    this.busy = false,
    super.key,
  });

  final IconData icon;
  final String message;
  final Color color;
  final bool busy;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Insets.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: <Widget>[
            if (busy)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              )
            else
              Icon(icon, size: 20, color: color),
            const SizedBox(width: Insets.sm),
            Expanded(child: Text(message)),
          ],
        ),
      );
}

void showSpeedtestResultDetails(
  BuildContext context,
  SpeedtestResult result,
) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Insets.lg,
          0,
          Insets.lg,
          Insets.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Speedtest result',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: Insets.md),
            _DetailRow(label: 'Status', value: result.status.label),
            _DetailRow(
              label: 'Download',
              value: formatSpeed(result.downloadBitsPerSecond),
            ),
            _DetailRow(
              label: 'Upload',
              value: formatSpeed(result.uploadBitsPerSecond),
            ),
            _DetailRow(
              label: 'Ping',
              value: formatMilliseconds(result.pingMilliseconds),
            ),
            if (result.jitterMilliseconds != null)
              _DetailRow(
                label: 'Jitter',
                value: formatMilliseconds(result.jitterMilliseconds),
              ),
            if (result.packetLossPercent != null)
              _DetailRow(
                label: 'Packet loss',
                value: formatPacketLoss(result.packetLossPercent),
              ),
            if (result.server?.displayName != null)
              _DetailRow(label: 'Server', value: result.server!.displayName!),
            if (result.server?.displayLocation != null)
              _DetailRow(
                label: 'Location',
                value: result.server!.displayLocation!,
              ),
            if (result.isp != null)
              _DetailRow(label: 'Provider', value: result.isp!),
            _DetailRow(
              label: 'Completed',
              value: formatResultTime(result.completedAt),
            ),
          ],
        ),
      ),
    ),
  );
}

String formatResultTime(DateTime? value) => value == null
    ? 'Unknown time'
    : DateFormat.yMMMd().add_jm().format(
          value.isUtc ? value.toLocal() : value,
        );

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        children: <Widget>[
          Icon(icon, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      );
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Chip(
        avatar: Icon(icon, size: 16),
        label: Text(text),
        visualDensity: VisualDensity.compact,
      );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 105,
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );
}
