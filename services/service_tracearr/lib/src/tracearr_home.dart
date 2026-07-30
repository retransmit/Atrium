import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator_plus/palette_generator_plus.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';

import 'models/tracearr_active_sessions.dart';
import 'models/tracearr_session.dart';
import 'models/tracearr_stats.dart';
import 'tracearr_providers.dart';
import 'tracearr_session_detail_screen.dart';

class TracearrHome extends StatelessWidget {
  const TracearrHome({required this.instance, super.key});

  final Instance instance;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: <Widget>[
          const TabBar(
            tabs: <Widget>[
              Tab(icon: Icon(Icons.home_outlined), text: 'Home'),
              Tab(icon: Icon(Icons.history), text: 'History'),
              Tab(icon: Icon(Icons.bar_chart_outlined), text: 'Stats'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                _HomeTab(instance: instance),
                _HistoryTab(instance: instance),
                _StatsTab(instance: instance),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TracearrHistoryNotifier notifier =
        ref.watch(tracearrHistoryProvider(instance));
    final Map<String, String> servers =
        ref.watch(tracearrServersProvider(instance)).value ??
            <String, String>{};

    return ListenableBuilder(
      listenable: notifier,
      builder: (BuildContext context, Widget? child) {
        final AsyncValue<List<TracearrSession>> historyVal = notifier.state;
        return AsyncValueView<List<TracearrSession>>(
          value: historyVal,
          onRetry: () => ref.invalidate(tracearrHistoryProvider(instance)),
          data: (List<TracearrSession> data) {
            if (data.isEmpty) {
              return const EmptyView(
                icon: Icons.history,
                title: 'No history',
                message: 'There are no historical sessions available.',
              );
            }

            return NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification scrollInfo) {
                if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
                  notifier.loadMore();
                }
                return false;
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(Insets.lg),
                itemCount: data.length,
                itemBuilder: (BuildContext context, int index) {
                  final TracearrSession session = data[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: Insets.lg),
                    child: _SessionCard(
                      serverUrl: servers[session.serverId],
                      session: session,
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _StatsTab extends ConsumerWidget {
  const _StatsTab({required this.instance});

  final Instance instance;

  String _formatBytes(String bytesStr) {
    final int bytes = int.tryParse(bytesStr) ?? 0;
    if (bytes == 0) return '0 B';
    const List<String> suffixes = <String>['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    int i = 0;
    double val = bytes.toDouble();
    while (val >= 1024 && i < suffixes.length - 1) {
      val /= 1024;
      i++;
    }
    return '${val.toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TracearrStats> statsVal =
        ref.watch(tracearrStatsProvider(instance));

    return AsyncValueView<TracearrStats>(
      value: statsVal,
      onRetry: () => ref.invalidate(tracearrStatsProvider(instance)),
      data: (TracearrStats data) {
        final bool hasQualityData = data.qualityBreakdown != null &&
            (data.qualityBreakdown!.count4k +
                    data.qualityBreakdown!.count1080p +
                    data.qualityBreakdown!.count720p +
                    data.qualityBreakdown!.countSd) >
                0;

        return ListView(
          padding: const EdgeInsets.all(Insets.lg),
          children: <Widget>[
            // Hero section: Totals
            Row(
              children: <Widget>[
                Expanded(
                  child: Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    color: Theme.of(context).colorScheme.primaryContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      child: Column(
                        children: <Widget>[
                          Icon(Icons.storage_outlined, size: 32, color: Theme.of(context).colorScheme.onPrimaryContainer),
                          const SizedBox(height: 8),
                          Text(
                            data.totalItems.toString(),
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                          ),
                          Text(
                            'Total Items',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Insets.lg),
                Expanded(
                  child: Card(
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
                      child: Column(
                        children: <Widget>[
                          Icon(Icons.sd_storage_outlined, size: 32, color: Theme.of(context).colorScheme.onTertiaryContainer),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _formatBytes(data.totalSizeBytes),
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                                  ),
                            ),
                          ),
                          Text(
                            'Total Size',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.lg),

            // Library Composition (PieChart)
            Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(Insets.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Library Composition',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: Insets.lg),
                    SizedBox(
                      height: 200,
                      child: Builder(
                        builder: (BuildContext context) {
                          final double total = (data.movieCount + data.showCount + data.episodeCount).toDouble();
                          if (total == 0) return const SizedBox.shrink();

                          final BorderSide border = BorderSide(
                            color: Theme.of(context).colorScheme.surfaceContainerLow,
                            width: 1.5,
                          );

                          return PieChart(
                            PieChartData(
                              sectionsSpace: 0,
                              centerSpaceRadius: 50,
                              sections: <PieChartSectionData>[
                                if (data.movieCount > 0)
                                  PieChartSectionData(
                                    color: Colors.pink.shade400,
                                    value: data.movieCount.toDouble(),
                                    showTitle: false,
                                    radius: 50,
                                    borderSide: border,
                                  ),
                                if (data.showCount > 0)
                                  PieChartSectionData(
                                    color: Colors.teal.shade400,
                                    value: data.showCount.toDouble(),
                                    showTitle: false,
                                    radius: 50,
                                    borderSide: border,
                                  ),
                                if (data.episodeCount > 0)
                                  PieChartSectionData(
                                    color: Colors.amber.shade400,
                                    value: data.episodeCount.toDouble(),
                                    showTitle: false,
                                    radius: 50,
                                    borderSide: border,
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: Insets.lg),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: Insets.md,
                      runSpacing: Insets.sm,
                      children: <Widget>[
                        if (data.movieCount > 0) _Indicator(color: Colors.pink.shade400, text: '${data.movieCount} Movies'),
                        if (data.showCount > 0) _Indicator(color: Colors.teal.shade400, text: '${data.showCount} Shows'),
                        if (data.episodeCount > 0) _Indicator(color: Colors.amber.shade400, text: '${data.episodeCount} Episodes'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Insets.lg),

            // Quality Breakdown (PieChart)
            if (hasQualityData)
              Card(
                elevation: 0,
                margin: EdgeInsets.zero,
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(Insets.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        'Quality Breakdown',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: Insets.lg),
                      SizedBox(
                        height: 200,
                        child: Builder(
                          builder: (BuildContext context) {
                            final List<MapEntry<String, int>> validQualities = <MapEntry<String, int>>[];
                            final List<Color> validColors = <Color>[];
                            
                            if (data.qualityBreakdown!.count4k > 0) {
                              validQualities.add(MapEntry<String, int>('4K', data.qualityBreakdown!.count4k));
                              validColors.add(Colors.purple.shade400);
                            }
                            if (data.qualityBreakdown!.count1080p > 0) {
                              validQualities.add(MapEntry<String, int>('1080p', data.qualityBreakdown!.count1080p));
                              validColors.add(Colors.blue.shade400);
                            }
                            if (data.qualityBreakdown!.count720p > 0) {
                              validQualities.add(MapEntry<String, int>('720p', data.qualityBreakdown!.count720p));
                              validColors.add(Colors.green.shade400);
                            }
                            if (data.qualityBreakdown!.countSd > 0) {
                              validQualities.add(MapEntry<String, int>('SD', data.qualityBreakdown!.countSd));
                              validColors.add(Colors.orange.shade400);
                            }

                            if (validQualities.isEmpty) return const SizedBox.shrink();

                            final double maxVal = validQualities.map((MapEntry<String, int> e) => e.value).reduce(max).toDouble();

                            return BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: max(1, maxVal) * 1.2,
                                barTouchData: BarTouchData(enabled: false),
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (double value, TitleMeta meta) {
                                        final int index = value.toInt();
                                        if (index < 0 || index >= validQualities.length) {
                                          return const SizedBox.shrink();
                                        }
                                        final TextStyle style = Theme.of(context).textTheme.bodySmall!.copyWith(fontWeight: FontWeight.bold);
                                        return SideTitleWidget(
                                          meta: meta,
                                          space: 4,
                                          child: Text(validQualities[index].key, style: style),
                                        );
                                      },
                                    ),
                                  ),
                                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                gridData: const FlGridData(show: false),
                                borderData: FlBorderData(show: false),
                                barGroups: List<BarChartGroupData>.generate(validQualities.length, (int index) {
                                  // Enforce a visual minimum toY so tiny values don't disappear completely
                                  final double rawValue = validQualities[index].value.toDouble();
                                  final double displayValue = max(rawValue, maxVal * 0.05);

                                  return BarChartGroupData(
                                    x: index,
                                    barRods: <BarChartRodData>[
                                      BarChartRodData(
                                        toY: displayValue,
                                        color: validColors[index],
                                        width: 32,
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                      )
                                    ],
                                  );
                                }),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: Insets.lg),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: Insets.md,
                        runSpacing: Insets.sm,
                        children: <Widget>[
                          if (data.qualityBreakdown!.count4k > 0)
                            _Indicator(color: Colors.purple.shade400, text: '4K (${data.qualityBreakdown!.count4k})'),
                          if (data.qualityBreakdown!.count1080p > 0)
                            _Indicator(color: Colors.blue.shade400, text: '1080p (${data.qualityBreakdown!.count1080p})'),
                          if (data.qualityBreakdown!.count720p > 0)
                            _Indicator(color: Colors.green.shade400, text: '720p (${data.qualityBreakdown!.count720p})'),
                          if (data.qualityBreakdown!.countSd > 0)
                            _Indicator(color: Colors.orange.shade400, text: 'SD (${data.qualityBreakdown!.countSd})'),
                        ],
                      )
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HomeTab extends ConsumerWidget {
  const _HomeTab({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TracearrActiveSessions> sessions =
        ref.watch(tracearrSessionsProvider(instance));
    final Map<String, String> servers =
        ref.watch(tracearrServersProvider(instance)).value ??
            <String, String>{};

    return AsyncValueView<TracearrActiveSessions>(
      value: sessions,
      onRetry: () => ref.invalidate(tracearrSessionsProvider(instance)),
      data: (TracearrActiveSessions data) {
        if (data.sessions.isEmpty) {
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
            onRefresh: () async =>
                ref.invalidate(tracearrSessionsProvider(instance)),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const <Widget>[
                SizedBox(height: 100),
                EmptyView(
                  icon: Icons.podcasts_outlined,
                  title: 'Nothing playing',
                  message: 'No active streams right now.',
                ),
              ],
            ),
          );
        }

        final List<TracearrSession> embySessions = <TracearrSession>[];
        final List<TracearrSession> plexSessions = <TracearrSession>[];
        final List<TracearrSession> jellyfinSessions = <TracearrSession>[];

        final Set<String> seen = <String>{};

        for (final TracearrSession s in data.sessions) {
          final String key = '${s.playerName}|${s.displayTitle}|${s.device}';
          if (seen.contains(key)) continue;
          seen.add(key);

          final String type = s.serverType.toLowerCase();
          if (type.contains('plex')) {
            plexSessions.add(s);
          } else if (type.contains('emby')) {
            embySessions.add(s);
          } else {
            jellyfinSessions.add(s);
          }
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
          onRefresh: () async =>
              ref.invalidate(tracearrSessionsProvider(instance)),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: Insets.lg),
            children: <Widget>[
              if (embySessions.isNotEmpty) ...<Widget>[
                const _SectionHeader(title: 'Emby Servers'),
                SizedBox(
                  height: 168,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
                    itemCount: embySessions.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: Insets.md),
                    itemBuilder: (BuildContext context, int index) {
                      return SizedBox(
                        width: 330,
                        child: _SessionCard(
                          session: embySessions[index],
                          serverUrl: servers[embySessions[index].serverId],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: Insets.lg),
              ],
              if (plexSessions.isNotEmpty) ...<Widget>[
                const _SectionHeader(title: 'Plex Servers'),
                SizedBox(
                  height: 168,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
                    itemCount: plexSessions.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: Insets.md),
                    itemBuilder: (BuildContext context, int index) {
                      return SizedBox(
                        width: 330,
                        child: _SessionCard(
                          session: plexSessions[index],
                          serverUrl: servers[plexSessions[index].serverId],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: Insets.lg),
              ],
              if (jellyfinSessions.isNotEmpty) ...<Widget>[
                const _SectionHeader(title: 'JellyFin Servers'),
                SizedBox(
                  height: 168,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
                    itemCount: jellyfinSessions.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: Insets.md),
                    itemBuilder: (BuildContext context, int index) {
                      return SizedBox(
                        width: 330,
                        child: _SessionCard(
                          session: jellyfinSessions[index],
                          serverUrl: servers[jellyfinSessions[index].serverId],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: Insets.lg),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.sm,
      ),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _SessionCard extends StatefulWidget {
  const _SessionCard({
    required this.session,
    this.serverUrl,
  });

  final TracearrSession session;
  final String? serverUrl;

  @override
  State<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<_SessionCard> {
  PaletteGenerator? _palette;
  String? _lastPosterUrl;

  String? get imageUrl {
    if (widget.serverUrl != null && widget.session.thumbPath != null) {
      final String cleanPath = widget.session.thumbPath!.startsWith('/')
          ? widget.session.thumbPath!
          : '/${widget.session.thumbPath!}';
      return '${widget.serverUrl}$cleanPath';
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateColorScheme();
  }

  @override
  void didUpdateWidget(covariant _SessionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.thumbPath != widget.session.thumbPath ||
        oldWidget.serverUrl != widget.serverUrl) {
      _updateColorScheme();
    }
  }

  void _updateColorScheme() {
    final String? posterUrl = imageUrl;
    if (posterUrl == null || posterUrl == _lastPosterUrl) return;
    _lastPosterUrl = posterUrl;

    PaletteGenerator.fromImageProvider(
      CachedNetworkImageProvider(posterUrl, maxWidth: 200, maxHeight: 300),
      size: const Size(200, 300),
    ).then((PaletteGenerator palette) {
      if (mounted) {
        setState(() {
          _palette = palette;
        });
      }
    }).catchError((_) {});
  }

  String formatMs(int ms) {
    final Duration d = Duration(milliseconds: ms);
    final int h = d.inHours;
    final int m = d.inMinutes.remainder(60);
    final int sec = d.inSeconds.remainder(60);
    return h > 0
        ? '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}'
        : '$m:${sec.toString().padLeft(2, '0')}';
  }

  String _formatRelativeTime(DateTime time) {
    final Duration diff = DateTime.now().difference(time);
    if (diff.inDays > 365) return '${(diff.inDays / 365).floor()}y ago';
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final TracearrSession session = widget.session;
    ThemeData theme = Theme.of(context);

    if (_palette != null) {
      final Color dominant =
          _palette!.dominantColor?.color ?? theme.colorScheme.surface;
      final Color vibrant = _palette!.vibrantColor?.color ??
          _palette!.lightVibrantColor?.color ??
          dominant;
      theme = theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          primary: vibrant,
        ),
      );
    }

    final double pct = session.progressPercent / 100.0;
    final bool playing = session.state.toLowerCase() == 'playing';
    final String? posterUrl = imageUrl;

    final String type = session.mediaType.toLowerCase();
    String mainTitle;
    String? subTitle;

    if (type == 'track' || type == 'album' || type == 'audio') {
      mainTitle = session.mediaTitle;
      subTitle = session.artist ??
          session.artistName ??
          session.grandparentTitle ??
          session.parentTitle ??
          session.originalTitle;
    } else if (type == 'episode') {
      final String s = (session.seasonNumber ?? 0).toString().padLeft(2, '0');
      final String e = (session.episodeNumber ?? 0).toString().padLeft(2, '0');
      mainTitle = 'S${s}E$e - ${session.mediaTitle}';
      subTitle = session.grandparentTitle;
    } else {
      mainTitle = session.mediaTitle;
      subTitle = null;
    }

    final String user = session.playerName;
    final String device = session.device;
    final String timePosition = formatMs(session.progressMs);
    final String timeDuration = formatMs(session.totalDurationMs);

    return Theme(
      data: theme,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: InkWell(
          onTap: () => pushScreen<void>(
            context,
            TracearrSessionDetailScreen(
              session: session,
              posterUrl: posterUrl,
            ),
          ),
          child: Stack(
            children: <Widget>[
              // Backdrop
              if (posterUrl != null)
                Positioned.fill(
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      Image.network(
                        posterUrl,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              theme.colorScheme.surfaceContainerLow
                                  .withValues(alpha: 0.3),
                              theme.colorScheme.surfaceContainerLow
                                  .withValues(alpha: 0.85),
                              theme.colorScheme.surfaceContainerLow
                                  .withValues(alpha: 0.95),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Content
              Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Poster
                    ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: 80, maxHeight: 100),
                      child: AspectRatio(
                        aspectRatio: session.mediaType.toLowerCase() ==
                                    'track' ||
                                session.mediaType.toLowerCase() == 'album' ||
                                session.mediaType.toLowerCase() == 'audio'
                            ? 1.0
                            : (2 / 3),
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                            image: posterUrl != null
                                ? DecorationImage(
                                    image: CachedNetworkImageProvider(
                                      posterUrl,
                                    ),
                                    fit: BoxFit.cover,
                                    onError: (Object _, StackTrace? __) {},
                                  )
                                : null,
                          ),
                          child: posterUrl == null
                              ? Icon(
                                  Icons.movie_outlined,
                                  color: theme.colorScheme.outline,
                                  size: 32,
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: Insets.lg),

                    // Details
                    Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            // Title
                            Text(
                              mainTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                shadows: <Shadow>[
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.8),
                                    offset: const Offset(0, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),

                            if (subTitle != null)
                              Text(
                                subTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  shadows: <Shadow>[
                                    Shadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.8),
                                      offset: const Offset(0, 1),
                                      blurRadius: 3,
                                    ),
                                  ],
                                ),
                              ),

                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    Icons.person,
                                    size: 14,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      '$user: $device',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          theme.textTheme.labelSmall?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Only show progress bar if it's an active session (has progress)
                            if (session.state.toLowerCase() == 'playing' ||
                                session.state.toLowerCase() == 'paused' ||
                                session.state.toLowerCase() == 'buffering' ||
                                session.state.toLowerCase() == 'idle') ...<Widget>[
                              const SizedBox(height: 8),

                              // Progress Header
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  Text(
                                    timePosition,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    timeDuration,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.outline,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),

                              // Progress Bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicatorM3E(
                                  shape: ProgressM3EShape.flat,
                                  value: pct.clamp(0.0, 1.0),
                                  trackColor:
                                      theme.colorScheme.surfaceContainerHighest,
                                  activeColor: playing
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.outline,
                                ),
                              ),
                            ] else if (session.startedAt != null) ...<Widget>[
                              const SizedBox(height: 8),
                              Row(
                                children: <Widget>[
                                  Icon(
                                    Icons.schedule,
                                    size: 14,
                                    color: theme.colorScheme.outline,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatRelativeTime(session.startedAt!),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.outline,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(
                                    Icons.devices,
                                    size: 14,
                                    color: theme.colorScheme.outline,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      session.platform,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.outline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: <Widget>[
                                  Icon(
                                    Icons.public,
                                    size: 14,
                                    color: theme.colorScheme.outline,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      session.location != session.ipAddress
                                          ? '${session.location} (${session.ipAddress})'
                                          : session.ipAddress,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.outline,
                                      ),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({
    required this.color,
    required this.text,
  });

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
