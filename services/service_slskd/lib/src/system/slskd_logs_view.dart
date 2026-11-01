import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/slskd_system_models.dart';
import '../slskd_format.dart';
import '../slskd_providers.dart';

/// View displaying live slskd logs with severity filter chips, text search, and monospaced log stream tiles.
class SlskdLogsView extends ConsumerStatefulWidget {
  const SlskdLogsView({
    required this.instance,
    super.key,
  });

  final Instance instance;

  @override
  ConsumerState<SlskdLogsView> createState() => _SlskdLogsViewState();
}

class _SlskdLogsViewState extends ConsumerState<SlskdLogsView> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(slskdLogSearchQueryProvider(widget.instance)),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showLogDetails(SlskdLogRecord log) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        final ColorScheme cs = Theme.of(ctx).colorScheme;
        final TextTheme tt = Theme.of(ctx).textTheme;

        return DraggableScrollableSheet(
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (BuildContext context, ScrollController scrollCtrl) {
            return SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(Insets.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: Insets.md),
                      decoration: BoxDecoration(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Insets.sm,
                          vertical: Insets.xs / 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getSeverityBg(log.level, cs),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          log.level.toUpperCase(),
                          style: tt.labelSmall?.copyWith(
                            color: _getSeverityText(log.level, cs),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: Insets.sm),
                      Expanded(
                        child: Text(
                          slskdFormatDateTime(log.timestamp),
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 20),
                        tooltip: 'Copy message',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: log.message));
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Log copied to clipboard'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  if (log.context != null) ...<Widget>[
                    const SizedBox(height: Insets.sm),
                    Text(
                      'Context: ${log.context}',
                      style: tt.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                    ),
                  ],
                  if (log.subContext != null) ...<Widget>[
                    const SizedBox(height: Insets.xs),
                    Text(
                      'SubContext: ${log.subContext}',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: Insets.md),
                  const Divider(),
                  const SizedBox(height: Insets.sm),
                  Text(
                    'Log Message',
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: Insets.xs),
                  SelectableText(
                    log.message,
                    style: tt.bodyMedium,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _getSeverityBg(String level, ColorScheme cs) {
    final l = level.toLowerCase();
    if (l.contains('error') || l.contains('fatal')) return cs.errorContainer;
    if (l.contains('warn')) return cs.tertiaryContainer;
    if (l.contains('info')) return cs.secondaryContainer;
    return cs.surfaceContainerHighest;
  }

  Color _getSeverityText(String level, ColorScheme cs) {
    final l = level.toLowerCase();
    if (l.contains('error') || l.contains('fatal')) return cs.onErrorContainer;
    if (l.contains('warn')) return cs.onTertiaryContainer;
    if (l.contains('info')) return cs.onSecondaryContainer;
    return cs.onSurfaceVariant;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final selectedHistoricalLog =
        ref.watch(slskdSelectedHistoricalLogProvider(widget.instance));
    final logFilesAsync = ref.watch(slskdLogFilesProvider(widget.instance));

    // slskd rotates its log files. When a refresh no longer lists the one
    // being viewed, fall back to the live stream rather than keep asking
    // for a file that is gone.
    ref.listen<AsyncValue<List<SlskdDiskFile>>>(
      slskdLogFilesProvider(widget.instance),
      (_, AsyncValue<List<SlskdDiskFile>> next) {
        final List<SlskdDiskFile>? files = next.value;
        final String? selected =
            ref.read(slskdSelectedHistoricalLogProvider(widget.instance));
        if (files != null &&
            selected != null &&
            !files.any((SlskdDiskFile f) => f.name == selected)) {
          ref.read(slskdSelectedHistoricalLogProvider(widget.instance).notifier).state =
              null;
        }
      },
    );

    final selectedSeverity =
        ref.watch(slskdLogSeverityFilterProvider(widget.instance));
    final filteredLogsAsync =
        ref.watch(slskdFilteredLogsProvider(widget.instance));

    final List<String> severities = <String>[
      'All',
      'Error',
      'Warning',
      'Information',
      'Debug',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Log Source Selector
        logFilesAsync.maybeWhen(
          data: (files) {
            if (files.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: Insets.sm),
              child: Row(
                children: <Widget>[
                  Text(
                    'Log Source:',
                    style: textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          // Exactly one item must match the value, so a file
                          // that is no longer listed cannot be passed in.
                          value: files.any((f) => f.name == selectedHistoricalLog)
                              ? selectedHistoricalLog
                              : null,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down_rounded),
                          items: [
                            const DropdownMenuItem<String?>(
                              child: Row(
                                children: <Widget>[
                                  Icon(Icons.stream_rounded, size: 18),
                                  SizedBox(width: Insets.xs),
                                  Text('Live Stream (In-Memory)'),
                                ],
                              ),
                            ),
                            ...files.map(
                              (f) => DropdownMenuItem<String?>(
                                value: f.name,
                                child: Row(
                                  children: <Widget>[
                                    const Icon(Icons.description_outlined, size: 18),
                                    const SizedBox(width: Insets.xs),
                                    Expanded(
                                      child: Text(
                                        '${f.name} (${slskdFormatBytes(f.length)})',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            ref
                                .read(
                                  slskdSelectedHistoricalLogProvider(widget.instance).notifier,
                                )
                                .state = val;
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),

        if (selectedHistoricalLog != null)
          _buildHistoricalLogViewer(
            context,
            filename: selectedHistoricalLog,
            colorScheme: colorScheme,
            textTheme: textTheme,
          )
        else ...<Widget>[
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search logs by message or context...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        ref
                            .read(
                              slskdLogSearchQueryProvider(widget.instance).notifier,
                            )
                            .state = '';
                      },
                    )
                  : null,
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: Insets.md,
                vertical: Insets.sm,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (String val) {
              ref
                  .read(slskdLogSearchQueryProvider(widget.instance).notifier)
                  .state = val;
            },
          ),
          const SizedBox(height: Insets.sm),
          // Severity Chips with horizontal scroll affordance
          ShaderMask(
            shaderCallback: (Rect bounds) {
              return const LinearGradient(
                colors: <Color>[Colors.white, Colors.white, Colors.transparent],
                stops: <double>[0.0, 0.92, 1.0],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: severities.map((String severity) {
                  final bool isSelected = selectedSeverity.toLowerCase() ==
                      severity.toLowerCase();
                  return Padding(
                    padding: const EdgeInsets.only(right: Insets.xs),
                    child: FilterChip(
                      label: Text(severity),
                      selected: isSelected,
                      onSelected: (bool selected) {
                        ref
                            .read(
                              slskdLogSeverityFilterProvider(widget.instance).notifier,
                            )
                            .state = selected ? severity : 'All';
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: Insets.sm),
          // Log stream
          filteredLogsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(Insets.xl),
              child: ExpressiveProgressIndicator(),
            ),
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: Text(
                'Failed to load logs: $error',
                style: TextStyle(color: colorScheme.error),
              ),
            ),
          ),
          data: (logs) {
            if (logs.isEmpty) {
              return Card(
                elevation: 0,
                color: colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(Insets.xl),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.article_outlined,
                          size: 40,
                          color:
                              colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: Insets.sm),
                        Text(
                          'No Logs Found',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: Insets.xs),
                        Text(
                          'No log records match current severity or search query.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.xs,
                    vertical: Insets.xs,
                  ),
                  child: Text(
                    '${logs.length} log records',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
                ...logs.map((SlskdLogRecord log) {
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: Insets.xs),
                    color: colorScheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _showLogDetails(log),
                      child: Padding(
                        padding: const EdgeInsets.all(Insets.sm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: Insets.xs,
                                    vertical: Insets.xs / 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getSeverityBg(log.level, colorScheme),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    log.level.toUpperCase(),
                                    style: textTheme.labelSmall?.copyWith(
                                      color: _getSeverityText(
                                        log.level,
                                        colorScheme,
                                      ),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: Insets.xs),
                                Text(
                                  slskdFormatTimeWithSeconds(log.timestamp),
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                                if (log.context != null) ...<Widget>[
                                  const SizedBox(width: Insets.xs),
                                  Expanded(
                                    child: Text(
                                      log.context!,
                                      style: textTheme.bodySmall?.copyWith(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: Insets.xs / 2),
                            Text(
                              log.message,
                              style: textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        ),
        ],
      ],
    );
  }

  Widget _buildHistoricalLogViewer(
    BuildContext context, {
    required String filename,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    final logContentAsync =
        ref.watch(slskdLogFileContentProvider((widget.instance, filename)));

    return logContentAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(Insets.xl),
          child: ExpressiveProgressIndicator(),
        ),
      ),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Text(
            'Failed to read log file: $err',
            style: TextStyle(color: colorScheme.error),
          ),
        ),
      ),
      data: (content) {
        final lines = content.split('\n');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '$filename • ${lines.length} lines',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  tooltip: 'Copy all log content',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Historical log copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: Insets.xs),
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 500),
                padding: const EdgeInsets.all(Insets.sm),
                child: SingleChildScrollView(
                  child: SelectableText(
                    content.isEmpty ? '(Empty log file)' : content,
                    style: textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
