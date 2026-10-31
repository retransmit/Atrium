import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';

import '../models/slskd_models.dart';
import '../slskd_format.dart';
import '../slskd_providers.dart';
import 'slskd_transfer_details_sheet.dart';

/// Single item representation for the Flat (un-grouped) transfers view.
class SlskdFlatTransferItem {
  const SlskdFlatTransferItem({
    required this.direction,
    required this.username,
    required this.directory,
    required this.transfer,
  });

  final TransferDirection direction;
  final String username;
  final String directory;
  final SlskdTransfer transfer;
}

/// Standalone card tile representing a single transfer in Flat View.
/// Displays track name, peer name, album folder, progress bar, live speed,
/// ETA, queue position tag, and cancel/abort action menu.
class SlskdTransferFlatTile extends ConsumerWidget {
  const SlskdTransferFlatTile({
    required this.instance,
    required this.item,
    super.key,
  });

  final Instance instance;
  final SlskdFlatTransferItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final SlskdTransfer transfer = item.transfer;
    final bool isDownload = item.direction == TransferDirection.download;
    final String baseName = transfer.fileBaseName;
    final double progress = transfer.progress;
    final double percent = transfer.percentComplete;
    final int transferred = transfer.bytesTransferred;
    final int total = transfer.size;
    final double speed = transfer.averageSpeed;
    final Duration? remaining = transfer.remainingTime;

    final bool isActive = transfer.category == TransferCategory.inProgress;
    final String speedText = (isActive && speed.isFinite && speed > 0) ? slskdFormatRate(speed) : '';
    final String remainingText = (isActive && remaining != null) ? slskdFormatDuration(remaining) : '';
    final String bytesText = '${slskdFormatBytes(transferred)} / ${slskdFormatBytes(total)}';
    final String folderLeaf = _extractDirectoryLeaf(item.directory);

    final Color dirContainer = isDownload ? colorScheme.primaryContainer : colorScheme.tertiaryContainer;
    final Color dirText = isDownload ? colorScheme.onPrimaryContainer : colorScheme.onTertiaryContainer;

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

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.xs),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showSlskdTransferDetailsSheet(
          context,
          instance: instance,
          transfer: transfer,
          direction: item.direction,
          directory: item.directory,
        ),
        child: Padding(
          padding: const EdgeInsets.all(Insets.sm),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Row 1: File icon, Filename, Direction badge, Menu
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
                    style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: Insets.xs),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: dirContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        isDownload ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        size: 10,
                        color: dirText,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        isDownload ? 'DL' : 'UL',
                        style: textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: dirText,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildActionsMenu(context, ref, isDownload),
              ],
            ),
            const SizedBox(height: Insets.xs - 2),

            // Row 2: Peer name, Folder leaf, Status badge
            Row(
              children: <Widget>[
                Icon(Icons.person_outline_rounded, size: 14, color: colorScheme.outline),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    item.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (folderLeaf.isNotEmpty) ...<Widget>[
                  Text(' • ', style: textTheme.labelSmall?.copyWith(color: colorScheme.outline)),
                  Icon(Icons.folder_outlined, size: 13, color: colorScheme.outline),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      folderLeaf,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall?.copyWith(color: colorScheme.outline),
                    ),
                  ),
                ],
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: Insets.xs, vertical: 1),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(statusIcon, size: 10, color: badgeFg),
                      const SizedBox(width: 2),
                      Text(
                        statusText,
                        style: textTheme.labelSmall?.copyWith(
                          color: badgeFg,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.xs),

            // Row 3: Progress Bar
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

            // Row 4: Metrics (Bytes, Percent, Speed, ETA)
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
          ],
        ),
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
              item.transfer.username,
              <QueueDownloadRequest>[
                QueueDownloadRequest(
                  filename: item.transfer.filename,
                  size: item.transfer.size,
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
            final String peerUser =
                item.username.isNotEmpty ? item.username : item.transfer.username;
            if (isDownload) {
              await api.cancelDownload(peerUser, item.transfer.id);
              ref.invalidate(slskdDownloadsProvider(instance));
            } else {
              await api.cancelUpload(peerUser, item.transfer.id);
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
            final String peerUser =
                item.username.isNotEmpty ? item.username : item.transfer.username;
            if (isDownload) {
              await api.cancelDownload(peerUser, item.transfer.id, remove: true);
              ref.invalidate(slskdDownloadsProvider(instance));
            } else {
              await api.cancelUpload(peerUser, item.transfer.id, remove: true);
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
        if (isDownload && item.transfer.canRetry)
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
        if (item.transfer.canCancel)
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

  static String _extractDirectoryLeaf(String dirPath) {
    final sep = dirPath.contains('\\') ? '\\' : '/';
    final parts = dirPath.split(sep).where((p) => p.trim().isNotEmpty).toList();
    return parts.isNotEmpty ? parts.last : dirPath;
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
