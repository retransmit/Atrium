part of '../sonarr_home.dart';

class _ActivityTab extends StatefulWidget {
  const _ActivityTab({required this.instance});
  final Instance instance;

  @override
  State<_ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<_ActivityTab> {
  int _subTabIndex = 0;
  late final ScrollController _scrollController;
  bool _showScrollUp = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      final show = _scrollController.offset > 200;
      if (show != _showScrollUp) {
        setState(() {
          _showScrollUp = show;
        });
      }
    }
  }

  void _scrollToTop() {
    HapticFeedback.lightImpact();
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          NestedScrollView(
            controller: _scrollController,
            headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
              return <Widget>[
                const _OneUIAppBar(
                  title: 'Activity',
                  showLeading: false,
                  expandedHeight: 280, // Expanded height matching One UI 8.5 Specs
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  sliver: SliverToBoxAdapter(
                    child: _OneUISegmentedBar(
                      items: const <String>['Queue', 'History'],
                      selectedIndex: _subTabIndex,
                      onSelected: (int val) => setState(() => _subTabIndex = val),
                    ),
                  ),
                ),
              ];
            },
            body: IndexedStack(
              index: _subTabIndex,
              children: <Widget>[
                _QueueTab(instance: widget.instance),
                _HistoryTab(instance: widget.instance),
              ],
            ),
          ),

          // Floating scroll-up button
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            bottom: _showScrollUp ? 96 : 40,
            right: 24,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _showScrollUp ? 1.0 : 0.0,
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: FloatingActionButton.small(
                  heroTag: 'scroll_up_activity',
                  onPressed: _scrollToTop,
                  backgroundColor: colors.secondaryContainer,
                  foregroundColor: colors.onSecondaryContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.keyboard_arrow_up_rounded, size: 24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueItem {
  _QueueItem({required this.downloadId, required this.records});

  final String? downloadId;
  final List<SonarrQueueRecord> records;

  bool get isGrouped => records.length > 1;
  SonarrQueueRecord get primary => records.first;
}

class _QueueTab extends ConsumerWidget {
  const _QueueTab({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SonarrQueuePage> queue =
        ref.watch(sonarrQueueProvider(instance));
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return RefreshIndicator(
      onRefresh: () async {
        try {
          final SonarrApi api = await ref.read(
            sonarrApiProvider(instance).future,
          );
          await api.runSystemTask('RefreshMonitoredDownloads');
        } catch (_) {}
        ref.invalidate(sonarrQueueProvider(instance));
        await ref.read(sonarrQueueProvider(instance).future);
      },
      child: AsyncValueView<SonarrQueuePage>(
        value: queue,
        onRetry: () => ref.invalidate(sonarrQueueProvider(instance)),
        data: (SonarrQueuePage page) {
          if (page.records.isEmpty) {
            return const CustomScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyView(
                    icon: Icons.download_done_outlined,
                    title: 'Queue is empty',
                    message: 'Nothing downloading right now.',
                  ),
                ),
              ],
            );
          }

          // Group records by downloadId (season pack / sessional grab)
          final List<_QueueItem> items = <_QueueItem>[];
          final Map<String, List<SonarrQueueRecord>> groups = <String, List<SonarrQueueRecord>>{};

          for (final SonarrQueueRecord r in page.records) {
            final String? dId = r.downloadId;
            if (dId != null && dId.isNotEmpty) {
              groups.putIfAbsent(dId, () => <SonarrQueueRecord>[]).add(r);
            } else {
              items.add(_QueueItem(downloadId: null, records: <SonarrQueueRecord>[r]));
            }
          }

          groups.forEach((String dId, List<SonarrQueueRecord> list) {
            items.add(_QueueItem(downloadId: dId, records: list));
          });

          // Sort items by their original order in page.records
          items.sort((_QueueItem a, _QueueItem b) {
            final int indexA = page.records.indexOf(a.primary);
            final int indexB = page.records.indexOf(b.primary);
            return indexA.compareTo(indexB);
          });

          return ListView(
            padding: const EdgeInsets.only(
                left: 16, right: 16, top: 8, bottom: 100,), // padding bottom for bottom nav
            children: <Widget>[
              _OneUIGroupCard(
                margin: EdgeInsets.zero, // already padded by ListView
                children: items.map((_QueueItem item) {
                  final SonarrQueueRecord r = item.primary;
                  final double progress = r.size <= 0
                      ? 0
                      : ((r.size - r.sizeleft) / r.size).clamp(0, 1).toDouble();
                  final int progressPct = (progress * 100).round();
                  final String sizeStr = _formatBytes(r.size.toInt());
                  final String sizeLeftStr = _formatBytes(r.sizeleft.toInt());
                  final String sizeDoneStr = _formatBytes((r.size - r.sizeleft).toInt());

                  final bool hasWarning = item.records.any(
                    (SonarrQueueRecord rec) =>
                        rec.trackedDownloadStatus?.toLowerCase() == 'warning' ||
                        rec.statusMessages.isNotEmpty,
                  );
                  final bool hasError = item.records.any(
                    (SonarrQueueRecord rec) =>
                        rec.trackedDownloadStatus?.toLowerCase() == 'error',
                  );

                  IconData stateIcon = Icons.cloud_download_outlined;
                  Color stateColor = colors.primary;

                  if (hasError) {
                    stateIcon = Icons.error_outline;
                    stateColor = colors.error;
                  } else if (hasWarning) {
                    stateIcon = Icons.warning_amber_rounded;
                    stateColor = Colors.orange;
                  } else if (r.status?.toLowerCase() == 'paused') {
                    stateIcon = Icons.pause_circle_outline;
                    stateColor = colors.outline;
                  } else if (r.status?.toLowerCase() == 'completed' || progress >= 0.999) {
                    stateIcon = Icons.check_circle_outline;
                    stateColor = Colors.green;
                  }

                  final List<SonarrQueueStatusMessage> combinedMessages = item.records
                      .expand((SonarrQueueRecord rec) => rec.statusMessages)
                      .toList();

                  return InkWell(
                    onTap: r.seriesId != null
                        ? () => _pushSeriesDetail(context, instance, r.seriesId!)
                        : null,
                    splashFactory: InkRipple.splashFactory, // Uniform circular ripples
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), // 20dp list tile padding
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: stateColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(stateIcon, color: stateColor, size: 20),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      r.title ?? 'Item ${r.id}',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: <Widget>[
                                        if (item.isGrouped)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2,),
                                            decoration: BoxDecoration(
                                              color: colors.primary.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: colors.primary.withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Text(
                                              'SEASON GRAB (${item.records.length} EPS)',
                                              style: theme.textTheme.labelSmall?.copyWith(
                                                color: colors.primary,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        if (r.downloadClient != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2,),
                                            decoration: BoxDecoration(
                                              color: colors.surfaceContainerHighest,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              r.downloadClient!,
                                              style: theme.textTheme.labelSmall?.copyWith(
                                                color: colors.onSurfaceVariant,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                        if (r.protocol != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2,),
                                            decoration: BoxDecoration(
                                              color: colors.surfaceContainerHighest,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              r.protocol!.toUpperCase(),
                                              style: theme.textTheme.labelSmall?.copyWith(
                                                color: colors.onSurfaceVariant,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded), // Rounded icon
                                color: colors.error, // pure error color
                                onPressed: () async {
                                  final String deleteTitle = item.isGrouped
                                      ? 'Season grab for "${r.title ?? 'this series'}" (${item.records.length} eps)'
                                      : r.title ?? 'this item';
                                  final bool? ok =
                                      await _showDeleteConfirm(context, deleteTitle);
                                  if (ok == true) {
                                    final SonarrApi delApi = await ref
                                        .read(sonarrApiProvider(instance).future);
                                    if (item.isGrouped) {
                                      await Future.wait(item.records.map(
                                        (SonarrQueueRecord rec) =>
                                            delApi.deleteQueueItem(rec.id),
                                      ),);
                                    } else {
                                      await delApi.deleteQueueItem(r.id);
                                    }
                                    ref.invalidate(sonarrQueueProvider(instance));
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 8, // Chunkier progress bar
                                    backgroundColor: colors.surfaceContainerHighest,
                                    valueColor: AlwaysStoppedAnimation<Color>(stateColor),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '$progressPct%',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: stateColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  '$sizeDoneStr of $sizeStr ($sizeLeftStr left)',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  <String?>[
                                    if (r.status != null) r.status,
                                    if (r.timeleft != null) r.timeleft,
                                  ].whereType<String>().join(' • '),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (combinedMessages.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: (hasError ? colors.error : Colors.orange)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: (hasError ? colors.error : Colors.orange)
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Icon(
                                        hasError
                                            ? Icons.error_outline
                                            : Icons.warning_amber_rounded,
                                        color: hasError ? colors.error : Colors.orange,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          hasError ? 'Error Details' : 'Warning Details',
                                          style: theme.textTheme.labelMedium?.copyWith(
                                            color: hasError
                                                ? colors.error
                                                : Colors.orange[800] ?? Colors.orange,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ...combinedMessages.map((SonarrQueueStatusMessage msg) {
                                    final List<String> details = msg.messages;
                                    final String text = msg.title ?? '';
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          if (text.isNotEmpty)
                                            Text(
                                              '• $text',
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: hasError
                                                    ? colors.error
                                                    : Colors.orange[800] ?? Colors.orange,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          if (details.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(left: 12.0),
                                              child: Text(
                                                details.join('\n'),
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  color: hasError
                                                      ? colors.error.withValues(alpha: 0.8)
                                                      : (Colors.orange[900] ?? Colors.orange)
                                                          .withValues(alpha: 0.8),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HistoryTab extends ConsumerStatefulWidget {
  const _HistoryTab({required this.instance});

  final Instance instance;

  @override
  ConsumerState<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends ConsumerState<_HistoryTab> {
  String _activeDate = '';
  double _pillOpacity = 0.0;
  Timer? _fadeTimer;
  List<double> _cumulativeHeights = [];
  List<String> _dateKeys = [];

  @override
  void dispose() {
    _fadeTimer?.cancel();
    super.dispose();
  }

  bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  double _estimateItemHeight(List<SonarrHistoryRecord> records) {
    double height = 48.0; // Header padding + text
    for (int i = 0; i < records.length; i++) {
      final record = records[i];
      final String? indexer = record.data['indexer'] as String?;
      final String? client = record.data['downloadClient'] as String?;
      final Map<String, dynamic>? qualityMap = record.quality?['quality'] as Map<String, dynamic>?;
      final String? qualityName = qualityMap?['name'] as String?;
      final bool isThreeLine = indexer != null || client != null || qualityName != null;
      height += isThreeLine ? 92.0 : 76.0;
      if (i < records.length - 1) {
        height += 1.0; // Divider
      }
    }
    height += 16.0; // Bottom spacing (SizedBox(height: 16))
    return height;
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<SonarrHistoryPage> history =
        ref.watch(sonarrHistoryProvider(widget.instance));

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(sonarrHistoryProvider(widget.instance));
            await ref.read(sonarrHistoryProvider(widget.instance).future);
          },
          child: AsyncValueView<SonarrHistoryPage>(
            value: history,
            onRetry: () => ref.invalidate(sonarrHistoryProvider(widget.instance)),
            data: (SonarrHistoryPage dataPage) {
              if (dataPage.records.isEmpty) {
                return const CustomScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyView(
                        icon: Icons.history,
                        title: 'History is empty',
                        message: 'No actions have been logged yet.',
                      ),
                    ),
                  ],
                );
              }

              final Map<String, List<SonarrHistoryRecord>> grouped = {};
              for (final record in dataPage.records) {
                final String dateKey = _formatDateGroupKey(record.date.toLocal());
                grouped.putIfAbsent(dateKey, () => []).add(record);
              }
              final List<String> dateKeys = grouped.keys.toList();

              // Compute cumulative heights once when dateKeys changes
              if (_dateKeys.isEmpty || !_listsEqual(_dateKeys, dateKeys)) {
                _dateKeys = dateKeys;
                _cumulativeHeights = [0.0];
                double runningSum = 0.0;
                for (int i = 0; i < dateKeys.length; i++) {
                  runningSum += _estimateItemHeight(grouped[dateKeys[i]]!);
                  _cumulativeHeights.add(runningSum);
                }
                if (_activeDate.isEmpty && dateKeys.isNotEmpty) {
                  _activeDate = dateKeys.first;
                }
              }

              return NotificationListener<ScrollNotification>(
                onNotification: (ScrollNotification notification) {
                  if (_cumulativeHeights.isEmpty) return false;

                  final double offset = notification.metrics.pixels;

                  int activeIndex = 0;
                  for (int i = 0; i < _cumulativeHeights.length; i++) {
                    if (offset >= _cumulativeHeights[i]) {
                      activeIndex = i;
                    } else {
                      break;
                    }
                  }

                  if (activeIndex < _dateKeys.length) {
                    final String date = _dateKeys[activeIndex];
                    if (date != _activeDate) {
                      setState(() {
                        _activeDate = date;
                      });
                    }
                  }

                  if (_pillOpacity == 0.0) {
                    setState(() {
                      _pillOpacity = 1.0;
                    });
                  }

                  _fadeTimer?.cancel();
                  _fadeTimer = Timer(const Duration(milliseconds: 1000), () {
                    if (mounted) {
                      setState(() {
                        _pillOpacity = 0.0;
                      });
                    }
                  });

                  return false; // Allow the scroll notification to bubble up to NestedScrollView
                },
                child: ListView.builder(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 8,
                    bottom: 100,
                  ), // padding bottom for bottom nav
                  itemCount: dateKeys.length,
                  itemBuilder: (BuildContext context, int index) {
                    final String dateKey = dateKeys[index];
                    final List<SonarrHistoryRecord> records = grouped[dateKey]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _OneUISectionHeader(dateKey),
                        _OneUIGroupCard(
                          margin: EdgeInsets.zero,
                          children: records.map((SonarrHistoryRecord record) {
                            final (icon, color) = _getEventVisuals(record.eventType);
                            final String formattedTime =
                                DateFormat.jm().format(record.date.toLocal());

                            final String? indexer = record.data['indexer'] as String?;
                            final String? client = record.data['downloadClient'] as String?;
                            final Map<String, dynamic>? qualityMap =
                                record.quality?['quality'] as Map<String, dynamic>?;
                            final String? qualityName = qualityMap?['name'] as String?;

                            final List<String> details = [
                              if (indexer != null) 'Indexer: $indexer',
                              if (client != null) 'Client: $client',
                              if (qualityName != null) 'Quality: $qualityName',
                            ];

                            return ListTile(
                              splashColor: color.withValues(alpha: 0.1),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                              leading: CircleAvatar(
                                backgroundColor: color.withValues(alpha: 0.12),
                                child: Icon(icon, color: color),
                              ),
                              title: Text(
                                record.sourceTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2,),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          _formatEventType(record.eventType),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: color,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (details.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      details.join(' • '),
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Theme.of(context).colorScheme.outline,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                              isThreeLine: details.isNotEmpty,
                              trailing: Text(
                                formattedTime,
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              onTap: () => _pushSeriesDetail(
                                context,
                                widget.instance,
                                record.seriesId,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ),
        // Floating date pill
        if (_activeDate.isNotEmpty)
          Positioned(
            top: 24,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: AnimatedOpacity(
                  opacity: _pillOpacity,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      _activeDate,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  (IconData, Color) _getEventVisuals(String eventType) {
    return switch (eventType) {
      'grabbed' => (Icons.downloading, Colors.blue),
      'downloadFolderImported' => (Icons.download_done, Colors.green),
      'episodeFileDeleted' => (Icons.delete_outline, Colors.red),
      'failed' => (Icons.error_outline, Colors.orange),
      _ => (Icons.info_outline, Colors.grey),
    };
  }

  String _formatEventType(String eventType) {
    final matches = RegExp(r'[A-Z]?[a-z]+|[A-Z]+(?=[A-Z]|$)');
    final words = matches.allMatches(eventType).map((m) => m.group(0)!).toList();
    if (words.isEmpty) return eventType;
    return words.map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  }
}
