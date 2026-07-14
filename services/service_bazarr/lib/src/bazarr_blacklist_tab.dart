import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bazarr_api.dart';
import 'bazarr_providers.dart';
import 'models/bazarr_models.dart';

/// The Blacklist tab: subtitles that have been blacklisted (so Bazarr never
/// re-downloads them), across episodes and movies, each removable.
class BazarrBlacklistTab extends ConsumerWidget {
  const BazarrBlacklistTab({required this.instance, super.key});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<BazarrBlacklistItem>> blacklist =
        ref.watch(bazarrBlacklistProvider(instance));
    return EasyRefresh(
      header: const MaterialHeader(),
      onRefresh: () async => ref.invalidate(bazarrBlacklistProvider(instance)),
      child: AsyncValueView<List<BazarrBlacklistItem>>(
        value: blacklist,
        onRetry: () => ref.invalidate(bazarrBlacklistProvider(instance)),
        data: (List<BazarrBlacklistItem> items) {
          if (items.isEmpty) {
            return const EmptyView(
              icon: Icons.block,
              title: 'Blacklist empty',
              message: 'Blacklisted subtitles will appear here.',
            );
          }
          return ListView.separated(
            padding: Insets.pageH,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: Insets.sm),
            itemBuilder: (BuildContext context, int i) => _BlacklistTile(
              instance: instance,
              item: items[i],
            ),
          );
        },
      ),
    );
  }
}

class _BlacklistTile extends ConsumerWidget {
  const _BlacklistTile({required this.instance, required this.item});

  final Instance instance;
  final BazarrBlacklistItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final String title = item.isMovie
        ? item.title
        : <String>[
            item.seriesTitle,
            if (item.episodeNumber.isNotEmpty) item.episodeNumber,
          ].join(' · ');
    final String lang = item.language?.code2.toUpperCase() ?? '';
    final String detail = <String>[
      if (lang.isNotEmpty) lang,
      if (item.provider.isNotEmpty) item.provider,
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
          children: <Widget>[
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cs.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.block, size: 17, color: cs.error),
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
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Remove from blacklist',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmRemove(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Remove from blacklist?'),
        content: const Text(
          'Bazarr will be allowed to download this subtitle again.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    try {
      final BazarrApi api = await ref.read(bazarrApiProvider(instance).future);
      if (item.isMovie) {
        await api.removeMovieBlacklist(
          provider: item.provider,
          subsId: item.subsId,
        );
      } else {
        await api.removeEpisodeBlacklist(
          provider: item.provider,
          subsId: item.subsId,
        );
      }
      ref.invalidate(bazarrBlacklistProvider(instance));
      messenger.showSnackBar(
        const SnackBar(content: Text('Removed from blacklist')),
      );
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Remove failed: ${_err(e)}')),
      );
    }
  }
}

String _err(Object e) {
  if (e is NetworkException && e.message.isNotEmpty) {
    return e.message;
  }
  return 'request failed';
}
