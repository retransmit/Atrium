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
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(bazarrHistoryProvider(instance)),
      child: AsyncValueView<List<BazarrHistoryItem>>(
        value: history,
        onRetry: () => ref.invalidate(bazarrHistoryProvider(instance)),
        data: (List<BazarrHistoryItem> items) {
          if (items.isEmpty) {
            return const EmptyView(
              icon: Icons.history,
              title: 'No history',
              message: 'Subtitle downloads and changes will appear here.',
            );
          }
          return ListView.builder(
            padding: Insets.pageH,
            itemCount: items.length,
            itemBuilder: (BuildContext context, int i) =>
                _HistoryTile(item: items[i]),
          );
        },
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item});

  final BazarrHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 2),
      leading: Icon(_icon(item.action)),
      title: Text(
        title.isEmpty ? 'Unknown' : title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        detail,
        maxLines: 3,
        style: theme.textTheme.bodySmall,
      ),
    );
  }

  // Bazarr history action codes: 0 deleted, 1 downloaded, 2 manually
  // downloaded, 3 upgraded.
  IconData _icon(int action) {
    switch (action) {
      case 0:
        return Icons.delete_outline;
      case 1:
        return Icons.download_done;
      case 2:
        return Icons.download_outlined;
      case 3:
        return Icons.upgrade;
      default:
        return Icons.history;
    }
  }
}
