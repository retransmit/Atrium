// series_detail_screen.dart
//
// Performance architecture:
//   • _BodyState is the ONLY ConsumerState that calls ref.watch.
//   • All child widgets (_Header, _SeasonTile, _EpisodeTile) receive plain
//     pre-resolved data — zero Riverpod subscriptions inside list items.
//   • Background uses CachedNetworkImage color/colorBlendMode instead of
//     Opacity()+ShaderMask() to avoid two GPU saveLayer passes per frame.
//   • The download-pulse AnimatedBuilder is wrapped in RepaintBoundary so
//     only those pixels are repainted during animation, not the whole Card.

import 'dart:ui' show lerpDouble;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'models/sonarr_add_models.dart';
import 'models/sonarr_episode.dart';
import 'models/sonarr_queue.dart';
import 'models/sonarr_series.dart';
import 'sonarr_api.dart';
import 'sonarr_providers.dart';
import 'sonarr_release_search_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SeriesDetailScreen — thin shell. Loads the series by ID, then delegates.
// ─────────────────────────────────────────────────────────────────────────────
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: Colors.white,
          onPressed: () => Navigator.of(context).pop(),
        ),
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

// ─────────────────────────────────────────────────────────────────────────────
// _Body — THE single ConsumerStatefulWidget.
//
// ALL ref.watch calls live here. Children receive plain data so they have
// zero Riverpod subscription overhead in their build methods.
// ─────────────────────────────────────────────────────────────────────────────
class _Body extends ConsumerStatefulWidget {
  const _Body({required this.instance, required this.series});

  final Instance instance;
  final SonarrSeries series;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  late final ScrollController _scrollController;
  bool _showScrollUp = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    final bool show = _scrollController.offset > 300;
    if (show != _showScrollUp) setState(() => _showScrollUp = show);
  }

  void _scrollToTop() {
    HapticFeedback.lightImpact();
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _refresh() {
    ref.invalidate(sonarrSeriesByIdProvider((widget.instance, widget.series.id)));
    ref.invalidate(sonarrSeriesProvider(widget.instance));
    ref.invalidate(sonarrEpisodesProvider((widget.instance, widget.series.id)));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final ColorScheme colors = theme.colorScheme;

    // ── All provider watches in one place ─────────────────────────────────
    final SonarrApi? api = ref.watch(sonarrApiProvider(widget.instance)).value;

    final String profileName =
        ref.watch(sonarrQualityProfilesProvider(widget.instance)).maybeWhen(
              data: (List<SonarrQualityProfile> profiles) =>
                  profiles
                      .firstWhereOrNull(
                        (SonarrQualityProfile p) =>
                            p.id == widget.series.qualityProfileId,
                      )
                      ?.name ??
                  'Unknown',
              orElse: () => '...',
            );

    final AsyncValue<List<SonarrEpisode>> episodesValue =
        ref.watch(sonarrEpisodesProvider((widget.instance, widget.series.id)));

    // Pre-filter queue records to this series so season/episode tiles receive
    // a plain List with no ref.watch of their own.
    final List<SonarrQueueRecord> seriesQueueRecords =
        ref.watch(sonarrQueueProvider(widget.instance)).maybeWhen(
              data: (SonarrQueuePage page) => page.records
                  .where((SonarrQueueRecord r) => r.seriesId == widget.series.id)
                  .toList(),
              orElse: () => <SonarrQueueRecord>[],
            );

    // Pre-group episodes by season
    final Map<int, List<SonarrEpisode>> episodesBySeason = episodesValue.maybeWhen(
      data: (List<SonarrEpisode> list) {
        final Map<int, List<SonarrEpisode>> groups = list.groupListsBy((SonarrEpisode ep) => ep.seasonNumber);
        for (final List<SonarrEpisode> eps in groups.values) {
          eps.sort((SonarrEpisode a, SonarrEpisode b) => a.episodeNumber.compareTo(b.episodeNumber));
        }
        return groups;
      },
      orElse: () => <int, List<SonarrEpisode>>{},
    );

    // Index queue records by episode ID for O(1) lookup
    final Map<int, SonarrQueueRecord> queueRecordsByEpisode = seriesQueueRecords.fold(
      <int, SonarrQueueRecord>{},
      (Map<int, SonarrQueueRecord> map, SonarrQueueRecord record) {
        if (record.episodeId != null) {
          map[record.episodeId!] = record;
        }
        return map;
      },
    );
    // ──────────────────────────────────────────────────────────────────────

    // Resolve image URLs
    final SonarrImage? posterImg = widget.series.images
        .firstWhereOrNull((SonarrImage i) => i.coverType == 'poster');
    final SonarrImage? fanartImg = widget.series.images
        .firstWhereOrNull((SonarrImage i) => i.coverType == 'fanart');
    final String? imageUrl =
        posterImg == null ? null : api?.posterUrl(posterImg);
    final String? fanartUrl =
        fanartImg == null ? null : api?.posterUrl(fanartImg);

    // Season lists
    final List<SonarrSeasonStats> seasons = widget.series.seasons
        .where((SonarrSeasonStats s) => s.seasonNumber > 0)
        .sorted(
          (SonarrSeasonStats a, SonarrSeasonStats b) =>
              b.seasonNumber - a.seasonNumber,
        );
    final SonarrSeasonStats? specials = widget.series.seasons
        .firstWhereOrNull((SonarrSeasonStats s) => s.seasonNumber == 0);

    return Stack(
      children: <Widget>[
        // ── Static fanart background ────────────────────────────────────
        // Uses CachedNetworkImage color/colorBlendMode instead of
        // Opacity() + ShaderMask() — avoids two GPU saveLayer passes.
        if (fanartUrl != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 420,
            child: RepaintBoundary(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  CachedNetworkImage(
                    imageUrl: fanartUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 1000,
                    // Blend-mode darkening — no Opacity saveLayer.
                    color: Colors.black
                        .withValues(alpha: isDark ? 0.65 : 0.40),
                    colorBlendMode: BlendMode.darken,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                  // Bottom-fade via a simple gradient box (no saveLayer).
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: <Color>[Colors.black, Colors.transparent],
                        stops: <double>[0.0, 0.45],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Status-bar protection gradient ─────────────────────────────
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 100,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.black.withValues(alpha: 0.45),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Scrollable content ─────────────────────────────────────────
        RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 280, 16, 120),
            children: <Widget>[
              // RepaintBoundary: only rebuilds when series data/profileName
              // changes, not when queue or episodes update.
              RepaintBoundary(
                child: _Header(
                  instance: widget.instance,
                  series: widget.series,
                  imageUrl: imageUrl,
                  profileName: profileName,
                ),
              ),
              const SizedBox(height: 16),
              RepaintBoundary(
                child: _ActionsRow(
                  instance: widget.instance,
                  series: widget.series,
                  onChanged: (_) => _refresh(),
                ),
              ),
              if (widget.series.overview?.isNotEmpty == true) ...<Widget>[
                const SizedBox(height: 16),
                RepaintBoundary(
                  child: _OverviewCard(
                    overview: widget.series.overview!,
                    isDark: isDark,
                    colors: colors,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 8),
                child: Text(
                  'Seasons',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              for (final SonarrSeasonStats season in seasons)
                _SeasonTile(
                  instance: widget.instance,
                  series: widget.series,
                  season: season,
                  onChanged: (_) => _refresh(),
                  episodesValue: episodesValue,
                  seasonEps: episodesBySeason[season.seasonNumber] ?? <SonarrEpisode>[],
                  queueRecordsByEpisode: queueRecordsByEpisode,
                ),
              if (specials != null)
                _SeasonTile(
                  instance: widget.instance,
                  series: widget.series,
                  season: specials,
                  onChanged: (_) => _refresh(),
                  episodesValue: episodesValue,
                  seasonEps: episodesBySeason[0] ?? <SonarrEpisode>[],
                  queueRecordsByEpisode: queueRecordsByEpisode,
                ),
            ],
          ),
        ),

        // ── Scroll-to-top FAB ──────────────────────────────────────────
        AnimatedPositioned(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          bottom: _showScrollUp ? 96 : 40,
          right: 24,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _showScrollUp ? 1.0 : 0.0,
            child: IgnorePointer(
              ignoring: !_showScrollUp,
              child: FloatingActionButton.small(
                heroTag: 'scroll_up_series_detail',
                onPressed: _scrollToTop,
                backgroundColor: colors.secondaryContainer,
                foregroundColor: colors.onSecondaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child:
                    const Icon(Icons.keyboard_arrow_up_rounded, size: 24),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _OverviewCard — pure StatelessWidget
// ─────────────────────────────────────────────────────────────────────────────
class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.overview,
    required this.isDark,
    required this.colors,
  });

  final String overview;
  final bool isDark;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceContainerLow.withValues(alpha: 0.88)
            : colors.surfaceContainerLowest.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        overview,
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _Header — pure StatelessWidget. All data pre-resolved by _BodyState.
// ─────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({
    required this.instance,
    required this.series,
    required this.imageUrl,
    required this.profileName,
  });

  final Instance instance;
  final SonarrSeries series;
  final String? imageUrl;
  final String profileName;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final SonarrSeriesStatistics? st = series.statistics;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.92)
            : theme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(Insets.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Poster
          Hero(
            tag: 'poster-${series.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 110,
                height: 165,
                child: imageUrl == null
                    ? ColoredBox(
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
                        memCacheWidth: 220,
                        placeholder: (_, __) => ColoredBox(
                          color: theme.colorScheme.surfaceContainerHighest,
                        ),
                        errorWidget: (_, __, ___) => ColoredBox(
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
          const SizedBox(width: Insets.lg),
          // Info column
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
                Wrap(
                  spacing: Insets.xs,
                  runSpacing: 4,
                  children: <Widget>[
                    if (series.year != null)
                      _InfoChip(label: '${series.year}'),
                    if (series.network?.isNotEmpty == true)
                      _InfoChip(label: series.network!),
                    if (series.status != null)
                      _InfoChip(
                        label: series.status!,
                        isPrimary:
                            series.status?.toLowerCase() == 'continuing',
                      ),
                  ],
                ),
                const SizedBox(height: Insets.sm),
                // Quality profile pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.video_settings,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
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
          _SeriesMenu(instance: instance, series: series),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _InfoChip — pure StatelessWidget
// ─────────────────────────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────
// _ActionsRow — ConsumerWidget using only ref.read in handlers (no ref.watch).
// ─────────────────────────────────────────────────────────────────────────────
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
        Expanded(
          child: series.monitored
              ? FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primaryContainer
                        .withValues(alpha: 0.8),
                    foregroundColor: theme.colorScheme.onPrimaryContainer,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  icon: const Icon(Icons.bookmark, size: 20),
                  label: const Text(
                    'Monitored',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _toggleMonitored(ref),
                )
              : OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: theme.colorScheme.outline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  icon: const Icon(Icons.bookmark_border, size: 20),
                  label: const Text('Unmonitored'),
                  onPressed: () => _toggleMonitored(ref),
                ),
        ),
        const SizedBox(width: Insets.md),
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            icon: const Icon(Icons.search, size: 20),
            label: const Text(
              'Search all',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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

// ─────────────────────────────────────────────────────────────────────────────
// _SeasonTile — ConsumerStatefulWidget.
//
// KEY CHANGE: ref.watch(sonarrQueueProvider) has been REMOVED from build().
// The pre-filtered seriesQueueRecords list is passed from _BodyState instead.
// This means N season tiles no longer create N queue-provider subscriptions.
// ─────────────────────────────────────────────────────────────────────────────
class _SeasonTile extends ConsumerStatefulWidget {
  const _SeasonTile({
    required this.instance,
    required this.series,
    required this.season,
    required this.onChanged,
    required this.episodesValue,
    required this.seasonEps,
    required this.queueRecordsByEpisode,
  });

  final Instance instance;
  final SonarrSeries series;
  final SonarrSeasonStats season;
  final void Function(WidgetRef) onChanged;
  final AsyncValue<List<SonarrEpisode>> episodesValue;
  final List<SonarrEpisode> seasonEps;
  final Map<int, SonarrQueueRecord> queueRecordsByEpisode;

  @override
  ConsumerState<_SeasonTile> createState() => _SeasonTileState();
}

class _SeasonTileState extends ConsumerState<_SeasonTile>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _expandController;
  late final Animation<double> _expandAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..addStatusListener(_onExpandStatusChanged);
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _expandController
      ..removeStatusListener(_onExpandStatusChanged)
      ..dispose();
    super.dispose();
  }

  void _onExpandStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.dismissed && mounted) {
      setState(() {});
    }
  }

  void _syncPulse(bool hasActiveDownload) {
    if (hasActiveDownload && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!hasActiveDownload && _pulseController.isAnimating) {
      _pulseController
        ..stop()
        ..value = 0;
    }
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

  Future<void> _toggleSeason() async {
    final SonarrApi api =
        await ref.read(sonarrApiProvider(widget.instance).future);
    final Map<String, dynamic> raw = await api.getSeriesRaw(widget.series.id);
    final List<dynamic> seasons = raw['seasons'] as List<dynamic>;
    for (final dynamic s in seasons) {
      final Map<String, dynamic> sm = s as Map<String, dynamic>;
      if (sm['seasonNumber'] == widget.season.seasonNumber) {
        sm['monitored'] = !widget.season.monitored;
      }
    }
    await api.updateSeriesRaw(raw);
    widget.onChanged(ref);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final SonarrSeasonStatistics? st = widget.season.statistics;
    final String label = widget.season.seasonNumber == 0
        ? 'Specials'
        : 'Season ${widget.season.seasonNumber}';

    final String statsStr = st == null
        ? ''
        : '${st.episodeFileCount}/${st.totalEpisodeCount} eps'
            ' • ${_fmtSize(st.sizeOnDisk)}';

    final List<SonarrEpisode> seasonEps = widget.seasonEps;
    final List<SonarrQueueRecord> seasonQueueRecords = seasonEps
        .map((SonarrEpisode ep) => widget.queueRecordsByEpisode[ep.id])
        .whereType<SonarrQueueRecord>()
        .toList();
    final bool shouldBuildEpisodes = _isExpanded || _expandController.value > 0;

    // Compute download progress from pre-filtered records.
    double progress = 0;
    int progressPct = 0;
    String downloadStatusStr = '';
    if (seasonQueueRecords.isNotEmpty) {
      final double totalSize = seasonQueueRecords.fold<double>(
        0,
        (double p, SonarrQueueRecord r) => p + r.size,
      );
      final double totalLeft = seasonQueueRecords.fold<double>(
        0,
        (double p, SonarrQueueRecord r) => p + r.sizeleft,
      );
      progress = totalSize <= 0
          ? 0
          : ((totalSize - totalLeft) / totalSize).clamp(0, 1).toDouble();
      progressPct = (progress * 100).round();
      final bool isSeasonal = seasonQueueRecords
          .any((SonarrQueueRecord r) => r.downloadId?.isNotEmpty == true);
      downloadStatusStr = isSeasonal
          ? 'Season Grab: $progressPct%'
          : 'Downloading ${seasonQueueRecords.length} ep(s): $progressPct%';
    }

    final double cardProgress = (st == null || st.totalEpisodeCount == 0)
        ? 0
        : (st.episodeFileCount / st.totalEpisodeCount).clamp(0, 1).toDouble();

    final bool hasActiveDownload =
        seasonQueueRecords.isNotEmpty && progress > 0;

    // Sync pulse animation after build without calling setState inside build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncPulse(hasActiveDownload);
    });

    return Card(
      margin: const EdgeInsets.only(bottom: Insets.sm),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          Stack(
            children: <Widget>[
              // Static library-progress fill (no animation).
              if (cardProgress > 0 && !hasActiveDownload)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: cardProgress,
                      child: ColoredBox(
                        color: theme.colorScheme.primary.withValues(
                          alpha: isDark ? 0.08 : 0.06,
                        ),
                      ),
                    ),
                  ),
                ),

              // Animated download-progress fill.
              // RepaintBoundary ensures ONLY these pixels repaint during
              // the pulse animation — not the ListTile, text, or icons.
              if (hasActiveDownload)
                Positioned.fill(
                  child: RepaintBoundary(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: progress,
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (BuildContext context, Widget? child) {
                            return ColoredBox(
                              color: theme.colorScheme.primary.withValues(
                                alpha: lerpDouble(
                                  isDark ? 0.08 : 0.05,
                                  isDark ? 0.22 : 0.16,
                                  _pulseController.value,
                                )!,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),

              ListTile(
                onTap: _toggleExpand,
                title: Text(
                  label,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                subtitle: (statsStr.isNotEmpty || downloadStatusStr.isNotEmpty)
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text.rich(
                          TextSpan(
                            children: <InlineSpan>[
                              if (downloadStatusStr.isNotEmpty)
                                TextSpan(
                                  text: '$downloadStatusStr • ',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              if (statsStr.isNotEmpty)
                                TextSpan(
                                  text: statsStr,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )
                    : null,
                leading: Container(
                  decoration: BoxDecoration(
                    color: widget.season.monitored
                        ? theme.colorScheme.primary.withValues(alpha: 0.1)
                        : theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    tooltip: widget.season.monitored
                        ? 'Unmonitor season'
                        : 'Monitor season',
                    icon: Icon(
                      widget.season.monitored
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      color: widget.season.monitored
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                      size: 20,
                    ),
                    onPressed: _toggleSeason,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      tooltip: 'Season actions',
                      onSelected: (String value) async {
                        if (value == 'manual') {
                          await Navigator.of(context, rootNavigator: true)
                              .push(
                            MaterialPageRoute<void>(
                              builder: (_) => SonarrReleaseSearchScreen(
                                instance: widget.instance,
                                seriesId: widget.series.id,
                                seasonNumber: widget.season.seasonNumber,
                                seriesTitle: widget.series.title,
                              ),
                            ),
                          );
                        } else if (value == 'search') {
                          final SonarrApi api = await ref.read(
                            sonarrApiProvider(widget.instance).future,
                          );
                          await api.searchSeason(
                            widget.series.id,
                            widget.season.seasonNumber,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('Search started for $label'),
                              ),
                            );
                          }
                        } else if (value == 'delete') {
                          final bool? confirm = await showDialog<bool>(
                            context: context,
                            builder: (BuildContext context) => AlertDialog(
                              title: Text('Delete $label files?'),
                              content: Text(
                                'Are you sure you want to delete all '
                                '$label files on disk?\n'
                                'This will delete '
                                '${st!.episodeFileCount} file(s).',
                              ),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor:
                                        theme.colorScheme.error,
                                    foregroundColor:
                                        theme.colorScheme.onError,
                                  ),
                                  onPressed: () =>
                                      Navigator.pop(context, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true && context.mounted) {
                            final SonarrApi api = await ref.read(
                              sonarrApiProvider(widget.instance).future,
                            );
                            final List<SonarrEpisode> episodes =
                                await api.getEpisodes(widget.series.id);
                            final List<SonarrEpisode> toDelete = episodes
                                .where(
                                  (SonarrEpisode ep) =>
                                      ep.seasonNumber ==
                                          widget.season.seasonNumber &&
                                      ep.hasFile &&
                                      ep.episodeFileId > 0,
                                )
                                .toList();
                            if (toDelete.isNotEmpty) {
                              await Future.wait(
                                toDelete.map(
                                  (SonarrEpisode ep) =>
                                      api.deleteEpisodeFile(ep.episodeFileId),
                                ),
                              );
                            }
                            widget.onChanged(ref);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('All $label files deleted'),
                                ),
                              );
                            }
                          }
                        }
                      },
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'manual',
                          child: Row(
                            children: <Widget>[
                              Icon(Icons.manage_search),
                              SizedBox(width: 8),
                              Text('Manual search'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'search',
                          child: Row(
                            children: <Widget>[
                              Icon(Icons.search),
                              SizedBox(width: 8),
                              Text('Search season'),
                            ],
                          ),
                        ),
                        if (st != null && st.episodeFileCount > 0)
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: <Widget>[
                                Icon(
                                  Icons.delete_outline,
                                  color: theme.colorScheme.error,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Delete season files',
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.expand_more),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Expandable episodes section ─────────────────────────────
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: !shouldBuildEpisodes
                ? const SizedBox.shrink()
                : Column(
                    children: <Widget>[
                      const Divider(height: 1),
                      widget.episodesValue.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: Insets.md),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (Object err, StackTrace? _) => Padding(
                          padding: const EdgeInsets.all(Insets.md),
                          child: Center(
                            child: Text(
                              'Error loading episodes: $err',
                              style:
                                  TextStyle(color: theme.colorScheme.error),
                            ),
                          ),
                        ),
                        data: (List<SonarrEpisode> _) {
                          if (seasonEps.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: Insets.md,
                              ),
                              child: Center(child: Text('No episodes found')),
                            );
                          }
                          return Column(
                            children: <Widget>[
                              for (int i = 0; i < seasonEps.length; i++) ...<Widget>[
                                _EpisodeTile(
                                  instance: widget.instance,
                                  seriesId: widget.series.id,
                                  episode: seasonEps[i],
                                  queueRecord: widget.queueRecordsByEpisode[seasonEps[i].id],
                                ),
                                if (i < seasonEps.length - 1)
                                  const Divider(height: 1, indent: Insets.xl),
                              ],
                              const SizedBox(height: Insets.xs),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _EpisodeTile — ConsumerWidget using only ref.read in handlers (no ref.watch).
//
// KEY CHANGE: ref.watch(sonarrQueueProvider) has been REMOVED from build().
// The pre-resolved queueRecord is passed from _SeasonTileState instead.
// This eliminates N*episodes simultaneous subscriptions on the queue provider.
// ─────────────────────────────────────────────────────────────────────────────
class _EpisodeTile extends ConsumerWidget {
  const _EpisodeTile({
    required this.instance,
    required this.seriesId,
    required this.episode,
    required this.queueRecord,
  });

  final Instance instance;
  final int seriesId;
  final SonarrEpisode episode;
  // Pre-resolved by _SeasonTileState — no provider watch needed here.
  final SonarrQueueRecord? queueRecord;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final String epCode =
        'E${episode.episodeNumber.toString().padLeft(2, '0')}';
    final DateTime? airDate = episode.airDateUtc?.toLocal();
    final String airDateStr = airDate != null
        ? DateFormat('yMMMd').format(airDate)
        : 'Unknown air date';

    final bool isFuture =
        airDate != null && airDate.isAfter(DateTime.now());

    final (String label, Color bg, Color fg) = episode.hasFile
        ? (
            'Downloaded',
            theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
            theme.colorScheme.onPrimaryContainer,
          )
        : isFuture
            ? (
                'Upcoming',
                theme.colorScheme.secondaryContainer
                    .withValues(alpha: 0.4),
                theme.colorScheme.onSecondaryContainer,
              )
            : (
                'Missing',
                theme.colorScheme.errorContainer.withValues(alpha: 0.4),
                theme.colorScheme.onErrorContainer,
              );

    // Resolve download state from the passed-in record.
    double progress = 0;
    String detailText = '';
    String labelOverride = '';
    Color bgOverride = Colors.transparent;
    Color fgOverride = Colors.transparent;

    if (queueRecord != null) {
      progress = queueRecord!.size <= 0
          ? 0
          : ((queueRecord!.size - queueRecord!.sizeleft) / queueRecord!.size)
              .clamp(0, 1)
              .toDouble();
      final int progressPct = (progress * 100).round();
      final bool hasWarning =
          queueRecord!.trackedDownloadStatus?.toLowerCase() == 'warning' ||
              queueRecord!.statusMessages.isNotEmpty;
      final bool hasError =
          queueRecord!.trackedDownloadStatus?.toLowerCase() == 'error';

      if (hasError) {
        labelOverride = 'Error';
        bgOverride =
            theme.colorScheme.errorContainer.withValues(alpha: 0.4);
        fgOverride = theme.colorScheme.onErrorContainer;
      } else if (hasWarning) {
        labelOverride = 'Warning';
        bgOverride = Colors.orange.withValues(alpha: 0.2);
        fgOverride = Colors.orange[800] ?? Colors.orange;
      } else if (queueRecord!.status?.toLowerCase() == 'paused') {
        labelOverride = 'Paused';
        bgOverride =
            theme.colorScheme.outlineVariant.withValues(alpha: 0.4);
        fgOverride = theme.colorScheme.outline;
      } else if (queueRecord!.status?.toLowerCase() == 'completed' ||
          progress >= 0.999) {
        labelOverride = 'Completed';
        bgOverride = Colors.green.withValues(alpha: 0.15);
        fgOverride = Colors.green[800] ?? Colors.green;
      } else {
        labelOverride = 'Downloading ($progressPct%)';
        bgOverride = theme.colorScheme.primaryContainer
            .withValues(alpha: 0.4);
        fgOverride = theme.colorScheme.onPrimaryContainer;
      }

      final List<String> details = <String>[];
      if (queueRecord!.timeleft?.isNotEmpty == true) {
        details.add(queueRecord!.timeleft!);
      }
      if (queueRecord!.status?.isNotEmpty == true &&
          queueRecord!.status?.toLowerCase() != 'downloading') {
        details.add(queueRecord!.status!);
      }
      detailText = details.join(' • ');
    }

    final String activeLabel = queueRecord != null ? labelOverride : label;
    final Color activeBg = queueRecord != null ? bgOverride : bg;
    final Color activeFg = queueRecord != null ? fgOverride : fg;

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
        padding: const EdgeInsets.symmetric(
          vertical: 8,
          horizontal: Insets.sm,
        ),
        child: Row(
          children: <Widget>[
            IconButton(
              icon: Icon(
                episode.monitored ? Icons.bookmark : Icons.bookmark_border,
                size: 20,
                color: episode.monitored
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              visualDensity: VisualDensity.compact,
              tooltip: episode.monitored
                  ? 'Stop monitoring'
                  : 'Monitor episode',
              onPressed: () async {
                final SonarrApi api =
                    await ref.read(sonarrApiProvider(instance).future);
                await api.updateEpisode(
                  episode.copyWith(monitored: !episode.monitored),
                );
                ref.invalidate(
                  sonarrEpisodesProvider((instance, seriesId)),
                );
              },
            ),
            const SizedBox(width: Insets.xs),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: activeBg,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: activeFg.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Text(
                          activeLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: activeFg,
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
                  if (queueRecord != null) ...<Widget>[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          activeFg == Colors.transparent
                              ? theme.colorScheme.primary
                              : activeFg,
                        ),
                      ),
                    ),
                    if (detailText.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        detailText,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(width: Insets.xs),
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
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (String val) async {
                final SonarrApi api =
                    await ref.read(sonarrApiProvider(instance).future);
                if (val == 'search') {
                  await api.searchEpisode(episode.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Search started for $epCode'
                          ' • ${episode.title ?? "Episode"}',
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
                          onPressed: () =>
                              Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.error,
                            foregroundColor: theme.colorScheme.onError,
                          ),
                          onPressed: () =>
                              Navigator.of(context).pop(true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await api.deleteEpisodeFile(episode.episodeFileId);
                    ref.invalidate(
                      sonarrEpisodesProvider((instance, seriesId)),
                    );
                    ref.invalidate(
                      sonarrSeriesByIdProvider((instance, seriesId)),
                    );
                    ref.invalidate(sonarrSeriesProvider(instance));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Episode file deleted'),
                        ),
                      );
                    }
                  }
                }
              },
              itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<String>>[
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
                      leading: Icon(
                        Icons.delete_outline,
                        color: theme.colorScheme.error,
                        size: 20,
                      ),
                      title: Text(
                        'Delete episode file',
                        style:
                            TextStyle(color: theme.colorScheme.error),
                      ),
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

// ─────────────────────────────────────────────────────────────────────────────
// _SeriesMenu — three-dot menu: delete, rename, change quality profile.
// Uses ref.read only in action handlers — no subscriptions in build.
// ─────────────────────────────────────────────────────────────────────────────
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
          _showRenameDialog(context);
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
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Change Quality Profile'),
        content: Consumer(
          builder: (BuildContext context, WidgetRef ref, Widget? child) {
            return ref
                .watch(sonarrQualityProfilesProvider(instance))
                .when(
                  loading: () => const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (Object err, _) => Text('Error: $err'),
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
                          final bool isSelected =
                              p.id == series.qualityProfileId;
                          return ListTile(
                            title: Text(p.name),
                            trailing: isSelected
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.green,
                                  )
                                : null,
                            selected: isSelected,
                            onTap: () async {
                              final SonarrApi api = await ref.read(
                                sonarrApiProvider(instance).future,
                              );
                              final Map<String, dynamic> raw =
                                  await api.getSeriesRaw(series.id);
                              raw['qualityProfileId'] = p.id;
                              await api.updateSeriesRaw(raw);
                              ref.invalidate(
                                sonarrSeriesByIdProvider(
                                  (instance, series.id),
                                ),
                              );
                              ref.invalidate(
                                sonarrSeriesProvider(instance),
                              );
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
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
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RenameDialog(instance: instance, series: series),
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
      final SonarrApi api =
          await ref.read(sonarrApiProvider(instance).future);
      await api.deleteSeries(series.id, deleteFiles: deleteFiles);
      ref.invalidate(sonarrSeriesProvider(instance));
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RenameDialog — ConsumerStatefulWidget for async rename previews.
// ─────────────────────────────────────────────────────────────────────────────
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
  List<Map<String, dynamic>> _previews = <Map<String, dynamic>>[];
  final Set<int> _selectedFileIds = <int>{};

  @override
  void initState() {
    super.initState();
    _fetchPreviews();
  }

  Future<void> _fetchPreviews() async {
    try {
      final SonarrApi api =
          await ref.read(sonarrApiProvider(widget.instance).future);
      final List<Map<String, dynamic>> list =
          await api.getRenamePreviews(widget.series.id);
      if (mounted) {
        setState(() {
          _previews = list;
          _selectedFileIds
            ..clear()
            ..addAll(
              list.map(
                (Map<String, dynamic> e) => e['episodeFileId'] as int,
              ),
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

  String _filename(String path) => path.split(RegExp(r'[/\\]')).last;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final Widget content;
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
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: Insets.xs),
            Text(
              _error!,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
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
              title: const Text(
                'Select All',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              value: _selectedFileIds.length == _previews.length,
              onChanged: (bool? checked) {
                setState(() {
                  if (checked == true) {
                    _selectedFileIds.addAll(
                      _previews.map(
                        (Map<String, dynamic> e) =>
                            e['episodeFileId'] as int,
                      ),
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
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (BuildContext context, int index) {
                  final Map<String, dynamic> preview = _previews[index];
                  final int fileId = preview['episodeFileId'] as int;
                  final bool isSelected = _selectedFileIds.contains(fileId);
                  final int season = preview['seasonNumber'] as int;
                  final List<dynamic> epNums =
                      preview['episodeNumbers'] as List<dynamic>;
                  final String epLabel =
                      'S${season.toString().padLeft(2, '0')}'
                      'E${epNums.map((dynamic e) => e.toString().padLeft(2, '0')).join('-')}';
                  final String existingName =
                      _filename(preview['existingPath'] as String);
                  final String newName =
                      _filename(preview['newPath'] as String);

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
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
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
                    final SonarrApi api = await ref.read(
                      sonarrApiProvider(widget.instance).future,
                    );
                    await api.executeRename(
                      widget.series.id,
                      _selectedFileIds.toList(),
                    );
                    ref.invalidate(
                      sonarrEpisodesProvider(
                        (widget.instance, widget.series.id),
                      ),
                    );
                    ref.invalidate(
                      sonarrSeriesByIdProvider(
                        (widget.instance, widget.series.id),
                      ),
                    );
                    ref.invalidate(sonarrSeriesProvider(widget.instance));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Rename started for ${_selectedFileIds.length} files',
                          ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
String _fmtSize(int bytes) {
  if (bytes <= 0) return '0 B';
  const List<String> units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
  double value = bytes.toDouble();
  int unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final String text = value >= 100 || unit == 0
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$text ${units[unit]}';
}
