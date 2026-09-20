import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'qbittorrent_providers.dart';

/// The Logs tab for qBittorrent displaying execution logs from `/api/v2/log/main`.
class QbittorrentLogsTab extends ConsumerStatefulWidget {
  const QbittorrentLogsTab({required this.instance, super.key});

  final Instance instance;

  @override
  ConsumerState<QbittorrentLogsTab> createState() => _QbittorrentLogsTabState();
}

class _QbittorrentLogsTabState extends ConsumerState<QbittorrentLogsTab> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';
  QbitLogLevel? _selectedLevel;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final String query = _searchController.text.trim().toLowerCase();
      if (query != _searchQuery) {
        setState(() => _searchQuery = query);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// The most text one copy puts on the clipboard.
  ///
  /// Android hands clipboard text to the system in a single binder call,
  /// which is refused outright past about a megabyte. qBittorrent keeps up to
  /// 20,000 log entries, and copying all of them came to 1.3 MB and failed.
  static const int _maxCopyChars = 100000;

  Future<void> _copyLogs(List<QbitLogEntry> logs) async {
    if (logs.isEmpty) return;
    // The newest entries that fit, put back in the order they happened.
    final List<String> lines = <String>[];
    int chars = 0;
    for (final QbitLogEntry entry in logs.reversed) {
      final String line = _copyLine(entry);
      if (lines.isNotEmpty && chars + line.length > _maxCopyChars) break;
      lines.add(line);
      chars += line.length + 1;
    }
    final int total = logs.length;
    await _copyToClipboard(
      lines.reversed.join('\n'),
      lines.length == total
          ? 'Copied $total log ${total == 1 ? "entry" : "entries"} to clipboard'
          : 'Copied the newest ${lines.length} of $total log entries to '
              'clipboard',
      const Duration(seconds: 2),
    );
  }

  Future<void> _copyLogEntry(QbitLogEntry entry) => _copyToClipboard(
        _copyLine(entry),
        'Log entry copied to clipboard',
        const Duration(seconds: 1),
      );

  String _copyLine(QbitLogEntry entry) =>
      '[${entry.timeText}] [${entry.level.label.toUpperCase()}] ${entry.message}';

  /// Copies [text], then says whether it worked.
  ///
  /// The platform can refuse the write, and a success message shown anyway
  /// leaves someone pasting whatever was on the clipboard before.
  Future<void> _copyToClipboard(
    String text,
    String copiedMessage,
    Duration duration,
  ) async {
    String message = copiedMessage;
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } on PlatformException {
      message = 'Could not copy to the clipboard';
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: duration),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    // Listen to scroll to top signal from bottom nav tap (index 2 is Logs)
    ref.listen<int>(
      qbitHomeScrollToTopProvider((widget.instance, 2)),
      (_, __) => _scrollToTop(),
    );

    final AsyncValue<List<QbitLogEntry>> logsAsync =
        ref.watch(qbitLogsProvider(widget.instance));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: theme.textTheme.titleMedium,
                decoration: InputDecoration(
                  hintText: 'Search logs...',
                  border: InputBorder.none,
                  hintStyle: theme.textTheme.titleMedium
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              )
            : Text('${widget.instance.name} Logs'),
        actions: <Widget>[
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Close search',
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                  _searchQuery = '';
                });
              },
            )
          else ...<Widget>[
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search logs',
              onPressed: () => setState(() => _isSearching = true),
            ),
            IconButton(
              icon: const Icon(Icons.copy_all_outlined),
              // It copies what the filter and search leave, not everything.
              tooltip: 'Copy logs',
              onPressed: () {
                final List<QbitLogEntry>? currentLogs = logsAsync.value;
                if (currentLogs != null) {
                  final List<QbitLogEntry> filtered = _filterLogs(currentLogs);
                  _copyLogs(filtered);
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () => ref.invalidate(qbitLogsProvider(widget.instance)),
            ),
          ],
          const SizedBox(width: Insets.xs),
        ],
      ),
      body: Column(
        children: <Widget>[
          _buildFilterChips(cs),
          const Divider(height: 1),
          Expanded(
            child: AsyncValueView<List<QbitLogEntry>>(
              value: logsAsync,
              onRetry: () => ref.invalidate(qbitLogsProvider(widget.instance)),
              data: (List<QbitLogEntry> allLogs) {
                final List<QbitLogEntry> filtered = _filterLogs(allLogs);

                if (filtered.isEmpty) {
                  return EmptyView(
                    icon: Icons.article_outlined,
                    title: allLogs.isEmpty
                        ? 'No logs available'
                        : 'No matching logs',
                    message: allLogs.isEmpty
                        ? 'qBittorrent has not reported any log entries yet.'
                        : 'Try changing your search query or level filter.',
                  );
                }

                // Show newest logs at top by reversing the list
                final List<QbitLogEntry> reversed = filtered.reversed.toList();

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
                    ref.invalidate(qbitLogsProvider(widget.instance));
                    await ref.read(qbitLogsProvider(widget.instance).future);
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(
                      top: Insets.xs,
                      bottom: 80,
                    ),
                    itemCount: reversed.length,
                    itemBuilder: (BuildContext context, int index) {
                      final QbitLogEntry entry = reversed[index];
                      return _LogCard(
                        entry: entry,
                        onTap: () => _copyLogEntry(entry),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<QbitLogEntry> _filterLogs(List<QbitLogEntry> logs) {
    return logs.where((QbitLogEntry e) {
      if (_selectedLevel != null && e.level != _selectedLevel) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        return e.message.toLowerCase().contains(_searchQuery);
      }
      return true;
    }).toList();
  }

  Widget _buildFilterChips(ColorScheme cs) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.xs,
      ),
      child: Row(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: Insets.xs),
            child: FilterChip(
              selected: _selectedLevel == null,
              label: const Text('All'),
              onSelected: (_) => setState(() => _selectedLevel = null),
            ),
          ),
          for (final QbitLogLevel level in QbitLogLevel.values)
            Padding(
              padding: const EdgeInsets.only(right: Insets.xs),
              child: FilterChip(
                selected: _selectedLevel == level,
                label: Text(level.label),
                onSelected: (bool selected) {
                  setState(() => _selectedLevel = selected ? level : null);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _LogVisual {
  const _LogVisual({
    required this.color,
    required this.container,
    required this.onContainer,
    required this.icon,
  });

  final Color color;
  final Color container;
  final Color onContainer;
  final IconData icon;
}

_LogVisual _visualForLevel(QbitLogLevel level, ColorScheme cs) {
  return switch (level) {
    QbitLogLevel.critical => _LogVisual(
        color: cs.error,
        container: cs.errorContainer,
        onContainer: cs.onErrorContainer,
        icon: Icons.error_outline_rounded,
      ),
    QbitLogLevel.warning => _LogVisual(
        color: cs.secondary,
        container: cs.secondaryContainer,
        onContainer: cs.onSecondaryContainer,
        icon: Icons.warning_amber_rounded,
      ),
    QbitLogLevel.info => _LogVisual(
        color: cs.tertiary,
        container: cs.tertiaryContainer,
        onContainer: cs.onTertiaryContainer,
        icon: Icons.info_outline_rounded,
      ),
    QbitLogLevel.normal => _LogVisual(
        color: cs.primary,
        container: cs.primaryContainer,
        onContainer: cs.onPrimaryContainer,
        icon: Icons.article_rounded,
      ),
  };
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.label, required this.visual});

  final String label;
  final _LogVisual visual;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: visual.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(visual.icon, size: 12, color: visual.color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: visual.color,
                ),
          ),
        ],
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({required this.entry, required this.onTap});

  final QbitLogEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final _LogVisual v = _visualForLevel(entry.level, cs);

    final Widget tile = Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: v.container,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  v.icon,
                  size: 22,
                  color: v.onContainer,
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entry.message,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        _StatePill(
                          label: entry.level.label.toUpperCase(),
                          visual: v,
                        ),
                        const SizedBox(width: Insets.sm),
                        Expanded(
                          child: Text(
                            entry.timeText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        Icon(
                          Icons.copy_outlined,
                          size: 14,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.md,
        Insets.xs,
        Insets.md,
        Insets.xs,
      ),
      child: tile,
    );
  }
}
