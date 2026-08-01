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
import 'models/tracearr_activity_platform.dart';
import 'models/tracearr_activity_play.dart';
import 'models/tracearr_activity_play_dow.dart';
import 'models/tracearr_activity_play_hod.dart';
import 'models/tracearr_activity_quality.dart';
import 'models/tracearr_activity_stats.dart';
import 'models/tracearr_activity_locations.dart';
import 'models/tracearr_dashboard_stats.dart';
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
    if (data.isEmpty) {
      return EasyRefresh(
        onRefresh: () async => ref.invalidate(tracearrHistoryProvider(instance)),
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
              serverUrl: servers[session.serverId],
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
    final Map<String, String> servers = ref.watch(tracearrServersProvider(instance)).value ?? <String, String>{};
    final AsyncValue<TracearrActivityLocationsResponse> locsVal = ref.watch(tracearrActivityLocationsProvider(instance));
    
    return AsyncValueView<TracearrActivityLocationsResponse>(
      value: locsVal,
      onRetry: () => ref.invalidate(tracearrActivityLocationsProvider(instance)),
      data: (TracearrActivityLocationsResponse res) {
        final List<Marker> markers = <Marker>[];
        TracearrActivityLocation? maxLoc;

        for (final TracearrActivityLocation loc in res.data) {
          if (loc.lat != null && loc.lon != null) {
            if (maxLoc == null || loc.count > maxLoc.count) {
              maxLoc = loc;
            }

            final List<String> parts = <String>[loc.city, loc.region, loc.country];
            final String locationName = parts.where((String p) => p.isNotEmpty).join(', ');

            final List<InlineSpan> spans = <InlineSpan>[
              TextSpan(
                text: locationName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ];

            if (loc.users.isNotEmpty) {
              for (final TracearrActivityLocationUser user in loc.users) {
                spans.add(const TextSpan(text: '\n'));
                String? imageUrl;
                if (user.thumbUrl != null && servers.isNotEmpty) {
                  final String serverUrl = servers.values.first;
                  final String cleanPath = user.thumbUrl!.startsWith('/') ? user.thumbUrl! : '/${user.thumbUrl!}';
                  imageUrl = '$serverUrl$cleanPath';
                }

                spans.add(
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4.0, right: 6.0),
                      child: imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              width: 16,
                              height: 16,
                              imageBuilder: (BuildContext context, ImageProvider<Object> provider) => CircleAvatar(
                                backgroundImage: provider,
                                radius: 8,
                              ),
                              errorWidget: (BuildContext context, String url, Object error) => const Icon(Icons.person, size: 16),
                            )
                          : const Icon(Icons.person, size: 16),
                    ),
                  ),
                );
                spans.add(TextSpan(text: user.username));
              }
            }

            markers.add(
              Marker(
                point: LatLng(loc.lat!, loc.lon!),
                width: 60,
                height: 60,
                child: Center(
                  child: Tooltip(
                    richMessage: TextSpan(children: spans),
                    triggerMode: TooltipTriggerMode.tap,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
                            blurRadius: 12,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '${loc.count}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
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
            message: 'None of the history sessions have geographic coordinates.',
          );
        }

        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        final String tileUrl = isDark
            ? 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
            : 'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';

        final LatLng initialCenter = maxLoc != null && maxLoc.lat != null && maxLoc.lon != null
            ? LatLng(maxLoc.lat!, maxLoc.lon!)
            : markers.first.point;

        return FlutterMap(
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: 11.0,
          ),
          children: <Widget>[
            TileLayer(
              urlTemplate: tileUrl,
              userAgentPackageName: 'com.atrium.app',
            ),
            MarkerLayer(markers: markers),
          ],
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
    final List<String> serverIds = widget.plays.map((TracearrActivityPlay e) => e.serverId).toSet().toList();
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
    final Map<String, Map<String, int>> groupedData = <String, Map<String, int>>{};
    for (final TracearrActivityPlay item in widget.plays) {
      final String date = item.date;
      final String server = item.serverId;
      final int count = item.count;

      groupedData.putIfAbsent(date, () => <String, int>{});
      groupedData[date]![server] = count;
    }

    final List<String> dates = groupedData.keys.toList();

    Widget buildSingleServerChart(String serverId, Color color) {
      final String serverName = widget.servers[serverId] ?? (serverId.length > 8 ? serverId.substring(0, 8) : serverId);

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
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 6),
                Text(
                  serverName,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: Insets.sm),
          ],
          AspectRatio(
            aspectRatio: 1.70,
            child: Padding(
              padding: const EdgeInsets.only(right: 18, left: 12, top: 16, bottom: 12),
              child: LineChart(
                LineChartData(
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipColor: (_) => Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
                      getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                        return touchedBarSpots.map((LineBarSpot barSpot) {
                          final int index = barSpot.x.toInt();
                          if (index < 0 || index >= dates.length) return null;

                          final String dateStr = dates[index].split(' ').first;

                          return LineTooltipItem(
                            '${barSpot.y.toInt()} plays\n',
                            TextStyle(color: color, fontWeight: FontWeight.bold),
                            children: <TextSpan>[
                              TextSpan(
                                text: '$serverName\n$dateStr',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
                      return FlLine(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2), strokeWidth: 1);
                    },
                    getDrawingVerticalLine: (double value) {
                      return FlLine(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2), strokeWidth: 1);
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
                          if (index < 0 || index >= dates.length) return const SizedBox.shrink();
                          if (index % max(1, dates.length ~/ 5) != 0) return const SizedBox.shrink();
                          final String text = dates[index].split(' ').first.substring(5); // MM-DD
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
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
                          return Text(value.toInt().toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.left);
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
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

    final Color barBackgroundColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1);
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
                getTooltipColor: (_) => Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
                tooltipHorizontalAlignment: FLHorizontalAlignment.center,
                tooltipMargin: 8,
                getTooltipItem: (BarChartGroupData group, int groupIndex, BarChartRodData rod, int rodIndex) {
                  return BarTooltipItem(
                    '${widget.plays[groupIndex].name}\n',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    children: <TextSpan>[
                      TextSpan(
                        text: widget.plays[groupIndex].count.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ],
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
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 38,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    final int index = value.toInt();
                    if (index < 0 || index >= widget.plays.length) return const SizedBox.shrink();
                    return SideTitleWidget(
                      meta: meta,
                      space: 16,
                      child: Text(widget.plays[index].name.substring(0, 3).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    );
                  },
                ),
              ),
              leftTitles: const AxisTitles(),
            ),
            borderData: FlBorderData(show: false),
            barGroups: widget.plays.asMap().entries.map((MapEntry<int, TracearrActivityPlayDow> e) {
              final bool isTouched = e.key == touchedIndex;
              return BarChartGroupData(
                x: e.key,
                barRods: <BarChartRodData>[
                  BarChartRodData(
                    toY: e.value.count.toDouble(),
                    color: isTouched ? touchedBarColor : barColor,
                    width: 22,
                    borderSide: isTouched ? BorderSide(color: touchedBarColor.withValues(alpha: 0.8)) : const BorderSide(color: Colors.white, width: 0),
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

    final Color barBackgroundColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1);
    final Color barColor = Theme.of(context).colorScheme.primary;
    final Color touchedBarColor = Theme.of(context).colorScheme.secondary;

    final Map<int, int> playsMap = <int, int>{
      for (final TracearrActivityPlayHod p in widget.plays) p.hour: p.count
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
                getTooltipColor: (_) => Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
                tooltipHorizontalAlignment: FLHorizontalAlignment.center,
                tooltipMargin: 8,
                getTooltipItem: (BarChartGroupData group, int groupIndex, BarChartRodData rod, int rodIndex) {
                  return BarTooltipItem(
                    '${_formatHour(group.x.toInt())}\n${rod.toY.toInt()} plays',
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
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 38,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    final int hour = value.toInt();
                    if (hour % 4 != 0) return const SizedBox.shrink();
                    
                    return SideTitleWidget(
                      meta: meta,
                      space: 8,
                      fitInside: SideTitleFitInsideData.fromTitleMeta(meta, distanceFromEdge: 0),
                      child: Text(_formatHour(hour), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
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
                    borderSide: isTouched ? BorderSide(color: touchedBarColor.withValues(alpha: 0.8)) : const BorderSide(color: Colors.white, width: 0),
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
            children: widget.platforms.asMap().entries.map((MapEntry<int, TracearrActivityPlatform> e) {
              final bool isTouched = touchedIndex == e.key;
              return _ActivityChartIndicator(
                color: colors[e.key % colors.length],
                text: '${e.value.platform} (${e.value.count})',
                isSquare: false,
                size: isTouched ? 18 : 16,
                textColor: isTouched ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                    touchCallback: (FlTouchEvent event, PieTouchResponse? pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                          touchedIndex = -1;
                          return;
                        }
                        touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  startDegreeOffset: 180,
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 1,
                  centerSpaceRadius: 0,
                  sections: widget.platforms.asMap().entries.map((MapEntry<int, TracearrActivityPlatform> e) {
                    final bool isTouched = e.key == touchedIndex;
                    final double radius = radiusValues[e.key % radiusValues.length];
                    return PieChartSectionData(
                      color: colors[e.key % colors.length],
                      value: e.value.count.toDouble(),
                      title: '',
                      radius: radius,
                      borderSide: isTouched
                          ? const BorderSide(color: Colors.white, width: 6)
                          : BorderSide(color: Colors.white.withValues(alpha: 0)),
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
    final List<Color> colors = <Color>[scheme.primary, scheme.secondary, scheme.tertiary];
    final List<String> labels = <String>['Direct Play', 'Direct Stream', 'Transcode'];
    final List<int> counts = <int>[widget.quality.directPlay, widget.quality.directStream, widget.quality.transcode];
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
                textColor: isTouched ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                    touchCallback: (FlTouchEvent event, PieTouchResponse? pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                          touchedIndex = -1;
                          return;
                        }
                        touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
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
                          : BorderSide(color: Colors.white.withValues(alpha: 0)),
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
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      );
    }

    return Column(
      children: <Widget>[
        AspectRatio(
          aspectRatio: 1.70,
          child: Padding(
            padding: const EdgeInsets.only(right: 18, left: 12, top: 24, bottom: 12),
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipColor: (_) => Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                      return touchedBarSpots.map((LineBarSpot barSpot) {
                        final int index = barSpot.x.toInt();
                        if (index < 0 || index >= widget.concurrentPlays.length) return null;
                        final TracearrActivityConcurrent p = widget.concurrentPlays[index];
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
                          TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                          children: isLast ? <TextSpan>[
                            TextSpan(
                              text: dateStr,
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.normal),
                            ),
                          ] : null,
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(
                  horizontalInterval: max(1, maxVal ~/ 5).toDouble(),
                  verticalInterval: 1,
                  getDrawingHorizontalLine: (double value) {
                    return FlLine(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2), strokeWidth: 1);
                  },
                  getDrawingVerticalLine: (double value) {
                    return FlLine(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2), strokeWidth: 1);
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
                        if (index < 0 || index >= widget.concurrentPlays.length) return const SizedBox.shrink();
                        if (index % max(1, widget.concurrentPlays.length ~/ 5) != 0) return const SizedBox.shrink();
                        final String text = widget.concurrentPlays[index].hour.split(' ').first.substring(5); // MM-DD
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
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
                        return Text(value.toInt().toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.left);
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                ),
                minX: 0,
                maxX: max(0, widget.concurrentPlays.length - 1).toDouble(),
                minY: 0,
                maxY: maxVal * 1.2,
                lineBarsData: <LineChartBarData>[
                  LineChartBarData(
                    spots: widget.concurrentPlays.asMap().entries.map((MapEntry<int, TracearrActivityConcurrent> e) {
                      return FlSpot(e.key.toDouble(), e.value.direct.toDouble());
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
                    spots: widget.concurrentPlays.asMap().entries.map((MapEntry<int, TracearrActivityConcurrent> e) {
                      return FlSpot(e.key.toDouble(), e.value.directStream.toDouble());
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
                    spots: widget.concurrentPlays.asMap().entries.map((MapEntry<int, TracearrActivityConcurrent> e) {
                      return FlSpot(e.key.toDouble(), e.value.transcode.toDouble());
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
  const _EngagementSummary({required this.engagement, required this.servers});
  final TracearrActivityEngagement engagement;
  final Map<String, String> servers;

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
            _StatCard(title: 'Total Plays', value: engagement.summary.totalPlays.toString()),
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
              value: '${engagement.summary.totalValidSessions} / ${engagement.summary.totalAllSessions}',
            ),
          ],
        ),
        const SizedBox(height: Insets.xl),

        // 2. Engagement Breakdown
        if (engagement.engagementBreakdown.isNotEmpty) ...<Widget>[
          Text('Engagement Breakdown', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: Insets.md),
          _EngagementPieChart(breakdown: engagement.engagementBreakdown),
          const SizedBox(height: Insets.xl),
        ],

        // 3. Audience Personas
        if (engagement.userProfiles.isNotEmpty) ...<Widget>[
          Text('Audience Personas', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: Insets.md),
          _AudiencePersonaTable(profiles: engagement.userProfiles, servers: servers),
          const SizedBox(height: Insets.xl),
        ],

        // 4. Top Performers
        if (engagement.topContent.isNotEmpty || engagement.topShows.isNotEmpty) ...<Widget>[
          Text('Top Performers', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: Insets.md),
          _TopPerformersView(
            topShows: engagement.topShows,
            topContent: engagement.topContent,
            servers: servers,
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
              Text(title, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7))),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimaryContainer)),
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
            children: widget.breakdown.asMap().entries.map((MapEntry<int, TracearrEngagementBreakdown> entry) {
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
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                    touchCallback: (FlTouchEvent event, PieTouchResponse? pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                          touchedIndex = -1;
                          return;
                        }
                        touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  startDegreeOffset: 180,
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 1,
                  centerSpaceRadius: 0,
                  sections: widget.breakdown.asMap().entries.map((MapEntry<int, TracearrEngagementBreakdown> entry) {
                    final int index = entry.key;
                    final TracearrEngagementBreakdown data = entry.value;
                    final bool isTouched = index == touchedIndex;
                    final double radius = radiusValues[index % radiusValues.length];

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
                          : BorderSide(color: Colors.white.withValues(alpha: 0)),
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
  const _AudiencePersonaTable({required this.profiles, required this.servers});
  final List<TracearrUserProfile> profiles;
  final Map<String, String> servers;

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
          final bool isCompletionist = profile.behaviorType?.toLowerCase() == 'completionist';
          
          String? imageUrl;
          if (profile.thumbUrl != null && servers.isNotEmpty) {
            final String serverUrl = servers.values.first; // Fallback to first server since no serverId is provided
            final String cleanPath = profile.thumbUrl!.startsWith('/') ? profile.thumbUrl! : '/${profile.thumbUrl!}';
            imageUrl = '$serverUrl$cleanPath';
          }
          
          return DataRow(
            cells: <DataCell>[
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                      backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
                      child: imageUrl == null ? const Icon(Icons.person, size: 16) : null,
                    ),
                    const SizedBox(width: 8),
                    Text(profile.username),
                  ],
                ),
              ),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCompletionist ? Colors.green.withValues(alpha: 0.2) : Colors.blue.withValues(alpha: 0.2),
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

class _TopPerformersView extends StatelessWidget {
  const _TopPerformersView({
    required this.topShows,
    required this.topContent,
    required this.servers,
  });
  final List<TracearrTopShow> topShows;
  final List<TracearrTopContent> topContent;
  final Map<String, String> servers;

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
                      if (show.thumbPath != null && servers.containsKey(show.serverId)) {
                        final String cleanPath = show.thumbPath!.startsWith('/') ? show.thumbPath! : '/${show.thumbPath!}';
                        imageUrl = '${servers[show.serverId]}$cleanPath';
                      }
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: imageUrl != null 
                              ? Image.network(imageUrl, width: 40, height: 60, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.movie))
                              : const Icon(Icons.movie),
                        ),
                        title: Text(show.showTitle),
                        subtitle: Text('${show.totalEpisodeViews} views • ${show.totalWatchHours} hrs'),
                        trailing: Text('Score: ${show.bingeScore.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                      if (content.thumbPath != null && servers.containsKey(content.serverId)) {
                        final String cleanPath = content.thumbPath!.startsWith('/') ? content.thumbPath! : '/${content.thumbPath!}';
                        imageUrl = '${servers[content.serverId]}$cleanPath';
                      }
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: imageUrl != null 
                              ? Image.network(imageUrl, width: 40, height: 60, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.movie))
                              : const Icon(Icons.movie),
                        ),
                        title: Text(content.title),
                        subtitle: Text('${content.showTitle ?? 'Movie'} • ${content.totalWatchHours} hrs'),
                        trailing: Text('${content.completionRate}% completed', style: const TextStyle(fontWeight: FontWeight.bold)),
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
      final DateTimeRange? picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime.now(),
        initialDateRange: _customFrom != null && _customTo != null
            ? DateTimeRange(start: _customFrom!, end: _customTo!)
            : null,
      );
      if (picked != null) {
        setState(() {
          _selectedRange = 'Custom';
          _customFrom = picked.start;
          _customTo = picked.end.add(
            const Duration(hours: 23, minutes: 59, seconds: 59),
          );
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

    return Column(
      children: <Widget>[
        const SizedBox(height: Insets.sm),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
            children: <Widget>[
              for (final String range in _ranges)
                Padding(
                  padding: const EdgeInsets.only(right: Insets.sm),
                  child: Center(
                    child: ChoiceChip(
                      label: Text(
                        range == 'Custom' &&
                                _selectedRange == 'Custom' &&
                                _customFrom != null &&
                                _customTo != null
                            ? 'Custom (${_customFrom!.month}/${_customFrom!.day} - ${_customTo!.month}/${_customTo!.day})'
                            : range,
                      ),
                      selected: _selectedRange == range,
                      onSelected: (_) => _handleSelect(range),
                    ),
                  ),
                ),
            ],
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

class _WatchStatsView extends StatelessWidget {
  const _WatchStatsView({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Watch Stats (Coming Soon)'),
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
  State<_LibraryCompositionPieChart> createState() => _LibraryCompositionPieChartState();
}

class _LibraryCompositionPieChartState extends State<_LibraryCompositionPieChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.movieCount == 0 && widget.showCount == 0 && widget.episodeCount == 0) {
      return const SizedBox.shrink();
    }

    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<Color> colors = <Color>[scheme.primary, scheme.secondary, scheme.tertiary];
    final List<String> labels = <String>['Movies', 'Shows', 'Episodes'];
    final List<int> counts = <int>[widget.movieCount, widget.showCount, widget.episodeCount];
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
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                    touchCallback: (FlTouchEvent event, PieTouchResponse? pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                          touchedIndex = -1;
                          return;
                        }
                        touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
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
                          : BorderSide(color: Colors.white.withValues(alpha: 0)),
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
      final DateTimeRange? picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime.now(),
        initialDateRange: _customFrom != null && _customTo != null
            ? DateTimeRange(start: _customFrom!, end: _customTo!)
            : null,
      );
      if (picked != null) {
        setState(() {
          _selectedRange = 'Custom';
          _customFrom = picked.start;
          _customTo = picked.end.add(
            const Duration(hours: 23, minutes: 59, seconds: 59),
          );
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
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
            children: <Widget>[
              for (final String range in _ranges)
                Padding(
                  padding: const EdgeInsets.only(right: Insets.sm),
                  child: Center(
                    child: ChoiceChip(
                      label: Text(
                        range == 'Custom' &&
                                _selectedRange == 'Custom' &&
                                _customFrom != null &&
                                _customTo != null
                            ? 'Custom (${_customFrom!.month}/${_customFrom!.day} - ${_customTo!.month}/${_customTo!.day})'
                            : range,
                      ),
                      selected: _selectedRange == range,
                      onSelected: (_) => _handleSelect(range),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: AsyncValueView<TracearrStats>(
            value: statsVal,
            onRetry: () => ref.invalidate(tracearrStatsProvider(params)),
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
            _ChartCard(
              title: 'Library Composition',
              child: _LibraryCompositionPieChart(
                movieCount: data.movieCount,
                showCount: data.showCount,
                episodeCount: data.episodeCount,
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
                            final ColorScheme scheme = Theme.of(context).colorScheme;
                            final List<MapEntry<String, int>> validQualities = <MapEntry<String, int>>[];
                            final List<Color> validColors = <Color>[];
                            
                            if (data.qualityBreakdown!.count4k > 0) {
                              validQualities.add(MapEntry<String, int>('4K', data.qualityBreakdown!.count4k));
                              validColors.add(scheme.primary);
                            }
                            if (data.qualityBreakdown!.count1080p > 0) {
                              validQualities.add(MapEntry<String, int>('1080p', data.qualityBreakdown!.count1080p));
                              validColors.add(scheme.secondary);
                            }
                            if (data.qualityBreakdown!.count720p > 0) {
                              validQualities.add(MapEntry<String, int>('720p', data.qualityBreakdown!.count720p));
                              validColors.add(scheme.tertiary);
                            }
                            if (data.qualityBreakdown!.countSd > 0) {
                              validQualities.add(MapEntry<String, int>('SD', data.qualityBreakdown!.countSd));
                              validColors.add(scheme.error);
                            }

                            if (validQualities.isEmpty) return const SizedBox.shrink();

                            final double maxVal = validQualities.map((MapEntry<String, int> e) => e.value).reduce(max).toDouble();

                            return BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: max(1, maxVal) * 1.2,
                                barTouchData: const BarTouchData(enabled: false),
                                titlesData: FlTitlesData(
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
                                  leftTitles: const AxisTitles(),
                                  topTitles: const AxisTitles(),
                                  rightTitles: const AxisTitles(),
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
                                      ),
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
                            _Indicator(color: Theme.of(context).colorScheme.primary, text: '4K (${data.qualityBreakdown!.count4k})'),
                          if (data.qualityBreakdown!.count1080p > 0)
                            _Indicator(color: Theme.of(context).colorScheme.secondary, text: '1080p (${data.qualityBreakdown!.count1080p})'),
                          if (data.qualityBreakdown!.count720p > 0)
                            _Indicator(color: Theme.of(context).colorScheme.tertiary, text: '720p (${data.qualityBreakdown!.count720p})'),
                          if (data.qualityBreakdown!.countSd > 0)
                            _Indicator(color: Theme.of(context).colorScheme.error, text: 'SD (${data.qualityBreakdown!.countSd})'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
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
      padding: const EdgeInsets.symmetric(vertical: Insets.lg, horizontal: Insets.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
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
    final AsyncValue<TracearrDashboardStats> stats = ref.watch(tracearrDashboardStatsProvider(instance));

    return stats.when(
      data: (TracearrDashboardStats data) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Today\'s Overview', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: Insets.md),
              Row(
                children: <Widget>[
                  Expanded(child: _DashboardStatCard(title: 'Active Streams', value: '${data.activeStreams}')),
                  const SizedBox(width: Insets.md),
                  Expanded(child: _DashboardStatCard(title: 'Watch Hours', value: data.watchTimeHours.toStringAsFixed(1))),
                ],
              ),
              const SizedBox(height: Insets.md),
              Row(
                children: <Widget>[
                  Expanded(child: _DashboardStatCard(title: 'Plays Today', value: '${data.todayPlays}')),
                  const SizedBox(width: Insets.md),
                  Expanded(child: _DashboardStatCard(title: 'Sessions Today', value: '${data.todaySessions}')),
                ],
              ),
              const SizedBox(height: Insets.md),
              Row(
                children: <Widget>[
                  Expanded(child: _DashboardStatCard(title: 'Active Users', value: '${data.activeUsersToday}')),
                  const SizedBox(width: Insets.md),
                  Expanded(child: _DashboardStatCard(title: 'Recent Alerts', value: '${data.alertsLast24h}')),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const Padding(padding: EdgeInsets.all(Insets.lg), child: Center(child: CircularProgressIndicator())),
      error: (Object e, StackTrace st) => Padding(padding: const EdgeInsets.all(Insets.lg), child: Text('Failed to load stats: $e')),
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
            onRefresh: () async {
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
    this.serverUrl,
    this.isHistory = false,
  });

  final TracearrSession session;
  final String? serverUrl;
  final bool isHistory;

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
              isHistory: widget.isHistory,
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
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(Insets.md),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // Poster
                      ConstrainedBox(
                        constraints:
                            const BoxConstraints(minHeight: 100),
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
