import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/slskd_models.dart';
import '../slskd_format.dart';
import '../slskd_providers.dart';
import 'slskd_search_models_ui.dart';

/// Card component rendering an entire album directory from a single peer in Search Results.
/// Provides a 1-tap "Download Album" batch action and collapsible track listing.
class SlskdSearchAlbumCard extends ConsumerStatefulWidget {
  const SlskdSearchAlbumCard({
    required this.instance,
    required this.group,
    required this.onDownloadAlbum,
    required this.onDownloadTrack,
    super.key,
  });

  final Instance instance;
  final SlskdAlbumGroup group;
  final ValueChanged<SlskdAlbumGroup> onDownloadAlbum;
  final void Function(SlskdAlbumGroup group, SlskdSearchFile file) onDownloadTrack;

  @override
  ConsumerState<SlskdSearchAlbumCard> createState() => _SlskdSearchAlbumCardState();
}

class _SlskdSearchAlbumCardState extends ConsumerState<SlskdSearchAlbumCard> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final SlskdAlbumGroup group = widget.group;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.xs),
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Insets.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 1. Album Header: Title, Peer info, Download Album button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(Insets.xs + 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.album_rounded,
                    size: 24,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        group.albumTitle,
                        style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: <Widget>[
                          InkWell(
                            onTap: () {
                              ref.read(slskdBrowseUsernameProvider(widget.instance).notifier).state = group.username;
                              ref.read(slskdBrowsePathSegmentsProvider(widget.instance).notifier).state = const <String>[];
                              ref.read(slskdActiveTabProvider(widget.instance).notifier).state = 2;
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
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: Insets.xs),
                          Text('•', style: TextStyle(color: colorScheme.outline, fontSize: 10)),
                          const SizedBox(width: Insets.xs),
                          Text(
                            group.formattedSpeed,
                            style: textTheme.labelSmall?.copyWith(color: colorScheme.outline),
                          ),
                          const SizedBox(width: Insets.xs),
                          Text('•', style: TextStyle(color: colorScheme.outline, fontSize: 10)),
                          const SizedBox(width: Insets.xs),
                          // Slot badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: group.hasFreeUploadSlot
                                  ? colorScheme.tertiaryContainer
                                  : colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  group.hasFreeUploadSlot
                                      ? Icons.bolt_rounded
                                      : Icons.hourglass_empty_rounded,
                                  size: 10,
                                  color: group.hasFreeUploadSlot
                                      ? colorScheme.onTertiaryContainer
                                      : colorScheme.outline,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  group.hasFreeUploadSlot
                                      ? 'Free Slot'
                                      : 'Queue: #${group.queueLength}',
                                  style: textTheme.labelSmall?.copyWith(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: group.hasFreeUploadSlot
                                      ? colorScheme.onTertiaryContainer
                                      : colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: _isExpanded ? 'Collapse tracks' : 'Expand tracks',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    _isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                ),
              ],
            ),
            const SizedBox(height: Insets.xs),

            // 2. Metrics & Batch Action Row
            Row(
              children: <Widget>[
                // Dominant quality badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    group.qualityBadge,
                    style: textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: Insets.xs),

                Expanded(
                  child: Text(
                    '${group.files.length} tracks • ${group.formattedTotalSize}',
                    style: textTheme.labelSmall?.copyWith(color: colorScheme.outline),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: Insets.xs),

                // 1-Tap "Download Album" action
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
                    textStyle: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Download Album'),
                  onPressed: (group.files.isNotEmpty && group.files.any((f) => !f.isLocked))
                      ? () => widget.onDownloadAlbum(group)
                      : null,
                ),
              ],
            ),

            // 3. Collapsible Tracks List
            if (_isExpanded) ...<Widget>[
              const Divider(height: Insets.md, thickness: 0.5),
              for (int i = 0; i < group.files.length; i++) ...<Widget>[
                _TrackRow(
                  index: i + 1,
                  file: group.files[i],
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  onDownload: () => widget.onDownloadTrack(group, group.files[i]),
                ),
                if (i < group.files.length - 1)
                  Divider(
                    height: Insets.xs,
                    thickness: 0.3,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({
    required this.index,
    required this.file,
    required this.colorScheme,
    required this.textTheme,
    required this.onDownload,
  });

  final int index;
  final SlskdSearchFile file;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final String duration = file.formattedDuration;
    final String size = slskdFormatBytes(file.size);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 22,
            child: Text(
              index.toString().padLeft(2, '0'),
              style: textTheme.labelSmall?.copyWith(color: colorScheme.outline),
            ),
          ),
          const SizedBox(width: Insets.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  file.trackTitle,
                  style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: <Widget>[
                    Text(
                      file.qualityBadge,
                      style: textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: Insets.xs),
                    Text('•', style: TextStyle(color: colorScheme.outline, fontSize: 9)),
                    const SizedBox(width: Insets.xs),
                    Text(size, style: textTheme.labelSmall?.copyWith(fontSize: 9, color: colorScheme.outline)),
                    if (duration.isNotEmpty) ...<Widget>[
                      const SizedBox(width: Insets.xs),
                      Text('•', style: TextStyle(color: colorScheme.outline, fontSize: 9)),
                      const SizedBox(width: Insets.xs),
                      Text(duration, style: textTheme.labelSmall?.copyWith(fontSize: 9, color: colorScheme.outline)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: file.isLocked ? 'Track is locked by peer' : 'Download track',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              file.isLocked ? Icons.lock_clock_outlined : Icons.download_rounded,
              size: 18,
            ),
            onPressed: file.isLocked ? null : onDownload,
          ),
        ],
      ),
    );
  }
}
