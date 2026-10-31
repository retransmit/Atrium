import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../slskd_format.dart';
import 'slskd_browse_models_ui.dart';

/// List tile representing a subdirectory within the browsed peer share.
class SlskdBrowseFolderTile extends StatelessWidget {
  const SlskdBrowseFolderTile({
    required this.node,
    required this.onTap,
    required this.onDownloadFolder,
    super.key,
  });

  final BrowseNode node;
  final VoidCallback onTap;
  final VoidCallback onDownloadFolder;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final int subfolderCount = node.subfolders.length;
    final int fileCount = node.totalFiles;
    final String size = node.formattedTotalSize;

    final String subtitleText = subfolderCount > 0
        ? '${slskdFormatFolderAndFileCounts(subfolderCount, fileCount, fileNoun: 'track')} • $size'
        : '${slskdPluralize(fileCount, 'track')} • $size';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 3),
      elevation: 0,
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
          width: 0.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: Insets.xs + 2),
          child: Row(
            children: <Widget>[
              // Folder Icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: node.isLocked
                      ? colorScheme.surfaceContainerHighest
                      : colorScheme.primaryContainer.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  node.isLocked ? Icons.lock_outline_rounded : Icons.folder_rounded,
                  size: 20,
                  color: node.isLocked ? colorScheme.outline : colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: Insets.sm),

              // Folder segment name & stats
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            node.segment,
                            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (node.isLocked) ...<Widget>[
                          const SizedBox(width: Insets.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'LOCKED',
                              style: textTheme.labelSmall?.copyWith(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitleText,
                      style: textTheme.labelSmall?.copyWith(color: colorScheme.outline),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // 1-Tap download folder button
              if (fileCount > 0)
                IconButton(
                  tooltip: node.isLocked
                      ? 'Directory is locked'
                      : 'Download folder (${node.segment})',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    node.isLocked ? Icons.lock_clock_outlined : Icons.download_rounded,
                    size: 20,
                  ),
                  onPressed: node.isLocked ? null : onDownloadFolder,
                ),

              // Chevron forward
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
