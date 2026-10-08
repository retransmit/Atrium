import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../adguard_home_errors.dart';
import '../adguard_home_format.dart';
import '../adguard_home_providers.dart';
import '../adguard_home_query_log.dart';
import '../models/adguard_home_query_log.dart';
import '../widgets/adguard_home_pullable.dart';
import '../widgets/adguard_home_query_detail.dart';
import '../widgets/adguard_home_query_log_row.dart';
import '../widgets/adguard_home_refused_view.dart';

/// The server's query log: newest first, read a page at a time as the list
/// is scrolled, under a search and one of the web UI's ten filters. A row
/// opens the query in full.
///
/// Nothing here is read on a timer. Pulling down reads the newest entries
/// again.
class AdguardHomeQueryLogTab extends ConsumerStatefulWidget {
  const AdguardHomeQueryLogTab({
    required this.instance,
    this.now = DateTime.now,
    super.key,
  });

  final Instance instance;

  /// The clock that decides which entries are from today. Tests hand in
  /// their own.
  final DateTime Function() now;

  @override
  ConsumerState<AdguardHomeQueryLogTab> createState() =>
      _AdguardHomeQueryLogTabState();
}

class _AdguardHomeQueryLogTabState
    extends ConsumerState<AdguardHomeQueryLogTab> {
  /// How long the typing has to pause before a search is sent. Each search
  /// is a scan of the log on the server.
  static const Duration _pause = Duration(milliseconds: 400);

  final TextEditingController _search = TextEditingController();
  Timer? _typing;

  Instance get _instance => widget.instance;

  AdguardHomeQueryLog get _log =>
      ref.read(adguardHomeQueryLogProvider(_instance).notifier);

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(adguardHomeQueryLogProvider(_instance)).search;
  }

  @override
  void dispose() {
    _typing?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _typed(String text) {
    _typing?.cancel();
    _typing = Timer(_pause, () => _log.setSearch(text));
    // The cross comes and goes with the text.
    setState(() {});
  }

  void _submitted(String text) {
    _typing?.cancel();
    _log.setSearch(text);
  }

  void _clearSearch() {
    _typing?.cancel();
    _search.clear();
    _log.setSearch('');
    setState(() {});
  }

  void _clearNarrowing() {
    _typing?.cancel();
    _search.clear();
    _log.clearNarrowing();
    setState(() {});
  }

  /// The log listens for this and reads itself again, as the other reads
  /// do, so one tap is one request whichever tab it is made on.
  void _retrySignIn() =>
      ref.read(adguardHomeActionsProvider(_instance)).retrySignIn();

  void _edit() {
    context.pushNamed(
      AtriumRoutes.editInstanceName,
      pathParameters: <String, String>{'instanceId': _instance.id},
    );
  }

  @override
  Widget build(BuildContext context) {
    final AdguardHomeQueryLogState state =
        ref.watch(adguardHomeQueryLogProvider(_instance));

    // Nothing can be searched or filtered while the server refuses the
    // sign-in, so this takes the place of all of it.
    if (state.error is AdguardHomeSignInRefused) {
      return AdguardHomeRefusedView(
        onRetry: _retrySignIn,
        onEdit: _edit,
        hasCredentials: adguardHomeHasCredentials(_instance),
        refusals: ref.read(adguardHomeSessionProvider(_instance)).refusals,
      );
    }

    final ColorScheme cs = Theme.of(context).colorScheme;
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.lg,
            Insets.sm,
            Insets.lg,
            Insets.sm,
          ),
          child: TextField(
            controller: _search,
            onChanged: _typed,
            onSubmitted: _submitted,
            // Otherwise the keyboard comes back whenever a sheet or a menu
            // closes above the field.
            onTapOutside: (PointerDownEvent _) =>
                FocusManager.instance.primaryFocus?.unfocus(),
            textInputAction: TextInputAction.search,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: 'Domain or client',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Clear search',
                      onPressed: _clearSearch,
                    ),
              isDense: true,
              filled: true,
              fillColor: cs.surfaceContainerHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
          child: Row(
            children: <Widget>[
              for (final AdguardHomeLogFilter filter
                  in AdguardHomeLogFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: Insets.sm),
                  child: ChoiceChip(
                    label: Text(filter.label),
                    selected: state.filter == filter,
                    onSelected: (bool _) => _log.setFilter(filter),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Insets.xs),
        Expanded(child: _body(context, state)),
      ],
    );
  }

  Widget _body(BuildContext context, AdguardHomeQueryLogState state) {
    final DateTime now = widget.now();

    if (state.entries.isNotEmpty) {
      return EasyRefresh(
        onRefresh: _log.reload,
        child: ListView.separated(
          padding: const EdgeInsets.only(bottom: Insets.lg),
          itemCount: state.entries.length + 1,
          separatorBuilder: (BuildContext _, int __) => const Divider(
            height: 1,
            indent: Insets.lg,
            endIndent: Insets.lg,
          ),
          itemBuilder: (BuildContext context, int index) {
            if (index == state.entries.length) {
              return _Footer(state: state, now: now, onMore: _log.loadMore);
            }
            final AdguardHomeQueryLogEntry entry = state.entries[index];
            return AdguardHomeQueryLogRow(
              entry: entry,
              now: now,
              onTap: () => showAdguardHomeQueryDetail(
                context,
                instance: _instance,
                entry: entry,
                onChanged: _log.reload,
              ),
            );
          },
        ),
      );
    }

    if (state.loading) {
      return const Center(child: ExpressiveProgressIndicator());
    }
    // These scroll, like the two below: in the room a keyboard leaves on a
    // small phone they are taller than the space, and their button would
    // end up under the keyboard.
    final Object? error = state.error;
    if (error != null) {
      return AdguardHomePullable(
        onRefresh: _log.reload,
        child: ErrorView(
          message: describeAdguardHomeError(error),
          // A search that got some way back goes on from there. Starting
          // over would throw away every Keep searching made so far.
          onRetry: state.searchedBackTo.isEmpty ? _log.reload : _log.loadMore,
        ),
      );
    }
    // A search that has found nothing so far and has not reached the end.
    if (state.stalled || state.loadingMore) {
      return AdguardHomePullable(
        onRefresh: _log.reload,
        child: MessageView(
          icon: Icons.manage_search,
          title: 'Nothing found yet',
          message: _searchedBackTo(state, now),
          action: state.loadingMore
              ? const ExpressiveProgressIndicator()
              : FilledButton.tonal(
                  onPressed: _log.loadMore,
                  child: const Text('Keep searching'),
                ),
        ),
      );
    }
    // An empty list is the one that most wants reading again: the first
    // query after the log was cleared, or the one just made to test a rule.
    if (state.narrowed) {
      return AdguardHomePullable(
        onRefresh: _log.reload,
        child: EmptyView(
          icon: Icons.search_off,
          title: 'Nothing found',
          message: 'No query in the log matches.',
          action: TextButton(
            onPressed: _clearNarrowing,
            child: const Text('Clear search and filter'),
          ),
        ),
      );
    }
    return AdguardHomePullable(
      onRefresh: _log.reload,
      child: _EmptyLog(instance: _instance),
    );
  }
}

/// How far back a search has got, in words, or null when the server's
/// answer does not say.
String? _searchedBackTo(AdguardHomeQueryLogState state, DateTime now) {
  final DateTime? time = DateTime.tryParse(state.searchedBackTo);
  if (time == null) return null;
  return 'Searched back to ${formatAdguardHomeLogTime(time, now)}';
}

/// What stands where the list would be when the log has nothing in it: that
/// it is empty, or that the server keeps none.
class _EmptyLog extends ConsumerWidget {
  const _EmptyLog({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only read here, where an empty list needs explaining.
    final AdguardHomeQueryLogConfig? config =
        ref.watch(adguardHomeQueryLogConfigProvider(instance)).value;
    if (config != null && !config.enabled) {
      return const EmptyView(
        icon: Icons.history_toggle_off,
        title: 'The query log is off',
        message: 'AdGuard Home is not keeping one. It can be turned on in '
            'its settings.',
      );
    }
    return const EmptyView(
      icon: Icons.history,
      title: 'Nothing in the query log yet',
    );
  }
}

/// The last row of the list: it asks for older entries as it comes into
/// view, and says where the list stands when it does not.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.state,
    required this.now,
    required this.onMore,
  });

  final AdguardHomeQueryLogState state;
  final DateTime now;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final Object? error = state.error;

    final Widget child;
    // While the list is being read again from the top, what is below is
    // not known to be the end either.
    if (state.wantsMore || state.loadingMore || state.loading) {
      if (state.wantsMore) {
        // Being built means the end of the list is in view, or close to it.
        // Asking turns wantsMore off at once, so this asks once.
        WidgetsBinding.instance.addPostFrameCallback((Duration _) => onMore());
      }
      child = const SizedBox(
        width: 24,
        height: 24,
        child: ExpressiveProgressIndicator(strokeWidth: 2.5),
      );
    } else if (error != null) {
      child = Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            describeAdguardHomeError(error),
            style: muted,
            textAlign: TextAlign.center,
          ),
          TextButton(onPressed: onMore, child: const Text('Retry')),
        ],
      );
    } else if (state.stalled) {
      final String? reached = _searchedBackTo(state, now);
      child = Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (reached != null)
            Text(reached, style: muted, textAlign: TextAlign.center),
          TextButton(onPressed: onMore, child: const Text('Keep searching')),
        ],
      );
    } else {
      child = Text('End of the query log', style: muted);
    }

    return Padding(
      padding: const EdgeInsets.all(Insets.lg),
      child: Center(child: child),
    );
  }
}
