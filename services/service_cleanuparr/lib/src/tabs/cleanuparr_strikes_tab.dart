import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cleanuparr_errors.dart';
import '../cleanuparr_providers.dart';
import '../models/cleanuparr_strike.dart';
import '../widgets/cleanuparr_strike_card.dart';

/// Tab 1: Active download strikes with search filtering and strike reset operations.
class CleanuparrStrikesTab extends ConsumerStatefulWidget {
  const CleanuparrStrikesTab({
    required this.instance,
    this.onOpenDrawer,
    super.key,
  });

  final Instance instance;
  final VoidCallback? onOpenDrawer;

  @override
  ConsumerState<CleanuparrStrikesTab> createState() => _CleanuparrStrikesTabState();
}

class _CleanuparrStrikesTabState extends ConsumerState<CleanuparrStrikesTab> {
  late final TextEditingController _searchController;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(cleanuparrStrikesSearchProvider(widget.instance)),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(cleanuparrStrikesProvider(widget.instance));
    ref.invalidate(cleanuparrStrikesCountProvider(widget.instance));
    await ref.read(cleanuparrStrikesCountProvider(widget.instance).future);
    await ref.read(cleanuparrStrikesProvider(widget.instance).future);
  }

  @override
  Widget build(BuildContext context) {
    // Keep the text field in sync when the shell's back-press handler resets
    // the provider; initState alone would leave stale text in the controller.
    ref.listen<String>(cleanuparrStrikesSearchProvider(widget.instance), (
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

    final strikesAsync = ref.watch(cleanuparrStrikesProvider(widget.instance));
    // The search the list was fetched with. The field runs ahead of it while
    // a keystroke waits on the debounce, so the empty state reads this one.
    final String appliedSearch =
        ref.watch(cleanuparrStrikesSearchProvider(widget.instance)).trim();
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
        title: const Text('Strikes Ledger'),
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
                hintText: 'Search strikes by title or hash',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _debounceTimer?.cancel();
                          _searchController.clear();
                          ref
                              .read(
                                cleanuparrStrikesSearchProvider(
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
                          cleanuparrStrikesSearchProvider(widget.instance).notifier,
                        )
                        .state = val;
                  }
                });
                setState(() {});
              },
            ),
            const SizedBox(height: Insets.md),

            // Strikes content
            strikesAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(Insets.xl),
                  child: ExpressiveProgressIndicator(),
                ),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(Insets.xl),
                  child: Text('Could not load strikes: ${describeCleanuparrError(err)}'),
                ),
              ),
              data: (List<CleanuparrStrikeItem> strikes) {
                if (strikes.isEmpty) {
                  if (appliedSearch.isNotEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: Insets.xxl * 2),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.search_off_rounded,
                              size: 48,
                              color: colorScheme.outline,
                            ),
                            const SizedBox(height: Insets.md),
                            Text(
                              'No Strikes Found',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: Insets.xs),
                            Text(
                              "No strikes matching '$appliedSearch'",
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.only(top: Insets.xxl * 2),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(Insets.lg),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer.withValues(
                                alpha: 0.3,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.verified_outlined,
                              size: 48,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: Insets.md),
                          Text(
                            'All Queues Clean',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: Insets.xs),
                          Text(
                            'No downloads currently hold strikes',
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
                    for (final CleanuparrStrikeItem item in strikes)
                      CleanuparrStrikeCard(
                        strikeItem: item,
                        instance: widget.instance,
                      ),
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
