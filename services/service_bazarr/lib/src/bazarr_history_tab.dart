import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bazarr_providers.dart';
import 'models/bazarr_models.dart';

/// The History tab: a unified, newest-first log of subtitle downloads,
/// upgrades, and deletions across episodes and movies.
class BazarrHistoryTab extends ConsumerWidget {
  const BazarrHistoryTab({required this.instance, super.key});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<BazarrHistoryItem>> history =
        ref.watch(bazarrHistoryProvider(instance));
    return AsyncValueView<List<BazarrHistoryItem>>(
          value: history,
        onRetry: () => ref.invalidate(bazarrHistoryProvider(instance)),
          data: (List<BazarrHistoryItem> items) {
            
          if (items.isEmpty) {
            return EasyRefresh(
        header: const ClassicHeader(
          dragText: 'Pull to refresh',
          armedText: 'Release ready',
          readyText: 'Refreshing...',
          processingText: 'Refreshing...',
          processedText: 'Succeeded',
          failedText: 'Failed',
          messageText: 'Last updated at %T',
        ),
        onRefresh: () async => ref.invalidate(bazarrHistoryProvider(instance)),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const <Widget>[
            SizedBox(height: 100),
            EmptyView(
              icon: Icons.history,
              title: 'No history',
              message: 'Subtitle downloads and changes will appear here.',
            ),
          ],
        ),
      );
          }
          return EasyRefresh(
      header: const ClassicHeader(
        dragText: 'Pull to refresh',
        armedText: 'Release ready',
        readyText: 'Refreshing...',
        processingText: 'Refreshing...',
        processedText: 'Succeeded',
        failedText: 'Failed',
        messageText: 'Last updated at %T',
      ),
      onRefresh: () async => ref.invalidate(bazarrHistoryProvider(instance)),
      child: ListView.separated(
            padding: Insets.pageH,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: Insets.sm),
            itemBuilder: (BuildContext context, int i) =>
                _HistoryTile(item: items[i]),
          ),
    );
        
          },
        );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item});

  final BazarrHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final (Color accent, IconData icon) = _look(item.action, cs);
    final String title = item.isMovie
        ? item.title
        : <String>[
            item.seriesTitle,
            if (item.episodeNumber.isNotEmpty) item.episodeNumber,
          ].join(' · ');
    final String detail = <String>[
      if (item.description.isNotEmpty) item.description,
      if (item.timestamp.isNotEmpty) item.timestamp,
    ].join(' · ');
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: accent),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title.isEmpty ? 'Unknown' : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (detail.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      maxLines: 3,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Bazarr history action codes: 0 deleted, 1 downloaded, 2 manually downloaded,
// 3 upgraded. Downloads and upgrades read as positive (tertiary), deletions as
// destructive (error), anything else neutral (secondary).
(Color, IconData) _look(int action, ColorScheme cs) {
  switch (action) {
    case 0:
      return (cs.error, Icons.delete_outline);
    case 1:
      return (cs.tertiary, Icons.download_done);
    case 2:
      return (cs.tertiary, Icons.download_outlined);
    case 3:
      return (cs.tertiary, Icons.upgrade);
    default:
      return (cs.secondary, Icons.history);
  }
}
