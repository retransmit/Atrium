import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home/sonarr_rename_dialog.dart';
import 'models/sonarr_episode.dart';
import 'models/sonarr_series.dart';
import 'sonarr_api.dart';
import 'sonarr_providers.dart';
import 'sonarr_release_search_screen.dart';
import 'sonarr_settings_form_screen.dart';

class SeriesDetailScreen extends ConsumerWidget {
  const SeriesDetailScreen({
    required this.instance,
    required this.series,
    super.key,
  });

  final Instance instance;
  final SonarrSeries series;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SonarrSeries> seriesAsync =
        ref.watch(sonarrSeriesByIdProvider((instance, series.id)));
    final AsyncValue<List<SonarrEpisode>> episodesAsync =
        ref.watch(sonarrEpisodesProvider((instance, series.id)));

    final SonarrSeries activeSeries = seriesAsync.value ?? series;

    return Scaffold(
      body: _SeriesDetailBody(
        instance: instance,
        series: activeSeries,
        episodesAsync: episodesAsync,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Main body
// ---------------------------------------------------------------------------

class _SeriesDetailBody extends ConsumerWidget {
  const _SeriesDetailBody({
    required this.instance,
    required this.series,
    required this.episodesAsync,
  });

  final Instance instance;
  final SonarrSeries series;
  final AsyncValue<List<SonarrEpisode>> episodesAsync;

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    try {
      final api = await ref.read(sonarrApiProvider(instance).future);
      await api.runCommand(<String, dynamic>{
        'name': 'RefreshSeries',
        'seriesId': series.id,
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to refresh: $e')),
        );
      }
    } finally {
      _invalidateProviders(ref);
    }
  }

  void _invalidateProviders(WidgetRef ref) {
    ref.invalidate(sonarrSeriesByIdProvider((instance, series.id)));
    ref.invalidate(sonarrEpisodesProvider((instance, series.id)));
    ref.invalidate(sonarrSeriesProvider(instance));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final SonarrApi? api = ref.watch(sonarrApiProvider(instance)).value;

    final SonarrImage? poster = series.images
        .firstWhereOrNull((SonarrImage i) => i.coverType == 'poster');
    final String? posterUrl =
        poster == null ? null : api?.posterUrl(poster, width: 500);

    final int downloadedCount = series.statistics?.episodeFileCount ?? 0;
    final int totalEpisodes = series.statistics?.episodeCount ?? 0;

    return M3RefreshIndicator(
      onRefresh: () => _refresh(context, ref),
      child: CustomScrollView(
        slivers: <Widget>[
          // -- AppBar --
          SliverAppBar(
            pinned: true,
            title: Text(
              series.title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            actions: <Widget>[
              _OverflowMenu(
                instance: instance,
                series: series,
                onRefreshed: () => _invalidateProviders(ref),
              ),
            ],
          ),

          // -- Content --
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              Insets.lg,
              Insets.sm,
              Insets.lg,
              Insets.xl,
            ),
            sliver: SliverList.list(
              children: <Widget>[
                // Hero info card
                _HeroInfoCard(
                  series: series,
                  posterUrl: posterUrl,
                ),

                const SizedBox(height: Insets.lg),

                // Stats card with progress bar
                _StatsCard(
                  downloadedCount: downloadedCount,
                  totalEpisodes: totalEpisodes,
                  sizeOnDisk: series.statistics?.sizeOnDisk ?? 0,
                ),

                const SizedBox(height: Insets.lg),

                // Action buttons row
                _ActionsRow(
                  instance: instance,
                  series: series,
                  onRefreshed: () => _invalidateProviders(ref),
                ),

                // Genre chips
                if (series.genres.isNotEmpty) ...<Widget>[
                  const SizedBox(height: Insets.lg),
                  Wrap(
                    spacing: Insets.sm,
                    runSpacing: Insets.sm,
                    children: series.genres
                        .map(
                          (String g) => Chip(
                            label: Text(g),
                            backgroundColor: cs.tertiaryContainer,
                            labelStyle: TextStyle(
                              color: cs.onTertiaryContainer,
                              fontSize: 12,
                            ),
                            side: BorderSide.none,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                        )
                        .toList(),
                  ),
                ],

                // Overview
                if (series.overview != null &&
                    series.overview!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: Insets.lg),
                  _OverviewSection(overview: series.overview!),
                ],

                // Info section (path, next airing)
                if (series.path != null ||
                    series.nextAiring != null) ...<Widget>[
                  const SizedBox(height: Insets.lg),
                  _InfoSection(series: series),
                ],

                const SizedBox(height: Insets.xl),

                // Season & Episodes header
                Text(
                  'Seasons & Episodes',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: Insets.md),

                // Episodes content
                ...episodesAsync.when(
                  data: (List<SonarrEpisode> episodes) =>
                      _buildSeasonCards(context, ref, episodes),
                  loading: () => <Widget>[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: Insets.xl),
                        child: ExpressiveProgressIndicator(),
                      ),
                    ),
                  ],
                  error: (error, stack) => <Widget>[
                    Center(
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: Insets.xl),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              'Failed to load episodes.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.error,
                              ),
                            ),
                            const SizedBox(height: Insets.sm),
                            FilledButton.tonal(
                              onPressed: () => ref.invalidate(
                                sonarrEpisodesProvider((instance, series.id)),
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSeasonCards(
    BuildContext context,
    WidgetRef ref,
    List<SonarrEpisode> episodes,
  ) {
    final Map<int, List<SonarrEpisode>> episodesBySeason =
        groupBy(episodes, (e) => e.seasonNumber);
    final List<int> sortedSeasons = episodesBySeason.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // newest first

    return sortedSeasons.map((int seasonNum) {
      final List<SonarrEpisode> seasonEpisodes = episodesBySeason[seasonNum]!
        ..sort((a, b) => b.episodeNumber.compareTo(a.episodeNumber));

      // Get per-season stats from the series model if available
      final SonarrSeason? seasonMeta =
          series.seasons.firstWhereOrNull((s) => s.seasonNumber == seasonNum);

      return Padding(
        padding: const EdgeInsets.only(bottom: Insets.md),
        child: _SeasonCard(
          instance: instance,
          series: series,
          seasonNumber: seasonNum,
          episodes: seasonEpisodes,
          seasonMeta: seasonMeta,
          onRefreshed: () => _refresh(context, ref),
        ),
      );
    }).toList();
  }
}

// ---------------------------------------------------------------------------
// Hero Info Card — poster + metadata on a tinted surface
// ---------------------------------------------------------------------------

class _HeroInfoCard extends StatelessWidget {
  const _HeroInfoCard({required this.series, required this.posterUrl});

  final SonarrSeries series;
  final String? posterUrl;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(Radii.xl),
      ),
      padding: const EdgeInsets.all(Insets.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Poster
          Hero(
            tag: 'series-poster-${series.id}',
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.md),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.md),
                child: SizedBox(
                  width: 110,
                  height: 165,
                  child: posterUrl != null
                      ? CachedNetworkImage(
                          imageUrl: posterUrl!,
                          fit: BoxFit.cover,
                          memCacheWidth: 500,
                          placeholder: (_, __) => Container(
                            color: cs.surfaceContainerHighest,
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    ExpressiveProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: cs.surfaceContainerHighest,
                            child: Icon(
                              Icons.live_tv,
                              color: cs.outline,
                              size: 32,
                            ),
                          ),
                        )
                      : Container(
                          color: cs.surfaceContainerHighest,
                          child:
                              Icon(Icons.live_tv, color: cs.outline, size: 32),
                        ),
                ),
              ),
            ),
          ),

          const SizedBox(width: Insets.lg),

          // Metadata column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Title
                Text(
                  series.title,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: Insets.sm),

                // Info chips row
                Wrap(
                  spacing: Insets.xs,
                  runSpacing: Insets.xs,
                  children: <Widget>[
                    if (series.year != null) _MetaChip(label: '${series.year}'),
                    if (series.network != null)
                      _MetaChip(label: series.network!),
                    if (series.runtime != null && series.runtime! > 0)
                      _MetaChip(label: '${series.runtime} min'),
                    if (series.certification != null &&
                        series.certification!.isNotEmpty)
                      _MetaChip(label: series.certification!),
                    if (series.seriesType != null)
                      _MetaChip(label: _capitalise(series.seriesType!)),
                  ],
                ),

                const SizedBox(height: Insets.md),

                // Status pill
                _StatusPill(status: series.status),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _capitalise(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ---------------------------------------------------------------------------
// Stats Card — progress bar + numbers
// ---------------------------------------------------------------------------

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.downloadedCount,
    required this.totalEpisodes,
    required this.sizeOnDisk,
  });

  final int downloadedCount;
  final int totalEpisodes;
  final int sizeOnDisk;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final double progress =
        totalEpisodes > 0 ? downloadedCount / totalEpisodes : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      padding: const EdgeInsets.all(Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.tv, size: 18, color: cs.onSecondaryContainer),
              const SizedBox(width: Insets.xs),
              Text(
                '$downloadedCount of $totalEpisodes episodes',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: cs.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Icon(Icons.storage, size: 18, color: cs.onSecondaryContainer),
              const SizedBox(width: Insets.xs),
              Text(
                _formatSize(sizeOnDisk),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: cs.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.sm),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0 ? cs.tertiary : cs.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Actions Row — pill-shaped tonal buttons
// ---------------------------------------------------------------------------

class _ActionsRow extends ConsumerWidget {
  const _ActionsRow({
    required this.instance,
    required this.series,
    required this.onRefreshed,
  });

  final Instance instance;
  final SonarrSeries series;
  final VoidCallback onRefreshed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Row(
      children: <Widget>[
        // Monitor toggle
        Expanded(
          child: series.monitored
              ? FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.secondaryContainer,
                    foregroundColor: cs.onSecondaryContainer,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.bookmark, size: 20),
                  label: const Text(
                    'Monitored',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _showMonitorSeriesDialog(context, ref),
                )
              : OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: cs.outline),
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.bookmark_border, size: 20),
                  label: const Text('Unmonitored'),
                  onPressed: () => _showMonitorSeriesDialog(context, ref),
                ),
        ),

        const SizedBox(width: Insets.sm),

        // Search button
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: const StadiumBorder(),
            ),
            icon: const Icon(Icons.search, size: 20),
            label: const Text(
              'Search',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () => _searchSeries(context, ref),
          ),
        ),
      ],
    );
  }

  void _showMonitorSeriesDialog(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    String selectedType = series.monitored ? 'all' : 'none';

    final Map<String, String> options = {
      'all': 'All Episodes',
      'future': 'Future Episodes',
      'missing': 'Missing Episodes',
      'existing': 'Existing Episodes',
      'firstSeason': 'First Season',
      'lastSeason': 'Last Season',
      'pilot': 'Pilot Episode',
      'recent': 'Recent Episodes',
      'monitorSpecials': 'Monitor Specials',
      'unmonitorSpecials': 'Unmonitor Specials',
      'none': 'None (Unmonitor All)',
    };

    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              title: Text(
                'Monitor Series',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Choose which episodes of "${series.title}" should be monitored by Sonarr:',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration: InputDecoration(
                      labelText: 'Monitoring',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    items: options.entries.map((e) {
                      return DropdownMenuItem<String>(
                        value: e.key,
                        child: Text(e.value),
                      );
                    }).toList(),
                    onChanged: (String? val) {
                      if (val != null) {
                        setState(() {
                          selectedType = val;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    try {
                      final api = await ref.read(sonarrApiProvider(instance).future);
                      await api.updateSeasonPass(
                        seriesIds: [series.id],
                        monitorType: selectedType,
                      );
                      onRefreshed();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              selectedType == 'none'
                                  ? 'Series unmonitored.'
                                  : 'Series monitoring updated to ${options[selectedType]}.',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to update monitoring: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _searchSeries(BuildContext context, WidgetRef ref) async {
    final api = await ref.read(sonarrApiProvider(instance).future);
    try {
      await api.runCommand(<String, dynamic>{
        'name': 'SeriesSearch',
        'seriesId': series.id,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Search started for series.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to trigger search: $e')),
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Overview Section — expandable synopsis
// ---------------------------------------------------------------------------

class _OverviewSection extends StatefulWidget {
  const _OverviewSection({required this.overview});

  final String overview;

  @override
  State<_OverviewSection> createState() => _OverviewSectionState();
}

class _OverviewSectionState extends State<_OverviewSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Overview',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: Insets.sm),
          AnimatedCrossFade(
            firstChild: Text(
              widget.overview,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            secondChild: Text(
              widget.overview,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
          if (widget.overview.length > 150) ...<Widget>[
            const SizedBox(height: Insets.xs),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded ? 'Show less' : 'Show more',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info Section — path, next airing
// ---------------------------------------------------------------------------

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.series});

  final SonarrSeries series;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (series.path != null) ...<Widget>[
            _InfoRow(
              icon: Icons.folder_outlined,
              label: 'Path',
              value: series.path!,
            ),
          ],
          if (series.nextAiring != null) ...<Widget>[
            if (series.path != null) const SizedBox(height: Insets.sm),
            _InfoRow(
              icon: Icons.schedule,
              label: 'Next Airing',
              value: _formatDateTime(series.nextAiring!),
            ),
          ],
          if (series.previousAiring != null) ...<Widget>[
            const SizedBox(height: Insets.sm),
            _InfoRow(
              icon: Icons.history,
              label: 'Previous Airing',
              value: _formatDateTime(series.previousAiring!),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDateTime(String isoDate) {
    try {
      final DateTime dt = DateTime.parse(isoDate).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 16, color: cs.outline),
        const SizedBox(width: Insets.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.outline,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Season Card — expandable card with progress bar
// ---------------------------------------------------------------------------

class _SeasonCard extends ConsumerStatefulWidget {
  const _SeasonCard({
    required this.instance,
    required this.series,
    required this.seasonNumber,
    required this.episodes,
    required this.seasonMeta,
    required this.onRefreshed,
  });

  final Instance instance;
  final SonarrSeries series;
  final int seasonNumber;
  final List<SonarrEpisode> episodes;
  final SonarrSeason? seasonMeta;
  final VoidCallback onRefreshed;

  @override
  ConsumerState<_SeasonCard> createState() => _SeasonCardState();
}

class _SeasonCardState extends ConsumerState<_SeasonCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    final int downloaded = widget.episodes.where((e) => e.hasFile).length;
    final int total = widget.episodes.length;
    final double progress = total > 0 ? downloaded / total : 0.0;
    final bool isMonitored = widget.seasonMeta?.monitored ?? false;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(Radii.lg),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.lg,
                Insets.md,
                Insets.sm,
                Insets.md,
              ),
              child: Row(
                children: <Widget>[
                  // Monitor indicator (Togglable IconButton)
                  IconButton(
                    icon: Icon(
                      isMonitored ? Icons.bookmark : Icons.bookmark_border,
                      size: 18,
                      color: isMonitored ? cs.primary : cs.outline,
                    ),
                    tooltip: isMonitored ? 'Unmonitor Season' : 'Monitor Season',
                    onPressed: () => _toggleSeasonMonitoring(context, isMonitored),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                  const SizedBox(width: Insets.sm),

                  // Season title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.seasonNumber == 0
                              ? 'Specials'
                              : 'Season ${widget.seasonNumber}',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: <Widget>[
                            // Progress bar (inline)
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 4,
                                  backgroundColor: cs.surfaceContainerHighest,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    progress >= 1.0 ? cs.tertiary : cs.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: Insets.sm),
                            Text(
                              '$downloaded/$total',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.outline,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Search season (automatic)
                  IconButton(
                    icon: const Icon(Icons.search, size: 20),
                    tooltip: 'Automatic Search',
                    onPressed: () =>
                        _searchSeason(context, widget.seasonNumber),
                    visualDensity: VisualDensity.compact,
                  ),

                  // Search season (interactive)
                  IconButton(
                    icon: const Icon(Icons.person_search, size: 20),
                    tooltip: 'Interactive Search',
                    onPressed: () => _openSeasonInteractiveSearch(
                      context,
                      widget.seasonNumber,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),

                  // Delete season files
                  if (downloaded > 0)
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: cs.error, size: 20),
                      tooltip: 'Delete Season Files',
                      onPressed: () => _confirmDeleteSeasonFiles(context),
                      visualDensity: VisualDensity.compact,
                    ),

                  // Expand indicator
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more, size: 24),
                  ),
                ],
              ),
            ),
          ),

          // Episode list
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Column(
              children: <Widget>[
                Divider(
                  height: 1,
                  color: cs.outlineVariant.withValues(alpha: 0.3),
                ),
                ...widget.episodes.map(
                  (SonarrEpisode episode) => _EpisodeRow(
                    instance: widget.instance,
                    series: widget.series,
                    episode: episode,
                  ),
                ),
              ],
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleSeasonMonitoring(BuildContext context, bool currentMonitored) async {
    try {
      final api = await ref.read(sonarrApiProvider(widget.instance).future);
      final raw = await api.getSeriesRaw(widget.series.id);
      
      final List<dynamic> seasons = raw['seasons'] as List<dynamic>;
      for (final dynamic s in seasons) {
        final Map<String, dynamic> season = s as Map<String, dynamic>;
        if (season['seasonNumber'] == widget.seasonNumber) {
          season['monitored'] = !currentMonitored;
          break;
        }
      }
      
      await api.updateSeriesRaw(raw);

      if (!context.mounted) return;
      ref.invalidate(sonarrSeriesByIdProvider((widget.instance, widget.series.id)));
      ref.invalidate(sonarrSeriesProvider(widget.instance));
      widget.onRefreshed();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !currentMonitored
                ? 'Season ${widget.seasonNumber} monitored.'
                : 'Season ${widget.seasonNumber} unmonitored.',
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update monitoring: $e')),
        );
      }
    }
  }

  Future<void> _confirmDeleteSeasonFiles(BuildContext context) async {
    final theme = Theme.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Season ${widget.seasonNumber} Files'),
        content: Text(
          'Are you sure you want to delete all episode files for Season ${widget.seasonNumber}? This will delete the files from disk and cannot be undone.',
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
      if (!context.mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deleting season files...'),
          duration: Duration(seconds: 1),
        ),
      );

      int deletedCount = 0;
      int failedCount = 0;

      final fileIds = widget.episodes
          .where((e) => e.hasFile && e.episodeFileId != null)
          .map((e) => e.episodeFileId!)
          .toList();

      try {
        final api = await ref.read(sonarrApiProvider(widget.instance).future);
        for (final fileId in fileIds) {
          try {
            await api.deleteEpisodeFile(fileId);
            deletedCount++;
          } catch (e) {
            failedCount++;
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete season files: $e')),
          );
        }
        return;
      }

      if (!context.mounted) return;
      ref.invalidate(sonarrEpisodesProvider((widget.instance, widget.series.id)));
      ref.invalidate(sonarrSeriesByIdProvider((widget.instance, widget.series.id)));
      ref.invalidate(sonarrSeriesProvider(widget.instance));
      widget.onRefreshed();

      if (context.mounted) {
        if (failedCount == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully deleted $deletedCount file(s).')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Deleted $deletedCount file(s). Failed to delete $failedCount file(s).',
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _searchSeason(BuildContext context, int seasonNum) async {
    try {
      final api = await ref.read(sonarrApiProvider(widget.instance).future);
      await api.runCommand(<String, dynamic>{
        'name': 'SeasonSearch',
        'seriesId': widget.series.id,
        'seasonNumber': seasonNum,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search queued for Season $seasonNum.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  void _openSeasonInteractiveSearch(BuildContext context, int seasonNum) {
    pushScreen<void>(
      context,
      SonarrReleaseSearchScreen(
        instance: widget.instance,
        series: widget.series,
        seasonNumber: seasonNum,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Episode Row — clean row with popup menu
// ---------------------------------------------------------------------------

class _EpisodeRow extends ConsumerWidget {
  const _EpisodeRow({
    required this.instance,
    required this.series,
    required this.episode,
  });

  final Instance instance;
  final SonarrSeries series;
  final SonarrEpisode episode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    final Color statusColor =
        episode.hasFile ? cs.tertiary : cs.outlineVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.sm,
      ),
      child: Row(
        children: <Widget>[
          // Episode number circle
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: episode.hasFile
                  ? cs.tertiary.withValues(alpha: 0.15)
                  : cs.surfaceContainerHighest,
              border: Border.all(color: statusColor, width: 1.5),
            ),
            child: Center(
              child: Text(
                '${episode.episodeNumber}',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: episode.hasFile ? cs.tertiary : cs.outline,
                ),
              ),
            ),
          ),

          const SizedBox(width: Insets.md),

          // Title + air date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  episode.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (episode.airDate != null)
                  Text(
                    episode.airDate!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.outline,
                    ),
                  ),
              ],
            ),
          ),

          // Monitored indicator
          Icon(
            episode.monitored ? Icons.bookmark : Icons.bookmark_border,
            size: 16,
            color: episode.monitored ? cs.primary : cs.outline,
          ),

          // Popup menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            padding: EdgeInsets.zero,
            onSelected: (String action) => _handleAction(context, ref, action),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'monitor',
                child: ListTile(
                  leading: Icon(
                    episode.monitored
                        ? Icons.bookmark_remove
                        : Icons.bookmark_add,
                  ),
                  title: Text(episode.monitored ? 'Unmonitor' : 'Monitor'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'auto_search',
                child: ListTile(
                  leading: Icon(Icons.search),
                  title: Text('Automatic Search'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'manual_search',
                child: ListTile(
                  leading: Icon(Icons.manage_search),
                  title: Text('Interactive Search'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              if (episode.hasFile && episode.episodeFileId != null)
                PopupMenuItem<String>(
                  value: 'delete_file',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline, color: cs.error),
                    title: Text(
                      'Delete File',
                      style: TextStyle(color: cs.error),
                    ),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    switch (action) {
      case 'monitor':
        try {
          final api = await ref.read(sonarrApiProvider(instance).future);
          final updated = episode.copyWith(monitored: !episode.monitored);
          await api.updateEpisode(updated.toJson());
          if (!context.mounted) return;
          ref.invalidate(sonarrEpisodesProvider((instance, series.id)));
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed: $e')),
            );
          }
        }

      case 'auto_search':
        try {
          final api = await ref.read(sonarrApiProvider(instance).future);
          await api.runCommand(<String, dynamic>{
            'name': 'EpisodeSearch',
            'episodeIds': [episode.id],
          });
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Automatic search queued.')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed: $e')),
            );
          }
        }

      case 'manual_search':
        if (context.mounted) {
          await pushScreen<void>(
            context,
            SonarrReleaseSearchScreen(
              instance: instance,
              episode: episode,
            ),
          );
        }

      case 'delete_file':
        if (context.mounted) {
          await _confirmDeleteFile(context, ref);
        }
    }
  }

  Future<void> _confirmDeleteFile(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Episode File'),
        content: const Text(
          'Are you sure? This will delete the file from disk and cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && episode.episodeFileId != null) {
      try {
        final api = await ref.read(sonarrApiProvider(instance).future);
        await api.deleteEpisodeFile(episode.episodeFileId!);
        if (!context.mounted) return;
        ref.invalidate(sonarrEpisodesProvider((instance, series.id)));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File deleted.')),
        );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Overflow Menu — edit, rename, delete
// ---------------------------------------------------------------------------

class _OverflowMenu extends ConsumerWidget {
  const _OverflowMenu({
    required this.instance,
    required this.series,
    required this.onRefreshed,
  });

  final Instance instance;
  final SonarrSeries series;
  final VoidCallback onRefreshed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      onSelected: (String value) => _handleAction(context, ref, value),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'edit',
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Edit Series'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem<String>(
          value: 'rename',
          child: ListTile(
            leading: Icon(Icons.drive_file_rename_outline),
            title: Text('Rename Files'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'delete',
          child: ListTile(
            leading: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Delete Series',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'edit':
        pushScreen<void>(
          context,
          SonarrSettingsFormScreen(
            instance: instance,
            series: series,
          ),
        );

      case 'rename':
        showDialog<void>(
          context: context,
          builder: (_) => SonarrRenameDialog(
            instance: instance,
            seriesId: series.id,
          ),
        );

      case 'delete':
        _confirmDelete(context, ref);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    bool deleteFiles = false;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setState) => AlertDialog(
          title: const Text('Delete Series'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Are you sure you want to delete "${series.title}"?'),
              const SizedBox(height: Insets.md),
              CheckboxListTile(
                title: const Text(
                  'Delete files from disk',
                  style: TextStyle(fontSize: 14),
                ),
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: deleteFiles,
                onChanged: (val) {
                  if (val != null) setState(() => deleteFiles = val);
                },
              ),
            ],
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
      ),
    );

    if (ok == true) {
      try {
        final api = await ref.read(sonarrApiProvider(instance).future);
        await api.deleteSeries(series.id, deleteFiles: deleteFiles);
        if (!context.mounted) return;
        ref.invalidate(sonarrSeriesProvider(instance));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Series deleted.')),
        );
        Navigator.pop(context);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Small reusable widgets
// ---------------------------------------------------------------------------

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.outlineVariant.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(Radii.xl),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isContinuing = status?.toLowerCase() == 'continuing';
    final Color tint = isContinuing ? Colors.green : theme.colorScheme.outline;
    final String label = status ?? 'Unknown';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.xl),
        border: Border.all(color: tint.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tint,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _capitalise(label),
            style: theme.textTheme.labelSmall?.copyWith(
              color: tint,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static String _capitalise(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
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
