import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/prowlarr_history.dart';
import 'models/prowlarr_indexer.dart';
import 'prowlarr_providers.dart';
import 'package:m3_expressive/m3_expressive.dart';

/// History tab: recent indexer queries, grabs and auth events, newest first.
/// A server-side event-type filter keeps RSS syncs (which flood the feed) from
/// burying grabs and queries.
class ProwlarrHistoryTab extends ConsumerStatefulWidget {
  const ProwlarrHistoryTab({required this.instance, super.key});

  final Instance instance;

  @override
  ConsumerState<ProwlarrHistoryTab> createState() => _ProwlarrHistoryTabState();
}

class _ProwlarrHistoryTabState extends ConsumerState<ProwlarrHistoryTab> {
  // null = all; 1 grabbed, 2 query, 3 RSS (HistoryEventType).
  int? _eventType;

  static const List<(String, int?)> _filters = <(String, int?)>[
    ('All', null),
    ('Grabbed', 1),
    ('Queries', 2),
    ('RSS', 3),
  ];

  @override
  Widget build(BuildContext context) {
    final Instance instance = widget.instance;
    final ProwlarrHistoryArgs args =
        (instance: instance, eventType: _eventType);
    final AsyncValue<ProwlarrHistoryPage> history =
        ref.watch(prowlarrHistoryProvider(args));
    final List<ProwlarrIndexer> indexers =
        ref.watch(prowlarrIndexersProvider(instance)).value ??
            const <ProwlarrIndexer>[];
    final Map<int, String> names = <int, String>{
      for (final ProwlarrIndexer ix in indexers) ix.id: ix.name,
    };

    return Column(
      children: <Widget>[
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: Insets.pageH,
            children: <Widget>[
              for (final (String label, int? type) in _filters)
                Padding(
                  padding: const EdgeInsets.only(right: Insets.sm),
                  child: Center(
                    child: FilterChip(
                      label: Text(label),
                      selected: _eventType == type,
                      onSelected: (_) => setState(() => _eventType = type),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: M3RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(prowlarrHistoryProvider(args)),
            child: AsyncValueView<ProwlarrHistoryPage>(
              value: history,
              onRetry: () => ref.invalidate(prowlarrHistoryProvider(args)),
              data: (ProwlarrHistoryPage page) {
                if (page.records.isEmpty) {
                  return const EmptyView(
                    icon: Icons.history,
                    title: 'No history',
                    message: 'Nothing matches this filter yet.',
                  );
                }
                return ListView.separated(
                  padding: Insets.page,
                  itemCount: page.records.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: Insets.sm),
                  itemBuilder: (BuildContext context, int index) {
                    final ProwlarrHistoryRecord r = page.records[index];
                    return _HistoryTile(
                      record: r,
                      indexerName: names[r.indexerId],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.record, this.indexerName});

  final ProwlarrHistoryRecord record;
  final String? indexerName;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final (IconData icon, String label) = _event(record.eventType);
    final bool failed = record.successful == false;
    final Color accent = failed ? cs.error : _eventColor(record.eventType, cs);

    final String detail = _detail(record);
    final String meta = <String>[
      if (indexerName != null && indexerName!.isNotEmpty) indexerName!,
      _relative(record.date),
    ].where((String s) => s.isNotEmpty).join(' • ');

    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: accent),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    detail.isEmpty ? label : detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail.isEmpty ? meta : '$label • $meta',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Accent for the leading badge by event type (failed grabs override to error
  /// in [build]).
  Color _eventColor(String type, ColorScheme cs) {
    switch (type) {
      case 'releaseGrabbed':
        return cs.tertiary;
      case 'indexerQuery':
        return cs.primary;
      case 'indexerRss':
        return cs.secondary;
      case 'indexerAuth':
      case 'indexerStatusChanged':
        return cs.secondary;
      default:
        return cs.primary;
    }
  }

  (IconData, String) _event(String type) {
    switch (type) {
      case 'releaseGrabbed':
        return (Icons.download_outlined, 'Grabbed');
      case 'indexerQuery':
        return (Icons.search, 'Query');
      case 'indexerRss':
        return (Icons.rss_feed, 'RSS');
      case 'indexerAuth':
        return (Icons.vpn_key_outlined, 'Auth');
      case 'indexerStatusChanged':
        return (Icons.sync_problem, 'Status changed');
      default:
        return (Icons.history, type.isEmpty ? 'Event' : type);
    }
  }

  /// The most useful single line for a record, drawn from its loose [data] bag.
  ///
  /// For a grab that is the release title (Prowlarr stores it under `GrabTitle`,
  /// camelCased to `grabTitle` on output); for a query/RSS it is the search
  /// term. Looked up case-insensitively so either casing works.
  String _detail(ProwlarrHistoryRecord r) {
    final String? grab = _ci(r.data, 'grabtitle');
    if (grab != null) {
      return grab;
    }
    final String? query = _ci(r.data, 'query');
    if (query != null) {
      return '"$query"';
    }
    return '';
  }

  /// Case-insensitive lookup into the loose data bag; null if missing/empty.
  String? _ci(Map<String, dynamic> data, String key) {
    for (final MapEntry<String, dynamic> e in data.entries) {
      if (e.key.toLowerCase() == key) {
        final String s = (e.value ?? '').toString();
        return s.isEmpty ? null : s;
      }
    }
    return null;
  }

  String _relative(DateTime? date) {
    if (date == null) {
      return '';
    }
    final DateTime local = date.toLocal();
    final Duration diff = DateTime.now().difference(local);
    if (diff.inSeconds < 60) {
      return 'just now';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    }
    final String m = local.month.toString().padLeft(2, '0');
    final String day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$m-$day';
  }
}
