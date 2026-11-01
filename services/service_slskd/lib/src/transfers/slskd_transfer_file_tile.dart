import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';

import '../models/slskd_models.dart';
import '../slskd_format.dart';
import '../slskd_providers.dart';
import 'slskd_transfer_details_sheet.dart';

/// Single transfer file row in [SlskdTransfersTab].
/// Renders track name, progress bar, live speed, ETA, queue position tag,
/// and cancel/remove/retry action buttons.
class SlskdTransferFileTile extends ConsumerWidget {
  const SlskdTransferFileTile({
    required this.instance,
    required this.transfer,
    this.direction,
    super.key,
  });

  final Instance instance;
  final SlskdTransfer transfer;
  final TransferDirection? direction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final bool isDownload = (direction ?? transfer.direction) == TransferDirection.download;
    final String baseName = transfer.fileBaseName;
    final double progress = transfer.progress;
    final double percent = transfer.percentComplete;
    final int transferred = transfer.bytesTransferred;
    final int total = transfer.size;
    final double speed = transfer.averageSpeed;
    final Duration? remaining = transfer.remainingTime;

    final bool isActive = transfer.category == TransferCategory.inProgress;

    // Formatting speed & ETA
    final String speedText = (isActive && speed.isFinite && speed > 0) ? slskdFormatRate(speed) : '';
    final String remainingText = (isActive && remaining != null) ? slskdFormatDuration(remaining) : '';
    final String bytesText = '${slskdFormatBytes(transferred)} / ${slskdFormatBytes(total)}';

    // Status pill colors and icon
    final (Color badgeBg, Color badgeFg, IconData statusIcon, String statusText) =
        switch (transfer.category) {
      TransferCategory.inProgress => (
          isDownload ? colorScheme.primaryContainer : colorScheme.tertiaryContainer,
          isDownload ? colorScheme.onPrimaryContainer : colorScheme.onTertiaryContainer,
          isDownload ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
          isDownload ? 'Downloading' : 'Uploading',
        ),
      TransferCategory.queued => (
          colorScheme.secondaryContainer,
          colorScheme.onSecondaryContainer,
          Icons.hourglass_empty_rounded,
          transfer.placeInQueue != null && transfer.placeInQueue! > 0
              ? '#${transfer.placeInQueue} in queue'
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

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => showSlskdTransferDetailsSheet(
        context,
        instance: instance,
        transfer: transfer,
        direction: direction ?? transfer.direction,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: Insets.xs),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Row 1: File icon, Name, Status Badge, Menu
          Row(
            children: <Widget>[
              Icon(
                _fileIcon(transfer.filename),
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: Insets.xs),
              Expanded(
                child: Text(
                  baseName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: Insets.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: Insets.xs + 2, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(statusIcon, size: 12, color: badgeFg),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: textTheme.labelSmall?.copyWith(
                        color: badgeFg,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              _buildActionsMenu(context, ref, isDownload),
            ],
          ),
          const SizedBox(height: Insets.xs),

          // Row 2: Progress indicator
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicatorM3E(
              value: transfer.category == TransferCategory.completed
                  ? 1.0
                  : progress.clamp(0.0, 1.0),
              size: LinearProgressM3ESize.s,
              shape: ProgressM3EShape.flat,
              trackColor: colorScheme.surfaceContainerHighest,
              activeColor: transfer.category == TransferCategory.completed
                  ? colorScheme.tertiary
                  : transfer.category == TransferCategory.failed
                      ? colorScheme.error
                      : (isDownload ? colorScheme.primary : colorScheme.tertiary),
            ),
          ),
          const SizedBox(height: Insets.xs),

          // Row 3: Metrics details (bytes, percent, speed, ETA)
          Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  bytesText,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                ),
              ),
              const SizedBox(width: Insets.xs),
              Text(
                '(${percent.toStringAsFixed(1)}%)',
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (speedText.isNotEmpty) ...<Widget>[
                Text(
                  speedText,
                  style: textTheme.bodySmall?.copyWith(
                    color: isDownload ? colorScheme.primary : colorScheme.tertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: Insets.xs),
              ],
              if (remainingText.isNotEmpty) ...<Widget>[
                Text(
                  remainingText,
                  style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                ),
              ],
            ],
          ),
          const Divider(height: Insets.md, thickness: 0.5),
        ],
      ),
    ),
  );
}

  Widget _buildActionsMenu(BuildContext context, WidgetRef ref, bool isDownload) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return PopupMenuButton<String>(
      tooltip: 'Transfer options',
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Insets.xs + 2, vertical: Insets.xs),
        alignment: Alignment.center,
        child: Icon(
          Icons.more_vert,
          size: 20,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      onSelected: (String action) async {
        try {
          final api = await ref.read(slskdApiProvider(instance).future);

          if (action == 'retry') {
            final resp = await api.enqueueDownloads(
              transfer.username,
              <QueueDownloadRequest>[
                QueueDownloadRequest(
                  filename: transfer.filename,
                  size: transfer.size,
                ),
              ],
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
              }
            }
          } else if (action == 'cancel') {
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
            }
          } else if (action == 'remove') {
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
            }
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
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        if (isDownload && transfer.canRetry)
          const PopupMenuItem<String>(
            value: 'retry',
            child: Row(
              children: <Widget>[
                Icon(Icons.refresh_rounded, size: 18),
                SizedBox(width: Insets.sm),
                Text('Retry Download'),
              ],
            ),
          ),
        if (transfer.canCancel)
          PopupMenuItem<String>(
            value: 'cancel',
            child: Row(
              children: <Widget>[
                const Icon(Icons.stop_circle_outlined, size: 18),
                const SizedBox(width: Insets.sm),
                Text(isDownload ? 'Cancel Download' : 'Abort Upload'),
              ],
            ),
          ),
        const PopupMenuItem<String>(
          value: 'remove',
          child: Row(
            children: <Widget>[
              Icon(Icons.delete_outline_rounded, size: 18),
              SizedBox(width: Insets.sm),
              Text('Remove from List'),
            ],
          ),
        ),
      ],
    );
  }

  static IconData _fileIcon(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.flac') ||
        lower.endsWith('.mp3') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.ogg') ||
        lower.endsWith('.alac')) {
      return Icons.audio_file_rounded;
    }
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png')) {
      return Icons.image_rounded;
    }
    return Icons.insert_drive_file_outlined;
  }
}
