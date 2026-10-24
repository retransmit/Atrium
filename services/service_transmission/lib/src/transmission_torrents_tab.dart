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

/// The torrent list, laid out the way qBittorrent's home is: a transfer panel
/// on top carrying the counts, the speeds, the search box and the turtle, then
/// the rows. The filters that used to sit in three chip rows live in the end
/// drawer behind the app bar's filter button, and sort lives behind the sort
/// button beside it.
class TransmissionTorrentsTab extends ConsumerStatefulWidget {
  const TransmissionTorrentsTab({
    required this.instance,
    this.onOpenDrawer,
    this.onOpenFilters,
    super.key,
  });

  final Instance instance;

  /// How to open the app's services drawer. The tab sits inside the home's
  /// Scaffold, so its own app bar has to be handed the callback.
  final VoidCallback? onOpenDrawer;

  /// How to open the filter drawer, which the home's Scaffold owns for the
  /// same reason.
  final VoidCallback? onOpenFilters;

  @override
  ConsumerState<TransmissionTorrentsTab> createState() =>
      _TransmissionTorrentsTabState();
}

class _TransmissionTorrentsTabState
    extends ConsumerState<TransmissionTorrentsTab> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
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

  Future<void> _add({bool file = false}) async {
    await showTransmissionAddSheet(
      context,
      widget.instance,
      initialMode: file ? TransmissionAddMode.file : TransmissionAddMode.link,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Instance instance = widget.instance;
    final AsyncValue<List<TransmissionTorrent>> torrents =
        ref.watch(transmissionTorrentsProvider(instance));
    final Set<String> selection =
        ref.watch(transmissionSelectionProvider(instance));
    final bool compact = ref.watch(transmissionCompactProvider(instance));
    final bool labelsSupported = ref
            .watch(transmissionSessionProvider(instance))
            .value
            ?.supportsLabels ??
        false;

    ref.listen<int>(transmissionScrollToTopProvider((instance, 0)), (
      int? previous,
      int next,
    ) {
      if (next > 0 && _scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });

    return Scaffold(
      appBar: selection.isEmpty
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: widget.onOpenDrawer ??
                    () => Scaffold.of(context).openDrawer(),
              ),
              title: Text(instance.name, overflow: TextOverflow.ellipsis),
              actions: <Widget>[
                IconButton(
                  tooltip: 'Filter torrents',
                  icon: const Icon(Icons.filter_list),
                  onPressed: widget.onOpenFilters ??
                      () => Scaffold.of(context).openEndDrawer(),
                ),
                IconButton(
                  tooltip: 'Sort torrents',
                  icon: const Icon(Icons.sort),
                  onPressed: _showSortSheet,
                ),
              ],
            )
          : _SelectionAppBar(
              instance: instance,
              visible: torrents.value ?? const <TransmissionTorrent>[],
              selection: selection,
            ),
      floatingActionButton: ExpandableFab(
        builder: (BuildContext context, VoidCallback close) => <Widget>[
          FloatingActionButton(
            heroTag: null,
            tooltip: 'Magnet or URL',
            onPressed: () {
              close();
              _add();
            },
            child: const Icon(Icons.link),
          ),
          FloatingActionButton(
            heroTag: null,
            tooltip: 'Torrent file',
            onPressed: () {
              close();
              _add(file: true);
            },
            child: const Icon(Icons.attach_file),
          ),
        ],
      ),
      body: AsyncValueView<List<TransmissionTorrent>>(
        value: torrents,
        onRetry: _refresh,
        data: (List<TransmissionTorrent> list) => EasyRefresh(
          header: const ClassicHeader(
            dragText: 'Pull to refresh',
            armedText: 'Release ready',
            readyText: 'Refreshing...',
            processingText: 'Refreshing...',
            processedText: 'Succeeded',
            failedText: 'Failed',
            messageText: 'Last updated at %T',
          ),
          onRefresh: () async => _refresh(),
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: _TransferPanel(
                  instance: instance,
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
                  onPauseAll: () =>
                      _run((TransmissionApi api) => api.stopAll()),
                  onStartAll: () =>
                      _run((TransmissionApi api) => api.startAll()),
                ),
              ),
              if (list.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: Insets.xl * 2),
                    child: EmptyView(
                      icon: Icons.download_done_outlined,
                      title: 'No torrents',
                      message: 'Tap + to add a magnet, URL, or .torrent file.',
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 96),
                  sliver: SliverList.builder(
                    itemCount: list.length,
                    itemBuilder: (BuildContext context, int index) {
                      final TransmissionTorrent t = list[index];
                      return TransmissionTorrentRow(
                        torrent: t,
                        compact: compact,
                        selected: selection.contains(t.hashString),
                        selectionMode: selection.isNotEmpty,
                        labelsSupported: labelsSupported,
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
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sort field and direction, as a sheet: the same control the other
  /// torrent clients have.
  void _showSortSheet() {
    final Instance instance = widget.instance;
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
                  trailing: Switch(
                    value: descending,
                    onChanged: (_) => ref
                        .read(
                          transmissionSortDescendingProvider(instance).notifier,
                        )
                        .state = !descending,
                  ),
                  onTap: () => ref
                      .read(
                        transmissionSortDescendingProvider(instance).notifier,
                      )
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
                          .read(
                            transmissionSortFieldProvider(instance).notifier,
                          )
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

/// The panel at the top: the three figures, the search box with the turtle
/// beside it, then the caps and the two bulk controls.
///
/// It is the transfer panel qBittorrent's home carries, with Transmission's
/// own controls where they belong. The turtle sits beside the search box
/// because it is a mode, not a reading; the two caps and the pause/resume pair
/// share the line below, and Add is the floating button rather than a fourth
/// thing to fit across a phone.
class _TransferPanel extends ConsumerWidget {
  const _TransferPanel({
    required this.instance,
    required this.onToggleTurtle,
    required this.onSetDown,
    required this.onSetUp,
    required this.onPauseAll,
    required this.onStartAll,
  });

  final Instance instance;
  final void Function(bool enabled) onToggleTurtle;
  final void Function(int kbps) onSetDown;
  final void Function(int kbps) onSetUp;
  final VoidCallback onPauseAll;
  final VoidCallback onStartAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final List<TransmissionTorrent> all =
        ref.watch(transmissionRawTorrentsProvider(instance)).value ??
            const <TransmissionTorrent>[];
    final TransmissionSession session =
        ref.watch(transmissionSessionProvider(instance)).value ??
            const TransmissionSession();
    final TransmissionSessionStats stats =
        ref.watch(transmissionSessionStatsProvider(instance)).value ??
            const TransmissionSessionStats();
    final bool compact = ref.watch(transmissionCompactProvider(instance));
    final int downloading =
        all.where((TransmissionTorrent t) => t.status.isDownloading).length;
    final int seeding =
        all.where((TransmissionTorrent t) => t.status.isSeeding).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        Insets.md,
        Insets.xs,
        Insets.md,
        Insets.sm,
      ),
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
              Expanded(child: _SearchRow(instance: instance)),
              const SizedBox(width: Insets.xs),
              // Turtle mode overrides both caps while on, so it is a mode
              // switch rather than another limit value.
              IconButton.filledTonal(
                style: IconButton.styleFrom(
                  backgroundColor:
                      cs.surfaceContainerHighest.withValues(alpha: 0.7),
                  minimumSize: const Size(48, 48),
                  padding: EdgeInsets.zero,
                ),
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
          // Caps are status, not furniture: a pill appears only while a limit
          // is actually in force. Two "Unlimited" badges said nothing and took
          // the room the bulk controls needed. Setting either cap, and turning
          // one off, lives in the overflow menu.
          if (session.speedLimitDownEnabled ||
              session.speedLimitUpEnabled) ...<Widget>[
            const SizedBox(height: Insets.sm),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.xs,
              children: <Widget>[
                if (session.speedLimitDownEnabled)
                  _LimitPill(
                    key: const ValueKey<String>('limit-down-pill'),
                    icon: Icons.south,
                    color: cs.primary,
                    kbps: session.speedLimitDown,
                    enabled: true,
                    onTap: () => _editLimit(
                      context,
                      title: 'Download limit',
                      kbps: session.speedLimitDown,
                      enabled: session.speedLimitDownEnabled,
                      onSet: onSetDown,
                    ),
                  ),
                if (session.speedLimitUpEnabled)
                  _LimitPill(
                    key: const ValueKey<String>('limit-up-pill'),
                    icon: Icons.north,
                    color: cs.tertiary,
                    kbps: session.speedLimitUp,
                    enabled: true,
                    onTap: () => _editLimit(
                      context,
                      title: 'Upload limit',
                      kbps: session.speedLimitUp,
                      enabled: session.speedLimitUpEnabled,
                      onSet: onSetUp,
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: Insets.sm),
          // Three equal controls across the panel, at a size a thumb can hit.
          // They were 48 px buttons bunched at the right of a row the cap pills
          // had already filled; they now share the whole width.
          Row(
            children: <Widget>[
              Expanded(
                child: _BulkButton(
                  tooltip: 'Resume all',
                  icon: Icons.play_arrow_rounded,
                  onPressed: onStartAll,
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: _BulkButton(
                  tooltip: 'Pause all',
                  icon: Icons.pause_rounded,
                  onPressed: onPauseAll,
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Material(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: PopupMenuButton<String>(
                    tooltip: 'More',
                    padding: EdgeInsets.zero,
                    position: PopupMenuPosition.under,
                    onSelected: (String value) => switch (value) {
                      'pauseAll' => onPauseAll(),
                      'startAll' => onStartAll(),
                      'limitDown' => _editLimit(
                          context,
                          title: 'Download limit',
                          kbps: session.speedLimitDown,
                          enabled: session.speedLimitDownEnabled,
                          onSet: onSetDown,
                        ),
                      'limitUp' => _editLimit(
                          context,
                          title: 'Upload limit',
                          kbps: session.speedLimitUp,
                          enabled: session.speedLimitUpEnabled,
                          onSet: onSetUp,
                        ),
                      _ => ref
                          .read(transmissionCompactProvider(instance).notifier)
                          .update((bool c) => !c),
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
                      PopupMenuItem<String>(
                        value: 'limitDown',
                        child: Text(
                          'Download limit: ${trFmtLimit(
                            kbps: session.speedLimitDown,
                            enabled: session.speedLimitDownEnabled,
                          )}',
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'limitUp',
                        child: Text(
                          'Upload limit: ${trFmtLimit(
                            kbps: session.speedLimitUp,
                            enabled: session.speedLimitUpEnabled,
                          )}',
                        ),
                      ),
                      const PopupMenuDivider(),
                      CheckedPopupMenuItem<String>(
                        value: 'compact',
                        checked: compact,
                        child: const Text('Compact rows'),
                      ),
                    ],
                    // The menu button's own child fills the surface so the
                    // whole tile is the target, not just the glyph.
                    child: SizedBox(
                      height: _BulkButton.height,
                      child: Icon(
                        Icons.more_vert_rounded,
                        size: 28,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The cap dialog, shared by an active pill and the menu's two entries.
  Future<void> _editLimit(
    BuildContext context, {
    required String title,
    required int kbps,
    required bool enabled,
    required void Function(int kbps) onSet,
  }) async {
    final int? chosen = await showTransmissionSpeedDialog(
      context,
      title: title,
      currentKbps: kbps,
      currentEnabled: enabled,
    );
    if (chosen != null) onSet(chosen);
  }
}

/// One of the panel's bulk controls: a full-width target 56 px tall, so it is
/// comfortable under a thumb and the three of them divide the panel evenly.
class _BulkButton extends StatelessWidget {
  const _BulkButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  static const double height = 56;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: IconButton.filledTonal(
        style: IconButton.styleFrom(
          backgroundColor: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        tooltip: tooltip,
        onPressed: onPressed,
        iconSize: 28,
        icon: Icon(icon),
      ),
    );
  }
}

/// The search box, collapsed to a tap target until it is wanted, so the list
/// keeps the room. Same behaviour as qBittorrent's: tapping opens a field with
/// the current query, clearing it puts the box back.
class _SearchRow extends ConsumerStatefulWidget {
  const _SearchRow({required this.instance});

  final Instance instance;

  @override
  ConsumerState<_SearchRow> createState() => _SearchRowState();
}

class _SearchRowState extends ConsumerState<_SearchRow> {
  final TextEditingController _search = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Instance instance = widget.instance;
    final String query = ref.watch(transmissionSearchProvider(instance));

    if (_isSearching) {
      return Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: Insets.xs),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: <Widget>[
            IconButton(
              tooltip: 'Close search',
              icon: const Icon(Icons.arrow_back_rounded, size: 22),
              onPressed: _close,
            ),
            Expanded(
              child: TextField(
                controller: _search,
                autofocus: true,
                style: theme.textTheme.bodyMedium,
                decoration: const InputDecoration(
                  hintText: 'Search torrents...',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 10,
                  ),
                ),
                onChanged: (String v) {
                  ref
                      .read(transmissionSearchProvider(instance).notifier)
                      .state = v;
                },
                // A focused field gets the keyboard back whenever a sheet
                // closes above it, so a tap anywhere else lets it go.
                onTapOutside: (PointerDownEvent _) =>
                    FocusScope.of(context).unfocus(),
              ),
            ),
            if (query.isNotEmpty)
              IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.clear_rounded, size: 22),
                onPressed: () {
                  _search.clear();
                  ref
                      .read(transmissionSearchProvider(instance).notifier)
                      .state = '';
                },
              ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () {
        _search.text = query;
        setState(() => _isSearching = true);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: Insets.md),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.search_rounded,
              size: 22,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Text(
                query.isEmpty ? 'Search torrents...' : query,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: query.isEmpty ? cs.onSurfaceVariant : cs.onSurface,
                ),
              ),
            ),
            if (query.isNotEmpty)
              Tooltip(
                message: 'Clear search',
                child: InkWell(
                  onTap: () {
                    _search.clear();
                    ref
                        .read(transmissionSearchProvider(instance).notifier)
                        .state = '';
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Icon(
                    Icons.clear_rounded,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _close() {
    _search.clear();
    ref.read(transmissionSearchProvider(widget.instance).notifier).state = '';
    setState(() => _isSearching = false);
  }
}

/// A bandwidth cap shown as its current value, tinted while it is in force;
/// tapping changes it.
class _LimitPill extends StatelessWidget {
  const _LimitPill({
    super.key,
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

/// Count, Select all, the bulk actions, and a way out, in place of the app bar
/// while rows are selected.
class _SelectionAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _SelectionAppBar({
    required this.instance,
    required this.visible,
    required this.selection,
  });

  final Instance instance;
  final List<TransmissionTorrent> visible;
  final Set<String> selection;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

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

    return AppBar(
      backgroundColor: theme.colorScheme.primaryContainer,
      foregroundColor: theme.colorScheme.onPrimaryContainer,
      leading: IconButton(
        tooltip: 'Clear selection',
        icon: const Icon(Icons.close),
        onPressed: () =>
            ref.invalidate(transmissionSelectionProvider(instance)),
      ),
      title: Text('${selection.length} selected'),
      actions: <Widget>[
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
          icon: const Icon(Icons.more_vert),
          itemBuilder: (BuildContext _) => transmissionActionMenuItems(
            anyStopped: targets.any(
              (TransmissionTorrent t) => t.status.isStopped,
            ),
            single: targets.length == 1,
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
    );
  }
}
