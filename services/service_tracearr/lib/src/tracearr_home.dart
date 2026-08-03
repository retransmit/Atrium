import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:palette_generator_plus/palette_generator_plus.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';

import 'models/tracearr_active_sessions.dart';
import 'models/tracearr_activity_concurrent.dart';
import 'models/tracearr_activity_engagement.dart';
import 'models/tracearr_activity_locations.dart';
import 'models/tracearr_activity_platform.dart';
import 'models/tracearr_activity_play.dart';
import 'models/tracearr_activity_play_dow.dart';
import 'models/tracearr_activity_play_hod.dart';
import 'models/tracearr_activity_quality.dart';
import 'models/tracearr_activity_stats.dart';
import 'models/tracearr_completion.dart';
import 'models/tracearr_dashboard_stats.dart';
import 'models/tracearr_library_roi.dart';
import 'models/tracearr_library_storage.dart';
import 'models/tracearr_library_watch_activity.dart';
import 'models/tracearr_patterns.dart';
import 'models/tracearr_session.dart';
import 'models/tracearr_stats.dart';
import 'models/tracearr_top_movies.dart';
import 'models/tracearr_top_shows.dart';
import 'tracearr_api.dart';
import 'tracearr_framed_map.dart';
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
            return DefaultTabController(
              length: 2,
              child: Column(
                children: <Widget>[
                  const TabBar(
                    tabs: <Widget>[
                      Tab(text: 'List'),
                      Tab(text: 'Map'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      physics: const NeverScrollableScrollPhysics(),
                      children: <Widget>[
                        _HistoryListView(
                          instance: instance,
                          notifier: notifier,
                          data: data,
                          servers: servers,
                        ),
                        _HistoryMapView(instance: instance),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _HistoryListView extends ConsumerWidget {
  const _HistoryListView({
    required this.instance,
    required this.notifier,
    required this.data,
    required this.servers,
  });

  final Instance instance;
  final TracearrHistoryNotifier notifier;
  final List<TracearrSession> data;
  final Map<String, String> servers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TracearrApi? api = ref.watch(tracearrApiProvider(instance)).value;
    if (data.isEmpty) {
      return EasyRefresh(
        onRefresh: () async =>
            ref.invalidate(tracearrHistoryProvider(instance)),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const <Widget>[
            SizedBox(height: 100),
            EmptyView(
              icon: Icons.history,
              title: 'No history',
              message: 'There are no historical sessions available.',
            ),
          ],
        ),
      );
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
      footer: const ClassicFooter(
        dragText: 'Pull to load',
        armedText: 'Release ready',
        readyText: 'Loading...',
        processingText: 'Loading...',
        processedText: 'Succeeded',
        failedText: 'Failed',
        noMoreText: 'No more',
        messageText: 'Last updated at %T',
      ),
      onRefresh: () async => ref.invalidate(tracearrHistoryProvider(instance)),
      onLoad: notifier.hasMore ? () async => notifier.loadMore() : null,
      child: ListView.builder(
        padding: const EdgeInsets.all(Insets.lg),
        itemCount: data.length,
        itemBuilder: (BuildContext context, int index) {
          final TracearrSession session = data[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: Insets.lg),
            child: _SessionCard(
              api: api,
              session: session,
              isHistory: true,
            ),
          );
        },
      ),
    );
  }
}

class _HistoryMapView extends ConsumerWidget {
  const _HistoryMapView({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TracearrApi? api = ref.watch(tracearrApiProvider(instance)).value;
    final Map<String, String>? servers =
        ref.watch(tracearrServersProvider(instance)).value;
    final AsyncValue<TracearrActivityLocationsResponse> locsVal =
        ref.watch(tracearrActivityLocationsProvider(instance));

    return AsyncValueView<TracearrActivityLocationsResponse>(
      value: locsVal,
      onRetry: () =>
          ref.invalidate(tracearrActivityLocationsProvider(instance)),
      data: (TracearrActivityLocationsResponse res) {
        final List<Marker> markers = <Marker>[];
        TracearrActivityLocation? maxLoc;

        for (final TracearrActivityLocation loc in res.data) {
          if (loc.lat != null && loc.lon != null) {
            if (maxLoc == null || loc.count > maxLoc.count) {
              maxLoc = loc;
            }

            final List<String> parts = <String>[
              loc.city,
              loc.region,
              loc.country,
            ];
            final String locationName =
                parts.where((String p) => p.isNotEmpty).join(', ');

            final List<TracearrMarkerUser> markerUsers = <TracearrMarkerUser>[];
            for (final TracearrActivityLocationUser user in loc.users) {
              String? imageUrl;
              if (user.thumbUrl != null && api != null) {
                imageUrl = api.proxyImageUrl(
                  serverId: user.serverId ??
                      (servers != null && servers.isNotEmpty
                          ? servers.keys.first
                          : null),
                  path: user.thumbUrl,
                  width: 64,
                  height: 64,
                  fallback: 'avatar',
                );
              }
              markerUsers.add(
                TracearrMarkerUser(
                  username: user.username,
                  avatarUrl: imageUrl,
                  sessionCount: loc.users.length == 1 ? loc.count : 1,
                ),
              );
            }
            if (markerUsers.isEmpty && loc.count > 0) {
              markerUsers.add(
                TracearrMarkerUser(
                  username: loc.city.isNotEmpty ? loc.city : 'Unknown',
                  sessionCount: loc.count,
                ),
              );
            }

            markers.add(
              Marker(
                point: LatLng(loc.lat!, loc.lon!),
                width: 180,
                height: 54,
                child: Center(
                  child: TracearrMapMarkerBadge(
                    users: markerUsers,
                    locationTitle: locationName.isNotEmpty
                        ? locationName
                        : 'Location Activity',
                    coordinates: loc.lat != null && loc.lon != null
                        ? '${loc.lat!.toStringAsFixed(4)}, ${loc.lon!.toStringAsFixed(4)}'
                        : null,
                  ),
                ),
              ),
            );
          }
        }

        if (markers.isEmpty) {
          return const EmptyView(
            icon: Icons.map,
            title: 'No Map Data',
            message:
                'None of the history sessions have geographic coordinates.',
          );
        }

        final LatLng initialCenter =
            maxLoc != null && maxLoc.lat != null && maxLoc.lon != null
                ? LatLng(maxLoc.lat!, maxLoc.lon!)
                : markers.first.point;

        return TracearrFramedMap(
          initialCenter: initialCenter,
          markers: markers,
        );
      },
    );
  }
}

class _StatsTab extends StatelessWidget {
  const _StatsTab({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: <Widget>[
          const TabBar(
            tabs: <Widget>[
              Tab(text: 'Activity'),
              Tab(text: 'Storage'),
              Tab(text: 'Watch'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                _ActivityStatsView(instance: instance),
                _StorageStatsView(instance: instance),
                _WatchStatsView(instance: instance),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
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
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Insets.md),
            const Divider(height: 1),
            const SizedBox(height: Insets.md),
            child,
          ],
        ),
      ),
    );
  }
}

class _PlaysLineChart extends StatefulWidget {
  const _PlaysLineChart({required this.plays, required this.servers});
  final List<TracearrActivityPlay> plays;
  final Map<String, String> servers;

  @override
  State<_PlaysLineChart> createState() => _PlaysLineChartState();
}

class _PlaysLineChartState extends State<_PlaysLineChart> {
  bool _showMore = false;

  @override
  Widget build(BuildContext context) {
    if (widget.plays.isEmpty) return const SizedBox.shrink();

    // 1. Extract unique servers
    final List<String> serverIds = widget.plays
        .map((TracearrActivityPlay e) => e.serverId)
        .toSet()
        .toList();
    final Map<String, Color> serverColors = <String, Color>{};
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<Color> availableColors = <Color>[
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      scheme.error,
      scheme.inversePrimary,
      scheme.primaryContainer,
      scheme.secondaryContainer,
      scheme.tertiaryContainer,
      scheme.surfaceTint,
      scheme.outline,
    ];
    for (int i = 0; i < serverIds.length; i++) {
      serverColors[serverIds[i]] = availableColors[i % availableColors.length];
    }

    // 2. Group by Date
    final Map<String, Map<String, int>> groupedData =
        <String, Map<String, int>>{};
    for (final TracearrActivityPlay item in widget.plays) {
      final String date = item.date;
      final String server = item.serverId;
      final int count = item.count;

      groupedData.putIfAbsent(date, () => <String, int>{});
      groupedData[date]![server] = count;
    }

    final List<String> dates = groupedData.keys.toList();

    Widget buildSingleServerChart(String serverId, Color color) {
      final String serverName = widget.servers[serverId] ??
          (serverId.length > 8 ? serverId.substring(0, 8) : serverId);

      double maxVal = 0;
      final List<FlSpot> spots = <FlSpot>[];
      for (int i = 0; i < dates.length; i++) {
        final int count = groupedData[dates[i]]![serverId] ?? 0;
        if (count > maxVal) maxVal = count.toDouble();
        spots.add(FlSpot(i.toDouble(), count.toDouble()));
      }
      if (maxVal == 0) maxVal = 1;

      return Column(
        children: <Widget>[
          if (serverIds.length > 1) ...<Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 6),
                Text(
                  serverName,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: Insets.sm),
          ],
          AspectRatio(
            aspectRatio: 1.70,
            child: Padding(
              padding: const EdgeInsets.only(
                  right: 18, left: 12, top: 16, bottom: 12),
              child: LineChart(
                LineChartData(
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipColor: (_) => Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.9),
                      getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                        return touchedBarSpots.map((LineBarSpot barSpot) {
                          final int index = barSpot.x.toInt();
                          if (index < 0 || index >= dates.length) return null;

                          final String dateStr = dates[index].split(' ').first;

                          return LineTooltipItem(
                            '${barSpot.y.toInt()} plays\n',
                            TextStyle(
                                color: color, fontWeight: FontWeight.bold),
                            children: <TextSpan>[
                              TextSpan(
                                text: '$serverName\n$dateStr',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.7),
                                  fontSize: 10,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ],
                          );
                        }).toList();
                      },
                    ),
                  ),
                  gridData: FlGridData(
                    horizontalInterval: max(1, maxVal ~/ 5).toDouble(),
                    verticalInterval: 1,
                    getDrawingHorizontalLine: (double value) {
                      return FlLine(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.2),
                          strokeWidth: 1);
                    },
                    getDrawingVerticalLine: (double value) {
                      return FlLine(
                          color: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.2),
                          strokeWidth: 1);
                    },
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final int index = value.toInt();
                          if (index < 0 || index >= dates.length)
                            return const SizedBox.shrink();
                          if (index % max(1, dates.length ~/ 5) != 0)
                            return const SizedBox.shrink();
                          final String text = dates[index]
                              .split(' ')
                              .first
                              .substring(5); // MM-DD
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(text,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 10)),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: max(1, maxVal ~/ 5).toDouble(),
                        reservedSize: 42,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          if (value % 1 != 0) return const SizedBox.shrink();
                          return Text(value.toInt().toString(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12),
                              textAlign: TextAlign.left);
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.2)),
                  ),
                  minX: 0,
                  maxX: max(0, dates.length - 1).toDouble(),
                  minY: 0,
                  maxY: maxVal * 1.2,
                  lineBarsData: <LineChartBarData>[
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      preventCurveOverShooting: true,
                      color: color,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: color.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    final String firstServerId = serverIds.first;

    return Column(
      children: <Widget>[
        buildSingleServerChart(firstServerId, serverColors[firstServerId]!),
        if (serverIds.length > 1) ...<Widget>[
          if (_showMore)
            for (int i = 1; i < serverIds.length; i++) ...<Widget>[
              const SizedBox(height: Insets.md),
              const Divider(height: 1),
              const SizedBox(height: Insets.md),
              buildSingleServerChart(serverIds[i], serverColors[serverIds[i]]!),
            ],
          const SizedBox(height: Insets.sm),
          Center(
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _showMore = !_showMore;
                });
              },
              icon: Icon(_showMore ? Icons.expand_less : Icons.expand_more),
              label: Text(_showMore ? 'Show Less' : 'Show More'),
            ),
          ),
        ],
      ],
    );
  }
}

class _PlaysDowBarChart extends StatefulWidget {
  const _PlaysDowBarChart({required this.plays});
  final List<TracearrActivityPlayDow> plays;

  @override
  State<_PlaysDowBarChart> createState() => _PlaysDowBarChartState();
}

class _PlaysDowBarChartState extends State<_PlaysDowBarChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.plays.isEmpty) return const SizedBox.shrink();

    double maxVal = 0;
    for (final TracearrActivityPlayDow p in widget.plays) {
      if (p.count > maxVal) maxVal = p.count.toDouble();
    }
    if (maxVal == 0) maxVal = 1;

    final Color barBackgroundColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1);
    final Color barColor = Theme.of(context).colorScheme.primary;
    final Color touchedBarColor = Theme.of(context).colorScheme.secondary;

    return AspectRatio(
      aspectRatio: 1.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: BarChart(
          BarChartData(
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipColor: (_) => Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.9),
                tooltipHorizontalAlignment: FLHorizontalAlignment.center,
                tooltipMargin: 8,
                getTooltipItem: (BarChartGroupData group, int groupIndex,
                    BarChartRodData rod, int rodIndex) {
                  return BarTooltipItem(
                    '${widget.plays[groupIndex].name}\n',
                    const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                    children: <TextSpan>[
                      TextSpan(
                        text: widget.plays[groupIndex].count.toString(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  );
                },
              ),
              touchCallback:
                  (FlTouchEvent event, BarTouchResponse? barTouchResponse) {
                setState(() {
                  if (!event.isInterestedForInteractions ||
                      barTouchResponse == null ||
                      barTouchResponse.spot == null) {
                    touchedIndex = -1;
                    return;
                  }
                  touchedIndex = barTouchResponse.spot!.touchedBarGroupIndex;
                });
              },
            ),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(),
              topTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 38,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    final int index = value.toInt();
                    if (index < 0 || index >= widget.plays.length)
                      return const SizedBox.shrink();
                    return SideTitleWidget(
                      meta: meta,
                      space: 16,
                      child: Text(
                          widget.plays[index].name
                              .substring(0, 3)
                              .toUpperCase(),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12)),
                    );
                  },
                ),
              ),
              leftTitles: const AxisTitles(),
            ),
            borderData: FlBorderData(show: false),
            barGroups: widget.plays
                .asMap()
                .entries
                .map((MapEntry<int, TracearrActivityPlayDow> e) {
              final bool isTouched = e.key == touchedIndex;
              return BarChartGroupData(
                x: e.key,
                barRods: <BarChartRodData>[
                  BarChartRodData(
                    toY: e.value.count.toDouble(),
                    color: isTouched ? touchedBarColor : barColor,
                    width: 22,
                    borderSide: isTouched
                        ? BorderSide(
                            color: touchedBarColor.withValues(alpha: 0.8))
                        : const BorderSide(color: Colors.white, width: 0),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxVal * 1.2,
                      color: barBackgroundColor,
                    ),
                  ),
                ],
              );
            }).toList(),
            gridData: const FlGridData(show: false),
          ),
        ),
      ),
    );
  }
}

class _PlaysHodBarChart extends StatefulWidget {
  const _PlaysHodBarChart({required this.plays});
  final List<TracearrActivityPlayHod> plays;

  @override
  State<_PlaysHodBarChart> createState() => _PlaysHodBarChartState();
}

class _PlaysHodBarChartState extends State<_PlaysHodBarChart> {
  int touchedIndex = -1;

  String _formatHour(int hour) {
    if (hour == 0) return '12am';
    if (hour < 12) return '${hour}am';
    if (hour == 12) return '12pm';
    return '${hour - 12}pm';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.plays.isEmpty) return const SizedBox.shrink();

    double maxVal = 0;
    for (final TracearrActivityPlayHod p in widget.plays) {
      if (p.count > maxVal) maxVal = p.count.toDouble();
    }
    if (maxVal == 0) maxVal = 1;

    final Color barBackgroundColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1);
    final Color barColor = Theme.of(context).colorScheme.primary;
    final Color touchedBarColor = Theme.of(context).colorScheme.secondary;

    final Map<int, int> playsMap = <int, int>{
      for (final TracearrActivityPlayHod p in widget.plays) p.hour: p.count,
    };

    return AspectRatio(
      aspectRatio: 1.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: BarChart(
          BarChartData(
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipColor: (_) => Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.9),
                tooltipHorizontalAlignment: FLHorizontalAlignment.center,
                tooltipMargin: 8,
                getTooltipItem: (BarChartGroupData group, int groupIndex,
                    BarChartRodData rod, int rodIndex) {
                  return BarTooltipItem(
                    '${_formatHour(group.x.toInt())}\n${rod.toY.toInt()} plays',
                    const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  );
                },
              ),
              touchCallback:
                  (FlTouchEvent event, BarTouchResponse? barTouchResponse) {
                setState(() {
                  if (!event.isInterestedForInteractions ||
                      barTouchResponse == null ||
                      barTouchResponse.spot == null) {
                    touchedIndex = -1;
                    return;
                  }
                  touchedIndex = barTouchResponse.spot!.touchedBarGroupIndex;
                });
              },
            ),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(),
              topTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 38,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    final int hour = value.toInt();
                    if (hour % 4 != 0) return const SizedBox.shrink();

                    return SideTitleWidget(
                      meta: meta,
                      fitInside: SideTitleFitInsideData.fromTitleMeta(meta,
                          distanceFromEdge: 0),
                      child: Text(_formatHour(hour),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 10)),
                    );
                  },
                ),
              ),
              leftTitles: const AxisTitles(),
            ),
            borderData: FlBorderData(show: false),
            maxY: maxVal * 1.2,
            minY: 0,
            barGroups: List<BarChartGroupData>.generate(24, (int index) {
              // The API returns 'hour' in the requested local timezone.
              // 'index' represents the local hour (0-23).
              final int searchHour = index;

              // Find if we have a play count for this local hour
              final int count = playsMap[searchHour] ?? 0;
              final bool isTouched = index == touchedIndex;

              return BarChartGroupData(
                x: index,
                barRods: <BarChartRodData>[
                  BarChartRodData(
                    toY: count.toDouble(),
                    color: isTouched ? touchedBarColor : barColor,
                    width: 8,
                    borderSide: isTouched
                        ? BorderSide(
                            color: touchedBarColor.withValues(alpha: 0.8))
                        : const BorderSide(color: Colors.white, width: 0),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxVal * 1.2,
                      color: barBackgroundColor,
                    ),
                  ),
                ],
              );
            }),
            gridData: const FlGridData(show: false),
          ),
        ),
      ),
    );
  }
}

class _ActivityChartIndicator extends StatelessWidget {
  const _ActivityChartIndicator({
    required this.color,
    required this.text,
    required this.isSquare,
    this.size = 16,
    this.textColor,
  });
  final Color color;
  final String text;
  final bool isSquare;
  final double size;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: isSquare ? BoxShape.rectangle : BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: textColor ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _PlatformsPieChart extends StatefulWidget {
  const _PlatformsPieChart({required this.platforms});
  final List<TracearrActivityPlatform> platforms;

  @override
  State<_PlatformsPieChart> createState() => _PlatformsPieChartState();
}

class _PlatformsPieChartState extends State<_PlatformsPieChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.platforms.isEmpty) return const SizedBox.shrink();

    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<Color> colors = <Color>[
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      scheme.error,
      scheme.inversePrimary,
      scheme.primaryContainer,
    ];
    final List<double> radiusValues = <double>[80, 65, 60, 70, 75, 85];

    return AspectRatio(
      aspectRatio: 1.3,
      child: Column(
        children: <Widget>[
          const SizedBox(height: 28),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: widget.platforms
                .asMap()
                .entries
                .map((MapEntry<int, TracearrActivityPlatform> e) {
              final bool isTouched = touchedIndex == e.key;
              return _ActivityChartIndicator(
                color: colors[e.key % colors.length],
                text: '${e.value.platform} (${e.value.count})',
                isSquare: false,
                size: isTouched ? 18 : 16,
                textColor: isTouched
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event,
                        PieTouchResponse? pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          touchedIndex = -1;
                          return;
                        }
                        touchedIndex = pieTouchResponse
                            .touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  startDegreeOffset: 180,
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 1,
                  centerSpaceRadius: 0,
                  sections: widget.platforms
                      .asMap()
                      .entries
                      .map((MapEntry<int, TracearrActivityPlatform> e) {
                    final bool isTouched = e.key == touchedIndex;
                    final double radius =
                        radiusValues[e.key % radiusValues.length];
                    return PieChartSectionData(
                      color: colors[e.key % colors.length],
                      value: e.value.count.toDouble(),
                      title: '',
                      radius: radius,
                      borderSide: isTouched
                          ? const BorderSide(color: Colors.white, width: 6)
                          : BorderSide(
                              color: Colors.white.withValues(alpha: 0)),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QualityPieChart extends StatefulWidget {
  const _QualityPieChart({required this.quality});
  final TracearrActivityQuality quality;

  @override
  State<_QualityPieChart> createState() => _QualityPieChartState();
}

class _QualityPieChartState extends State<_QualityPieChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.quality.total == 0) return const SizedBox.shrink();

    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<Color> colors = <Color>[
      scheme.primary,
      scheme.secondary,
      scheme.tertiary
    ];
    final List<String> labels = <String>[
      'Direct Play',
      'Direct Stream',
      'Transcode'
    ];
    final List<int> counts = <int>[
      widget.quality.directPlay,
      widget.quality.directStream,
      widget.quality.transcode
    ];
    final List<double> radiusValues = <double>[80, 65, 60];

    return AspectRatio(
      aspectRatio: 1.3,
      child: Column(
        children: <Widget>[
          const SizedBox(height: 28),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: List.generate(3, (int i) {
              final bool isTouched = touchedIndex == i;
              return _ActivityChartIndicator(
                color: colors[i],
                text: '${labels[i]} (${counts[i]})',
                isSquare: false,
                size: isTouched ? 18 : 16,
                textColor: isTouched
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
              );
            }),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event,
                        PieTouchResponse? pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          touchedIndex = -1;
                          return;
                        }
                        touchedIndex = pieTouchResponse
                            .touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  startDegreeOffset: 180,
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 1,
                  centerSpaceRadius: 0,
                  sections: List.generate(3, (int i) {
                    final bool isTouched = i == touchedIndex;
                    final double radius = radiusValues[i % radiusValues.length];
                    return PieChartSectionData(
                      color: colors[i],
                      value: counts[i].toDouble(),
                      title: '',
                      radius: radius,
                      borderSide: isTouched
                          ? const BorderSide(color: Colors.white, width: 6)
                          : BorderSide(
                              color: Colors.white.withValues(alpha: 0)),
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConcurrentLineChart extends StatefulWidget {
  const _ConcurrentLineChart({required this.concurrentPlays});
  final List<TracearrActivityConcurrent> concurrentPlays;

  @override
  State<_ConcurrentLineChart> createState() => _ConcurrentLineChartState();
}

class _ConcurrentLineChartState extends State<_ConcurrentLineChart> {
  @override
  Widget build(BuildContext context) {
    if (widget.concurrentPlays.isEmpty) return const SizedBox.shrink();

    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color colorDirect = scheme.primary;
    final Color colorDirectStream = scheme.secondary;
    final Color colorTranscode = scheme.tertiary;

    double maxVal = 0;
    for (final TracearrActivityConcurrent p in widget.concurrentPlays) {
      final int localMax = max(p.direct, max(p.directStream, p.transcode));
      if (localMax > maxVal) maxVal = localMax.toDouble();
    }
    if (maxVal == 0) maxVal = 1;

    Widget legendItem(Color color, String text) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 4),
          Text(text,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      );
    }

    return Column(
      children: <Widget>[
        AspectRatio(
          aspectRatio: 1.70,
          child: Padding(
            padding:
                const EdgeInsets.only(right: 18, left: 12, top: 24, bottom: 12),
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipColor: (_) => Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.9),
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                      return touchedBarSpots.map((LineBarSpot barSpot) {
                        final int index = barSpot.x.toInt();
                        if (index < 0 || index >= widget.concurrentPlays.length)
                          return null;
                        final TracearrActivityConcurrent p =
                            widget.concurrentPlays[index];
                        final String dateStr = p.hour.split('+').first;

                        String label;
                        Color color;
                        if (barSpot.barIndex == 0) {
                          label = 'Direct';
                          color = colorDirect;
                        } else if (barSpot.barIndex == 1) {
                          label = 'Stream';
                          color = colorDirectStream;
                        } else {
                          label = 'Transcode';
                          color = colorTranscode;
                        }

                        final bool isLast = barSpot == touchedBarSpots.last;

                        return LineTooltipItem(
                          '${barSpot.y.toInt()} $label${isLast ? '\n' : ''}',
                          TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                          children: isLast
                              ? <TextSpan>[
                                  TextSpan(
                                    text: dateStr,
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.7),
                                        fontSize: 10,
                                        fontWeight: FontWeight.normal),
                                  ),
                                ]
                              : null,
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(
                  horizontalInterval: max(1, maxVal ~/ 5).toDouble(),
                  verticalInterval: 1,
                  getDrawingHorizontalLine: (double value) {
                    return FlLine(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.2),
                        strokeWidth: 1);
                  },
                  getDrawingVerticalLine: (double value) {
                    return FlLine(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.2),
                        strokeWidth: 1);
                  },
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(),
                  topTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final int index = value.toInt();
                        if (index < 0 || index >= widget.concurrentPlays.length)
                          return const SizedBox.shrink();
                        if (index %
                                max(1, widget.concurrentPlays.length ~/ 5) !=
                            0) return const SizedBox.shrink();
                        final String text = widget.concurrentPlays[index].hour
                            .split(' ')
                            .first
                            .substring(5); // MM-DD
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(text,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 10)),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: max(1, maxVal ~/ 5).toDouble(),
                      reservedSize: 42,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        if (value % 1 != 0) return const SizedBox.shrink();
                        return Text(value.toInt().toString(),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12),
                            textAlign: TextAlign.left);
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.2)),
                ),
                minX: 0,
                maxX: max(0, widget.concurrentPlays.length - 1).toDouble(),
                minY: 0,
                maxY: maxVal * 1.2,
                lineBarsData: <LineChartBarData>[
                  LineChartBarData(
                    spots: widget.concurrentPlays
                        .asMap()
                        .entries
                        .map((MapEntry<int, TracearrActivityConcurrent> e) {
                      return FlSpot(
                          e.key.toDouble(), e.value.direct.toDouble());
                    }).toList(),
                    isCurved: true,
                    preventCurveOverShooting: true,
                    color: colorDirect,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: colorDirect.withValues(alpha: 0.1),
                    ),
                  ),
                  LineChartBarData(
                    spots: widget.concurrentPlays
                        .asMap()
                        .entries
                        .map((MapEntry<int, TracearrActivityConcurrent> e) {
                      return FlSpot(
                          e.key.toDouble(), e.value.directStream.toDouble());
                    }).toList(),
                    isCurved: true,
                    preventCurveOverShooting: true,
                    color: colorDirectStream,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: colorDirectStream.withValues(alpha: 0.1),
                    ),
                  ),
                  LineChartBarData(
                    spots: widget.concurrentPlays
                        .asMap()
                        .entries
                        .map((MapEntry<int, TracearrActivityConcurrent> e) {
                      return FlSpot(
                          e.key.toDouble(), e.value.transcode.toDouble());
                    }).toList(),
                    isCurved: true,
                    preventCurveOverShooting: true,
                    color: colorTranscode,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: colorTranscode.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            legendItem(colorDirect, 'Direct'),
            const SizedBox(width: 16),
            legendItem(colorDirectStream, 'Stream'),
            const SizedBox(width: 16),
            legendItem(colorTranscode, 'Transcode'),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _EngagementSummary extends StatelessWidget {
  const _EngagementSummary(
      {required this.engagement, required this.servers, this.api});
  final TracearrActivityEngagement engagement;
  final Map<String, String> servers;
  final TracearrApi? api;

  @override
  Widget build(BuildContext context) {
    if (engagement.summary.totalPlays == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // 1. High-Level KPI Summary
        Wrap(
          spacing: Insets.md,
          runSpacing: Insets.md,
          alignment: WrapAlignment.center,
          children: <Widget>[
            _StatCard(
                title: 'Total Plays',
                value: engagement.summary.totalPlays.toString()),
            _StatCard(
              title: 'Avg Completion',
              value: '${engagement.summary.avgCompletionRate}%',
              trailing: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  value: engagement.summary.avgCompletionRate / 100,
                  strokeWidth: 3,
                  backgroundColor: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            _StatCard(
              title: 'Session Health',
              value:
                  '${engagement.summary.totalValidSessions} / ${engagement.summary.totalAllSessions}',
            ),
          ],
        ),
        const SizedBox(height: Insets.xl),

        // 2. Engagement Breakdown
        if (engagement.engagementBreakdown.isNotEmpty) ...<Widget>[
          Text('Engagement Breakdown',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: Insets.md),
          _EngagementPieChart(breakdown: engagement.engagementBreakdown),
          const SizedBox(height: Insets.xl),
        ],

        // 3. Audience Personas
        if (engagement.userProfiles.isNotEmpty) ...<Widget>[
          Text('Audience Personas',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: Insets.md),
          _AudiencePersonaTable(
              profiles: engagement.userProfiles, servers: servers, api: api),
          const SizedBox(height: Insets.xl),
        ],

        // 4. Top Performers
        if (engagement.topContent.isNotEmpty ||
            engagement.topShows.isNotEmpty) ...<Widget>[
          Text('Top Performers',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: Insets.md),
          _TopPerformersView(
            topShows: engagement.topShows,
            topContent: engagement.topContent,
            servers: servers,
            api: api,
          ),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value, this.trailing});
  final String title;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Column(
            children: <Widget>[
              Text(title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer
                          .withValues(alpha: 0.7))),
              const SizedBox(height: 4),
              Text(value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer)),
            ],
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: Insets.md),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _EngagementPieChart extends StatefulWidget {
  const _EngagementPieChart({required this.breakdown});
  final List<TracearrEngagementBreakdown> breakdown;

  @override
  State<_EngagementPieChart> createState() => _EngagementPieChartState();
}

class _EngagementPieChartState extends State<_EngagementPieChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.breakdown.isEmpty) return const SizedBox.shrink();

    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<double> radiusValues = <double>[80, 65, 60];

    return AspectRatio(
      aspectRatio: 1.3,
      child: Column(
        children: <Widget>[
          const SizedBox(height: 28),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: widget.breakdown
                .asMap()
                .entries
                .map((MapEntry<int, TracearrEngagementBreakdown> entry) {
              final int index = entry.key;
              final TracearrEngagementBreakdown data = entry.value;
              final bool isTouched = index == touchedIndex;

              Color color;
              if (data.tier == 'watched') {
                color = scheme.primary;
              } else if (data.tier == 'abandoned') {
                color = scheme.error;
              } else {
                color = scheme.secondary;
              }

              return _ActivityChartIndicator(
                color: color,
                text: '${data.tier.toUpperCase()} (${data.count})',
                isSquare: false,
                size: isTouched ? 18 : 16,
                textColor: isTouched
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event,
                        PieTouchResponse? pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          touchedIndex = -1;
                          return;
                        }
                        touchedIndex = pieTouchResponse
                            .touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  startDegreeOffset: 180,
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 1,
                  centerSpaceRadius: 0,
                  sections: widget.breakdown
                      .asMap()
                      .entries
                      .map((MapEntry<int, TracearrEngagementBreakdown> entry) {
                    final int index = entry.key;
                    final TracearrEngagementBreakdown data = entry.value;
                    final bool isTouched = index == touchedIndex;
                    final double radius =
                        radiusValues[index % radiusValues.length];

                    Color color;
                    if (data.tier == 'watched') {
                      color = scheme.primary;
                    } else if (data.tier == 'abandoned') {
                      color = scheme.error;
                    } else {
                      color = scheme.secondary;
                    }

                    return PieChartSectionData(
                      color: color,
                      value: data.percentage,
                      title: '',
                      radius: radius,
                      borderSide: isTouched
                          ? const BorderSide(color: Colors.white, width: 6)
                          : BorderSide(
                              color: Colors.white.withValues(alpha: 0)),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AudiencePersonaTable extends StatelessWidget {
  const _AudiencePersonaTable(
      {required this.profiles, required this.servers, this.api});
  final List<TracearrUserProfile> profiles;
  final Map<String, String> servers;
  final TracearrApi? api;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingTextStyle: const TextStyle(fontWeight: FontWeight.bold),
        columns: const <DataColumn>[
          DataColumn(label: Text('User')),
          DataColumn(label: Text('Profile Type')),
          DataColumn(label: Text('Completion Rate')),
          DataColumn(label: Text('Watch Hours')),
          DataColumn(label: Text('Top Format')),
        ],
        rows: profiles.map((TracearrUserProfile profile) {
          final bool isCompletionist =
              profile.behaviorType?.toLowerCase() == 'completionist';

          String? imageUrl;
          if (profile.thumbUrl != null && api != null) {
            imageUrl = api!.proxyImageUrl(
                serverId: profile.serverId ??
                    (servers.isNotEmpty ? servers.keys.first : null),
                path: profile.thumbUrl,
                width: 32,
                height: 32,
                fallback: 'avatar');
          }

          return DataRow(
            cells: <DataCell>[
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    CircleAvatar(
                      radius: 14,
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHigh,
                      backgroundImage: imageUrl != null
                          ? CachedNetworkImageProvider(imageUrl)
                          : null,
                      child: imageUrl == null
                          ? const Icon(Icons.person, size: 16)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(profile.username),
                  ],
                ),
              ),
              DataCell(
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCompletionist
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    profile.behaviorType ?? 'Unknown',
                    style: TextStyle(
                      color: isCompletionist ? Colors.green : Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              DataCell(Text('${profile.completionRate}%')),
              DataCell(Text('${profile.totalWatchHours} hrs')),
              DataCell(Text(profile.favoriteMediaType ?? 'N/A')),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _TracearrListPoster extends StatelessWidget {
  const _TracearrListPoster({
    this.imageUrl,
    this.fallbackIcon = Icons.movie_outlined,
    this.aspectRatio = 2 / 3,
    this.maxWidth = 80,
    this.maxHeight = 120,
  });

  final String? imageUrl;
  final IconData fallbackIcon;
  final double aspectRatio;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Icon(
                      fallbackIcon,
                      color: theme.colorScheme.outline,
                      size: 28,
                    ),
                  )
                : Icon(
                    fallbackIcon,
                    color: theme.colorScheme.outline,
                    size: 28,
                  ),
          ),
        ),
      ),
    );
  }
}

class _TracearrStatItemRow extends StatelessWidget {
  const _TracearrStatItemRow({
    required this.title,
    required this.subtitle,
    this.trailing,
    this.imageUrl,
    this.fallbackIcon = Icons.movie_outlined,
  });

  final Widget title;
  final Widget subtitle;
  final Widget? trailing;
  final String? imageUrl;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          _TracearrListPoster(
            imageUrl: imageUrl,
            fallbackIcon: fallbackIcon,
            maxWidth: 80,
            maxHeight: 120,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                DefaultTextStyle(
                  style: theme.textTheme.bodyLarge!.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                  child: title,
                ),
                const SizedBox(height: 4),
                DefaultTextStyle(
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  child: subtitle,
                ),
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _TopPerformersView extends StatelessWidget {
  const _TopPerformersView({
    required this.topShows,
    required this.topContent,
    required this.servers,
    this.api,
  });
  final List<TracearrTopShow> topShows;
  final List<TracearrTopContent> topContent;
  final Map<String, String> servers;
  final TracearrApi? api;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 400,
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: <Widget>[
            const TabBar(
              tabs: <Widget>[
                Tab(text: 'Top Shows'),
                Tab(text: 'Top Content'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: <Widget>[
                  // Top Shows Tab
                  ListView.builder(
                    physics: const ClampingScrollPhysics(),
                    itemCount: topShows.length,
                    itemBuilder: (BuildContext context, int index) {
                      final TracearrTopShow show = topShows[index];
                      String? imageUrl;
                      if (show.thumbPath != null && api != null) {
                        imageUrl = api!.proxyImageUrl(
                          serverId: show.serverId,
                          path: show.thumbPath,
                          fallback: 'poster',
                        );
                      }
                      return _TracearrStatItemRow(
                        imageUrl: imageUrl,
                        fallbackIcon: Icons.tv_outlined,
                        title: Text(show.showTitle),
                        subtitle: Text(
                          '${show.totalEpisodeViews} views • ${show.totalWatchHours} hrs',
                        ),
                        trailing: Text(
                          'Score: ${show.bingeScore.toStringAsFixed(1)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
                  // Top Content Tab
                  ListView.builder(
                    physics: const ClampingScrollPhysics(),
                    itemCount: topContent.length,
                    itemBuilder: (BuildContext context, int index) {
                      final TracearrTopContent content = topContent[index];
                      String? imageUrl;
                      if (content.thumbPath != null && api != null) {
                        imageUrl = api!.proxyImageUrl(
                          serverId: content.serverId,
                          path: content.thumbPath,
                          fallback: 'poster',
                        );
                      }
                      return _TracearrStatItemRow(
                        imageUrl: imageUrl,
                        fallbackIcon: Icons.movie_outlined,
                        title: Text(content.title),
                        subtitle: Text(
                          '${content.showTitle ?? 'Movie'} • ${content.totalWatchHours} hrs',
                        ),
                        trailing: Text(
                          '${content.completionRate}% completed',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityStatsView extends ConsumerStatefulWidget {
  const _ActivityStatsView({required this.instance});

  final Instance instance;

  @override
  ConsumerState<_ActivityStatsView> createState() => _ActivityStatsViewState();
}

class _ActivityStatsViewState extends ConsumerState<_ActivityStatsView> {
  String _selectedRange = '30d';
  DateTime? _customFrom;
  DateTime? _customTo;

  final List<String> _ranges = const <String>[
    '7d',
    '30d',
    '1yr',
    'All',
    'Custom',
  ];

  String _getPeriod(String range) {
    switch (range) {
      case '7d':
        return 'week';
      case '1yr':
        return 'year';
      case 'All':
        return 'all';
      case 'Custom':
        return 'custom';
      case '30d':
      default:
        return 'month';
    }
  }

  Future<void> _handleSelect(String range) async {
    if (range == 'Custom') {
      final DateTimeRange? picked = await _showCustomDateRangeDialog(
        context: context,
        initialStart: _customFrom,
        initialEnd: _customTo,
      );
      if (picked != null) {
        setState(() {
          _selectedRange = 'Custom';
          _customFrom = picked.start;
          _customTo = picked.end;
        });
      } else if (_selectedRange != 'Custom') {
        setState(() {
          _selectedRange = 'Custom';
        });
      }
    } else {
      setState(() {
        _selectedRange = range;
        _customFrom = null;
        _customTo = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final TracearrActivityStatsParams params = TracearrActivityStatsParams(
      instance: widget.instance,
      period: _getPeriod(_selectedRange),
      from: _customFrom,
      to: _customTo,
    );
    final AsyncValue<TracearrActivityStats> statsVal =
        ref.watch(tracearrActivityStatsProvider(params));
    final Map<String, String> servers =
        ref.watch(tracearrServersProvider(widget.instance)).value ??
            <String, String>{};
    final TracearrApi? api =
        ref.watch(tracearrApiProvider(widget.instance)).value;

    return Column(
      children: <Widget>[
        const SizedBox(height: Insets.sm),
        SizedBox(
          height: 44,
          child: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (int i = 0; i < _ranges.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(width: Insets.sm),
                    ChoiceChip(
                      label: Text(
                        _ranges[i] == 'Custom' &&
                                _selectedRange == 'Custom' &&
                                _customFrom != null &&
                                _customTo != null
                            ? 'Custom (${_customFrom!.month}/${_customFrom!.day} - ${_customTo!.month}/${_customTo!.day})'
                            : _ranges[i],
                      ),
                      selected: _selectedRange == _ranges[i],
                      onSelected: (_) => _handleSelect(_ranges[i]),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: AsyncValueView<TracearrActivityStats>(
            value: statsVal,
            onRetry: () =>
                ref.invalidate(tracearrActivityStatsProvider(params)),
            data: (TracearrActivityStats data) {
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
                onRefresh: () async {
                  ref.invalidate(tracearrServersProvider(params.instance));
                  ref.invalidate(tracearrActivityStatsProvider(params));
                },
                child: ListView(
                  padding: const EdgeInsets.all(Insets.lg),
                  children: <Widget>[
                    if (data.plays.isNotEmpty)
                      _ChartCard(
                        title: 'Plays Over Time',
                        child: _PlaysLineChart(
                          plays: data.plays,
                          servers: servers,
                        ),
                      ),
                    const SizedBox(height: Insets.lg),
                    if (data.concurrentPlays.isNotEmpty)
                      _ChartCard(
                        title: 'Concurrent Streams',
                        child: _ConcurrentLineChart(
                          concurrentPlays: data.concurrentPlays,
                        ),
                      ),
                    const SizedBox(height: Insets.lg),
                    if (data.playsByDayOfWeek.isNotEmpty)
                      _ChartCard(
                        title: 'Plays by Day of Week',
                        child: _PlaysDowBarChart(plays: data.playsByDayOfWeek),
                      ),
                    const SizedBox(height: Insets.lg),
                    if (data.playsByHourOfDay.isNotEmpty)
                      _ChartCard(
                        title: 'Plays by Hour of Day',
                        child: _PlaysHodBarChart(plays: data.playsByHourOfDay),
                      ),
                    const SizedBox(height: Insets.lg),
                    if (data.quality.total > 0)
                      _ChartCard(
                        title: 'Quality',
                        child: _QualityPieChart(quality: data.quality),
                      ),
                    const SizedBox(height: Insets.lg),
                    if (data.platforms.isNotEmpty)
                      _ChartCard(
                        title: 'Platforms',
                        child: _PlatformsPieChart(platforms: data.platforms),
                      ),
                    const SizedBox(height: Insets.lg),
                    if (data.engagement.summary.totalPlays > 0)
                      _ChartCard(
                        title: 'Engagement',
                        child: _EngagementSummary(
                          engagement: data.engagement,
                          servers: servers,
                          api: api,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WatchStatsView extends ConsumerStatefulWidget {
  const _WatchStatsView({required this.instance});
  final Instance instance;

  @override
  ConsumerState<_WatchStatsView> createState() => _WatchStatsViewState();
}

class _WatchStatsViewState extends ConsumerState<_WatchStatsView> {
  String _selectedPeriod = '30d';
  final List<String> _periods = const <String>['7d', '30d', '90d', '1y', 'all'];

  String _formatWatchMs(int ms) {
    if (ms == 0) return '0 hrs';
    final double hours = ms / (1000 * 60 * 60);
    if (hours >= 24) {
      final double days = hours / 24;
      return '${days.toStringAsFixed(1)} days';
    }
    return '${hours.toStringAsFixed(1)} hrs';
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<TracearrCompletionSummary> completionVal =
        ref.watch(tracearrCompletionSummaryProvider(widget.instance));
    final AsyncValue<TracearrPatternsResponse> patternsVal =
        ref.watch(tracearrPatternsProvider(widget.instance));
    final TracearrLibraryWatchNotifier watchNotifier =
        ref.watch(tracearrLibraryWatchProvider(widget.instance));

    return EasyRefresh(
      header: const ClassicHeader(
        dragText: 'Pull to refresh',
        armedText: 'Release ready',
        readyText: 'Refreshing...',
        processingText: 'Refreshing...',
        processedText: 'Succeeded',
        failedText: 'Failed',
      ),
      onRefresh: () async {
        ref.invalidate(tracearrCompletionSummaryProvider(widget.instance));
        ref.invalidate(tracearrPatternsProvider(widget.instance));
        ref.invalidate(tracearrTopMoviesProvider((instance: widget.instance, period: _selectedPeriod)));
        ref.invalidate(tracearrTopShowsProvider((instance: widget.instance, period: _selectedPeriod)));
        await watchNotifier.refresh();
      },
      child: ListView(
        padding: const EdgeInsets.all(Insets.lg),
        children: <Widget>[
          // Hero Summary Stats Header
          Row(
            children: <Widget>[
              Expanded(
                child: Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    child: Column(
                      children: <Widget>[
                        Icon(Icons.check_circle_outline, size: 28, color: Theme.of(context).colorScheme.onPrimaryContainer),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            watchNotifier.state.value != null
                                ? '${watchNotifier.state.value!.summary.watchedCount}/${watchNotifier.state.value!.summary.totalItems} (${watchNotifier.state.value!.summary.watchedPct.toStringAsFixed(1)}%)'
                                : '0/0 (0%)',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                          ),
                        ),
                        Text(
                          'Watched Ratio',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    child: Column(
                      children: <Widget>[
                        Icon(Icons.schedule, size: 28, color: Theme.of(context).colorScheme.onTertiaryContainer),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            watchNotifier.state.value != null
                                ? _formatWatchMs(watchNotifier.state.value!.summary.totalWatchMs)
                                : '0 hrs',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                                ),
                          ),
                        ),
                        Text(
                          'Total Watch Time',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
          const SizedBox(height: Insets.md),
          Row(
            children: <Widget>[
              Expanded(
                child: Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    child: Column(
                      children: <Widget>[
                        Icon(Icons.task_alt, size: 28, color: Theme.of(context).colorScheme.onSecondaryContainer),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            completionVal.value != null
                                ? completionVal.value!.completedCount.toString()
                                : '0',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                                ),
                          ),
                        ),
                        Text(
                          'Completed Items',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSecondaryContainer,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    child: Column(
                      children: <Widget>[
                        Icon(Icons.trending_up, size: 28, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            patternsVal.value != null
                                ? '${patternsVal.value!.peakTimes.peakHour.toString().padLeft(2, '0')}:00'
                                : '--:--',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                        Text(
                          'Peak Hour',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
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

          // Library Completion Pie Chart
          _ChartCard(
            title: 'Library Completion',
            child: completionVal.when(
              data: (TracearrCompletionSummary data) => _CompletionPieChart(summary: data),
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
              error: (Object err, StackTrace st) => Center(child: Text('Error: $err', style: TextStyle(color: Theme.of(context).colorScheme.error))),
            ),
          ),
          const SizedBox(height: Insets.lg),

          // Top Content Period Selection
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Top Content Period',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              DropdownButton<String>(
                value: _selectedPeriod,
                borderRadius: BorderRadius.circular(12),
                underline: const SizedBox.shrink(),
                items: _periods.map((String p) => DropdownMenuItem<String>(value: p, child: Text(p.toUpperCase()))).toList(),
                onChanged: (String? val) {
                  if (val != null) {
                    setState(() => _selectedPeriod = val);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),

          // Top Movies
          _ChartCard(
            title: 'Top Movies (${_selectedPeriod.toUpperCase()})',
            child: _TopMoviesSection(instance: widget.instance, period: _selectedPeriod),
          ),
          const SizedBox(height: Insets.lg),

          // Top Shows
          _ChartCard(
            title: 'Top TV Shows (${_selectedPeriod.toUpperCase()})',
            child: _TopShowsSection(instance: widget.instance, period: _selectedPeriod),
          ),
          const SizedBox(height: Insets.lg),

          // Binge Highlights
          _ChartCard(
            title: 'Binge Highlights',
            child: patternsVal.when(
              data: (TracearrPatternsResponse data) => _BingeHighlightsSection(instance: widget.instance, shows: data.bingeShows),
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
              error: (Object err, StackTrace st) => Center(child: Text('Error: $err', style: TextStyle(color: Theme.of(context).colorScheme.error))),
            ),
          ),
          const SizedBox(height: Insets.lg),

          // Viewing Hours Distribution
          _ChartCard(
            title: 'Viewing Hours Distribution',
            child: patternsVal.when(
              data: (TracearrPatternsResponse data) => _ViewingHoursBarChart(hourly: data.peakTimes.hourlyDistribution),
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
              error: (Object err, StackTrace st) => Center(child: Text('Error: $err', style: TextStyle(color: Theme.of(context).colorScheme.error))),
            ),
          ),
          const SizedBox(height: Insets.lg),

          // Monthly Trends
          _ChartCard(
            title: 'Monthly Watch Trends',
            child: patternsVal.when(
              data: (TracearrPatternsResponse data) => _MonthlyTrendsChart(trends: data.seasonalTrends.monthlyTrends),
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
              error: (Object err, StackTrace st) => Center(child: Text('Error: $err', style: TextStyle(color: Theme.of(context).colorScheme.error))),
            ),
          ),
          const SizedBox(height: Insets.lg),

          // Paginated Library Watch Items
          _ChartCard(
            title: 'Library Watch History',
            child: _LibraryWatchListSection(instance: widget.instance),
          ),
          const SizedBox(height: Insets.xl),
        ],
      ),
    );
  }
}

class _CompletionPieChart extends StatefulWidget {
  const _CompletionPieChart({required this.summary});
  final TracearrCompletionSummary summary;

  @override
  State<_CompletionPieChart> createState() => _CompletionPieChartState();
}

class _CompletionPieChartState extends State<_CompletionPieChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final int completed = widget.summary.completedCount;
    final int inProgress = widget.summary.inProgressCount;
    final int notStarted = widget.summary.notStartedCount;

    if (completed == 0 && inProgress == 0 && notStarted == 0) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(child: Text('No library completion statistics found.')),
      );
    }

    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<Color> colors = <Color>[
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
    ];
    final List<String> labels = <String>[
      'Completed',
      'In Progress',
      'Not Started',
    ];
    final List<int> counts = <int>[completed, inProgress, notStarted];
    final List<double> radiusValues = <double>[80, 65, 60];

    final List<Color> validColors = <Color>[];
    final List<String> validLabels = <String>[];
    final List<int> validCounts = <int>[];

    for (int i = 0; i < 3; i++) {
      if (counts[i] > 0) {
        validColors.add(colors[i]);
        validLabels.add(labels[i]);
        validCounts.add(counts[i]);
      }
    }

    return AspectRatio(
      aspectRatio: 1.3,
      child: Column(
        children: <Widget>[
          const SizedBox(height: 28),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: List<Widget>.generate(validCounts.length, (int i) {
              final bool isTouched = touchedIndex == i;
              return _ActivityChartIndicator(
                color: validColors[i],
                text: '${validLabels[i]} (${validCounts[i]})',
                isSquare: false,
                size: isTouched ? 18 : 16,
                textColor: isTouched
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
              );
            }),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (
                      FlTouchEvent event,
                      PieTouchResponse? pieTouchResponse,
                    ) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          touchedIndex = -1;
                          return;
                        }
                        touchedIndex = pieTouchResponse
                            .touchedSection!
                            .touchedSectionIndex;
                      });
                    },
                  ),
                  startDegreeOffset: 180,
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 1,
                  centerSpaceRadius: 0,
                  sections: List<PieChartSectionData>.generate(
                    validCounts.length,
                    (int i) {
                      final bool isTouched = i == touchedIndex;
                      final double radius =
                          radiusValues[i % radiusValues.length];
                      return PieChartSectionData(
                        color: validColors[i],
                        value: validCounts[i].toDouble(),
                        title: '',
                        radius: radius,
                        borderSide: isTouched
                            ? const BorderSide(color: Colors.white, width: 6)
                            : BorderSide(
                                color: Colors.white.withValues(alpha: 0),
                              ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopMoviesSection extends ConsumerWidget {
  const _TopMoviesSection({required this.instance, required this.period});
  final Instance instance;
  final String period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TracearrTopMoviesResponse> val = ref.watch(tracearrTopMoviesProvider((instance: instance, period: period)));
    final AsyncValue<TracearrApi> apiVal = ref.watch(tracearrApiProvider(instance));

    return val.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
      error: (Object err, StackTrace st) => Center(child: Text('Error: $err', style: TextStyle(color: Theme.of(context).colorScheme.error))),
      data: (TracearrTopMoviesResponse data) {
        if (data.items.isEmpty) {
          return const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No movies watched in this period.')));
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: data.items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (BuildContext context, int index) {
            final TracearrTopMovieItem movie = data.items[index];
            String? posterUrl;
            if (movie.thumbPath != null &&
                apiVal.value != null &&
                movie.serverId.isNotEmpty) {
              posterUrl = apiVal.value!.proxyImageUrl(
                serverId: movie.serverId,
                path: movie.thumbPath,
                fallback: 'poster',
              );
            }
            return _TracearrStatItemRow(
              imageUrl: posterUrl,
              fallbackIcon: Icons.movie_outlined,
              title: Text(
                '${index + 1}. ${movie.title} (${movie.year})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${movie.totalPlays} plays • ${movie.totalWatchHours.toStringAsFixed(1)} hrs • ${movie.uniqueViewers} viewers',
              ),
              trailing: Chip(
                label: Text(
                  '${movie.completionRate.toStringAsFixed(0)}% Done',
                  style: const TextStyle(fontSize: 11),
                ),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                side: BorderSide.none,
              ),
            );
          },
        );
      },
    );
  }
}

class _TopShowsSection extends ConsumerWidget {
  const _TopShowsSection({required this.instance, required this.period});
  final Instance instance;
  final String period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TracearrTopShowsResponse> val =
        ref.watch(tracearrTopShowsProvider((instance: instance, period: period)));
    final AsyncValue<TracearrApi> apiVal =
        ref.watch(tracearrApiProvider(instance));

    return val.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (Object err, StackTrace st) => Center(
        child: Text(
          'Error: $err',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
      data: (TracearrTopShowsResponse data) {
        if (data.items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No TV shows watched in this period.')),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: data.items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (BuildContext context, int index) {
            final TracearrTopShowItem show = data.items[index];
            String? posterUrl;
            if (show.thumbPath != null &&
                apiVal.value != null &&
                show.serverId.isNotEmpty) {
              posterUrl = apiVal.value!.proxyImageUrl(
                serverId: show.serverId,
                path: show.thumbPath,
                fallback: 'poster',
              );
            }
            return _TracearrStatItemRow(
              imageUrl: posterUrl,
              fallbackIcon: Icons.tv_outlined,
              title: Text(
                '${index + 1}. ${show.showTitle} (${show.year})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${show.totalEpisodeViews} ep views • ${show.totalWatchHours.toStringAsFixed(1)} hrs',
              ),
              trailing: Chip(
                label: Text(
                  'Binge: ${show.bingeScore.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor:
                    Theme.of(context).colorScheme.secondaryContainer,
                side: BorderSide.none,
              ),
            );
          },
        );
      },
    );
  }
}

class _BingeHighlightsSection extends ConsumerWidget {
  const _BingeHighlightsSection({required this.instance, required this.shows});
  final Instance instance;
  final List<TracearrBingeShow> shows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TracearrApi> apiVal =
        ref.watch(tracearrApiProvider(instance));

    if (shows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('No binge viewing highlights recorded.')),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: shows.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (BuildContext context, int index) {
        final TracearrBingeShow show = shows[index];
        String? posterUrl;
        if (show.thumbPath != null &&
            apiVal.value != null &&
            show.primaryServerId.isNotEmpty) {
          posterUrl = apiVal.value!.proxyImageUrl(
            serverId: show.primaryServerId,
            path: show.thumbPath,
            fallback: 'poster',
          );
        }
        return _TracearrStatItemRow(
          imageUrl: posterUrl,
          fallbackIcon: Icons.tv_outlined,
          title: Text(
            show.showTitle,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '${show.consecutiveEpisodes} consecutive eps (${show.consecutivePct.toStringAsFixed(0)}% binge)\nAvg interval: ${show.avgGapMinutes.toStringAsFixed(1)} mins • Max/day: ${show.maxEpisodesInOneDay}',
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('🔥 ${show.bingeScore.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onTertiaryContainer)),
          ),
        );
      },
    );
  }
}

class _ViewingHoursBarChart extends StatefulWidget {
  const _ViewingHoursBarChart({required this.hourly});
  final List<TracearrHourlyDistribution> hourly;

  @override
  State<_ViewingHoursBarChart> createState() => _ViewingHoursBarChartState();
}

class _ViewingHoursBarChartState extends State<_ViewingHoursBarChart> {
  int touchedIndex = -1;

  String _formatHour(int hour) {
    if (hour == 0) return '12am';
    if (hour < 12) return '${hour}am';
    if (hour == 12) return '12pm';
    return '${hour - 12}pm';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hourly.isEmpty) {
      return const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No hourly viewing data found.')));
    }

    double maxVal = 0;
    for (final TracearrHourlyDistribution p in widget.hourly) {
      if (p.watchCount > maxVal) maxVal = p.watchCount.toDouble();
    }
    if (maxVal == 0) maxVal = 1;

    final Color barBackgroundColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1);
    final Color barColor = Theme.of(context).colorScheme.primary;
    final Color touchedBarColor = Theme.of(context).colorScheme.secondary;

    final Map<int, int> playsMap = <int, int>{
      for (final TracearrHourlyDistribution p in widget.hourly) p.hour: p.watchCount,
    };

    return AspectRatio(
      aspectRatio: 1.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: BarChart(
          BarChartData(
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipColor: (_) => Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
                getTooltipItem: (BarChartGroupData group, int groupIndex, BarChartRodData rod, int rodIndex) {
                  return BarTooltipItem(
                    '${_formatHour(group.x.toInt())}\n${rod.toY.toInt()} watches',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  );
                },
              ),
              touchCallback: (FlTouchEvent event, BarTouchResponse? barTouchResponse) {
                setState(() {
                  if (!event.isInterestedForInteractions || barTouchResponse == null || barTouchResponse.spot == null) {
                    touchedIndex = -1;
                    return;
                  }
                  touchedIndex = barTouchResponse.spot!.touchedBarGroupIndex;
                });
              },
            ),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(),
              topTitles: const AxisTitles(),
              leftTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    final int hour = value.toInt();
                    if (hour % 4 != 0) return const SizedBox.shrink();
                    return SideTitleWidget(
                      meta: meta,
                      space: 6,
                      fitInside: SideTitleFitInsideData.fromTitleMeta(meta, distanceFromEdge: 0),
                      child: Text(_formatHour(hour), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            maxY: maxVal * 1.2,
            minY: 0,
            barGroups: List<BarChartGroupData>.generate(24, (int index) {
              final int count = playsMap[index] ?? 0;
              final bool isTouched = index == touchedIndex;
              return BarChartGroupData(
                x: index,
                barRods: <BarChartRodData>[
                  BarChartRodData(
                    toY: count.toDouble(),
                    color: isTouched ? touchedBarColor : barColor,
                    width: 8,
                    borderSide: isTouched ? BorderSide(color: touchedBarColor.withValues(alpha: 0.8)) : const BorderSide(color: Colors.white, width: 0),
                    backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxVal * 1.2, color: barBackgroundColor),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _MonthlyTrendsChart extends StatelessWidget {
  const _MonthlyTrendsChart({required this.trends});
  final List<TracearrMonthlyTrend> trends;

  @override
  Widget build(BuildContext context) {
    if (trends.isEmpty) {
      return const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No monthly trend statistics found.')));
    }

    double maxVal = 0;
    for (final TracearrMonthlyTrend t in trends) {
      if (t.watchCount > maxVal) maxVal = t.watchCount.toDouble();
    }
    if (maxVal == 0) maxVal = 1;

    final Color color = Theme.of(context).colorScheme.primary;

    return AspectRatio(
      aspectRatio: 1.6,
      child: Padding(
        padding: const EdgeInsets.only(right: 18, left: 12, top: 24, bottom: 12),
        child: LineChart(
          LineChartData(
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipColor: (_) => Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
                getTooltipItems: (List<LineBarSpot> touchedSpots) {
                  return touchedSpots.map((LineBarSpot spot) {
                    final int index = spot.x.toInt();
                    if (index < 0 || index >= trends.length) return null;
                    final TracearrMonthlyTrend t = trends[index];
                    return LineTooltipItem(
                      '${t.month}\n${t.watchCount} watches\n(${((t.totalWatchMs) / (1000 * 3600)).toStringAsFixed(1)} hrs)',
                      TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                    );
                  }).toList();
                },
              ),
            ),
            gridData: FlGridData(
              horizontalInterval: max(1, maxVal ~/ 4).toDouble(),
              getDrawingHorizontalLine: (double val) => FlLine(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2), strokeWidth: 1),
              getDrawingVerticalLine: (_) => FlLine(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2), strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(),
              topTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  interval: max(1, maxVal ~/ 4).toDouble(),
                  getTitlesWidget: (double val, TitleMeta meta) => SideTitleWidget(meta: meta, space: 6, child: Text(val.toInt().toString(), style: const TextStyle(fontSize: 10))),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (double val, TitleMeta meta) {
                    final int idx = val.toInt();
                    if (idx < 0 || idx >= trends.length) return const SizedBox.shrink();
                    return SideTitleWidget(meta: meta, space: 6, child: Text(trends[idx].month, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)));
                  },
                ),
              ),
            ),
            borderData: FlBorderData(border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outline), left: BorderSide(color: Theme.of(context).colorScheme.outline))),
            maxX: (trends.length - 1).toDouble().clamp(0, double.infinity),
            minX: 0,
            maxY: maxVal * 1.15,
            minY: 0,
            lineBarsData: <LineChartBarData>[
              LineChartBarData(
                spots: List<FlSpot>.generate(trends.length, (int i) => FlSpot(i.toDouble(), trends[i].watchCount.toDouble())),
                isCurved: true,
                color: color,
                barWidth: 3,
                isStrokeCapRound: true,
                belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.15)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LibraryWatchListSection extends ConsumerStatefulWidget {
  const _LibraryWatchListSection({required this.instance});
  final Instance instance;

  @override
  ConsumerState<_LibraryWatchListSection> createState() => _LibraryWatchListSectionState();
}

class _LibraryWatchListSectionState extends ConsumerState<_LibraryWatchListSection> {
  void _showWatchPageDialog(BuildContext context, TracearrLibraryWatchNotifier notifier, int totalPages) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Page'),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 60,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.2,
              ),
              itemCount: totalPages,
              itemBuilder: (BuildContext context, int index) {
                final int p = index + 1;
                final bool isCurrent = p == notifier.page;
                return InkWell(
                  onTap: () {
                    notifier.setPage(p);
                    Navigator.of(context).pop();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$p',
                      style: TextStyle(
                        color: isCurrent
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  IconData _getMediaIcon(String type) {
    switch (type.toLowerCase()) {
      case 'track':
      case 'music':
        return Icons.music_note_outlined;
      case 'episode':
        return Icons.tv_outlined;
      case 'movie':
      default:
        return Icons.movie_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final TracearrLibraryWatchNotifier notifier = ref.watch(tracearrLibraryWatchProvider(widget.instance));

    return notifier.state.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
      error: (Object error, StackTrace stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: <Widget>[
              Text('Failed to load library watch items: $error', style: TextStyle(color: Theme.of(context).colorScheme.error), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: notifier.refresh, child: const Text('Retry')),
            ],
          ),
        ),
      ),
      data: (TracearrLibraryWatchResponse data) {
        if (data.items.isEmpty) {
          return const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No library watch history items found.')));
        }
        final int totalPages = (data.pagination.total + notifier.pageSize - 1) ~/ notifier.pageSize;

        return Column(
          children: <Widget>[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: data.items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (BuildContext context, int index) {
                final TracearrLibraryWatchItem item = data.items[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Icon(_getMediaIcon(item.mediaType), color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${item.serverName} • Watched ${item.watchCount}x • ${((item.totalWatchMs) / (1000 * 60)).toStringAsFixed(0)} mins total'),
                  trailing: Text(item.mediaType.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                );
              },
            ),
            const SizedBox(height: Insets.md),
            // Pagination controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: notifier.page > 1 ? notifier.previousPage : null,
                ),
                const SizedBox(width: Insets.md),
                ActionChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text('Page ${notifier.page} of $totalPages'),
                      if (totalPages > 1) ...<Widget>[
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, size: 18),
                      ],
                    ],
                  ),
                  onPressed: totalPages > 1 ? () => _showWatchPageDialog(context, notifier, totalPages) : null,
                ),
                const SizedBox(width: Insets.md),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: (notifier.page * notifier.pageSize) < data.pagination.total ? notifier.nextPage : null,
                ),
              ],
            ),
            const SizedBox(height: Insets.sm),
          ],
        );
      },
    );
  }
}

class _LibraryCompositionPieChart extends StatefulWidget {
  const _LibraryCompositionPieChart({
    required this.movieCount,
    required this.showCount,
    required this.episodeCount,
  });

  final int movieCount;
  final int showCount;
  final int episodeCount;

  @override
  State<_LibraryCompositionPieChart> createState() =>
      _LibraryCompositionPieChartState();
}

class _LibraryCompositionPieChartState
    extends State<_LibraryCompositionPieChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.movieCount == 0 &&
        widget.showCount == 0 &&
        widget.episodeCount == 0) {
      return const SizedBox.shrink();
    }

    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<Color> colors = <Color>[
      scheme.primary,
      scheme.secondary,
      scheme.tertiary
    ];
    final List<String> labels = <String>['Movies', 'Shows', 'Episodes'];
    final List<int> counts = <int>[
      widget.movieCount,
      widget.showCount,
      widget.episodeCount
    ];
    final List<double> radiusValues = <double>[80, 65, 60];

    final List<Color> validColors = <Color>[];
    final List<String> validLabels = <String>[];
    final List<int> validCounts = <int>[];

    for (int i = 0; i < 3; i++) {
      if (counts[i] > 0) {
        validColors.add(colors[i]);
        validLabels.add(labels[i]);
        validCounts.add(counts[i]);
      }
    }

    return AspectRatio(
      aspectRatio: 1.3,
      child: Column(
        children: <Widget>[
          const SizedBox(height: 28),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: List.generate(validCounts.length, (int i) {
              final bool isTouched = touchedIndex == i;
              return _ActivityChartIndicator(
                color: validColors[i],
                text: '${validCounts[i]} ${validLabels[i]}',
                isSquare: false,
                size: isTouched ? 18 : 16,
                textColor: isTouched
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
              );
            }),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event,
                        PieTouchResponse? pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          touchedIndex = -1;
                          return;
                        }
                        touchedIndex = pieTouchResponse
                            .touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  startDegreeOffset: 180,
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 1,
                  centerSpaceRadius: 0,
                  sections: List.generate(validCounts.length, (int i) {
                    final bool isTouched = i == touchedIndex;
                    final double radius = radiusValues[i % radiusValues.length];
                    return PieChartSectionData(
                      color: validColors[i],
                      value: validCounts[i].toDouble(),
                      title: '',
                      radius: radius,
                      borderSide: isTouched
                          ? const BorderSide(color: Colors.white, width: 6)
                          : BorderSide(
                              color: Colors.white.withValues(alpha: 0)),
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StorageQualityBarChart extends StatefulWidget {
  const _StorageQualityBarChart({
    required this.count4k,
    required this.count1080p,
    required this.count720p,
    required this.countSd,
  });

  final int count4k;
  final int count1080p;
  final int count720p;
  final int countSd;

  @override
  State<_StorageQualityBarChart> createState() =>
      _StorageQualityBarChartState();
}

class _StorageQualityBarChartState extends State<_StorageQualityBarChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<String, int>> items = <MapEntry<String, int>>[];
    if (widget.count4k > 0)
      items.add(MapEntry<String, int>('4K', widget.count4k));
    if (widget.count1080p > 0)
      items.add(MapEntry<String, int>('1080p', widget.count1080p));
    if (widget.count720p > 0)
      items.add(MapEntry<String, int>('720p', widget.count720p));
    if (widget.countSd > 0)
      items.add(MapEntry<String, int>('SD', widget.countSd));

    if (items.isEmpty) return const SizedBox.shrink();

    double maxVal = 0;
    for (final MapEntry<String, int> p in items) {
      if (p.value > maxVal) maxVal = p.value.toDouble();
    }
    if (maxVal == 0) maxVal = 1;

    final Color barBackgroundColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1);
    final Color barColor = Theme.of(context).colorScheme.primary;
    final Color touchedBarColor = Theme.of(context).colorScheme.secondary;

    return AspectRatio(
      aspectRatio: 1.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: BarChart(
          BarChartData(
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipColor: (_) => Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.9),
                tooltipHorizontalAlignment: FLHorizontalAlignment.center,
                tooltipMargin: 8,
                getTooltipItem: (BarChartGroupData group, int groupIndex,
                    BarChartRodData rod, int rodIndex) {
                  return BarTooltipItem(
                    '${items[groupIndex].key}\n',
                    const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                    children: <TextSpan>[
                      TextSpan(
                        text: items[groupIndex].value.toString(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  );
                },
              ),
              touchCallback:
                  (FlTouchEvent event, BarTouchResponse? barTouchResponse) {
                setState(() {
                  if (!event.isInterestedForInteractions ||
                      barTouchResponse == null ||
                      barTouchResponse.spot == null) {
                    touchedIndex = -1;
                    return;
                  }
                  touchedIndex = barTouchResponse.spot!.touchedBarGroupIndex;
                });
              },
            ),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(),
              topTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 38,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    final int index = value.toInt();
                    if (index < 0 || index >= items.length)
                      return const SizedBox.shrink();
                    return SideTitleWidget(
                      meta: meta,
                      space: 16,
                      child: Text(items[index].key,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12)),
                    );
                  },
                ),
              ),
              leftTitles: const AxisTitles(),
            ),
            borderData: FlBorderData(show: false),
            barGroups: items
                .asMap()
                .entries
                .map((MapEntry<int, MapEntry<String, int>> e) {
              final bool isTouched = e.key == touchedIndex;
              return BarChartGroupData(
                x: e.key,
                barRods: <BarChartRodData>[
                  BarChartRodData(
                    toY: e.value.value.toDouble(),
                    color: isTouched ? touchedBarColor : barColor,
                    width: 22,
                    borderSide: isTouched
                        ? BorderSide(
                            color: touchedBarColor.withValues(alpha: 0.8))
                        : const BorderSide(color: Colors.white, width: 0),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxVal * 1.2,
                      color: barBackgroundColor,
                    ),
                  ),
                ],
              );
            }).toList(),
            gridData: const FlGridData(show: false),
          ),
        ),
      ),
    );
  }
}

class _StorageStatsView extends ConsumerStatefulWidget {
  const _StorageStatsView({required this.instance});

  final Instance instance;

  @override
  ConsumerState<_StorageStatsView> createState() => _StorageStatsViewState();
}

class _StorageStatsViewState extends ConsumerState<_StorageStatsView> {
  String _selectedRange = '30d';
  DateTime? _customFrom;
  DateTime? _customTo;

  final List<String> _ranges = const <String>[
    '7d',
    '30d',
    '1yr',
    'All',
    'Custom',
  ];

  String _getPeriod(String range) {
    switch (range) {
      case '7d':
        return 'week';
      case '1yr':
        return 'year';
      case 'All':
        return 'all';
      case 'Custom':
        return 'custom';
      case '30d':
      default:
        return 'month';
    }
  }

  Future<void> _handleSelect(String range) async {
    if (range == 'Custom') {
      final DateTimeRange? picked = await _showCustomDateRangeDialog(
        context: context,
        initialStart: _customFrom,
        initialEnd: _customTo,
      );
      if (picked != null) {
        setState(() {
          _selectedRange = 'Custom';
          _customFrom = picked.start;
          _customTo = picked.end;
        });
      } else if (_selectedRange != 'Custom') {
        setState(() {
          _selectedRange = 'Custom';
        });
      }
    } else {
      setState(() {
        _selectedRange = range;
        _customFrom = null;
        _customTo = null;
      });
    }
  }

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
  Widget build(BuildContext context) {
    final TracearrStatsFilterParams params = TracearrStatsFilterParams(
      instance: widget.instance,
      period: _getPeriod(_selectedRange),
      from: _customFrom,
      to: _customTo,
    );
    final AsyncValue<TracearrStats> statsVal =
        ref.watch(tracearrStatsProvider(params));

    return Column(
      children: <Widget>[
        const SizedBox(height: Insets.sm),
        SizedBox(
          height: 44,
          child: Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (int i = 0; i < _ranges.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(width: Insets.sm),
                    ChoiceChip(
                      label: Text(
                        _ranges[i] == 'Custom' &&
                                _selectedRange == 'Custom' &&
                                _customFrom != null &&
                                _customTo != null
                            ? 'Custom (${_customFrom!.month}/${_customFrom!.day} - ${_customTo!.month}/${_customTo!.day})'
                            : _ranges[i],
                      ),
                      selected: _selectedRange == _ranges[i],
                      onSelected: (_) => _handleSelect(_ranges[i]),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: AsyncValueView<TracearrStats>(
            value: statsVal,
            onRetry: () {
              ref.invalidate(tracearrServersProvider(params.instance));
              ref.invalidate(tracearrStatsProvider(params));
            },
            data: (TracearrStats data) {
              final bool hasQualityData = data.qualityBreakdown != null &&
                  (data.qualityBreakdown!.count4k +
                          data.qualityBreakdown!.count1080p +
                          data.qualityBreakdown!.count720p +
                          data.qualityBreakdown!.countSd) >
                      0;

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
                onRefresh: () async {
                  ref.invalidate(tracearrServersProvider(params.instance));
                  ref.invalidate(tracearrStatsProvider(params));
                  ref.invalidate(tracearrStorageGrowthProvider(params));
                },
                child: ListView(
                  padding: const EdgeInsets.all(Insets.lg),
                  children: <Widget>[
                    // Hero section: Totals
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Card(
                            elevation: 0,
                            margin: EdgeInsets.zero,
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 24, horizontal: 16),
                              child: Column(
                                children: <Widget>[
                                  Icon(Icons.storage_outlined,
                                      size: 32,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer),
                                  const SizedBox(height: 8),
                                  Text(
                                    data.totalItems.toString(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimaryContainer,
                                        ),
                                  ),
                                  Text(
                                    'Total Items',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimaryContainer,
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
                            color:
                                Theme.of(context).colorScheme.tertiaryContainer,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 24, horizontal: 8),
                              child: Column(
                                children: <Widget>[
                                  Icon(Icons.sd_storage_outlined,
                                      size: 32,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onTertiaryContainer),
                                  const SizedBox(height: 8),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      _formatBytes(data.totalSizeBytes),
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onTertiaryContainer,
                                          ),
                                    ),
                                  ),
                                  Text(
                                    'Total Size',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onTertiaryContainer,
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
                    _ChartCard(
                      title: 'Library Composition',
                      child: _LibraryCompositionPieChart(
                        movieCount: data.movieCount,
                        showCount: data.showCount,
                        episodeCount: data.episodeCount,
                      ),
                    ),
                    const SizedBox(height: Insets.lg),

                    // Quality Breakdown (BarChart)
                    if (hasQualityData) ...<Widget>[
                      _ChartCard(
                        title: 'Quality Breakdown',
                        child: _StorageQualityBarChart(
                          count4k: data.qualityBreakdown!.count4k,
                          count1080p: data.qualityBreakdown!.count1080p,
                          count720p: data.qualityBreakdown!.count720p,
                          countSd: data.qualityBreakdown!.countSd,
                        ),
                      ),
                      const SizedBox(height: Insets.lg),
                    ],
                    _StorageGrowthSection(params: params),
                    const SizedBox(height: Insets.lg),
                    _StorageRoiSection(instance: widget.instance),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StorageGrowthSection extends ConsumerWidget {
  const _StorageGrowthSection({required this.params});

  final TracearrStatsFilterParams params;

  String _formatNumBytes(double bytes) {
    if (bytes == 0) return '0 B';
    const List<String> suffixes = <String>['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    int i = 0;
    double val = bytes;
    while (val >= 1024 && i < suffixes.length - 1) {
      val /= 1024;
      i++;
    }
    return '${val.toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Map<String, TracearrStorageResponse>> val =
        ref.watch(tracearrStorageGrowthProvider(params));
    final Map<String, String> servers =
        ref.watch(tracearrServersProvider(params.instance)).value ??
            <String, String>{};

    return AsyncValueView<Map<String, TracearrStorageResponse>>(
      value: val,
      onRetry: () => ref.invalidate(tracearrStorageGrowthProvider(params)),
      data: (Map<String, TracearrStorageResponse> data) {
        if (data.isEmpty) return const SizedBox.shrink();
        final TracearrStorageResponse aggregated =
            TracearrStorageResponse.aggregate(data.values.toList());

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: _GrowthRateCard(
                    title: 'Daily Growth',
                    value:
                        '+${_formatNumBytes(aggregated.growthRate.bytesPerDay)}/d',
                    icon: Icons.trending_up,
                    color: Theme.of(context).colorScheme.primaryContainer,
                    onColor: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: _GrowthRateCard(
                    title: 'Weekly Growth',
                    value:
                        '+${_formatNumBytes(aggregated.growthRate.bytesPerWeek)}/w',
                    icon: Icons.calendar_view_week,
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    onColor: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: _GrowthRateCard(
                    title: 'Monthly Growth',
                    value:
                        '+${_formatNumBytes(aggregated.growthRate.bytesPerMonth)}/m',
                    icon: Icons.date_range,
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    onColor: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                ),
              ],
            ),
            if (params.period.toLowerCase() != 'all') ...<Widget>[
              const SizedBox(height: Insets.lg),
              _ChartCard(
                title: 'Storage Growth & Predictive Forecast',
                child: _StorageGrowthCharts(
                  serverData: data,
                  servers: servers,
                  formatNumBytes: _formatNumBytes,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _StorageGrowthCharts extends StatefulWidget {
  const _StorageGrowthCharts({
    required this.serverData,
    required this.servers,
    required this.formatNumBytes,
  });
  final Map<String, TracearrStorageResponse> serverData;
  final Map<String, String> servers;
  final String Function(double) formatNumBytes;

  @override
  State<_StorageGrowthCharts> createState() => _StorageGrowthChartsState();
}

class _StorageGrowthChartsState extends State<_StorageGrowthCharts> {
  bool _showMore = false;

  @override
  Widget build(BuildContext context) {
    final List<String> serverIds = widget.serverData.keys.toList();
    if (serverIds.isEmpty) return const SizedBox.shrink();

    final Map<String, Color> serverColors = <String, Color>{};
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<Color> availableColors = <Color>[
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      scheme.error,
      scheme.inversePrimary,
      scheme.primaryContainer,
      scheme.secondaryContainer,
      scheme.tertiaryContainer,
      scheme.surfaceTint,
      scheme.outline,
    ];
    for (int i = 0; i < serverIds.length; i++) {
      serverColors[serverIds[i]] = availableColors[i % availableColors.length];
    }

    Widget buildSingleServerChart(String serverId, Color color) {
      final TracearrStorageResponse data = widget.serverData[serverId]!;
      final String serverName = widget.servers[serverId] ??
          (serverId.length > 8 ? serverId.substring(0, 8) : serverId);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (serverIds.length > 1) ...<Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 6),
                Text(
                  serverName,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: Insets.md),
          ],
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              Chip(
                avatar: Icon(Icons.psychology_outlined,
                    size: 16, color: Theme.of(context).colorScheme.primary),
                label: Text(
                  '${data.predictions.confidence.toUpperCase()} CONFIDENCE (${data.predictions.currentDataDays}d sample)',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              Chip(
                label: Text(
                    '30-Day Est: ${widget.formatNumBytes(data.predictions.day30.predicted)}'),
              ),
              Chip(
                label: Text(
                    '90-Day Est: ${widget.formatNumBytes(data.predictions.day90.predicted)}'),
              ),
              Chip(
                label: Text(
                    '1-Year Est: ${widget.formatNumBytes(data.predictions.day365.predicted)}'),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          _StorageGrowthLineChart(response: data),
          const SizedBox(height: Insets.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _StorageGrowthLegendItem(
                  color: Theme.of(context).colorScheme.primary,
                  label: 'Historical'),
              const SizedBox(width: 16),
              _StorageGrowthLegendItem(
                  color: Theme.of(context).colorScheme.secondary,
                  label: 'Predicted (Dotted)'),
              const SizedBox(width: 16),
              _StorageGrowthLegendItem(
                  color: Theme.of(context).colorScheme.tertiary,
                  label: 'Min/Max Range'),
            ],
          ),
        ],
      );
    }

    final String firstServerId = serverIds.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        buildSingleServerChart(firstServerId, serverColors[firstServerId]!),
        if (serverIds.length > 1) ...<Widget>[
          if (_showMore)
            for (int i = 1; i < serverIds.length; i++) ...<Widget>[
              const SizedBox(height: Insets.lg),
              const Divider(height: 1),
              const SizedBox(height: Insets.lg),
              buildSingleServerChart(serverIds[i], serverColors[serverIds[i]]!),
            ],
          const SizedBox(height: Insets.md),
          Center(
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _showMore = !_showMore;
                });
              },
              icon: Icon(_showMore ? Icons.expand_less : Icons.expand_more),
              label: Text(_showMore ? 'Show Less' : 'Show More'),
            ),
          ),
        ],
      ],
    );
  }
}

class _GrowthRateCard extends StatelessWidget {
  const _GrowthRateCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.onColor,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 24, color: onColor),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: onColor,
                    ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: onColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _StorageGrowthLegendItem extends StatelessWidget {
  const _StorageGrowthLegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(width: 12, height: 4, color: color),
        const SizedBox(width: 6),
        Text(label,
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
      ],
    );
  }
}

class _StorageGrowthLineChart extends StatelessWidget {
  const _StorageGrowthLineChart({required this.response});

  final TracearrStorageResponse response;

  @override
  Widget build(BuildContext context) {
    final List<TracearrStorageHistoryItem> hist = response.history;
    final Map<int, String> labelsMap = <int, String>{};
    final List<FlSpot> histSpots = <FlSpot>[];
    final List<FlSpot> predSpots = <FlSpot>[];
    final List<FlSpot> minSpots = <FlSpot>[];
    final List<FlSpot> maxSpots = <FlSpot>[];

    double minY = double.infinity;
    double maxY = 0.0;
    const double gbDivisor = 1073741824.0;

    for (int i = 0; i < hist.length; i++) {
      final double x = i.toDouble();
      final double y = hist[i].totalSizeBytes / gbDivisor;
      histSpots.add(FlSpot(x, y));
      labelsMap[i] = hist[i].day;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }

    final int lastIdx = hist.isEmpty ? 0 : hist.length - 1;
    final double startY = hist.isEmpty
        ? (response.current.totalSizeBytes / gbDivisor)
        : (hist.last.totalSizeBytes / gbDivisor);
    final String startLabel = hist.isEmpty ? 'Today' : hist.last.day;

    if (histSpots.isEmpty) {
      histSpots.add(FlSpot(0.0, startY));
      labelsMap[0] = startLabel;
    }

    predSpots.add(FlSpot(lastIdx.toDouble(), startY));
    minSpots.add(FlSpot(lastIdx.toDouble(), startY));
    maxSpots.add(FlSpot(lastIdx.toDouble(), startY));

    final int idx30 = lastIdx + 30;
    final double pred30Y = response.predictions.day30.predicted / gbDivisor;
    predSpots.add(FlSpot(idx30.toDouble(), pred30Y));
    minSpots.add(
        FlSpot(idx30.toDouble(), response.predictions.day30.min / gbDivisor));
    maxSpots.add(
        FlSpot(idx30.toDouble(), response.predictions.day30.max / gbDivisor));
    labelsMap[idx30] = '+30 Days';
    if (pred30Y < minY) minY = pred30Y;
    if (pred30Y > maxY) maxY = pred30Y;
    if (response.predictions.day30.max / gbDivisor > maxY)
      maxY = response.predictions.day30.max / gbDivisor;

    final int idx90 = lastIdx + 90;
    final double pred90Y = response.predictions.day90.predicted / gbDivisor;
    predSpots.add(FlSpot(idx90.toDouble(), pred90Y));
    minSpots.add(
        FlSpot(idx90.toDouble(), response.predictions.day90.min / gbDivisor));
    maxSpots.add(
        FlSpot(idx90.toDouble(), response.predictions.day90.max / gbDivisor));
    labelsMap[idx90] = '+90 Days';
    if (pred90Y < minY) minY = pred90Y;
    if (pred90Y > maxY) maxY = pred90Y;
    if (response.predictions.day90.max / gbDivisor > maxY)
      maxY = response.predictions.day90.max / gbDivisor;

    final int idx365 = lastIdx + 365;
    final double pred365Y = response.predictions.day365.predicted / gbDivisor;
    predSpots.add(FlSpot(idx365.toDouble(), pred365Y));
    minSpots.add(
        FlSpot(idx365.toDouble(), response.predictions.day365.min / gbDivisor));
    maxSpots.add(
        FlSpot(idx365.toDouble(), response.predictions.day365.max / gbDivisor));
    labelsMap[idx365] = '+1 Year';
    if (pred365Y < minY) minY = pred365Y;
    if (pred365Y > maxY) maxY = pred365Y;
    if (response.predictions.day365.max / gbDivisor > maxY)
      maxY = response.predictions.day365.max / gbDivisor;

    if (minY == double.infinity || minY > maxY) {
      minY = 0.0;
      maxY = 100.0;
    }
    final double paddingY = max(5.0, (maxY - minY) * 0.1);
    final double lowerLimit = max(0.0, minY - paddingY);
    final double upperLimit = maxY + paddingY;
    final double intervalY =
        max(1.0, ((upperLimit - lowerLimit) / 4).floorToDouble());

    final double maxX = max(1.0, idx365.toDouble());
    final double intervalX = max(1.0, (maxX / 4).floorToDouble());

    return AspectRatio(
      aspectRatio: 1.70,
      child: Padding(
        padding:
            const EdgeInsets.only(right: 18, left: 12, top: 24, bottom: 12),
        child: LineChart(
          LineChartData(
            minY: lowerLimit,
            maxY: upperLimit,
            minX: 0.0,
            maxX: maxX,
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipColor: (_) => Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.9),
                getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                  return touchedBarSpots.map((LineBarSpot barSpot) {
                    final int idx = barSpot.x.toInt();
                    final String title = labelsMap[idx] ?? 'Day $idx';
                    final String gbVal = '${barSpot.y.toStringAsFixed(1)} GB';
                    final String lineName;
                    final Color color = barSpot.bar.color ??
                        Theme.of(context).colorScheme.primary;
                    if (barSpot.barIndex == 1) {
                      lineName = 'Predicted';
                    } else if (barSpot.barIndex == 2) {
                      lineName = 'Min Bound';
                    } else if (barSpot.barIndex == 3) {
                      lineName = 'Max Bound';
                    } else {
                      lineName = 'Actual';
                    }
                    final bool isFirst = barSpot == touchedBarSpots.first;
                    return LineTooltipItem(
                      '${isFirst ? '$title\n' : ''}$lineName: $gbVal',
                      TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    );
                  }).toList();
                },
              ),
            ),
            gridData: FlGridData(
              horizontalInterval: intervalY,
              verticalInterval: intervalX,
              getDrawingHorizontalLine: (double value) {
                return FlLine(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.2),
                    strokeWidth: 1);
              },
              getDrawingVerticalLine: (double value) {
                return FlLine(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.2),
                    strokeWidth: 1);
              },
            ),
            titlesData: FlTitlesData(
              rightTitles: const AxisTitles(),
              topTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: intervalX,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    final int index = value.toInt();
                    String? label = labelsMap[index];
                    if (label == null && index == 0 && hist.isNotEmpty) {
                      label = hist.first.day;
                    }
                    if (label == null) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(label.length > 7 ? label.substring(5) : label,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 10)),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: intervalY,
                  reservedSize: 45,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    return Text('${value.toInt()} G',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 11),
                        textAlign: TextAlign.left);
                  },
                ),
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.2)),
            ),
            lineBarsData: <LineChartBarData>[
              LineChartBarData(
                spots: histSpots,
                isCurved: true,
                preventCurveOverShooting: true,
                color: Theme.of(context).colorScheme.primary,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.15),
                ),
              ),
              LineChartBarData(
                spots: predSpots,
                isCurved: true,
                preventCurveOverShooting: true,
                color: Theme.of(context).colorScheme.secondary,
                barWidth: 3,
                dashArray: <int>[8, 4],
                isStrokeCapRound: true,
                belowBarData: BarAreaData(
                  show: true,
                  color: Theme.of(context)
                      .colorScheme
                      .secondary
                      .withValues(alpha: 0.08),
                ),
              ),
              LineChartBarData(
                spots: minSpots,
                isCurved: true,
                preventCurveOverShooting: true,
                color: Theme.of(context)
                    .colorScheme
                    .tertiary
                    .withValues(alpha: 0.6),
                barWidth: 1.5,
                dashArray: <int>[4, 4],
                dotData: const FlDotData(show: false),
              ),
              LineChartBarData(
                spots: maxSpots,
                isCurved: true,
                preventCurveOverShooting: true,
                color: Theme.of(context)
                    .colorScheme
                    .tertiary
                    .withValues(alpha: 0.6),
                barWidth: 1.5,
                dashArray: <int>[4, 4],
                dotData: const FlDotData(show: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StorageRoiSection extends ConsumerWidget {
  const _StorageRoiSection({required this.instance});

  final Instance instance;

  IconData _getMediaIcon(String type) {
    switch (type.toLowerCase()) {
      case 'movie':
        return Icons.movie_outlined;
      case 'episode':
      case 'show':
      case 'series':
        return Icons.tv_outlined;
      case 'artist':
      case 'album':
      case 'track':
        return Icons.library_music_outlined;
      default:
        return Icons.perm_media_outlined;
    }
  }

  Color _getValueColor(String category, ColorScheme colorScheme) {
    switch (category.toLowerCase()) {
      case 'high_value':
        return Colors.green;
      case 'low_value':
        return colorScheme.error;
      case 'medium_value':
      default:
        return colorScheme.primary;
    }
  }

  String _getValueLabel(String category) {
    switch (category.toLowerCase()) {
      case 'high_value':
        return 'High Value';
      case 'low_value':
        return 'Low Value';
      case 'medium_value':
      default:
        return 'Medium Value';
    }
  }

  void _showPageDialog(
      BuildContext context, TracearrRoiNotifier notifier, int totalPages) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Page'),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 60,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.2,
              ),
              itemCount: totalPages,
              itemBuilder: (BuildContext context, int index) {
                final int p = index + 1;
                final bool isCurrent = p == notifier.page;
                return InkWell(
                  onTap: () {
                    notifier.setPage(p);
                    Navigator.of(context).pop();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$p',
                      style: TextStyle(
                        color: isCurrent
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight:
                            isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TracearrRoiNotifier notifier =
        ref.watch(tracearrRoiProvider(instance));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Storage Efficiency & ROI',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: Insets.md),
        ListenableBuilder(
          listenable: notifier,
          builder: (BuildContext context, Widget? child) {
            final AsyncValue<TracearrLibraryRoiResponse> state = notifier.state;
            return state.when(
              data: (TracearrLibraryRoiResponse data) {
                final TracearrRoiSummary summary = data.summary;
                final int totalPages =
                    (data.pagination.total > 0 && notifier.pageSize > 0)
                        ? ((data.pagination.total + notifier.pageSize - 1) ~/
                            notifier.pageSize)
                        : 1;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Summary Cards Row
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Card(
                            elevation: 0,
                            margin: EdgeInsets.zero,
                            color: Theme.of(context)
                                .colorScheme
                                .secondaryContainer,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 16, horizontal: 12),
                              child: Column(
                                children: <Widget>[
                                  Icon(Icons.auto_delete_outlined,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSecondaryContainer),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${summary.potentialSavingsGb.toStringAsFixed(1)} GB',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSecondaryContainer,
                                        ),
                                  ),
                                  Text(
                                    'Potential Savings',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSecondaryContainer,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: Insets.sm),
                        Expanded(
                          child: Card(
                            elevation: 0,
                            margin: EdgeInsets.zero,
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 16, horizontal: 12),
                              child: Column(
                                children: <Widget>[
                                  Icon(Icons.speed_outlined,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${summary.avgWatchHoursPerGb.toStringAsFixed(2)} hrs/GB',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                        ),
                                  ),
                                  Text(
                                    'Avg Efficiency',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: Insets.sm),
                        Expanded(
                          child: Card(
                            elevation: 0,
                            margin: EdgeInsets.zero,
                            color: Theme.of(context).colorScheme.errorContainer,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 16, horizontal: 12),
                              child: Column(
                                children: <Widget>[
                                  Icon(Icons.warning_amber_outlined,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onErrorContainer),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${summary.lowValueItems}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onErrorContainer,
                                        ),
                                  ),
                                  Text(
                                    'Low Value (${summary.lowValueStorageGb.toStringAsFixed(1)} GB)',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onErrorContainer,
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
                    // Sorting controls
                    Row(
                      children: <Widget>[
                        Text(
                          'Sort by:',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(width: Insets.sm),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: <Widget>[
                                ChoiceChip(
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      const Text('Efficiency'),
                                      if (notifier.sortBy ==
                                          'watch_hours_per_gb') ...<Widget>[
                                        const SizedBox(width: 4),
                                        Icon(
                                          notifier.sortOrder == 'desc'
                                              ? Icons.arrow_downward
                                              : Icons.arrow_upward,
                                          size: 16,
                                        ),
                                      ],
                                    ],
                                  ),
                                  selected:
                                      notifier.sortBy == 'watch_hours_per_gb',
                                  onSelected: (_) =>
                                      notifier.setSort('watch_hours_per_gb'),
                                ),
                                const SizedBox(width: Insets.sm),
                                ChoiceChip(
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      const Text('Size'),
                                      if (notifier.sortBy ==
                                          'file_size') ...<Widget>[
                                        const SizedBox(width: 4),
                                        Icon(
                                          notifier.sortOrder == 'desc'
                                              ? Icons.arrow_downward
                                              : Icons.arrow_upward,
                                          size: 16,
                                        ),
                                      ],
                                    ],
                                  ),
                                  selected: notifier.sortBy == 'file_size',
                                  onSelected: (_) =>
                                      notifier.setSort('file_size'),
                                ),
                                const SizedBox(width: Insets.sm),
                                ChoiceChip(
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      const Text('Score'),
                                      if (notifier.sortBy ==
                                          'value_score') ...<Widget>[
                                        const SizedBox(width: 4),
                                        Icon(
                                          notifier.sortOrder == 'desc'
                                              ? Icons.arrow_downward
                                              : Icons.arrow_upward,
                                          size: 16,
                                        ),
                                      ],
                                    ],
                                  ),
                                  selected: notifier.sortBy == 'value_score',
                                  onSelected: (_) =>
                                      notifier.setSort('value_score'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Insets.md),
                    if (data.items.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(Insets.xl),
                          child: Text('No storage efficiency items found.'),
                        ),
                      )
                    else ...<Widget>[
                      for (final TracearrRoiItem item in data.items)
                        Card(
                          margin: const EdgeInsets.only(bottom: Insets.md),
                          color:
                              Theme.of(context).colorScheme.surfaceContainerLow,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: Insets.md,
                              vertical: Insets.xs,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              child: Icon(_getMediaIcon(item.mediaType)),
                            ),
                            title: Text(
                              item.title +
                                  (item.year != null ? ' (${item.year})' : ''),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            subtitle: Text(
                              '${item.serverName} • ${item.fileSizeGb.toStringAsFixed(2)} GB • ${item.totalWatchHours.toStringAsFixed(1)} watch hrs\nEfficiency: ${item.watchHoursPerGb.toStringAsFixed(2)} hrs/GB (Score: ${item.valueScore.toStringAsFixed(0)})',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            isThreeLine: true,
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: <Widget>[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getValueColor(item.valueCategory,
                                            Theme.of(context).colorScheme)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: _getValueColor(item.valueCategory,
                                          Theme.of(context).colorScheme),
                                    ),
                                  ),
                                  child: Text(
                                    _getValueLabel(item.valueCategory),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: _getValueColor(
                                              item.valueCategory,
                                              Theme.of(context).colorScheme),
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ),
                                if (item.suggestDeletion) ...<Widget>[
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Icon(
                                        Icons.delete_outline,
                                        size: 14,
                                        color:
                                            Theme.of(context).colorScheme.error,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        'Suggest Cleanup',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error,
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      // Pagination controls
                      const SizedBox(height: Insets.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: notifier.page > 1
                                ? notifier.previousPage
                                : null,
                          ),
                          const SizedBox(width: Insets.md),
                          ActionChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text('Page ${notifier.page} of $totalPages'),
                                if (totalPages > 1) ...<Widget>[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.arrow_drop_down, size: 18),
                                ],
                              ],
                            ),
                            onPressed: totalPages > 1
                                ? () => _showPageDialog(
                                    context, notifier, totalPages)
                                : null,
                          ),
                          const SizedBox(width: Insets.md),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: (notifier.page * notifier.pageSize) <
                                    data.pagination.total
                                ? notifier.nextPage
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ],
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (Object error, StackTrace stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: <Widget>[
                      Text(
                        'Failed to load Storage ROI stats: $error',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: notifier.refresh,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _DashboardStatCard extends StatelessWidget {
  const _DashboardStatCard({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: Insets.lg, horizontal: Insets.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: Insets.sm),
          Text(
            value,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
        ],
      ),
    );
  }
}

class _DashboardStatsHeader extends ConsumerWidget {
  const _DashboardStatsHeader({required this.instance});
  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TracearrDashboardStats> stats =
        ref.watch(tracearrDashboardStatsProvider(instance));

    return stats.when(
      data: (TracearrDashboardStats data) {
        return Padding(
          padding:
              const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Today\'s Overview',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: Insets.md),
              Row(
                children: <Widget>[
                  Expanded(
                      child: _DashboardStatCard(
                          title: 'Active Streams',
                          value: '${data.activeStreams}')),
                  const SizedBox(width: Insets.md),
                  Expanded(
                      child: _DashboardStatCard(
                          title: 'Watch Hours',
                          value: data.watchTimeHours.toStringAsFixed(1))),
                ],
              ),
              const SizedBox(height: Insets.md),
              Row(
                children: <Widget>[
                  Expanded(
                      child: _DashboardStatCard(
                          title: 'Plays Today', value: '${data.todayPlays}')),
                  const SizedBox(width: Insets.md),
                  Expanded(
                      child: _DashboardStatCard(
                          title: 'Sessions Today',
                          value: '${data.todaySessions}')),
                ],
              ),
              const SizedBox(height: Insets.md),
              Row(
                children: <Widget>[
                  Expanded(
                      child: _DashboardStatCard(
                          title: 'Active Users',
                          value: '${data.activeUsersToday}')),
                  const SizedBox(width: Insets.md),
                  Expanded(
                      child: _DashboardStatCard(
                          title: 'Recent Alerts',
                          value: '${data.alertsLast24h}')),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const Padding(
          padding: EdgeInsets.all(Insets.lg),
          child: Center(child: CircularProgressIndicator())),
      error: (Object e, StackTrace st) => Padding(
          padding: const EdgeInsets.all(Insets.lg),
          child: Text('Failed to load stats: $e')),
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
    final TracearrApi? api = ref.watch(tracearrApiProvider(instance)).value;

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
            onRefresh: () async {
              ref.invalidate(tracearrServersProvider(instance));
              ref.invalidate(tracearrSessionsProvider(instance));
              ref.invalidate(tracearrDashboardStatsProvider(instance));
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: Insets.lg),
              children: <Widget>[
                const SizedBox(height: 48),
                const EmptyView(
                  icon: Icons.podcasts_outlined,
                  title: 'Nothing playing',
                  message: 'No active streams right now.',
                ),
                const SizedBox(height: 48),
                _DashboardStatsHeader(instance: instance),
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
          onRefresh: () async {
            ref.invalidate(tracearrServersProvider(instance));
            ref.invalidate(tracearrSessionsProvider(instance));
            ref.invalidate(tracearrDashboardStatsProvider(instance));
          },
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
                          api: api,
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
                          api: api,
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
                          api: api,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: Insets.lg),
              ],
              _DashboardStatsHeader(instance: instance),
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
    this.api,
    this.isHistory = false,
  });

  final TracearrSession session;
  final TracearrApi? api;
  final bool isHistory;

  @override
  State<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<_SessionCard> {
  PaletteGenerator? _palette;
  String? _lastPosterUrl;

  String? get imageUrl {
    if (widget.api != null && widget.session.thumbPath != null) {
      final String type = widget.session.mediaType.toLowerCase();
      final bool isAudio = type == 'track' || type == 'album' || type == 'audio' || type == 'music' || type == 'song' || type == 'podcast' || type == 'audiobook';
      return widget.api!.proxyImageUrl(
        serverId: widget.session.serverId,
        path: widget.session.thumbPath,
        width: isAudio ? 600 : 400,
        height: 600,
        fallback: isAudio ? 'art' : 'poster',
      );
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
        oldWidget.api != widget.api) {
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

    final String user = session.displayUser;
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
              isHistory: widget.isHistory,
              api: widget.api,
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
                      CachedNetworkImage(
                        imageUrl: posterUrl,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
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
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(Insets.md),
                  child: Row(
                    children: <Widget>[
                      // Poster
                      ConstrainedBox(
                        constraints:
                            const BoxConstraints(maxWidth: 120, maxHeight: 126),
                        child: AspectRatio(
                          aspectRatio: session.mediaType.toLowerCase() == 'track' ||
                                  session.mediaType.toLowerCase() == 'album' ||
                                  session.mediaType.toLowerCase() == 'audio' ||
                                  session.mediaType.toLowerCase() == 'music' ||
                                  session.mediaType.toLowerCase() == 'song' ||
                                  session.mediaType.toLowerCase() == 'podcast' ||
                                  session.mediaType.toLowerCase() == 'audiobook' ||
                                  session.mediaType.toLowerCase() == 'musicalbum' ||
                                  session.mediaType.toLowerCase() == 'musicartist'
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
                                session.state.toLowerCase() ==
                                    'idle') ...<Widget>[
                              const SizedBox(height: 8),

                              // Progress Header
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                      style:
                                          theme.textTheme.labelSmall?.copyWith(
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
                                      style:
                                          theme.textTheme.labelSmall?.copyWith(
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<DateTimeRange?> _showCustomDateRangeDialog({
  required BuildContext context,
  DateTime? initialStart,
  DateTime? initialEnd,
}) async {
  return showDialog<DateTimeRange>(
    context: context,
    builder: (BuildContext context) => _CustomDateRangeDialog(
      initialStart: initialStart,
      initialEnd: initialEnd,
    ),
  );
}

class _CustomDateRangeDialog extends StatefulWidget {
  const _CustomDateRangeDialog({this.initialStart, this.initialEnd});

  final DateTime? initialStart;
  final DateTime? initialEnd;

  @override
  State<_CustomDateRangeDialog> createState() => _CustomDateRangeDialogState();
}

class _CustomDateRangeDialogState extends State<_CustomDateRangeDialog> {
  late DateTime _startDate;
  late DateTime _endDate;
  String _activePreset = '';

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _startDate = widget.initialStart ?? DateTime(now.year - 1, now.month, now.day);
    _endDate = widget.initialEnd ?? now;
  }

  String _formatDate(DateTime d) {
    const List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  void _applyPreset(String preset) {
    final DateTime now = DateTime.now();
    setState(() {
      _activePreset = preset;
      switch (preset) {
        case 'This Year':
          _startDate = DateTime(now.year, 1, 1);
          _endDate = now;
          break;
        case 'Last Year':
          _startDate = DateTime(now.year - 1, 1, 1);
          _endDate = DateTime(now.year - 1, 12, 31, 23, 59, 59);
          break;
        case 'Last 2 Years':
          _startDate = DateTime(now.year - 2, now.month, now.day);
          _endDate = now;
          break;
        case 'Last 3 Years':
          _startDate = DateTime(now.year - 3, now.month, now.day);
          _endDate = now;
          break;
        case 'All Time':
          _startDate = DateTime(2000, 1, 1);
          _endDate = now;
          break;
      }
    });
  }

  Future<void> _pickStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: _endDate,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        _activePreset = '';
      });
    }
  }

  Future<void> _pickEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
        _activePreset = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Select Date Range'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Quick Presets',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: Insets.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <String>[
                'This Year',
                'Last Year',
                'Last 2 Years',
                'Last 3 Years',
                'All Time',
              ].map((String preset) {
                final bool isSelected = _activePreset == preset;
                return ChoiceChip(
                  label: Text(preset),
                  selected: isSelected,
                  onSelected: (bool selected) {
                    if (selected) _applyPreset(preset);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: Insets.xl),
            Text(
              'Custom Range',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: Insets.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: InkWell(
                    onTap: _pickStartDate,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Start Date',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: <Widget>[
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _formatDate(_startDate),
                                    maxLines: 1,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.arrow_forward, size: 16),
                ),
                Expanded(
                  child: InkWell(
                    onTap: _pickEndDate,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'End Date',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: <Widget>[
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _formatDate(_endDate),
                                    maxLines: 1,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            DateTimeRange(start: _startDate, end: _endDate),
          ),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

