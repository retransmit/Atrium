import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/slskd_models.dart';
import '../slskd_format.dart';
import '../slskd_providers.dart';
import 'slskd_search_models_ui.dart';

/// Standalone track tile for Flat View in Search Results.
class SlskdSearchFlatTile extends ConsumerWidget {
  const SlskdSearchFlatTile({
    required this.instance,
    required this.file,
    required this.group,
    required this.onDownload,
    super.key,
  });

  final Instance instance;
  final SlskdSearchFile file;
  final SlskdAlbumGroup group;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final String duration = file.formattedDuration;
    final String size = slskdFormatBytes(file.size);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.xs),
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Insets.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Row 1: File icon, Title, Quality badge, Download button
            Row(
              children: <Widget>[
                Icon(
                  file.extension.trim().replaceAll(RegExp(r'^\.+'), '').toUpperCase() == 'FLAC'
                      ? Icons.audio_file_rounded
                      : Icons.music_note_rounded,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: Insets.xs),
                Expanded(
                  child: Text(
                    file.trackTitle,
                    style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: Insets.xs),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
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
                if (file.isLocked) ...<Widget>[
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 14,
                    color: colorScheme.error,
                  ),
                  const SizedBox(width: Insets.xs / 2),
                ],
                IconButton(
                  tooltip: file.isLocked ? 'File is locked' : 'Download track',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    file.isLocked
                        ? Icons.lock_clock_outlined
                        : Icons.download_rounded,
                    size: 20,
                  ),
                  onPressed: file.isLocked ? null : onDownload,
                ),
              ],
            ),
            const SizedBox(height: 2),

            // Row 2: Peer info, Album directory leaf, Speed & Slot
            Row(
              children: <Widget>[
                InkWell(
                  onTap: () {
                    ref.read(slskdBrowseUsernameProvider(instance).notifier).state = group.username;
                    ref.read(slskdBrowsePathSegmentsProvider(instance).notifier).state = const <String>[];
                    ref.read(slskdActiveTabProvider(instance).notifier).state = 2;
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.person_outline_rounded, size: 13, color: colorScheme.primary),
                      const SizedBox(width: 3),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 100),
                        child: Text(
                          group.username,
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                            decorationColor: colorScheme.primary.withValues(alpha: 0.35),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (group.albumTitle.isNotEmpty) ...<Widget>[
                  Text(' • ', style: textTheme.labelSmall?.copyWith(color: colorScheme.outline)),
                  Icon(Icons.folder_outlined, size: 12, color: colorScheme.outline),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      group.albumTitle,
                      style: textTheme.labelSmall?.copyWith(color: colorScheme.outline),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else
                  const Spacer(),
                const SizedBox(width: Insets.xs),
                if (group.hasFreeUploadSlot)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Free Slot',
                      style: textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onTertiaryContainer,
                      ),
                    ),
                  )
                else
                  Text(
                    'Queue: #${group.queueLength}',
                    style: textTheme.labelSmall?.copyWith(fontSize: 9, color: colorScheme.outline),
                  ),
                const SizedBox(width: Insets.xs),
                Text(
                  size,
                  style: textTheme.labelSmall?.copyWith(fontSize: 10, color: colorScheme.outline),
                ),
                if (duration.isNotEmpty) ...<Widget>[
                  Text(' • ', style: textTheme.labelSmall?.copyWith(color: colorScheme.outline)),
                  Text(
                    duration,
                    style: textTheme.labelSmall?.copyWith(fontSize: 10, color: colorScheme.outline),
                  ),
                ],
                if (group.formattedSpeed.isNotEmpty) ...<Widget>[
                  Text(' • ', style: textTheme.labelSmall?.copyWith(color: colorScheme.outline)),
                  Text(
                    group.formattedSpeed,
                    style: textTheme.labelSmall?.copyWith(fontSize: 10, color: colorScheme.outline),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
