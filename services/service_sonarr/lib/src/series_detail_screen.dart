import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/sonarr_episode.dart';
import 'models/sonarr_series.dart';
import 'sonarr_api.dart';
import 'sonarr_providers.dart';

class SeriesDetailScreen extends ConsumerWidget {
  const SeriesDetailScreen({
    required this.instance,
    required this.seriesId,
    super.key,
  });

  final Instance instance;
  final int seriesId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SonarrSeries> seriesAsync =
        ref.watch(sonarrSeriesByIdProvider((instance, seriesId)));
    final AsyncValue<List<SonarrEpisode>> episodesAsync =
        ref.watch(sonarrEpisodesProvider((instance, seriesId)));

    return Scaffold(
      body: AsyncValueView<SonarrSeries>(
        value: seriesAsync,
        onRetry: () => ref.invalidate(sonarrSeriesByIdProvider((instance, seriesId))),
        data: (SonarrSeries series) {
          return AsyncValueView<List<SonarrEpisode>>(
            value: episodesAsync,
            onRetry: () => ref.invalidate(sonarrEpisodesProvider((instance, seriesId))),
            data: (List<SonarrEpisode> episodes) {
              return _SeriesDetailBody(
                instance: instance,
                series: series,
                episodes: episodes,
              );
            },
          );
        },
      ),
    );
  }
}

class _SeriesDetailBody extends ConsumerWidget {
  const _SeriesDetailBody({
    required this.instance,
    required this.series,
    required this.episodes,
  });

  final Instance instance;
  final SonarrSeries series;
  final List<SonarrEpisode> episodes;

  void _refresh(WidgetRef ref) {
    ref.invalidate(sonarrSeriesByIdProvider((instance, series.id)));
    ref.invalidate(sonarrEpisodesProvider((instance, series.id)));
    ref.invalidate(sonarrSeriesProvider(instance));
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final SonarrApi? api = ref.watch(sonarrApiProvider(instance)).value;

    final SonarrImage? poster = series.images
        .firstWhereOrNull((SonarrImage i) => i.coverType == 'poster');
    final String? posterUrl = poster == null ? null : api?.posterUrl(poster, width: 500);

    final SonarrImage? fanart = series.images
        .firstWhereOrNull((SonarrImage i) => i.coverType == 'fanart') ??
        series.images.firstWhereOrNull((SonarrImage i) => i.coverType == 'banner');
    final String? fanartUrl = fanart == null ? null : api?.posterUrl(fanart);

    final Map<int, List<SonarrEpisode>> episodesBySeason = groupBy(episodes, (e) => e.seasonNumber);
    final List<int> sortedSeasons = episodesBySeason.keys.toList()..sort();

    final int downloadedEpisodesCount = episodes.where((e) => e.hasFile).length;

    return Stack(
      children: <Widget>[
        // Enhanced Backdrop fanart image stacked in background
        if (fanartUrl != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 400,
            child: Hero(
              tag: 'series-banner-${series.id}',
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.black,
                      Colors.black.withValues(alpha: 0.1),
                      Colors.transparent,
                    ],
                    stops: const <double>[0.0, 0.6, 1.0],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: CachedNetworkImage(
                  imageUrl: fanartUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

        // Scrollable content on top of background
        Scaffold(
          backgroundColor: Colors.transparent,
          body: RefreshIndicator(
            onRefresh: () async => _refresh(ref),
            child: CustomScrollView(
              slivers: <Widget>[
                const SliverAppBar(
                  pinned: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  surfaceTintColor: Colors.transparent,
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: Insets.md),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 120),
                      // Full Title wrapping naturally
                      Text(
                        series.title,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: <Shadow>[
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.7),
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Insets.md),

                      _Header(
                        series: series,
                        posterUrl: posterUrl,
                        downloadedCount: downloadedEpisodesCount,
                        totalEpisodes: episodes.length,
                        formattedSize: _formatSize(series.statistics?.sizeOnDisk ?? 0),
                      ),
                      if (series.overview != null && series.overview!.isNotEmpty) ...[
                        const SizedBox(height: Insets.md),
                        _OverviewCard(overview: series.overview!),
                      ],
                      const SizedBox(height: Insets.lg),
                      Text(
                        'Seasons & Episodes',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: Insets.sm),
                      ...sortedSeasons.map((seasonNum) {
                        final List<SonarrEpisode> seasonEpisodes = episodesBySeason[seasonNum]!
                          ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
                        final int seasonDownloaded = seasonEpisodes.where((e) => e.hasFile).length;

                        return Card(
                          margin: const EdgeInsets.only(bottom: Insets.sm),
                          clipBehavior: Clip.antiAlias,
                          color: theme.colorScheme.surfaceContainerHigh,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ExpansionTile(
                            shape: const Border(),
                            title: Text(
                              seasonNum == 0 ? 'Specials' : 'Season $seasonNum',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '$seasonDownloaded / ${seasonEpisodes.length} downloaded',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                            ),
                            children: seasonEpisodes.map((episode) {
                              final String airDateStr = episode.airDate ?? 'Unknown Air Date';
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: Insets.md),
                                leading: Icon(
                                  episode.hasFile
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: episode.hasFile
                                      ? Colors.green
                                      : theme.colorScheme.outline,
                                  size: 20,
                                ),
                                title: Text(
                                  'E${episode.episodeNumber.toString().padLeft(2, '0')}: ${episode.title}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  airDateStr,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                                trailing: Icon(
                                  episode.monitored
                                      ? Icons.bookmark
                                      : Icons.bookmark_border,
                                  color: episode.monitored
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.outline,
                                  size: 18,
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      }),
                      const SizedBox(height: Insets.xl),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.series,
    required this.posterUrl,
    required this.downloadedCount,
    required this.totalEpisodes,
    required this.formattedSize,
  });

  final SonarrSeries series;
  final String? posterUrl;
  final int downloadedCount;
  final int totalEpisodes;
  final String formattedSize;

  Color _statusColor(String? status, ThemeData theme) {
    if (status == null) return theme.colorScheme.outline;
    if (status.toLowerCase() == 'continuing') return Colors.green;
    return theme.colorScheme.outline;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.65)
            : theme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      padding: const EdgeInsets.all(Insets.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (posterUrl != null)
            Hero(
              tag: 'series-poster-${series.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 80,
                  height: 120,
                  child: CachedNetworkImage(
                    imageUrl: posterUrl!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            )
          else
            Container(
              width: 80,
              height: 120,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.live_tv, size: 24),
            ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _statusColor(series.status, theme).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: _statusColor(series.status, theme).withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        series.status ?? 'Unknown',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: _statusColor(series.status, theme),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: Insets.xs),
                    if (series.monitored)
                      Icon(
                        Icons.bookmark,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                  ],
                ),
                const SizedBox(height: Insets.xs),
                Text(
                  '${series.year ?? 'Unknown'} • ${series.network ?? 'Unknown'}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: Insets.xs),
                Text(
                  '$downloadedCount / $totalEpisodes episodes',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: Insets.xs),
                Text(
                  'Size on disk: $formattedSize',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.overview});

  final String overview;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHigh,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Overview',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: Insets.xs),
            Text(
              overview,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
