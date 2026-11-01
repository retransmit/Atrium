import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/slskd_models.dart';
import '../slskd_format.dart';
import '../slskd_providers.dart';

/// Top aggregate statistics banner for [SlskdTransfersTab].
/// Inspired by Sonarr/Radarr queue summary cards.
/// Displays live simultaneous downstream & upstream throughput,
/// active/queued/completed counts, and a clear-completed action.
class SlskdTransfersStatsBar extends ConsumerWidget {
  const SlskdTransfersStatsBar({
    required this.instance,
    required this.downloads,
    required this.uploads,
    this.selectedDirection,
    super.key,
  });

  final Instance instance;
  final List<SlskdUserTransfers> downloads;
  final List<SlskdUserTransfers> uploads;
  final TransferDirection? selectedDirection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    // Aggregate metrics for downloads
    double downloadSpeed = 0;
    int dlInProgress = 0;
    int dlQueued = 0;
    int dlCompleted = 0;
    int dlFailed = 0;

    for (final user in downloads) {
      for (final dir in user.directories) {
        for (final transfer in dir.files) {
          if (transfer.category == TransferCategory.inProgress &&
              transfer.averageSpeed.isFinite &&
              transfer.averageSpeed > 0) {
            downloadSpeed += transfer.averageSpeed;
          }
          switch (transfer.category) {
            case TransferCategory.inProgress:
              dlInProgress++;
              break;
            case TransferCategory.queued:
              dlQueued++;
              break;
            case TransferCategory.completed:
              dlCompleted++;
              break;
            case TransferCategory.failed:
              dlFailed++;
              break;
          }
        }
      }
    }

    // Aggregate metrics for uploads
    double uploadSpeed = 0;
    int ulInProgress = 0;
    int ulQueued = 0;
    int ulCompleted = 0;
    int ulFailed = 0;

    for (final user in uploads) {
      for (final dir in user.directories) {
        for (final transfer in dir.files) {
          if (transfer.category == TransferCategory.inProgress &&
              transfer.averageSpeed.isFinite &&
              transfer.averageSpeed > 0) {
            uploadSpeed += transfer.averageSpeed;
          }
          switch (transfer.category) {
            case TransferCategory.inProgress:
              ulInProgress++;
              break;
            case TransferCategory.queued:
              ulQueued++;
              break;
            case TransferCategory.completed:
              ulCompleted++;
              break;
            case TransferCategory.failed:
              ulFailed++;
              break;
          }
        }
      }
    }

    // Filter counts according to active direction selection
    final int activeCount = switch (selectedDirection) {
      TransferDirection.download => dlInProgress,
      TransferDirection.upload => ulInProgress,
      null => dlInProgress + ulInProgress,
    };

    final int queuedCount = switch (selectedDirection) {
      TransferDirection.download => dlQueued,
      TransferDirection.upload => ulQueued,
      null => dlQueued + ulQueued,
    };

    final int completedCount = switch (selectedDirection) {
      TransferDirection.download => dlCompleted,
      TransferDirection.upload => ulCompleted,
      null => dlCompleted + ulCompleted,
    };

    final int failedCount = switch (selectedDirection) {
      TransferDirection.download => dlFailed,
      TransferDirection.upload => ulFailed,
      null => dlFailed + ulFailed,
    };

    final String dlFormatted =
        (downloadSpeed.isFinite && downloadSpeed > 0) ? slskdFormatRate(downloadSpeed) : '0 B/s';
    final String ulFormatted =
        (uploadSpeed.isFinite && uploadSpeed > 0) ? slskdFormatRate(uploadSpeed) : '0 B/s';

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHigh,
      margin: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.xs),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          children: <Widget>[
            // Row 1: Dual Stream Speed Indicators & Clear Action
            Row(
              children: <Widget>[
                // Downstream speed badge
                _SpeedBadge(
                  icon: Icons.download_rounded,
                  label: dlFormatted,
                  isActive: downloadSpeed > 0,
                  activeContainerColor: colorScheme.primaryContainer,
                  activeTextColor: colorScheme.onPrimaryContainer,
                  inactiveColor: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: Insets.xs),
                // Upstream speed badge
                _SpeedBadge(
                  icon: Icons.upload_rounded,
                  label: ulFormatted,
                  isActive: uploadSpeed > 0,
                  activeContainerColor: colorScheme.tertiaryContainer,
                  activeTextColor: colorScheme.onTertiaryContainer,
                  inactiveColor: colorScheme.onSurfaceVariant,
                ),
                const Spacer(),
                if (completedCount > 0)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
                    ),
                    icon: const Icon(Icons.cleaning_services_outlined, size: 16),
                    label: const Text('Clear'),
                    onPressed: () async {
                      try {
                        final api = await ref.read(slskdApiProvider(instance).future);
                        if (selectedDirection == TransferDirection.download) {
                          await api.clearCompletedDownloads();
                          ref.invalidate(slskdDownloadsProvider(instance));
                        } else if (selectedDirection == TransferDirection.upload) {
                          await api.clearCompletedUploads();
                          ref.invalidate(slskdUploadsProvider(instance));
                        } else {
                          await Future.wait([
                            api.clearCompletedDownloads(),
                            api.clearCompletedUploads(),
                          ]);
                          ref.invalidate(slskdDownloadsProvider(instance));
                          ref.invalidate(slskdUploadsProvider(instance));
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Cleared completed transfers'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Failed to clear: $e',
                                style: TextStyle(color: colorScheme.onError),
                              ),
                              backgroundColor: colorScheme.error,
                            ),
                          );
                        }
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: Insets.sm),

            // Row 2: Aggregate state counts
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                _StatBadge(
                  label: 'Active',
                  count: activeCount,
                  color: activeCount > 0 ? colorScheme.primary : colorScheme.onSurfaceVariant,
                ),
                _StatBadge(
                  label: 'Queued',
                  count: queuedCount,
                  color: queuedCount > 0 ? colorScheme.secondary : colorScheme.onSurfaceVariant,
                ),
                _StatBadge(
                  label: 'Completed',
                  count: completedCount,
                  color: completedCount > 0 ? colorScheme.tertiary : colorScheme.onSurfaceVariant,
                ),
                _StatBadge(
                  label: 'Failed',
                  count: failedCount,
                  color: failedCount > 0 ? colorScheme.error : colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeedBadge extends StatelessWidget {
  const _SpeedBadge({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeContainerColor,
    required this.activeTextColor,
    required this.inactiveColor,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeContainerColor;
  final Color activeTextColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.xs + 2, vertical: Insets.xs - 2),
      decoration: BoxDecoration(
        color: isActive ? activeContainerColor : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            icon,
            size: 16,
            color: isActive ? activeTextColor : inactiveColor,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isActive ? activeTextColor : inactiveColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          count.toString(),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}
