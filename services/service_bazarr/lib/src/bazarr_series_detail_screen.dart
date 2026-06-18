import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bazarr_providers.dart';
import 'bazarr_subtitle_chips.dart';
import 'models/bazarr_models.dart';

/// Per-series subtitle view: the episode list with present / missing subtitle
/// chips. Read-only for now; manual search and download land here next.
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
                  _EpisodeCard(episode: eps[index]),
            );
          },
        ),
      ),
    );
  }
}

class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({required this.episode});

  final BazarrEpisode episode;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String code =
        'S${(episode.season ?? 0).toString().padLeft(2, '0')}'
        'E${(episode.episode ?? 0).toString().padLeft(2, '0')}';
    return Card(
      margin: const EdgeInsets.only(bottom: Insets.sm),
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '$code · ${episode.title}',
              style: theme.textTheme.titleSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: Insets.sm),
            BazarrSubtitleChips(
              present: episode.subtitles,
              missing: episode.missingSubtitles,
            ),
          ],
        ),
      ),
    );
  }
}
