import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'models/sonarr_add_models.dart';
import 'models/sonarr_episode.dart';
import 'models/sonarr_series.dart';
import 'sonarr_api.dart';
import 'sonarr_providers.dart';
import 'sonarr_release_search_screen.dart';

/// Detail view for one Sonarr series: poster header, stats, season list with
/// per-season monitor toggles and search, plus series-level actions
/// (monitor toggle, search all, delete).
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
    final AsyncValue<SonarrSeries> series =
        ref.watch(sonarrSeriesByIdProvider((instance, seriesId)));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: <Widget>[
          if (series.hasValue)
            _SeriesMenu(
              instance: instance,
              series: series.requireValue,
            ),
        ],
      ),
      body: AsyncValueView<SonarrSeries>(
        value: series,
        onRetry: () =>
            ref.invalidate(sonarrSeriesByIdProvider((instance, seriesId))),
        data: (SonarrSeries s) => _Body(instance: instance, series: s),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.instance, required this.series});

  final Instance instance;
  final SonarrSeries series;

  void _refresh(WidgetRef ref) {
    ref.invalidate(sonarrSeriesByIdProvider((instance, series.id)));
    ref.invalidate(sonarrSeriesProvider(instance));
    ref.invalidate(sonarrEpisodesProvider((instance, series.id)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final SonarrApi? api = ref.watch(sonarrApiProvider(instance)).value;
    final SonarrImage? poster = series.images
        .firstWhereOrNull((SonarrImage i) => i.coverType == 'poster');
    final String? imageUrl = poster == null ? null : api?.posterUrl(poster);

    final SonarrImage? fanart = series.images
        .firstWhereOrNull((SonarrImage i) => i.coverType == 'fanart');
    final String? fanartUrl = fanart == null ? null : api?.posterUrl(fanart);

    final List<SonarrSeasonStats> seasons = series.seasons
        .where((SonarrSeasonStats s) => s.seasonNumber > 0)
        .sorted(
          (SonarrSeasonStats a, SonarrSeasonStats b) =>
              b.seasonNumber - a.seasonNumber,
        );
    final SonarrSeasonStats? specials = series.seasons
        .firstWhereOrNull((SonarrSeasonStats s) => s.seasonNumber == 0);

    final AsyncValue<List<SonarrEpisode>> episodesValue =
        ref.watch(sonarrEpisodesProvider((instance, series.id)));

    return Stack(
      children: <Widget>[
        // Backdrop Image Banner
         if (fanartUrl != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 260,
            child: ShaderMask(
              shaderCallback: (Rect rect) {
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.black.withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ).createShader(Rect.fromLTRB(0, 0, rect.width, rect.height));
              },
              blendMode: BlendMode.dstIn,
              child: CachedNetworkImage(
                imageUrl: fanartUrl,
                fit: BoxFit.cover,
                memCacheWidth: 800,
                errorWidget: (_, __, ___) => const SizedBox(),
              ),
            ),
          ),

        // Main Screen Content
        RefreshIndicator(
          onRefresh: () async => _refresh(ref),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Insets.lg, Insets.sm, Insets.lg, Insets.lg),
            children: <Widget>[
              // Top padding to show the backdrop beautiful top half
              const SizedBox(height: 110),
              _Header(instance: instance, series: series, imageUrl: imageUrl),
              const SizedBox(height: Insets.md),
              _ActionsRow(instance: instance, series: series, onChanged: _refresh),
              if (series.overview != null && series.overview!.isNotEmpty) ...<
                  Widget>[
                const SizedBox(height: Insets.md),
                // Overview Text Card for better readability over the backdrop
                Container(
                  padding: const EdgeInsets.all(Insets.md),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.8)
                        : theme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    series.overview!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.4,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: Insets.lg),
              Text('Seasons', style: theme.textTheme.titleMedium),
              const SizedBox(height: Insets.sm),
              for (final SonarrSeasonStats season in seasons)
                _SeasonTile(
                  instance: instance,
                  series: series,
                  season: season,
                  onChanged: _refresh,
                  episodesValue: episodesValue,
                ),
              if (specials != null)
                _SeasonTile(
                  instance: instance,
                  series: series,
                  season: specials,
                  onChanged: _refresh,
                  episodesValue: episodesValue,
                ),
              const SizedBox(height: Insets.xl),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.instance,
    required this.series,
    required this.imageUrl,
  });

  final Instance instance;
  final SonarrSeries series;
  final String? imageUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final SonarrSeriesStatistics? st = series.statistics;

    final AsyncValue<List<SonarrQualityProfile>> profilesVal =
        ref.watch(sonarrQualityProfilesProvider(instance));
    final String profileName = profilesVal.maybeWhen(
      data: (List<SonarrQualityProfile> profiles) =>
          profiles.firstWhereOrNull((SonarrQualityProfile p) => p.id == series.qualityProfileId)?.name ?? 'Unknown',
      orElse: () => '...',
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.65)
                : theme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(Insets.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
          // Premium Poster Design
          Hero(
            tag: 'poster-${series.id}',
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 110,
                  height: 165,
                  child: imageUrl == null
                      ? Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.live_tv_outlined,
                            color: theme.colorScheme.outline,
                            size: 32,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: imageUrl!,
                          fit: BoxFit.cover,
                          memCacheWidth: 200,
                          placeholder: (BuildContext context, String url) => Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.live_tv_outlined,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(width: Insets.lg),
          // Text & Stats Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  series.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: Insets.xs),
                // Tags row (Network, Year, Status)
                Wrap(
                  spacing: Insets.xs,
                  runSpacing: 4,
                  children: <Widget>[
                    if (series.year != null)
                      _InfoChip(label: '${series.year}'),
                    if (series.network != null && series.network!.isNotEmpty)
                      _InfoChip(label: series.network!),
                    if (series.status != null)
                      _InfoChip(
                        label: series.status!,
                        isPrimary: series.status?.toLowerCase() == 'continuing',
                      ),
                  ],
                ),
                const SizedBox(height: Insets.sm),
                // Quality profile pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.video_settings, size: 14, color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        profileName,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                if (st != null) ...<Widget>[
                  const SizedBox(height: Insets.md),
                  // Episodes progress text & indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        'Episodes',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      Text(
                        '${st.episodeFileCount}/${st.totalEpisodeCount}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: st.totalEpisodeCount == 0
                          ? 0
                          : (st.episodeFileCount / st.totalEpisodeCount)
                              .clamp(0, 1)
                              .toDouble(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.sd_storage_outlined,
                        size: 14,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _fmtSize(st.sizeOnDisk),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, this.isPrimary = false});
  final String label;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isPrimary
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: isPrimary
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
          fontWeight: isPrimary ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

class _ActionsRow extends ConsumerWidget {
  const _ActionsRow({
    required this.instance,
    required this.series,
    required this.onChanged,
  });

  final Instance instance;
  final SonarrSeries series;
  final void Function(WidgetRef) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        // Monitored Action Button
        Expanded(
          child: series.monitored
              ? FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.8),
                    foregroundColor: theme.colorScheme.onPrimaryContainer,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.bookmark, size: 20),
                  label: const Text('Monitored', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => _toggleMonitored(ref),
                )
              : OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: theme.colorScheme.outline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.bookmark_border, size: 20),
                  label: const Text('Unmonitored'),
                  onPressed: () => _toggleMonitored(ref),
                ),
        ),
        const SizedBox(width: Insets.md),
        // Search All Action Button
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.search, size: 20),
            label: const Text('Search all', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () async {
              final SonarrApi api =
                  await ref.read(sonarrApiProvider(instance).future);
              await api.searchSeries(series.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Search started for all monitored episodes'),
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Future<void> _toggleMonitored(WidgetRef ref) async {
    final SonarrApi api = await ref.read(sonarrApiProvider(instance).future);
    final Map<String, dynamic> raw = await api.getSeriesRaw(series.id);
    raw['monitored'] = !series.monitored;
    await api.updateSeriesRaw(raw);
    onChanged(ref);
  }
}

class _SeasonTile extends ConsumerWidget {
  const _SeasonTile({
    required this.instance,
    required this.series,
    required this.season,
    required this.onChanged,
    required this.episodesValue,
  });

  final Instance instance;
  final SonarrSeries series;
  final SonarrSeasonStats season;
  final void Function(WidgetRef) onChanged;
  final AsyncValue<List<SonarrEpisode>> episodesValue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final SonarrSeasonStatistics? st = season.statistics;
    final String label = season.seasonNumber == 0
        ? 'Specials'
        : 'Season ${season.seasonNumber}';

    final String statsStr = st == null
        ? ''
        : '${st.episodeFileCount}/${st.totalEpisodeCount} episodes'
            '${st.sizeOnDisk > 0 ? ' • ${_fmtSize(st.sizeOnDisk)}' : ''}';

    return Card(
      margin: const EdgeInsets.only(bottom: Insets.sm),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: statsStr.isNotEmpty
            ? Text(
                statsStr,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              )
            : null,
        leading: Container(
          decoration: BoxDecoration(
            color: season.monitored
                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            tooltip: season.monitored ? 'Unmonitor season' : 'Monitor season',
            icon: Icon(
              season.monitored ? Icons.bookmark : Icons.bookmark_border,
              color: season.monitored
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
              size: 20,
            ),
            onPressed: () => _toggleSeason(ref),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              tooltip: 'Manual search',
              icon: const Icon(Icons.manage_search),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SonarrReleaseSearchScreen(
                      instance: instance,
                      seriesId: series.id,
                      seasonNumber: season.seasonNumber,
                      seriesTitle: series.title,
                    ),
                  ),
                );
              },
            ),
            IconButton(
              tooltip: 'Search season',
              icon: const Icon(Icons.search),
              onPressed: () async {
                final SonarrApi api =
                    await ref.read(sonarrApiProvider(instance).future);
                await api.searchSeason(series.id, season.seasonNumber);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Search started for $label')),
                  );
                }
              },
            ),
            if (st != null && st.episodeFileCount > 0)
              IconButton(
                tooltip: 'Delete season files',
                icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                onPressed: () async {
                  final bool? confirm = await showDialog<bool>(
                    context: context,
                    builder: (BuildContext context) => AlertDialog(
                      title: Text('Delete $label files?'),
                      content: Text(
                        'Are you sure you want to delete all $label files on disk?\n'
                        'This will delete ${st.episodeFileCount} file(s).',
                      ),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.error,
                            foregroundColor: theme.colorScheme.onError,
                          ),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    final SonarrApi api = await ref.read(sonarrApiProvider(instance).future);
                    final List<SonarrEpisode> episodes = await api.getEpisodes(series.id);
                    final List<SonarrEpisode> seasonEpisodes = episodes
                        .where((ep) =>
                            ep.seasonNumber == season.seasonNumber &&
                            ep.hasFile &&
                            ep.episodeFileId > 0,)
                        .toList();

                    if (seasonEpisodes.isNotEmpty) {
                      await Future.wait(
                        seasonEpisodes.map((ep) => api.deleteEpisodeFile(ep.episodeFileId)),
                      );
                    }

                    onChanged(ref);

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('All $label files deleted')),
                      );
                    }
                  }
                },
              ),
            const Icon(Icons.expand_more),
          ],
        ),
        children: <Widget>[
          const Divider(height: 1),
          episodesValue.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: Insets.md),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (Object err, StackTrace? stack) => Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: Center(
                child: Text(
                  'Error loading episodes: $err',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ),
            data: (List<SonarrEpisode> list) {
              final List<SonarrEpisode> seasonEpisodes = list
                  .where((SonarrEpisode ep) => ep.seasonNumber == season.seasonNumber)
                  .toList();

              if (seasonEpisodes.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: Insets.md),
                  child: Center(child: Text('No episodes found')),
                );
              }

              // Sort by episode number ascending
              seasonEpisodes.sort((SonarrEpisode a, SonarrEpisode b) =>
                  a.episodeNumber - b.episodeNumber,);

              return Column(
                children: <Widget>[
                  for (final SonarrEpisode ep in seasonEpisodes) ...[
                    _EpisodeTile(
                      instance: instance,
                      seriesId: series.id,
                      episode: ep,
                    ),
                    if (ep != seasonEpisodes.last) const Divider(height: 1, indent: Insets.xl),
                  ],
                  const SizedBox(height: Insets.xs),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _toggleSeason(WidgetRef ref) async {
    final SonarrApi api = await ref.read(sonarrApiProvider(instance).future);
    final Map<String, dynamic> raw = await api.getSeriesRaw(series.id);
    final List<dynamic> seasons = raw['seasons'] as List<dynamic>;
    for (final dynamic s in seasons) {
      final Map<String, dynamic> sm = s as Map<String, dynamic>;
      if (sm['seasonNumber'] == season.seasonNumber) {
        sm['monitored'] = !season.monitored;
      }
    }
    await api.updateSeriesRaw(raw);
    onChanged(ref);
  }
}

class _EpisodeTile extends ConsumerWidget {
  const _EpisodeTile({
    required this.instance,
    required this.seriesId,
    required this.episode,
  });

  final Instance instance;
  final int seriesId;
  final SonarrEpisode episode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final String epCode = 'E${episode.episodeNumber.toString().padLeft(2, '0')}';
    final DateTime? airDate = episode.airDateUtc?.toLocal();
    final String airDateStr = airDate != null
        ? DateFormat('yMMMd').format(airDate)
        : 'Unknown air date';

    final bool isFuture = airDate != null && airDate.isAfter(DateTime.now());
    final (String label, Color bg, Color fg) = episode.hasFile
        ? (
            'Downloaded',
            theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
            theme.colorScheme.onPrimaryContainer,
          )
        : isFuture
            ? (
                'Upcoming',
                theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
                theme.colorScheme.onSecondaryContainer,
              )
            : (
                'Missing',
                theme.colorScheme.errorContainer.withValues(alpha: 0.4),
                theme.colorScheme.onErrorContainer,
              );

    return InkWell(
      onTap: () {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (_) => SonarrReleaseSearchScreen(
              instance: instance,
              episode: episode,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: Insets.sm),
        child: Row(
          children: <Widget>[
            // Monitored Toggle
            IconButton(
              icon: Icon(
                episode.monitored ? Icons.bookmark : Icons.bookmark_border,
                size: 20,
                color: episode.monitored ? theme.colorScheme.primary : theme.colorScheme.outline,
              ),
              visualDensity: VisualDensity.compact,
              tooltip: episode.monitored ? 'Stop monitoring' : 'Monitor episode',
              onPressed: () async {
                final SonarrApi api = await ref.read(sonarrApiProvider(instance).future);
                await api.updateEpisode(episode.copyWith(monitored: !episode.monitored));
                ref.invalidate(sonarrEpisodesProvider((instance, seriesId)));
              },
            ),
            const SizedBox(width: Insets.xs),
            // Episode info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '$epCode • ${episode.title ?? "Episode ${episode.episodeNumber}"}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: Insets.xs),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: Insets.xs,
                    runSpacing: 4,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: fg.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Text(
                          label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: fg,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      Text(
                        airDateStr,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: Insets.xs),
            // Primary Action: Manual Search
            IconButton(
              icon: const Icon(Icons.manage_search, size: 20),
              tooltip: 'Manual search',
              visualDensity: VisualDensity.compact,
              onPressed: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SonarrReleaseSearchScreen(
                      instance: instance,
                      episode: episode,
                    ),
                  ),
                );
              },
            ),
            // Secondary Actions Dropdown
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (String val) async {
                final SonarrApi api = await ref.read(sonarrApiProvider(instance).future);
                if (val == 'search') {
                  await api.searchEpisode(episode.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Search started for $epCode • ${episode.title ?? "Episode"}',
                        ),
                      ),
                    );
                  }
                } else if (val == 'delete') {
                  if (!context.mounted) return;
                  final bool? confirm = await showDialog<bool>(
                    context: context,
                    builder: (BuildContext context) => AlertDialog(
                      title: const Text('Delete episode file?'),
                      content: Text(
                        'Are you sure you want to delete the file for:\n'
                        '${episode.title ?? "Episode ${episode.episodeNumber}"}?',
                      ),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.error,
                            foregroundColor: theme.colorScheme.onError,
                          ),
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await api.deleteEpisodeFile(episode.episodeFileId);
                    ref.invalidate(sonarrEpisodesProvider((instance, seriesId)));
                    ref.invalidate(sonarrSeriesByIdProvider((instance, seriesId)));
                    ref.invalidate(sonarrSeriesProvider(instance));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Episode file deleted')),
                      );
                    }
                  }
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'search',
                  child: ListTile(
                    leading: Icon(Icons.search, size: 20),
                    title: Text('Automatic search'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                if (episode.hasFile && episode.episodeFileId > 0)
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline, color: theme.colorScheme.error, size: 20),
                      title: Text('Delete episode file', style: TextStyle(color: theme.colorScheme.error)),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SeriesMenu extends ConsumerWidget {
  const _SeriesMenu({required this.instance, required this.series});

  final Instance instance;
  final SonarrSeries series;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      onSelected: (String v) async {
        if (v == 'delete') {
          await _confirmDelete(context, ref);
        } else if (v == 'rename') {
          _showRenameDialog(context, ref);
        } else if (v == 'profile') {
          _showChangeProfileDialog(context, ref);
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'profile',
          child: ListTile(
            leading: Icon(Icons.settings_outlined),
            title: Text('Change quality profile'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem<String>(
          value: 'rename',
          child: ListTile(
            leading: Icon(Icons.drive_file_rename_outline),
            title: Text('Rename files'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem<String>(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('Delete series'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  void _showChangeProfileDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Change Quality Profile'),
          content: Consumer(
            builder: (BuildContext context, WidgetRef ref, Widget? child) {
              final AsyncValue<List<SonarrQualityProfile>> profilesVal =
                  ref.watch(sonarrQualityProfilesProvider(instance));
              return profilesVal.when(
                loading: () => const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (Object err, StackTrace? stack) => Text('Error: $err'),
                data: (List<SonarrQualityProfile> profiles) {
                  if (profiles.isEmpty) {
                    return const Text('No profiles available.');
                  }
                  return SizedBox(
                    width: double.maxFinite,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: profiles.length,
                      itemBuilder: (BuildContext context, int index) {
                        final SonarrQualityProfile p = profiles[index];
                        final bool isSelected = p.id == series.qualityProfileId;
                        return ListTile(
                          title: Text(p.name),
                          trailing: isSelected
                              ? const Icon(Icons.check, color: Colors.green)
                              : null,
                          selected: isSelected,
                          onTap: () async {
                            final SonarrApi api =
                                await ref.read(sonarrApiProvider(instance).future);
                            final Map<String, dynamic> raw =
                                await api.getSeriesRaw(series.id);
                            raw['qualityProfileId'] = p.id;
                            await api.updateSeriesRaw(raw);
                            ref.invalidate(
                              sonarrSeriesByIdProvider((instance, series.id)),
                            );
                            ref.invalidate(sonarrSeriesProvider(instance));
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Quality profile changed to ${p.name}',
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _RenameDialog(instance: instance, series: series);
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    bool deleteFiles = false;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) => AlertDialog(
          title: const Text('Delete series?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(series.title),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Also delete files on disk'),
                value: deleteFiles,
                onChanged: (bool? v) =>
                    setState(() => deleteFiles = v ?? false),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
    if (ok ?? false) {
      final SonarrApi api = await ref.read(sonarrApiProvider(instance).future);
      await api.deleteSeries(series.id, deleteFiles: deleteFiles);
      ref.invalidate(sonarrSeriesProvider(instance));
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }
}

class _RenameDialog extends ConsumerStatefulWidget {
  const _RenameDialog({required this.instance, required this.series});

  final Instance instance;
  final SonarrSeries series;

  @override
  ConsumerState<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends ConsumerState<_RenameDialog> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _previews = [];
  final Set<int> _selectedFileIds = {};

  @override
  void initState() {
    super.initState();
    _fetchPreviews();
  }

  Future<void> _fetchPreviews() async {
    try {
      final SonarrApi api = await ref.read(sonarrApiProvider(widget.instance).future);
      final List<Map<String, dynamic>> list = await api.getRenamePreviews(widget.series.id);
      if (mounted) {
        setState(() {
          _previews = list;
          _selectedFileIds.clear();
          _selectedFileIds.addAll(
            list.map((Map<String, dynamic> e) => e['episodeFileId'] as int),
          );
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  String _getFilename(String path) {
    return path.split(RegExp(r'[/\\]')).last;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    Widget content;
    if (_loading) {
      content = const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_error != null) {
      content = Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 48),
            const SizedBox(height: Insets.sm),
            Text(
              'Error loading rename previews',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: Insets.xs),
            Text(_error!, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      );
    } else if (_previews.isEmpty) {
      content = const Padding(
        padding: EdgeInsets.all(Insets.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
            SizedBox(height: Insets.sm),
            Text(
              'All files are properly named',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    } else {
      content = SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: <Widget>[
            CheckboxListTile(
              title: const Text('Select All', style: TextStyle(fontWeight: FontWeight.bold)),
              value: _selectedFileIds.length == _previews.length,
              onChanged: (bool? checked) {
                setState(() {
                  if (checked == true) {
                    _selectedFileIds.addAll(
                      _previews.map((Map<String, dynamic> e) => e['episodeFileId'] as int),
                    );
                  } else {
                    _selectedFileIds.clear();
                  }
                });
              },
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                itemCount: _previews.length,
                separatorBuilder: (BuildContext context, int index) => const Divider(height: 1),
                itemBuilder: (BuildContext context, int index) {
                  final Map<String, dynamic> preview = _previews[index];
                  final int fileId = preview['episodeFileId'] as int;
                  final bool isSelected = _selectedFileIds.contains(fileId);
                  
                  final int season = preview['seasonNumber'] as int;
                  final List<dynamic> epNums = preview['episodeNumbers'] as List<dynamic>;
                  final String epLabel = 'S${season.toString().padLeft(2, '0')}E${epNums.map((dynamic e) => e.toString().padLeft(2, '0')).join('-')}';

                  final String existingName = _getFilename(preview['existingPath'] as String);
                  final String newName = _getFilename(preview['newPath'] as String);

                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (bool? checked) {
                      setState(() {
                        if (checked == true) {
                          _selectedFileIds.add(fileId);
                        } else {
                          _selectedFileIds.remove(fileId);
                        }
                      });
                    },
                    title: Text(
                      epLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const SizedBox(height: 4),
                        Text(
                          'From: $existingName',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'To: $newName',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    return AlertDialog(
      title: const Text('Rename Files'),
      content: content,
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (!_loading && _error == null && _previews.isNotEmpty)
          FilledButton(
            onPressed: _selectedFileIds.isEmpty
                ? null
                : () async {
                    final SonarrApi api = await ref.read(sonarrApiProvider(widget.instance).future);
                    await api.executeRename(widget.series.id, _selectedFileIds.toList());
                    ref.invalidate(sonarrEpisodesProvider((widget.instance, widget.series.id)));
                    ref.invalidate(sonarrSeriesByIdProvider((widget.instance, widget.series.id)));
                    ref.invalidate(sonarrSeriesProvider(widget.instance));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Rename started for ${_selectedFileIds.length} files'),
                        ),
                      );
                      Navigator.of(context).pop();
                    }
                  },
            child: Text('Rename (${_selectedFileIds.length})'),
          ),
      ],
    );
  }
}

String _fmtSize(int bytes) {
  if (bytes <= 0) {
    return '0 B';
  }
  const List<String> units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
  double value = bytes.toDouble();
  int unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final String text =
      value >= 100 || unit == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  return '$text ${units[unit]}';
}
