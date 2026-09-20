import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/myspeed_test.dart';
import '../myspeed_api.dart';
import '../myspeed_providers.dart';
import '../widgets/myspeed_test_card.dart';

/// Tab 1: Historical speedtests tab.
///
/// Displays all speedtests from `GET /api/speedtests` with summary averages
/// and virtualized list of test cards. Cached in memory so switching tabs
/// never causes API lag or repeated fetches. Polls every 20 seconds.
class MySpeedHistoryTab extends ConsumerStatefulWidget {
  const MySpeedHistoryTab({required this.instance, super.key});

  final Instance instance;

  @override
  ConsumerState<MySpeedHistoryTab> createState() => _MySpeedHistoryTabState();
}

class _MySpeedHistoryTabState extends ConsumerState<MySpeedHistoryTab> {
  Timer? _pollingTimer;
  Timer? _searchDebounce;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  bool _isSearching = false;
  MySpeedTest? _searchResult;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _pollingTimer = Timer.periodic(const Duration(seconds: 20), (_) => _poll());
  }

  Future<void> _poll() async {
    if (!mounted) return;
    final int activeTab = ref.read(myspeedActiveTabBarIndexProvider(widget.instance));
    if (activeTab != 1) return;

    await ref.read(myspeedHistoryProvider(widget.instance).notifier).fetchDiff();
  }

  void _onSearchChanged(String val) {
    _searchDebounce?.cancel();
    final String trimmed = val.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchQuery = '';
        _isSearching = false;
        _searchResult = null;
        _searchError = null;
      });
      return;
    }
    _searchDebounce = Timer(
      const Duration(milliseconds: 400),
      () => _searchById(trimmed),
    );
  }

  Future<void> _searchById(String query) async {
    final String cleanId = query.startsWith('#') ? query.substring(1).trim() : query;
    if (cleanId.isEmpty) {
      setState(() {
        _searchQuery = '';
        _isSearching = false;
        _searchResult = null;
        _searchError = null;
      });
      return;
    }

    setState(() {
      _searchQuery = cleanId;
      _isSearching = true;
      _searchError = null;
    });

    try {
      final MySpeedApi api = await ref.read(myspeedApiProvider(widget.instance).future);
      final MySpeedTest? result = await api.getSpeedtestById(cleanId);
      if (!mounted) return;
      setState(() {
        _searchResult = result;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchError = e.toString();
        _isSearching = false;
      });
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildSearchBar(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return TextField(
      controller: _searchController,
      keyboardType: TextInputType.text,
      decoration: InputDecoration(
        hintText: 'Filter or search by test ID (e.g. 10)...',
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _searchController.clear();
                  _onSearchChanged('');
                },
              )
            : null,
        filled: true,
        fillColor: colors.surfaceContainer,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colors.primary,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      onChanged: _onSearchChanged,
      onSubmitted: (String val) => _searchById(val.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<MySpeedTest>> historyAsync =
        ref.watch(myspeedHistoryProvider(widget.instance));

    return AsyncValueView<List<MySpeedTest>>(
      value: historyAsync,
      onRetry: () => ref.read(myspeedHistoryProvider(widget.instance).notifier).reload(),
      data: (List<MySpeedTest> tests) {
        final int itemCount = _searchQuery.isNotEmpty
            ? 2
            : (tests.isEmpty ? 2 : tests.length + 1);

        return EasyRefresh(
          onRefresh: () async {
            await ref.read(myspeedHistoryProvider(widget.instance).notifier).reload();
          },
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: Insets.page,
            itemCount: itemCount,
            itemBuilder: (BuildContext context, int index) {
              if (index == 0) {
                final ThemeData theme = Theme.of(context);
                final ColorScheme colors = theme.colorScheme;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _buildSummaryCard(context, tests),
                    const SizedBox(height: Insets.lg),
                    Divider(color: colors.outlineVariant.withValues(alpha: 0.4)),
                    const SizedBox(height: Insets.md),
                    _buildSearchBar(context),
                    const SizedBox(height: Insets.md),
                  ],
                );
              }

              if (_searchQuery.isNotEmpty) {
                if (_isSearching) {
                  return const Padding(
                    padding: EdgeInsets.all(Insets.xl),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (_searchError != null) {
                  final ThemeData theme = Theme.of(context);
                  final ColorScheme colors = theme.colorScheme;
                  return Card(
                    elevation: 0,
                    color: colors.errorContainer.withValues(alpha: 0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: colors.error.withValues(alpha: 0.3)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(Insets.md),
                      child: Text(
                        'Error fetching speedtest #$_searchQuery: $_searchError',
                        style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
                      ),
                    ),
                  );
                }
                if (_searchResult == null) {
                  final ThemeData theme = Theme.of(context);
                  final ColorScheme colors = theme.colorScheme;
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: colors.outlineVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    color: colors.surfaceContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(Insets.xl),
                      child: Center(
                        child: Text(
                          'No speedtest found with ID #$_searchQuery',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: Insets.sm),
                  child: MySpeedTestCard(test: _searchResult!),
                );
              }

              if (tests.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: Insets.xl),
                  child: EmptyView(
                    icon: Icons.history_rounded,
                    title: 'No speedtests',
                    message: 'No speedtests recorded on this instance.',
                  ),
                );
              }

              final MySpeedTest test = tests[index - 1];
              return Padding(
                padding: const EdgeInsets.only(bottom: Insets.sm),
                child: MySpeedTestCard(test: test),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(BuildContext context, List<MySpeedTest> tests) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    double sumDown = 0;
    double sumUp = 0;
    double sumPing = 0;
    for (final MySpeedTest t in tests) {
      sumDown += t.download;
      sumUp += t.upload;
      sumPing += t.ping;
    }
    final double avgDown = tests.isNotEmpty ? sumDown / tests.length : 0;
    final double avgUp = tests.isNotEmpty ? sumUp / tests.length : 0;
    final double avgPing = tests.isNotEmpty ? sumPing / tests.length : 0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      color: colors.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'Historical summary',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    tests.length == 1 ? '1 test' : '${tests.length} tests',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: MySpeedMetricBox(
                    icon: Icons.arrow_downward_rounded,
                    label: 'AVG DOWN',
                    value: avgDown.toStringAsFixed(1),
                    unit: 'Mbps',
                    iconColor: colors.primary,
                    boxColor: colors.primaryContainer.withValues(alpha: 0.25),
                    borderColor: colors.primary.withValues(alpha: 0.25),
                  ),
                ),
                const SizedBox(width: Insets.xs),
                Expanded(
                  child: MySpeedMetricBox(
                    icon: Icons.arrow_upward_rounded,
                    label: 'AVG UP',
                    value: avgUp.toStringAsFixed(1),
                    unit: 'Mbps',
                    iconColor: colors.tertiary,
                    boxColor: colors.tertiaryContainer.withValues(alpha: 0.25),
                    borderColor: colors.tertiary.withValues(alpha: 0.25),
                  ),
                ),
                const SizedBox(width: Insets.xs),
                Expanded(
                  child: MySpeedMetricBox(
                    icon: Icons.timer_outlined,
                    label: 'AVG PING',
                    value: avgPing.toStringAsFixed(0),
                    unit: 'ms',
                    iconColor: colors.secondary,
                    boxColor: colors.secondaryContainer.withValues(alpha: 0.25),
                    borderColor: colors.secondary.withValues(alpha: 0.25),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
