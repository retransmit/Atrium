import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/technitium_query_log.dart';
import '../technitium_providers.dart';
import '../widgets/technitium_query_detail_modal.dart';
import '../widgets/technitium_query_log_row.dart';

/// Paginated query log viewer with filters and one-tap blocking.
class TechnitiumQueryLogTab extends ConsumerStatefulWidget {
  const TechnitiumQueryLogTab({
    required this.instance,
    super.key,
  });

  final Instance instance;

  @override
  ConsumerState<TechnitiumQueryLogTab> createState() =>
      _TechnitiumQueryLogTabState();
}

class _TechnitiumQueryLogTabState extends ConsumerState<TechnitiumQueryLogTab> {
  late final TextEditingController _searchController;

  Instance get _instance => widget.instance;
  TechnitiumActions get _actions =>
      ref.read(technitiumActionsProvider(_instance));

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(technitiumQueryLogSearchProvider(_instance)),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _blockDomain(String domain) async {
    try {
      await _actions.addBlockedZone(domain);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added $domain to Blocked Zones')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to block domain: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    final String selectedFilter =
        ref.watch(technitiumQueryLogFilterProvider(_instance));
    final int currentPage =
        ref.watch(technitiumQueryLogPageProvider(_instance));
    final AsyncValue<TechnitiumQueryLogPage> logPageAsync =
        ref.watch(technitiumQueryLogProvider(_instance));

    final List<String> filterOptions = <String>[
      'All',
      'Blocked',
      'Cached',
      'Recursive',
      'Authoritative',
    ];

    return Column(
      children: <Widget>[
        // Search & Filter header
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.md,
            Insets.md,
            Insets.md,
            Insets.xs,
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search domain or client...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        ref
                            .read(
                              technitiumQueryLogSearchProvider(_instance)
                                  .notifier,
                            )
                            .state = '';
                        ref
                            .read(
                              technitiumQueryLogPageProvider(_instance)
                                  .notifier,
                            )
                            .state = 1;
                      },
                    )
                  : null,
              filled: true,
              fillColor: cs.surfaceContainerHigh,
              contentPadding: const EdgeInsets.symmetric(horizontal: Insets.md),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (String val) {
              ref
                  .read(technitiumQueryLogSearchProvider(_instance).notifier)
                  .state = val.trim();
              ref
                  .read(technitiumQueryLogPageProvider(_instance).notifier)
                  .state = 1;
            },
          ),
        ),

        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.md,
            vertical: Insets.xs,
          ),
          child: Row(
            children: <Widget>[
              for (final String option in filterOptions) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.only(right: Insets.xs),
                  child: FilterChip(
                    label: Text(option),
                    selected:
                        selectedFilter.toLowerCase() == option.toLowerCase(),
                    onSelected: (bool selected) {
                      ref
                          .read(
                            technitiumQueryLogFilterProvider(_instance)
                                .notifier,
                          )
                          .state = selected ? option : 'All';
                      ref
                          .read(
                            technitiumQueryLogPageProvider(_instance).notifier,
                          )
                          .state = 1;
                    },
                  ),
                ),
              ],
            ],
          ),
        ),

        const Divider(height: 1),

        // Query log list
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(technitiumQueryLogProvider(_instance)),
            child: logPageAsync.when(
              data: (TechnitiumQueryLogPage page) {
                if (page.entries.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: <Widget>[
                      const SizedBox(height: Insets.xl * 2),
                      Center(
                        child: Text(
                          'No queries found',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return ListView.separated(
                  itemCount: page.entries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (BuildContext ctx, int index) {
                    final TechnitiumQueryEntry entry = page.entries[index];
                    return TechnitiumQueryLogRow(
                      entry: entry,
                      onTap: () => TechnitiumQueryDetailModal.show(
                        context,
                        entry: entry,
                        onBlockDomain: _blockDomain,
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(Insets.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.error_outline, size: 36, color: cs.error),
                      const SizedBox(height: Insets.sm),
                      Text('Error loading logs: $e'),
                      const SizedBox(height: Insets.md),
                      FilledButton(
                        onPressed: () => ref
                            .invalidate(technitiumQueryLogProvider(_instance)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // Pagination row
        logPageAsync.maybeWhen(
          data: (TechnitiumQueryLogPage page) => Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.md,
              vertical: Insets.xs,
            ),
            color: cs.surfaceContainerHigh,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'Page $currentPage of ${page.totalPages.clamp(1, 9999)} (${page.totalEntries} queries)',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                Row(
                  children: <Widget>[
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: currentPage > 1
                          ? () => ref
                              .read(
                                technitiumQueryLogPageProvider(_instance)
                                    .notifier,
                              )
                              .state--
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: currentPage < page.totalPages
                          ? () => ref
                              .read(
                                technitiumQueryLogPageProvider(_instance)
                                    .notifier,
                              )
                              .state++
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
