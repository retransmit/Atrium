import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../models/slskd_models.dart';

/// List tile representing a single downloadable audio file in the browsed peer share.
class SlskdBrowseFileTile extends StatelessWidget {
  const SlskdBrowseFileTile({
    required this.file,
    required this.onDownload,
    this.index,
    super.key,
  });

  final SlskdSearchFile file;
  final VoidCallback onDownload;
  final int? index;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final String duration = file.formattedDuration;
    final String size = file.formattedSize;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 2),
      elevation: 0,
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: Insets.xs),
        child: Row(
          children: <Widget>[
            // Track index or music note
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: index != null
                  ? Text(
                      index!.toString().padLeft(2, '0'),
                      style: textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.outline,
                      ),
                    )
                  : Icon(Icons.music_note_rounded, size: 16, color: colorScheme.outline),
            ),
            const SizedBox(width: Insets.sm),

            // Track title & metadata
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    file.trackTitle,
                    style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: <Widget>[
                      if (file.isLocked) ...<Widget>[
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
                        const SizedBox(width: Insets.xs),
                      ],
                      // Format badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          file.qualityBadge,
                          style: textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: Insets.xs),
                      Flexible(
                        child: Text(
                          duration.isNotEmpty ? '$size • $duration' : size,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            color: colorScheme.outline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 1-Tap download track button
            IconButton(
              tooltip: file.isLocked
                  ? 'File is locked'
                  : 'Download track (${file.trackTitle})',
              visualDensity: VisualDensity.compact,
              icon: Icon(
                file.isLocked ? Icons.lock_clock_outlined : Icons.download_rounded,
                size: 20,
              ),
              onPressed: file.isLocked ? null : onDownload,
            ),
          ],
        ),
      ),
    );
  }
}
