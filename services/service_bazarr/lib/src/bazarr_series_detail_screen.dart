import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bazarr_api.dart';
import 'bazarr_providers.dart';
import 'bazarr_search_screen.dart';
import 'bazarr_subtitle_chips.dart';
import 'models/bazarr_models.dart';

/// Per-series subtitle view: the episode list with present / missing subtitle
/// chips, a manual-search action per episode, and delete on downloaded subs.
class BazarrSeriesDetailScreen extends ConsumerWidget {
  const BazarrSeriesDetailScreen({
    required this.instance,
    required this.series,
    super.key,
  });

  final Instance instance;
  final BazarrSeries series;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BazarrEpisodesArgs args =
        (instance: instance, seriesId: series.sonarrSeriesId);
    final AsyncValue<List<BazarrEpisode>> episodes =
        ref.watch(bazarrEpisodesProvider(args));
    return Scaffold(
      appBar: AppBar(title: Text(series.title, overflow: TextOverflow.ellipsis)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(bazarrEpisodesProvider(args)),
        child: AsyncValueView<List<BazarrEpisode>>(
          value: episodes,
          onRetry: () => ref.invalidate(bazarrEpisodesProvider(args)),
          data: (List<BazarrEpisode> eps) {
            if (eps.isEmpty) {
              return const EmptyView(
                icon: Icons.subtitles_outlined,
                title: 'No episodes',
                message: 'This series has no episode files in Bazarr.',
              );
            }
            return ListView.builder(
              padding: Insets.page,
              itemCount: eps.length,
              itemBuilder: (BuildContext context, int index) =>
                  _EpisodeCard(instance: instance, episode: eps[index]),
            );
          },
        ),
      ),
    );
  }
}

class _EpisodeCard extends ConsumerWidget {
  const _EpisodeCard({required this.instance, required this.episode});

  final Instance instance;
  final BazarrEpisode episode;

  String get _code =>
      'S${(episode.season ?? 0).toString().padLeft(2, '0')}'
      'E${(episode.episode ?? 0).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: Insets.sm),
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '$_code · ${episode.title}',
                    style: theme.textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Search subtitles',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.subtitles_outlined),
                  onPressed: () => Navigator.of(context, rootNavigator: true)
                      .push(
                    MaterialPageRoute<void>(
                      builder: (_) => BazarrSubtitleSearchScreen(
                        instance: instance,
                        isMovie: false,
                        id: episode.sonarrEpisodeId,
                        seriesId: episode.sonarrSeriesId,
                        title: '$_code · ${episode.title}',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.sm),
            BazarrSubtitleChips(
              present: episode.subtitles,
              missing: episode.missingSubtitles,
              onDeletePresent: (BazarrSubtitle s) =>
                  _confirmDelete(context, ref, s),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    BazarrSubtitle s,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    if (!(s.path?.isNotEmpty ?? false)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'This subtitle is embedded in the video and cannot be removed here.',
          ),
        ),
      );
      return;
    }
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Delete subtitle?'),
        content: Text(
          'Remove the ${s.name.isNotEmpty ? s.name : s.code2.toUpperCase()} '
          'subtitle for $_code?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    try {
      final BazarrApi api =
          await ref.read(bazarrApiProvider(instance).future);
      await api.deleteEpisodeSubtitle(
        seriesId: episode.sonarrSeriesId,
        episodeId: episode.sonarrEpisodeId,
        subtitle: s,
      );
      ref.invalidate(
        bazarrEpisodesProvider(
          (instance: instance, seriesId: episode.sonarrSeriesId),
        ),
      );
      ref.invalidate(bazarrWantedProvider(instance));
      ref.invalidate(bazarrBadgesProvider(instance));
      messenger.showSnackBar(const SnackBar(content: Text('Subtitle deleted')));
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Delete failed: ${_err(e)}')),
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
