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
    return RefreshIndicator(
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
          return ListView.builder(
            padding: Insets.pageH,
            itemCount: items.length,
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
    return ListTile(
      leading: const Icon(Icons.block),
      title: Text(
        title.isEmpty ? 'Unknown' : title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(detail, style: theme.textTheme.bodySmall),
      trailing: IconButton(
        tooltip: 'Remove from blacklist',
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _confirmRemove(context, ref),
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
