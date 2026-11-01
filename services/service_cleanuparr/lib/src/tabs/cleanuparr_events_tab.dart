import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cleanuparr_errors.dart';
import '../cleanuparr_providers.dart';
import '../models/cleanuparr_event.dart';
import '../widgets/cleanuparr_event_card.dart';

/// Tab 2: Historical audit and security events with category filters and diagnostics sheet.
class CleanuparrEventsTab extends ConsumerStatefulWidget {
  const CleanuparrEventsTab({
    required this.instance,
    this.onOpenDrawer,
    super.key,
  });

  final Instance instance;
  final VoidCallback? onOpenDrawer;

  @override
  ConsumerState<CleanuparrEventsTab> createState() => _CleanuparrEventsTabState();
}

class _CleanuparrEventsTabState extends ConsumerState<CleanuparrEventsTab> {
  late final TextEditingController _searchController;
  Timer? _debounceTimer;

  static const List<(String label, String? filterKey)> _filters = [
    ('All', null),
    ('Malware', 'malware'),
    ('Strikes', 'strike'),
    ('Deletions', 'delet'),
    ('Cleaned', 'clean'),
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(cleanuparrEventsSearchProvider(widget.instance)),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(cleanuparrEventsProvider(widget.instance));
    await ref.read(cleanuparrEventsProvider(widget.instance).future);
  }

  @override
  Widget build(BuildContext context) {
    // Keep the text field in sync when the shell's back-press handler resets
    // the provider; initState alone would leave stale text in the controller.
    ref.listen<String>(cleanuparrEventsSearchProvider(widget.instance), (
      String? previous,
      String next,
    ) {
      if (next.isEmpty && _searchController.text.isNotEmpty) {
        // A keystroke still waiting on the debounce would put the old
        // search back after this reset.
        _debounceTimer?.cancel();
        _searchController.clear();
      }
    });

    final eventsAsync = ref.watch(cleanuparrEventsProvider(widget.instance));
    final String? activeFilter =
        ref.watch(cleanuparrEventsFilterProvider(widget.instance));

    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: widget.onOpenDrawer != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: widget.onOpenDrawer,
              )
            : null,
        title: const Text('Audit Events'),
      ),
      body: EasyRefresh(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(Insets.md, Insets.xs, Insets.md, Insets.xl),
          children: <Widget>[
            // Search field
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search audit events',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _debounceTimer?.cancel();
                          _searchController.clear();
                          ref
                              .read(
                                cleanuparrEventsSearchProvider(
                                  widget.instance,
                                ).notifier,
                              )
                              .state = '';
                          setState(() {});
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Insets.md,
                  vertical: Insets.sm,
                ),
                border: OutlineInputBorder(
                  borderRadius: Radii.card,
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: Radii.card,
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              onChanged: (String val) {
                _debounceTimer?.cancel();
                _debounceTimer = Timer(const Duration(milliseconds: 350), () {
                  if (mounted) {
                    ref
                        .read(
                          cleanuparrEventsSearchProvider(widget.instance).notifier,
                        )
                        .state = val;
                  }
                });
                setState(() {});
              },
            ),
            const SizedBox(height: Insets.sm),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  for (final item in _filters) ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.only(right: Insets.xs),
                      child: FilterChip(
                        label: Text(item.$1),
                        selected: activeFilter == item.$2,
                        onSelected: (bool selected) {
                          ref
                              .read(
                                cleanuparrEventsFilterProvider(
                                  widget.instance,
                                ).notifier,
                              )
                              .state = selected ? item.$2 : null;
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Insets.md),

            // Events List
            eventsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(Insets.xl),
                  child: ExpressiveProgressIndicator(),
                ),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(Insets.xl),
                  child: Text('Could not load events: ${describeCleanuparrError(err)}'),
                ),
              ),
              data: (List<CleanuparrEvent> events) {
                if (events.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: Insets.xxl * 2),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.history_toggle_off_rounded,
                            size: 48,
                            color: colorScheme.outline,
                          ),
                          const SizedBox(height: Insets.md),
                          Text(
                            'No Events Found',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: Insets.xs),
                          Text(
                            'No recent activity matching your filter',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: <Widget>[
                    for (final CleanuparrEvent ev in events)
                      CleanuparrEventCard(event: ev),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
