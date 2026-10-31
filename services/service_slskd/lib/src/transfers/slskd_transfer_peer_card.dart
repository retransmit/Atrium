import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/slskd_models.dart';
import '../slskd_format.dart';
import '../slskd_providers.dart';
import 'slskd_transfer_file_tile.dart';

/// Card grouping all transfers for a specific peer username in [SlskdTransfersTab].
/// Inspired by Sonarr/Radarr release/queue cards.
/// Displays peer avatar with directional badge, combined peer speed,
/// and collapsible directory sections with file progress.
class SlskdTransferPeerCard extends ConsumerStatefulWidget {
  const SlskdTransferPeerCard({
    required this.instance,
    required this.userTransfers,
    required this.direction,
    super.key,
  });

  final Instance instance;
  final SlskdUserTransfers userTransfers;
  final TransferDirection direction;

  @override
  ConsumerState<SlskdTransferPeerCard> createState() => _SlskdTransferPeerCardState();
}

class _SlskdTransferPeerCardState extends ConsumerState<SlskdTransferPeerCard> {
  // Expansion state map for directories
  final Map<String, bool> _directoryExpanded = {};

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final SlskdUserTransfers user = widget.userTransfers;
    final bool isDownload = widget.direction == TransferDirection.download;
    final int totalFiles = user.totalFileCount;
    final double peerSpeed = user.directories.fold<double>(
      0.0,
      (sum, d) => sum + d.files.fold<double>(
        0.0,
        (s, f) => s + (f.category == TransferCategory.inProgress && f.averageSpeed.isFinite && f.averageSpeed > 0
            ? f.averageSpeed
            : 0.0),
      ),
    );

    final String peerSpeedText =
        (peerSpeed.isFinite && peerSpeed > 0) ? slskdFormatRate(peerSpeed) : '';

    final Color dirContainerColor =
        isDownload ? colorScheme.primaryContainer : colorScheme.tertiaryContainer;
    final Color dirTextColor =
        isDownload ? colorScheme.onPrimaryContainer : colorScheme.onTertiaryContainer;
    final Color accentColor = isDownload ? colorScheme.primary : colorScheme.tertiary;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.xs),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Insets.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Peer Header Row
            Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: dirContainerColor,
                  child: Text(
                    user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: dirTextColor,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              user.username,
                              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: Insets.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: dirContainerColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  isDownload ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                  size: 11,
                                  color: dirTextColor,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  isDownload ? 'DOWNLOAD' : 'UPLOAD',
                                  style: textTheme.labelSmall?.copyWith(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: dirTextColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Text(
                        slskdFormatFolderAndFileCounts(user.directories.length, totalFiles),
                        style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                      ),
                    ],
                  ),
                ),
                if (peerSpeedText.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: Insets.xs + 2, vertical: 2),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      peerSpeedText,
                      style: textTheme.labelSmall?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(width: Insets.xs),
                IconButton(
                  tooltip: 'Browse ${user.username}\'s shares',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.folder_shared_outlined, size: 20),
                  onPressed: () {
                    ref.read(slskdBrowseUsernameProvider(widget.instance).notifier).state =
                        user.username;
                    ref.read(slskdBrowsePathSegmentsProvider(widget.instance).notifier).state =
                        const <String>[];
                    ref.read(slskdActiveTabProvider(widget.instance).notifier).state = 2;
                  },
                ),
              ],
            ),
            const SizedBox(height: Insets.xs),

            // Directory Subsections
            for (final dir in user.directories) ...<Widget>[
              _buildDirectorySection(context, dir),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDirectorySection(BuildContext context, SlskdDirectoryTransfers dir) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final String dirKey = dir.directory;
    final bool isExpanded = _directoryExpanded[dirKey] ?? true; // default expanded

    // Extract directory leaf name
    final String leafName = _extractDirectoryLeaf(dir.directory);
    final bool isDownload = widget.direction == TransferDirection.download;
    final Color folderColor = isDownload ? colorScheme.primary : colorScheme.tertiary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            setState(() {
              _directoryExpanded[dirKey] = !isExpanded;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Insets.xs, vertical: Insets.xs),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.folder_open_rounded,
                  size: 16,
                  color: folderColor,
                ),
                const SizedBox(width: Insets.xs),
                Expanded(
                  child: Text(
                    leafName.isNotEmpty ? leafName : dir.directory,
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${dir.files.length}',
                  style: textTheme.labelSmall?.copyWith(color: colorScheme.outline),
                ),
                Icon(
                  isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  size: 18,
                  color: colorScheme.outline,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          for (final transfer in dir.files) ...<Widget>[
            SlskdTransferFileTile(
              key: ValueKey('file_${transfer.id}'),
              instance: widget.instance,
              transfer: transfer,
              direction: widget.direction,
            ),
          ],
      ],
    );
  }

  static String _extractDirectoryLeaf(String dirPath) {
    final sep = dirPath.contains('\\') ? '\\' : '/';
    final parts = dirPath.split(sep).where((p) => p.trim().isNotEmpty).toList();
    return parts.isNotEmpty ? parts.last : dirPath;
  }
}
