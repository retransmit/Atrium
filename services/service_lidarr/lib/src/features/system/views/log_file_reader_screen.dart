import 'dart:async';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/lidarr_formatters.dart';
import '../../../generated/generated.dart';
import '../../../lidarr_providers.dart';
import '../log_file_save.dart';

/// High-performance, virtualized in-app log viewer for Lidarr log files.
class LogFileReaderScreen extends ConsumerStatefulWidget {
  const LogFileReaderScreen({
    required this.instance,
    required this.file,
    super.key,
  });

  final Instance instance;
  final LogFileResource file;

  @override
  ConsumerState<LogFileReaderScreen> createState() =>
      _LogFileReaderScreenState();
}

class _LogFileReaderScreenState extends ConsumerState<LogFileReaderScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  Timer? _debounceTimer;
  bool _isSearching = false;
  String _searchQuery = '';
  String _selectedLevelFilter = 'ALL';
  int _currentMatchIndex = 0;
  List<int> _matchedIndices = [];

  static const double _estimatedLineHeight = 22.0;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query, List<String> lines) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      final String trimmed = query.trim().toLowerCase();
      final List<int> matches = <int>[];

      if (trimmed.isNotEmpty) {
        for (int i = 0; i < lines.length; i++) {
          if (lines[i].toLowerCase().contains(trimmed)) {
            matches.add(i);
          }
        }
      }

      setState(() {
        _searchQuery = trimmed;
        _matchedIndices = matches;
        _currentMatchIndex = 0;
      });

      if (matches.isNotEmpty) {
        _scrollToLine(matches[0], lines.length);
      }
    });
  }

  void _scrollToLine(int lineIndex, int totalLines) {
    if (!_scrollController.hasClients) return;
    final double targetOffset = lineIndex * _estimatedLineHeight;
    final double maxScroll = _scrollController.position.maxScrollExtent;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, maxScroll),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  void _nextMatch(int totalLines) {
    if (_matchedIndices.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _matchedIndices.length;
    });
    _scrollToLine(_matchedIndices[_currentMatchIndex], totalLines);
  }

  void _previousMatch(int totalLines) {
    if (_matchedIndices.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex - 1 + _matchedIndices.length) %
          _matchedIndices.length;
    });
    _scrollToLine(_matchedIndices[_currentMatchIndex], totalLines);
  }

  void _jumpToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _jumpToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _copyFullLog(String content) async {
    await Clipboard.setData(ClipboardData(text: content));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Copied "${widget.file.filename ?? 'Log'}" (${content.length} chars)',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _downloadLogFile() => saveLidarrLogFile(
        context,
        filename: widget.file.filename ?? 'lidarr.txt',
        read: () => ref.read(
          lidarrLogFileContentProvider(
            (
              widget.instance,
              filename: widget.file.filename ?? '',
              contentsUrl: widget.file.contentsUrl,
              downloadUrl: widget.file.downloadUrl,
            ),
          ).future,
        ),
      );

  Color _getLineColor(String line, ColorScheme cs) {
    final String lower = line.toLowerCase();
    if (lower.contains('|fatal|') ||
        lower.contains('|error|') ||
        lower.contains('[fatal]') ||
        lower.contains('[error]')) {
      return cs.error;
    }
    if (lower.contains('|warn|') ||
        lower.contains('|warning|') ||
        lower.contains('[warn]') ||
        lower.contains('[warning]')) {
      return cs.tertiary;
    }
    if (lower.contains('|info|') || lower.contains('[info]')) {
      return cs.primary;
    }
    if (lower.contains('|debug|') ||
        lower.contains('|trace|') ||
        lower.contains('[debug]') ||
        lower.contains('[trace]')) {
      return cs.onSurfaceVariant;
    }
    return cs.onSurface;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;

    final AsyncValue<String> asyncContent = ref.watch(
      lidarrLogFileContentProvider(
        (
          widget.instance,
          filename: widget.file.filename ?? '',
          contentsUrl: widget.file.contentsUrl,
          downloadUrl: widget.file.downloadUrl,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                style: TextStyle(color: cs.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search in log...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
                onChanged: (String val) {
                  asyncContent.whenData((String content) {
                    final List<String> lines = content.split('\n');
                    _onSearchChanged(val, lines);
                  });
                },
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.file.filename ?? 'Log File',
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (widget.file.lastWriteTime != null)
                    Text(
                      LidarrFormatters.formatDate(widget.file.lastWriteTime),
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
        actions: [
          if (_isSearching) ...[
            if (_matchedIndices.isNotEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '${_currentMatchIndex + 1}/${_matchedIndices.length}',
                    style: tt.bodySmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up),
              tooltip: 'Previous match',
              onPressed: () {
                asyncContent.whenData((String content) {
                  _previousMatch(content.split('\n').length);
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down),
              tooltip: 'Next match',
              onPressed: () {
                asyncContent.whenData((String content) {
                  _nextMatch(content.split('\n').length);
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Close search',
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                  _searchQuery = '';
                  _matchedIndices = [];
                });
              },
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search in log',
              onPressed: () {
                setState(() => _isSearching = true);
              },
            ),
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy all to clipboard',
              onPressed: () {
                asyncContent.whenData(_copyFullLog);
              },
            ),
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Download log file',
              onPressed: _downloadLogFile,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () {
                ref.invalidate(
                  lidarrLogFileContentProvider(
                    (
                      widget.instance,
                      filename: widget.file.filename ?? '',
                      contentsUrl: widget.file.contentsUrl,
                      downloadUrl: widget.file.downloadUrl,
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
      body: AsyncValueView<String>(
        value: asyncContent,
        data: (String content) {
          if (content.trim().isEmpty) {
            return const Center(
              child: EmptyView(
                icon: Icons.article_outlined,
                title: 'Empty Log File',
                message: 'This log file contains no entries yet.',
              ),
            );
          }

          final List<String> allLines = content.split('\n');

          // Apply level filter if active
          final List<(int originalIndex, String text)> displayLines = [];
          for (int i = 0; i < allLines.length; i++) {
            final String line = allLines[i];
            if (_selectedLevelFilter != 'ALL') {
              final String lower = line.toLowerCase();
              final bool matchesFilter = switch (_selectedLevelFilter) {
                'ERROR' => lower.contains('error') || lower.contains('fatal'),
                'WARN' => lower.contains('warn'),
                'INFO' => lower.contains('info'),
                'DEBUG' => lower.contains('debug') || lower.contains('trace'),
                _ => true,
              };
              if (!matchesFilter) continue;
            }
            displayLines.add((i, line));
          }

          return Column(
            children: [
              // Level filter toolbar
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  border: Border(
                    bottom: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '${displayLines.length} lines',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    ...<String>['ALL', 'ERROR', 'WARN', 'INFO', 'DEBUG'].map(
                      (String lvl) {
                        final bool isSelected = _selectedLevelFilter == lvl;
                        return Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () {
                              setState(() => _selectedLevelFilter = lvl);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? cs.primaryContainer
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                lvl,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? cs.onPrimaryContainer
                                      : cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: displayLines.length,
                      itemBuilder: (BuildContext context, int index) {
                        final (int originalIndex, String line) =
                            displayLines[index];
                        final bool isMatched = _searchQuery.isNotEmpty &&
                            line.toLowerCase().contains(_searchQuery);
                        final bool isCurrentMatch =
                            _matchedIndices.isNotEmpty &&
                                _currentMatchIndex < _matchedIndices.length &&
                                _matchedIndices[_currentMatchIndex] ==
                                    originalIndex;

                        final Color lineColor = _getLineColor(line, cs);

                        return Container(
                          color: isCurrentMatch
                              ? cs.primaryContainer.withValues(alpha: 0.3)
                              : (isMatched
                                  ? cs.tertiaryContainer.withValues(alpha: 0.2)
                                  : null),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 1,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 44,
                                child: Text(
                                  (originalIndex + 1).toString(),
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    color: cs.onSurfaceVariant
                                        .withValues(alpha: 0.4),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: SelectableText(
                                  line,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11.5,
                                    color: isCurrentMatch
                                        ? cs.primary
                                        : (isMatched ? cs.tertiary : lineColor),
                                    fontWeight: isCurrentMatch || isMatched
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FloatingActionButton.small(
                            heroTag: 'log_scroll_top',
                            onPressed: _jumpToTop,
                            tooltip: 'Jump to top',
                            backgroundColor: cs.surfaceContainerHigh,
                            foregroundColor: cs.onSurface,
                            child: const Icon(Icons.arrow_upward, size: 18),
                          ),
                          const SizedBox(height: 8),
                          FloatingActionButton.small(
                            heroTag: 'log_scroll_bottom',
                            onPressed: _jumpToBottom,
                            tooltip: 'Jump to bottom',
                            backgroundColor: cs.primaryContainer,
                            foregroundColor: cs.onPrimaryContainer,
                            child: const Icon(Icons.arrow_downward, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
