import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/transmission_session.dart';
import 'models/transmission_torrent.dart';
import 'transmission_add_sheet.dart';
import 'transmission_api.dart';
import 'transmission_detail_screen.dart';
import 'transmission_format.dart';
import 'transmission_providers.dart';
import 'transmission_speed_dialog.dart';
import 'transmission_torrent_actions.dart';
import 'transmission_torrent_row.dart';
import 'transmission_visuals.dart';

/// The torrent list with everything the web UI's main pane has: search, its
/// nine filters, tracker and label filters, sort, selection, and the
/// session header.
class TransmissionTorrentsTab extends ConsumerStatefulWidget {
  const TransmissionTorrentsTab({required this.instance, super.key});

  final Instance instance;

  @override
  ConsumerState<TransmissionTorrentsTab> createState() =>
      _TransmissionTorrentsTabState();
}

class _TransmissionTorrentsTabState
    extends ConsumerState<TransmissionTorrentsTab> {
  late final TextEditingController _search = TextEditingController(
    text: ref.read(transmissionSearchProvider(widget.instance)),
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _refresh() {
    ref
      ..invalidate(transmissionRawTorrentsProvider(widget.instance))
      ..invalidate(transmissionSessionProvider(widget.instance))
      ..invalidate(transmissionSessionStatsProvider(widget.instance));
  }

  Future<void> _run(Future<void> Function(TransmissionApi api) action) =>
      runTransmissionAction(context, ref, widget.instance, action);

  void _openDetail(TransmissionTorrent t) {
    // pushScreen, not Navigator.push: a page pushed onto the branch navigator
    // is absent from GoRouter's route table and is dropped on the next shell
    // rebuild, which polling triggers constantly.
    pushScreen<void>(
      context,
      TransmissionDetailScreen(
        instance: widget.instance,
        hashString: t.hashString,
        initialName: t.name,
      ),
    );
  }

  void _toggleSelected(String hash) {
    ref.read(transmissionSelectionProvider(widget.instance).notifier).update(
      (Set<String> s) {
        final Set<String> next = Set<String>.of(s);
        if (!next.remove(hash)) next.add(hash);
        return next;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Instance instance = widget.instance;
    final AsyncValue<List<TransmissionTorrent>> torrents =
        ref.watch(transmissionTorrentsProvider(instance));
    final TransmissionSession session =
        ref.watch(transmissionSessionProvider(instance)).value ??
            const TransmissionSession();
    final Set<String> selection =
        ref.watch(transmissionSelectionProvider(instance));
    final bool compact = ref.watch(transmissionCompactProvider(instance));

    return AsyncValueView<List<TransmissionTorrent>>(
      value: torrents,
      onRetry: _refresh,
      data: (List<TransmissionTorrent> list) => EasyRefresh(
        header: const ClassicHeader(),
        onRefresh: () async => _refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Insets.md,
            Insets.xs,
            Insets.md,
            Insets.xl,
          ),
          children: <Widget>[
            _Header(
              instance: instance,
              search: _search,
              compact: compact,
              onAdd: () => showTransmissionAddSheet(context, instance),
              onToggleTurtle: (bool enabled) => _run(
                (TransmissionApi api) => api.setAltSpeed(enabled: enabled),
              ),
              onSetDown: (int kbps) => _run(
                (TransmissionApi api) => api.setSpeedLimits(
                  downKbps: kbps == transmissionUnlimited ? null : kbps,
                  downEnabled: kbps != transmissionUnlimited,
                ),
              ),
              onSetUp: (int kbps) => _run(
                (TransmissionApi api) => api.setSpeedLimits(
                  upKbps: kbps == transmissionUnlimited ? null : kbps,
                  upEnabled: kbps != transmissionUnlimited,
                ),
              ),
              onPauseAll: () => _run((TransmissionApi api) => api.stopAll()),
              onStartAll: () => _run((TransmissionApi api) => api.startAll()),
              onToggleCompact: () => ref
                  .read(transmissionCompactProvider(instance).notifier)
                  .update((bool c) => !c),
            ),
            const SizedBox(height: Insets.sm),
            _FilterBar(instance: instance, session: session),
            const SizedBox(height: Insets.sm),
            if (selection.isNotEmpty) ...<Widget>[
              _SelectionBar(
                instance: instance,
                visible: list,
                selection: selection,
              ),
              const SizedBox(height: Insets.sm),
            ],
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: Insets.xl),
                child: EmptyView(
                  icon: Icons.download_done_outlined,
                  title: 'No torrents',
                  message: 'Nothing here yet. Use Add to start one.',
                ),
              )
            else
              for (final TransmissionTorrent t in list)
                TransmissionTorrentRow(
                  torrent: t,
                  compact: compact,
                  selected: selection.contains(t.hashString),
                  selectionMode: selection.isNotEmpty,
                  labelsSupported: session.supportsLabels,
                  onTap: () => selection.isNotEmpty
                      ? _toggleSelected(t.hashString)
                      : _openDetail(t),
                  onLongPress: () => _toggleSelected(t.hashString),
                  onAction: (TransmissionTorrentAction a) =>
                      performTransmissionAction(
                    context,
                    ref,
                    instance,
                    a,
                    <TransmissionTorrent>[t],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// The panel at the top: three figures, the search box with sort and the
/// turtle beside it, then the limits, Add and the menu.
class _Header extends ConsumerWidget {
  const _Header({
    required this.instance,
    required this.search,
    required this.compact,
    required this.onAdd,
    required this.onToggleTurtle,
    required this.onSetDown,
    required this.onSetUp,
    required this.onPauseAll,
    required this.onStartAll,
    required this.onToggleCompact,
  });

  final Instance instance;
  final TextEditingController search;
  final bool compact;
  final VoidCallback onAdd;
  final void Function(bool enabled) onToggleTurtle;
  final void Function(int kbps) onSetDown;
  final void Function(int kbps) onSetUp;
  final VoidCallback onPauseAll;
  final VoidCallback onStartAll;
  final VoidCallback onToggleCompact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final List<TransmissionTorrent> all =
        ref.watch(transmissionRawTorrentsProvider(instance)).value ??
            const <TransmissionTorrent>[];
    final TransmissionSessionStats stats =
        ref.watch(transmissionSessionStatsProvider(instance)).value ??
            const TransmissionSessionStats();
    final TransmissionSession session =
        ref.watch(transmissionSessionProvider(instance)).value ??
            const TransmissionSession();
    final int downloading = all
        .where((TransmissionTorrent t) => t.status.isDownloading)
        .length;
    final int seeding =
        all.where((TransmissionTorrent t) => t.status.isSeeding).length;
    final bool searching = search.text.isNotEmpty;

    return TransmissionPanel(
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: TransmissionStatBadge(
                  label: 'Torrents',
                  value: '${all.length}',
                  icon: Icons.layers_outlined,
                  color: cs.onSurface,
                  // Only when the daemon actually knows: a containerised
                  // Transmission commonly reports -1 here.
                  detail: session.knowsFreeSpace
                      ? '${trFmtBytes(session.downloadDirFreeSpace)} free'
                      : '${stats.pausedTorrentCount} paused',
                ),
              ),
              const SizedBox(width: Insets.xs),
              Expanded(
                child: TransmissionStatBadge(
                  label: 'Down',
                  value: '$downloading',
                  icon: Icons.arrow_downward_rounded,
                  color: cs.primary,
                  detail: trFmtRate(stats.downloadSpeed),
                ),
              ),
              const SizedBox(width: Insets.xs),
              Expanded(
                child: TransmissionStatBadge(
                  label: 'Up',
                  value: '$seeding',
                  icon: Icons.arrow_upward_rounded,
                  color: cs.tertiary,
                  detail: trFmtRate(stats.uploadSpeed),
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: search,
                  decoration: transmissionFieldDecoration(
                    context,
                    hint: 'Search torrents',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searching
                        ? IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              search.clear();
                              ref
                                  .read(
                                    transmissionSearchProvider(instance)
                                        .notifier,
                                  )
                                  .state = '';
                            },
                          )
                        : null,
                  ),
                  onChanged: (String v) => ref
                      .read(transmissionSearchProvider(instance).notifier)
                      .state = v,
                  // A focused field gets the keyboard back whenever a menu or
                  // sheet closes above it, so a tap anywhere else lets it go.
                  onTapOutside: (PointerDownEvent _) =>
                      FocusScope.of(context).unfocus(),
                ),
              ),
              const SizedBox(width: Insets.xs),
              IconButton.filledTonal(
                tooltip: 'Sort',
                icon: const Icon(Icons.sort),
                onPressed: () => _showSortSheet(context, ref, instance),
              ),
              // Turtle mode overrides both limits while on, so it is a
              // distinct control rather than another limit value.
              IconButton.filledTonal(
                tooltip: session.altSpeedEnabled
                    ? 'Turtle on: ${session.altSpeedDown}/'
                        '${session.altSpeedUp} KB/s'
                    : 'Turtle off',
                isSelected: session.altSpeedEnabled,
                onPressed: () => onToggleTurtle(!session.altSpeedEnabled),
                icon: const Icon(Icons.slow_motion_video),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          Row(
            children: <Widget>[
              // Limits read as status first and controls second: pills that
              // light up while a cap is in force.
              _LimitPill(
                icon: Icons.south,
                color: cs.primary,
                kbps: session.speedLimitDown,
                enabled: session.speedLimitDownEnabled,
                onTap: () async {
                  final int? kbps = await showTransmissionSpeedDialog(
                    context,
                    title: 'Download limit',
                    currentKbps: session.speedLimitDown,
                    currentEnabled: session.speedLimitDownEnabled,
                  );
                  if (kbps != null) onSetDown(kbps);
                },
              ),
              const SizedBox(width: Insets.sm),
              _LimitPill(
                icon: Icons.north,
                color: cs.tertiary,
                kbps: session.speedLimitUp,
                enabled: session.speedLimitUpEnabled,
                onTap: () async {
                  final int? kbps = await showTransmissionSpeedDialog(
                    context,
                    title: 'Upload limit',
                    currentKbps: session.speedLimitUp,
                    currentEnabled: session.speedLimitUpEnabled,
                  );
                  if (kbps != null) onSetUp(kbps);
                },
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
              PopupMenuButton<String>(
                tooltip: 'More',
                onSelected: (String value) => switch (value) {
                  'pauseAll' => onPauseAll(),
                  'startAll' => onStartAll(),
                  _ => onToggleCompact(),
                },
                itemBuilder: (BuildContext _) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'pauseAll',
                    child: Text('Pause all'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'startAll',
                    child: Text('Start all'),
                  ),
                  const PopupMenuDivider(),
                  CheckedPopupMenuItem<String>(
                    value: 'compact',
                    checked: compact,
                    child: const Text('Compact rows'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Sort field and direction, as a sheet: the same control the other
  /// torrent clients have.
  void _showSortSheet(BuildContext context, WidgetRef ref, Instance instance) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (BuildContext _) => Consumer(
        builder: (BuildContext context, WidgetRef ref, Widget? _) {
          final TransmissionSortField field =
              ref.watch(transmissionSortFieldProvider(instance));
          final bool descending =
              ref.watch(transmissionSortDescendingProvider(instance));
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: Insets.md),
              children: <Widget>[
                ListTile(
                  leading: Icon(
                    descending ? Icons.arrow_downward : Icons.arrow_upward,
                  ),
                  title: Text(descending ? 'Descending' : 'Ascending'),
                  onTap: () => ref
                      .read(transmissionSortDescendingProvider(instance).notifier)
                      .state = !descending,
                ),
                const Divider(),
                for (final TransmissionSortField f
                    in TransmissionSortField.values)
                  ListTile(
                    title: Text(f.displayName),
                    trailing: field == f ? const Icon(Icons.check) : null,
                    onTap: () {
                      ref
                          .read(transmissionSortFieldProvider(instance).notifier)
                          .state = f;
                      Navigator.of(context).pop();
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A bandwidth cap shown as its current value, tinted while it is in force;
/// tapping changes it.
class _LimitPill extends StatelessWidget {
  const _LimitPill({
    required this.icon,
    required this.color,
    required this.kbps,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final int kbps;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: TransmissionSpeedPill(
        icon: icon,
        label: trFmtLimit(kbps: kbps, enabled: enabled),
        color: color,
        active: enabled,
      ),
    );
  }
}

/// Count, Select all, and the bulk actions, shown while rows are selected.
class _SelectionBar extends ConsumerWidget {
  const _SelectionBar({
    required this.instance,
    required this.visible,
    required this.selection,
  });

  final Instance instance;
  final List<TransmissionTorrent> visible;
  final Set<String> selection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final List<TransmissionTorrent> targets = <TransmissionTorrent>[
      for (final TransmissionTorrent t
          in ref.watch(transmissionRawTorrentsProvider(instance)).value ??
              const <TransmissionTorrent>[])
        if (selection.contains(t.hashString)) t,
    ];
    final bool labels = ref
            .watch(transmissionSessionProvider(instance))
            .value
            ?.supportsLabels ??
        false;
    return TransmissionPanel(
      color: theme.colorScheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: Insets.xs),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: 'Clear selection',
            icon: const Icon(Icons.close),
            onPressed: () =>
                ref.invalidate(transmissionSelectionProvider(instance)),
          ),
          Expanded(
            child: Text(
              '${selection.length} selected',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Select all',
            icon: const Icon(Icons.select_all),
            onPressed: () => ref
                .read(transmissionSelectionProvider(instance).notifier)
                .state = <String>{
              for (final TransmissionTorrent t in visible) t.hashString,
            },
          ),
          PopupMenuButton<TransmissionTorrentAction>(
            tooltip: 'Selection actions',
            itemBuilder: (BuildContext _) => transmissionActionMenuItems(
              anyStopped: targets.any(
                (TransmissionTorrent t) => t.status.isStopped,
              ),
              single: false,
              labelsSupported: labels,
            ),
            onSelected: (TransmissionTorrentAction a) async {
              await performTransmissionAction(
                context,
                ref,
                instance,
                a,
                targets,
              );
              ref.invalidate(transmissionSelectionProvider(instance));
            },
          ),
        ],
      ),
    );
  }
}

/// The web UI's nine state chips, the tracker chips and the label chips.
/// Counts follow the search so a chip says how many matches it holds.
class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.instance, required this.session});

  final Instance instance;
  final TransmissionSession session;

  Widget _chip(String text, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: Insets.xs),
        child: FilterChip(
          label: Text(text),
          selected: selected,
          onSelected: (_) => onTap(),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<TransmissionTorrent> all =
        ref.watch(transmissionRawTorrentsProvider(instance)).value ??
            const <TransmissionTorrent>[];
    final TransmissionFilter filter =
        ref.watch(transmissionFilterProvider(instance));
    final String search = ref.watch(transmissionSearchProvider(instance));
    final List<TransmissionTorrent> searched = filterTransmissionTorrents(
      all,
      const TransmissionFilter(),
      search: search,
    );
    final bool anyPrivate = all.any((TransmissionTorrent t) => t.isPrivate);
    final List<String> trackers = transmissionTrackers(all);
    final List<String> labels =
        session.supportsLabels ? transmissionLabels(all) : const <String>[];
    void set(TransmissionFilter Function(TransmissionFilter f) change) =>
        ref.read(transmissionFilterProvider(instance).notifier).update(change);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              for (final TransmissionFilterMode m
                  in TransmissionFilterMode.values)
                // Private and Public say nothing on an all-public list.
                if (anyPrivate ||
                    (m != TransmissionFilterMode.private &&
                        m != TransmissionFilterMode.public))
                  _chip(
                    '${m.label} (${searched.where(m.matches).length})',
                    filter.mode == m,
                    () => set((TransmissionFilter f) => f.copyWith(mode: m)),
                  ),
            ],
          ),
        ),
        if (trackers.isNotEmpty) ...<Widget>[
          const SizedBox(height: Insets.xs),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (final String host in trackers)
                  _chip(
                    '$host (${searched.where((TransmissionTorrent t) => t.trackerHosts.contains(host)).length})',
                    filter.tracker == host,
                    () => set(
                      (TransmissionFilter f) => f.copyWith(
                        tracker: f.tracker == host ? '' : host,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (labels.isNotEmpty) ...<Widget>[
          const SizedBox(height: Insets.xs),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (final String l in labels)
                  _chip(
                    l,
                    filter.label == l,
                    () => set(
                      (TransmissionFilter f) =>
                          f.copyWith(label: f.label == l ? '' : l),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
