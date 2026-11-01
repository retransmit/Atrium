import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';

import '../models/slskd_models.dart';
import '../slskd_format.dart';
import '../slskd_providers.dart';

/// Shows the detailed Soulseek transfer diagnostic bottom sheet.
Future<void> showSlskdTransferDetailsSheet(
  BuildContext context, {
  required Instance instance,
  required SlskdTransfer transfer,
  required TransferDirection direction,
  String? directory,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.88,
    ),
    builder: (BuildContext _) => SlskdTransferDetailsSheet(
      instance: instance,
      transfer: transfer,
      direction: direction,
      directory: directory,
    ),
  );
}

/// Modal bottom sheet displaying granular diagnostics and actions for a single Soulseek transfer.
class SlskdTransferDetailsSheet extends ConsumerWidget {
  const SlskdTransferDetailsSheet({
    required this.instance,
    required this.transfer,
    required this.direction,
    this.directory,
    super.key,
  });

  final Instance instance;
  final SlskdTransfer transfer;
  final TransferDirection direction;
  final String? directory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final bool isDownload = direction == TransferDirection.download;
    final String baseName = transfer.fileBaseName;
    final double progress = transfer.progress;
    final double percent = transfer.percentComplete;
    final int transferred = transfer.bytesTransferred;
    final int total = transfer.size;
    final double speed = transfer.averageSpeed;
    final Duration? remaining = transfer.remainingTime;

    final String speedText =
        (speed.isFinite && speed > 0) ? slskdFormatRate(speed) : 'Idle';
    final String remainingText = remaining != null ? slskdFormatDuration(remaining) : '—';
    final String bytesText = '${slskdFormatBytes(transferred)} / ${slskdFormatBytes(total)}';

    final Color dirContainer = isDownload ? colorScheme.primaryContainer : colorScheme.tertiaryContainer;
    final Color dirText = isDownload ? colorScheme.onPrimaryContainer : colorScheme.onTertiaryContainer;

    final queuePosAsync = (isDownload && transfer.category == TransferCategory.queued)
        ? ref.watch(slskdQueuePositionProvider((instance, transfer.username, transfer.id)))
        : null;
    final int? liveQueuePos = (queuePosAsync != null && queuePosAsync.hasValue)
        ? queuePosAsync.value
        : transfer.placeInQueue;

    // Status styling
    final (Color badgeBg, Color badgeFg, IconData statusIcon, String statusText) =
        switch (transfer.category) {
      TransferCategory.inProgress => (
          colorScheme.secondaryContainer,
          colorScheme.onSecondaryContainer,
          Icons.sync_rounded,
          'In Progress',
        ),
      TransferCategory.queued => (
          colorScheme.secondaryContainer,
          colorScheme.onSecondaryContainer,
          Icons.hourglass_empty_rounded,
          liveQueuePos != null && liveQueuePos > 0
              ? '#$liveQueuePos in queue'
              : 'Queued',
        ),
      TransferCategory.completed => (
          colorScheme.tertiaryContainer,
          colorScheme.onTertiaryContainer,
          Icons.check_circle_outline_rounded,
          'Completed',
        ),
      TransferCategory.failed => (
          colorScheme.errorContainer,
          colorScheme.onErrorContainer,
          Icons.error_outline_rounded,
          'Failed',
        ),
    };

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Insets.md, Insets.xs, Insets.md, Insets.xl),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header: Direction pill, Status badge, File icon & Filename
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: dirContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      isDownload ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                      size: 13,
                      color: dirText,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isDownload ? 'DOWNLOAD' : 'UPLOAD',
                      style: textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: dirText,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Insets.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(statusIcon, size: 13, color: badgeFg),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: badgeFg,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: Insets.xs),

          Text(
            baseName,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: Insets.md),

          // 1. Progress & Bandwidth Card
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        'Progress',
                        style: textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${percent.toStringAsFixed(1)}%',
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDownload ? colorScheme.primary : colorScheme.tertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicatorM3E(
                      value: progress.clamp(0.0, 1.0).toDouble(),
                      size: LinearProgressM3ESize.s,
                      shape: ProgressM3EShape.flat,
                      activeColor: isDownload ? colorScheme.primary : colorScheme.tertiary,
                      trackColor: colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(height: Insets.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      _MetricItem(
                        label: 'Transferred',
                        value: bytesText,
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),
                      _MetricItem(
                        label: 'Speed',
                        value: speedText,
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),
                      _MetricItem(
                        label: 'Remaining',
                        value: remainingText,
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Insets.sm),

          // 2. Peer & Soulseek Protocol Diagnostics Card
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Soulseek Diagnostics',
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: Insets.sm),
                  Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: dirContainer,
                        child: Text(
                          transfer.username.isNotEmpty ? transfer.username[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: dirText,
                          ),
                        ),
                      ),
                      const SizedBox(width: Insets.xs),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              transfer.username,
                              style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Peer User',
                              style: textTheme.labelSmall?.copyWith(color: colorScheme.outline),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.folder_shared_outlined, size: 16),
                        label: const Text('Browse Shares'),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          ref.read(slskdBrowseUsernameProvider(instance).notifier).state =
                              transfer.username;
                          ref.read(slskdBrowsePathSegmentsProvider(instance).notifier).state =
                              const <String>[];
                          ref.read(slskdActiveTabProvider(instance).notifier).state = 2;
                        },
                      ),
                    ],
                  ),
                  const Divider(height: Insets.lg),
                  _DiagnosticRow(
                    label: 'Network State',
                    value: transfer.state,
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  ),
                  const SizedBox(height: Insets.xs),
                  _DiagnosticRow(
                    label: 'Queue Rank',
                    value: liveQueuePos != null && liveQueuePos > 0
                        ? '#$liveQueuePos'
                        : 'Active / Direct',
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  ),
                  const SizedBox(height: Insets.xs),
                  _DiagnosticRow(
                    label: 'Retry Attempts',
                    value: '${transfer.attempts}',
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  ),
                  if (transfer.exception != null && transfer.exception!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: Insets.sm),
                    Container(
                      padding: const EdgeInsets.all(Insets.sm),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.warning_amber_rounded, size: 18, color: colorScheme.onErrorContainer),
                          const SizedBox(width: Insets.xs),
                          Expanded(
                            child: SelectableText(
                              transfer.exception!,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onErrorContainer,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: Insets.sm),

          // 3. File & Path Location Card
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        'File Location',
                        style: textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy path',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: transfer.filename));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('File path copied to clipboard'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(Insets.xs + 2),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      transfer.filename,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.xs),
                  Text(
                    'Exact file size: ${transfer.size} bytes (${slskdFormatBytes(transfer.size)})',
                    style: textTheme.labelSmall?.copyWith(color: colorScheme.outline),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Insets.sm),

          // 4. Timestamps Card
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Timeline',
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: Insets.sm),
                  _DiagnosticRow(
                    label: 'Requested',
                    value: slskdFormatDateTime(transfer.requestedAt),
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  ),
                  const SizedBox(height: Insets.xs),
                  _DiagnosticRow(
                    label: 'Started',
                    value: transfer.startedAt != null ? slskdFormatDateTime(transfer.startedAt!) : 'Waiting in queue',
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  ),
                  if (transfer.endedAt != null) ...<Widget>[
                    const SizedBox(height: Insets.xs),
                    _DiagnosticRow(
                      label: 'Ended',
                      value: slskdFormatDateTime(transfer.endedAt!),
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: Insets.md),

          // 5. Actions Row
          Row(
            children: <Widget>[
              if (transfer.canRetry) ...<Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                      side: BorderSide(color: colorScheme.primary),
                      padding: const EdgeInsets.symmetric(vertical: Insets.sm),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry'),
                    onPressed: () async {
                      try {
                        final api = await ref.read(slskdApiProvider(instance).future);
                        final resp = await api.enqueueBatch(
                          EnqueueDownloadBatchRequest(
                            username: transfer.username,
                            files: <EnqueueDownloadBatchItem>[
                              EnqueueDownloadBatchItem(
                                filename: transfer.filename,
                                size: transfer.size,
                              ),
                            ],
                          ),
                        );
                        ref.invalidate(slskdDownloadsProvider(instance));
                        if (context.mounted) {
                          if (resp.failures.isNotEmpty &&
                              (resp.batch?.transfers.isEmpty ?? true)) {
                            final failReason = resp.failures.first.message ??
                                'File already downloading or queued';
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Could not retry: $failReason',
                                  style: TextStyle(color: colorScheme.onError),
                                ),
                                backgroundColor: colorScheme.error,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Retrying download...'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                            Navigator.of(context).pop();
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Retry failed: $e',
                                style: TextStyle(color: colorScheme.onError),
                              ),
                              backgroundColor: colorScheme.error,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(width: Insets.sm),
              ],
              if (transfer.canCancel) ...<Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      side: BorderSide(color: colorScheme.error.withValues(alpha: 0.6)),
                      padding: const EdgeInsets.symmetric(vertical: Insets.sm),
                    ),
                    icon: const Icon(Icons.stop_circle_outlined, size: 18),
                    label: Text(isDownload ? 'Cancel' : 'Abort'),
                    onPressed: () async {
                      try {
                        final api = await ref.read(slskdApiProvider(instance).future);
                        if (isDownload) {
                          await api.cancelDownload(transfer.username, transfer.id);
                          ref.invalidate(slskdDownloadsProvider(instance));
                        } else {
                          await api.cancelUpload(transfer.username, transfer.id);
                          ref.invalidate(slskdUploadsProvider(instance));
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isDownload ? 'Cancelled download' : 'Aborted upload'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                          Navigator.of(context).pop();
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Operation failed: $e',
                                style: TextStyle(color: colorScheme.onError),
                              ),
                              backgroundColor: colorScheme.error,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(width: Insets.sm),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.onSurfaceVariant,
                    side: BorderSide(color: colorScheme.outlineVariant),
                    padding: const EdgeInsets.symmetric(vertical: Insets.sm),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Remove'),
                  onPressed: () async {
                    try {
                      final api = await ref.read(slskdApiProvider(instance).future);
                      if (isDownload) {
                        await api.cancelDownload(transfer.username, transfer.id, remove: true);
                        ref.invalidate(slskdDownloadsProvider(instance));
                      } else {
                        await api.cancelUpload(transfer.username, transfer.id, remove: true);
                        ref.invalidate(slskdUploadsProvider(instance));
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Removed transfer from list'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        Navigator.of(context).pop();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Operation failed: $e',
                              style: TextStyle(color: colorScheme.onError),
                            ),
                            backgroundColor: colorScheme.error,
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({
    required this.label,
    required this.value,
    required this.colorScheme,
    required this.textTheme,
  });

  final String label;
  final String value;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(color: colorScheme.outline),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({
    required this.label,
    required this.value,
    required this.colorScheme,
    required this.textTheme,
  });

  final String label;
  final String value;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
