import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';

import 'add_torrent_sheet.dart';
import 'models/qbit_torrent.dart';
import 'models/qbit_transfer_info.dart';
import 'qbittorrent_action_utils.dart';
import 'qbittorrent_client.dart';
import 'qbittorrent_filter_drawer.dart';
import 'qbittorrent_providers.dart';
import 'qbittorrent_settings_tab.dart';
import 'torrent_detail_screen.dart';

/// qBittorrent's per-instance UI: bottom navigation bar with Home and Settings tabs,
/// transfer hero card with speed limits & torrent list, and an expandable FAB.
class QbittorrentHome extends ConsumerWidget {
  const QbittorrentHome({
    required this.instance,
    this.drawer,
    this.onEdit,
    super.key,
  });

  final Instance instance;
  final Widget? drawer;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int currentIndex = ref.watch(qbitActiveTabBarIndexProvider(instance));
    final bool isNavbarVisible =
        ref.watch(qbitBottomNavVisibleProvider(instance));

    final List<Widget> tabs = <Widget>[
      _TorrentsTab(instance: instance),
      QbittorrentSettingsTab(instance: instance),
    ];

    return Scaffold(
      drawerEdgeDragWidth:
          drawer != null ? MediaQuery.sizeOf(context).width * 0.15 : null,
      drawer: drawer,
      endDrawer: QbittorrentFilterDrawer(instance: instance),
      body: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification notification) {
          if (notification.metrics.axis == Axis.vertical) {
            if (notification is ScrollUpdateNotification) {
              final double pixels = notification.metrics.pixels;
              if (pixels > 10.0) {
                final double maxExtent = notification.metrics.maxScrollExtent;
                final bool isAtBottom = pixels >= maxExtent - 10.0;
                final double? delta = notification.scrollDelta;
                if (delta != null && delta != 0.0) {
                  final bool isScrollingDown = delta > 0.0;
                  final bool currentVisible =
                      ref.read(qbitBottomNavVisibleProvider(instance));
                  if (isScrollingDown && currentVisible) {
                    ref
                        .read(qbitBottomNavVisibleProvider(instance).notifier)
                        .state = false;
                  } else if (!isScrollingDown &&
                      !currentVisible &&
                      !isAtBottom) {
                    ref
                        .read(qbitBottomNavVisibleProvider(instance).notifier)
                        .state = true;
                  }
                }
              } else if (pixels <= 0.0) {
                final bool currentVisible =
                    ref.read(qbitBottomNavVisibleProvider(instance));
                if (!currentVisible) {
                  ref
                      .read(qbitBottomNavVisibleProvider(instance).notifier)
                      .state = true;
                }
              }
            }
          }
          return false;
        },
        child: Builder(
          builder: (BuildContext context) {
            return PopScope<Object?>(
              canPop: false,
              onPopInvokedWithResult: (bool didPop, Object? result) {
                if (didPop) return;

                if (Scaffold.of(context).isDrawerOpen) {
                  Navigator.of(context).pop();
                  return;
                }
                if (Scaffold.of(context).isEndDrawerOpen) {
                  Navigator.of(context).pop();
                  return;
                }

                final String search = ref.read(qbitSearchProvider(instance));
                if (search.isNotEmpty) {
                  ref.read(qbitSearchProvider(instance).notifier).state = '';
                  return;
                }

                final Set<String> selection =
                    ref.read(qbitSelectionProvider(instance));
                if (selection.isNotEmpty) {
                  ref.read(qbitSelectionProvider(instance).notifier).state =
                      <String>{};
                  return;
                }

                if (ref.read(qbitActiveTabBarIndexProvider(instance)) != 0) {
                  ref
                      .read(qbitActiveTabBarIndexProvider(instance).notifier)
                      .state = 0;
                  return;
                }

                GoRouter.of(context).go(AtriumRoutes.dashboard);
              },
              child: IndexedStack(
                index: currentIndex,
                children: tabs,
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: isNavbarVisible ? 80 : 0,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: SizedBox(
            height: 80,
            child: NavigationBar(
              selectedIndex: currentIndex,
              onDestinationSelected: (int index) {
                if (index == currentIndex) {
                  ref
                      .read(
                        qbitHomeScrollToTopProvider((instance, index)).notifier,
                      )
                      .update((int state) => state + 1);
                } else {
                  ref
                      .read(qbitActiveTabBarIndexProvider(instance).notifier)
                      .state = index;
                }
              },
              destinations: const <NavigationDestination>[
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TorrentsTab extends ConsumerStatefulWidget {
  const _TorrentsTab({required this.instance});

  final Instance instance;

  @override
  ConsumerState<_TorrentsTab> createState() => _TorrentsTabState();
}

class _TorrentsTabState extends ConsumerState<_TorrentsTab> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(qbitRawTorrentsProvider(widget.instance));
    ref.invalidate(qbitTransferProvider(widget.instance));
  }

  Widget _torrentFab(BuildContext context, WidgetRef ref) {
    return _ExpandableFab(
      builder: (BuildContext context, VoidCallback close) => <Widget>[
        FloatingActionButton(
          heroTag: null,
          tooltip: 'Magnet link',
          onPressed: () async {
            close();
            final bool added = await AddTorrentSheet.show(
              context,
              widget.instance,
            );
            if (added) {
              ref.invalidate(qbitRawTorrentsProvider(widget.instance));
              ref.invalidate(qbitTransferProvider(widget.instance));
            }
          },
          child: const Icon(Icons.link),
        ),
        FloatingActionButton(
          heroTag: null,
          tooltip: 'Torrent file',
          onPressed: () async {
            close();
            final bool added = await AddTorrentSheet.show(
              context,
              widget.instance,
              initialMode: AddTorrentMode.file,
            );
            if (added) {
              ref.invalidate(qbitRawTorrentsProvider(widget.instance));
              ref.invalidate(qbitTransferProvider(widget.instance));
            }
          },
          child: const Icon(Icons.attach_file),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Instance instance = widget.instance;
    ref.listen<int>(
      qbitHomeScrollToTopProvider((instance, 0)),
      (int? previous, int next) {
        if (next > 0 && _scrollController.hasClients) {
          _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          );
        }
      },
    );

    final AsyncValue<List<QbitTorrent>> torrents =
        ref.watch(qbitTorrentsProvider(instance));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        title: Text(instance.name),
        actions: <Widget>[
          QbittorrentAppBarActions(
            instance: instance,
            // This context sits above the Scaffold being built here, so it
            // resolves to the outer one, which is where the drawer lives.
            onFilter: () => Scaffold.of(context).openEndDrawer(),
          ),
        ],
      ),
      floatingActionButton: _torrentFab(context, ref),
      body: AsyncValueView<List<QbitTorrent>>(
        value: torrents,
        onRetry: () => ref.invalidate(qbitRawTorrentsProvider(instance)),
        data: (List<QbitTorrent> list) {
          return EasyRefresh(
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
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: _TopControlBar(instance: instance),
                ),
                if (list.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: EmptyView(
                        icon: Icons.cloud_download_outlined,
                        title: 'No torrents',
                        message:
                            'Tap + to add a magnet, URL, or .torrent file.',
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.only(bottom: 80),
                    sliver: SliverList.builder(
                      itemCount: list.length,
                      itemBuilder: (BuildContext context, int index) =>
                          _TorrentTile(
                        instance: instance,
                        torrent: list[index],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TopControlBar extends ConsumerStatefulWidget {
  const _TopControlBar({required this.instance});

  final Instance instance;

  @override
  ConsumerState<_TopControlBar> createState() => _TopControlBarState();
}

class _TopControlBarState extends ConsumerState<_TopControlBar> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  Future<void> _setAll(WidgetRef ref, {required bool paused}) async {
    final QbittorrentClient client =
        await ref.read(qbittorrentClientProvider(widget.instance).future);
    await client.setAllPaused(paused: paused);
    ref.invalidate(qbitRawTorrentsProvider(widget.instance));
    ref.invalidate(qbitTransferProvider(widget.instance));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final QbitTransferInfo? info =
        ref.watch(qbitTransferProvider(widget.instance)).value;
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final int dlSpeed = info?.dlSpeed ?? 0;
    final int upSpeed = info?.upSpeed ?? 0;
    final bool dlActive = dlSpeed > 0;
    final bool upActive = upSpeed > 0;

    final List<QbitTorrent> rawTorrents =
        ref.watch(qbitRawTorrentsProvider(widget.instance)).value ??
            <QbitTorrent>[];
    final int downloadingCount = rawTorrents
        .where(
          (QbitTorrent t) =>
              t.state.contains('downloading') ||
              t.state.contains('DL') ||
              t.dlspeed > 0,
        )
        .length;
    final int seedingCount = rawTorrents
        .where(
          (QbitTorrent t) =>
              t.state.contains('uploading') ||
              t.state.contains('UP') ||
              t.upspeed > 0,
        )
        .length;
    final int totalCount = rawTorrents.length;

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
                child: _TransferStatBadge(
                  label: 'Torrents',
                  count: totalCount,
                  speed: 'Total',
                  color: cs.onSurface,
                  icon: Icons.layers_outlined,
                ),
              ),
              const SizedBox(width: Insets.xs),
              Expanded(
                child: _TransferStatBadge(
                  label: 'Downloads',
                  count: downloadingCount,
                  speed: dlActive ? '${fmtBytes(dlSpeed)}/s' : '0 B/s',
                  color: cs.primary,
                  icon: Icons.arrow_downward_rounded,
                ),
              ),
              const SizedBox(width: Insets.xs),
              Expanded(
                child: _TransferStatBadge(
                  label: 'Seeds',
                  count: seedingCount,
                  speed: upActive ? '${fmtBytes(upSpeed)}/s' : '0 B/s',
                  color: cs.tertiary,
                  icon: Icons.arrow_upward_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          _isSearching
              ? Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: Insets.xs),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, size: 22),
                        onPressed: () {
                          setState(() {
                            _isSearching = false;
                            _searchController.clear();
                            ref
                                .read(
                                  qbitSearchProvider(widget.instance).notifier,
                                )
                                .state = '';
                          });
                        },
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          style: theme.textTheme.bodyMedium,
                          decoration: const InputDecoration(
                            hintText: 'Filter torrents...',
                            filled: false,
                            fillColor: Colors.transparent,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 10,
                            ),
                          ),
                          onChanged: (String val) {
                            ref
                                .read(
                                  qbitSearchProvider(widget.instance).notifier,
                                )
                                .state = val;
                            setState(() {});
                          },
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 22),
                          onPressed: () {
                            _searchController.clear();
                            ref
                                .read(
                                  qbitSearchProvider(widget.instance).notifier,
                                )
                                .state = '';
                            setState(() {});
                          },
                        ),
                    ],
                  ),
                )
              : Row(
                  children: <Widget>[
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _isSearching = true),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          height: 48,
                          padding:
                              const EdgeInsets.symmetric(horizontal: Insets.md),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest
                                .withValues(alpha: 0.7),
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
                                  ref
                                          .watch(
                                            qbitSearchProvider(widget.instance),
                                          )
                                          .isNotEmpty
                                      ? ref.watch(
                                          qbitSearchProvider(widget.instance),
                                        )
                                      : 'Search torrents...',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (ref
                                  .watch(qbitSearchProvider(widget.instance))
                                  .isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    ref
                                        .read(
                                          qbitSearchProvider(widget.instance)
                                              .notifier,
                                        )
                                        .state = '';
                                    setState(() {});
                                  },
                                  child: Icon(
                                    Icons.clear_rounded,
                                    size: 20,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    IconButton.filledTonal(
                      style: IconButton.styleFrom(
                        backgroundColor:
                            cs.surfaceContainerHighest.withValues(alpha: 0.7),
                        minimumSize: const Size(48, 48),
                        padding: EdgeInsets.zero,
                      ),
                      tooltip: 'Resume all',
                      icon: const Icon(Icons.play_arrow_rounded, size: 26),
                      onPressed: () => _setAll(ref, paused: false),
                    ),
                    const SizedBox(width: Insets.xs),
                    IconButton.filledTonal(
                      style: IconButton.styleFrom(
                        backgroundColor:
                            cs.surfaceContainerHighest.withValues(alpha: 0.7),
                        minimumSize: const Size(48, 48),
                        padding: EdgeInsets.zero,
                      ),
                      tooltip: 'Pause all',
                      icon: const Icon(Icons.pause_rounded, size: 26),
                      onPressed: () => _setAll(ref, paused: true),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}

class _TransferStatBadge extends StatelessWidget {
  const _TransferStatBadge({
    required this.label,
    required this.count,
    this.speed,
    required this.color,
    required this.icon,
  });

  final String label;
  final int count;
  final String? speed;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            speed ?? '-',
            style: theme.textTheme.labelSmall?.copyWith(
              color: speed != null ? color : cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class QbittorrentAppBarActions extends ConsumerWidget {
  const QbittorrentAppBarActions({
    required this.instance,
    this.onFilter,
    super.key,
  });

  final Instance instance;

  /// How to open the filter drawer.
  ///
  /// The home screen nests one Scaffold inside another: the outer one owns the
  /// drawer, the inner one owns the bar this sits in. `Scaffold.of` finds the
  /// nearest, so left to itself the button asks the inner Scaffold for a
  /// drawer it does not have, and openEndDrawer returns quietly rather than
  /// throwing. The caller passes the right one in. Where the surrounding
  /// Scaffold does own the drawer, the fallback below is correct.
  final VoidCallback? onFilter;

  void _showSortMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (BuildContext context) {
        return Consumer(
          builder: (BuildContext context, WidgetRef ref, Widget? child) {
            final QbitSortConfig config = ref.watch(qbitSortProvider(instance));
            return ListView(
              padding: const EdgeInsets.symmetric(vertical: Insets.md),
              children: <Widget>[
                ListTile(
                  leading: Icon(
                    config.ascending
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                  ),
                  title: Text(config.ascending ? 'Ascending' : 'Descending'),
                  onTap: () {
                    ref.read(qbitSortProvider(instance).notifier).state =
                        config.copyWith(ascending: !config.ascending);
                  },
                ),
                const Divider(),
                for (final QbitSortField field in QbitSortField.values)
                  ListTile(
                    title: Text(field.displayName),
                    trailing:
                        config.field == field ? const Icon(Icons.check) : null,
                    onTap: () {
                      ref.read(qbitSortProvider(instance).notifier).state =
                          config.copyWith(field: field);
                      Navigator.of(context).pop();
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Set<String> selectedHashes =
        ref.watch(qbitSelectionProvider(instance));

    if (selectedHashes.isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            tooltip: 'Filter Torrents',
            icon: const Icon(Icons.filter_list),
            onPressed: onFilter ?? () => Scaffold.of(context).openEndDrawer(),
          ),
          IconButton(
            tooltip: 'Sort Torrents',
            icon: const Icon(Icons.sort),
            onPressed: () => _showSortMenu(context, ref),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Center(
          child: Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Text('${selectedHashes.length} Selected'),
          ),
        ),
        IconButton(
          tooltip: 'Select All',
          icon: const Icon(Icons.select_all),
          onPressed: () {
            final List<QbitTorrent>? torrents =
                ref.read(qbitTorrentsProvider(instance)).value;
            if (torrents != null) {
              ref.read(qbitSelectionProvider(instance).notifier).state =
                  torrents.map((QbitTorrent t) => t.hash).toSet();
            }
          },
        ),
        IconButton(
          tooltip: 'Select None',
          icon: const Icon(Icons.deselect),
          onPressed: () => ref.invalidate(qbitSelectionProvider(instance)),
        ),
        IconButton(
          tooltip: 'Delete Selected',
          icon: const Icon(Icons.delete),
          onPressed: () => QbittorrentActionUtils.confirmDelete(
            context,
            ref,
            instance,
            selectedHashes,
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (String value) async {
            final List<String> hashes = selectedHashes.toList();
            switch (value) {
              case 'pause':
                await QbittorrentActionUtils.run(
                  ref,
                  instance,
                  (QbittorrentClient c) => c.pause(hashes),
                );
              case 'resume':
                await QbittorrentActionUtils.run(
                  ref,
                  instance,
                  (QbittorrentClient c) => c.resume(hashes),
                );
              case 'copy':
                await Clipboard.setData(ClipboardData(text: hashes.join('\n')));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Hashes copied')),
                  );
                }
              case 'recheck':
                await QbittorrentActionUtils.run(
                  ref,
                  instance,
                  (QbittorrentClient c) => c.recheck(hashes),
                );
              case 'reannounce':
                await QbittorrentActionUtils.run(
                  ref,
                  instance,
                  (QbittorrentClient c) => c.reannounce(hashes),
                );
              case 'queue_top':
                await QbittorrentActionUtils.run(
                  ref,
                  instance,
                  (QbittorrentClient c) => c.queueTop(hashes),
                );
              case 'queue_up':
                await QbittorrentActionUtils.run(
                  ref,
                  instance,
                  (QbittorrentClient c) => c.queueUp(hashes),
                );
              case 'queue_down':
                await QbittorrentActionUtils.run(
                  ref,
                  instance,
                  (QbittorrentClient c) => c.queueDown(hashes),
                );
              case 'queue_bottom':
                await QbittorrentActionUtils.run(
                  ref,
                  instance,
                  (QbittorrentClient c) => c.queueBottom(hashes),
                );
              case 'forcestart':
                await QbittorrentActionUtils.run(
                  ref,
                  instance,
                  (QbittorrentClient c) => c.setForceStart(hashes, value: true),
                );
              case 'rename':
                await QbittorrentActionUtils.rename(
                  context,
                  ref,
                  instance,
                  selectedHashes,
                );
              case 'savepath':
                await QbittorrentActionUtils.editSavePath(
                  context,
                  ref,
                  instance,
                  selectedHashes,
                );
              case 'category':
                await QbittorrentActionUtils.editCategory(
                  context,
                  ref,
                  instance,
                  selectedHashes,
                );
              case 'tags':
                await QbittorrentActionUtils.editTags(
                  context,
                  ref,
                  instance,
                  selectedHashes,
                );
              case 'export':
                try {
                  final QbittorrentClient client = await ref
                      .read(qbittorrentClientProvider(instance).future);
                  await client.exportTorrent(hashes.first);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Torrent exported successfully'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Export failed: $e')),
                    );
                  }
                }
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(value: 'pause', child: Text('Pause')),
            const PopupMenuItem<String>(value: 'resume', child: Text('Resume')),
            const PopupMenuItem<String>(value: 'copy', child: Text('Copy')),
            const PopupMenuItem<String>(
              value: 'recheck',
              child: Text('Force Recheck'),
            ),
            const PopupMenuItem<String>(
              value: 'reannounce',
              child: Text('Force Reannounce'),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'queue_top',
              child: Text('Queue to Top'),
            ),
            const PopupMenuItem<String>(
              value: 'queue_up',
              child: Text('Queue Up'),
            ),
            const PopupMenuItem<String>(
              value: 'queue_down',
              child: Text('Queue Down'),
            ),
            const PopupMenuItem<String>(
              value: 'queue_bottom',
              child: Text('Queue to Bottom'),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'forcestart',
              child: Text('Force Start'),
            ),
            PopupMenuItem<String>(
              value: 'rename',
              enabled: selectedHashes.length == 1,
              child: const Text('Rename'),
            ),
            const PopupMenuItem<String>(
              value: 'savepath',
              child: Text('Set SavePath'),
            ),
            const PopupMenuItem<String>(
              value: 'category',
              child: Text('Set Category'),
            ),
            const PopupMenuItem<String>(value: 'tags', child: Text('Set Tags')),
            PopupMenuItem<String>(
              value: 'export',
              enabled: selectedHashes.length == 1,
              child: const Text('Export .torrent'),
            ),
          ],
        ),
      ],
    );
  }
}

class _TorrentTile extends ConsumerStatefulWidget {
  const _TorrentTile({required this.instance, required this.torrent});

  final Instance instance;
  final QbitTorrent torrent;

  @override
  ConsumerState<_TorrentTile> createState() => _TorrentTileState();
}

class _TorrentTileState extends ConsumerState<_TorrentTile> {
  Timer? _longPressTimer;
  Offset? _tapPosition;
  bool _menuShown = false;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  String _formatEta(int eta) {
    if (eta >= 8640000 || eta < 0) {
      return '∞';
    }
    final Duration d = Duration(seconds: eta);
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours.remainder(24)}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    return '${d.inSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final QbitTorrent torrent = widget.torrent;
    final Instance instance = widget.instance;
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Set<String> selection = ref.watch(qbitSelectionProvider(instance));
    final bool selectionMode = selection.isNotEmpty;
    final bool isSelected = selection.contains(torrent.hash);
    final _QbitVisual v = _visualFor(torrent.state, cs);
    final double progress = torrent.progress.clamp(0, 1).toDouble();
    final bool complete = progress >= 1.0;
    final bool dlActive = torrent.dlspeed > 0;
    final bool upActive = torrent.upspeed > 0;

    final Widget tile = Material(
      color: isSelected ? cs.primaryContainer : cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTapDown: (TapDownDetails details) {
          _tapPosition = details.globalPosition;
          _menuShown = false;
          if (!selectionMode) {
            _longPressTimer?.cancel();
            _longPressTimer = Timer(const Duration(milliseconds: 250), () {
              if (_tapPosition != null && mounted) {
                _menuShown = true;
                _showContextMenu(context);
              }
            });
          }
        },
        onTapCancel: () => _longPressTimer?.cancel(),
        onTap: () {
          _longPressTimer?.cancel();
          if (_menuShown) return;

          if (selectionMode) {
            ref
                .read(qbitSelectionProvider(instance).notifier)
                .update((Set<String> s) {
              final Set<String> next = Set<String>.of(s);
              if (next.contains(torrent.hash)) {
                next.remove(torrent.hash);
              } else {
                next.add(torrent.hash);
              }
              return next;
            });
          } else {
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(
                builder: (_) => TorrentDetailScreen(
                  instance: instance,
                  torrent: torrent,
                ),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? cs.onPrimaryContainer.withValues(alpha: 0.15)
                          : v.container,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isSelected ? Icons.check : v.icon,
                      size: 22,
                      color: isSelected ? cs.onPrimaryContainer : v.onContainer,
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          torrent.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isSelected ? cs.onPrimaryContainer : null,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: <Widget>[
                            _StatePill(
                              label: friendlyState(torrent.state),
                              visual: v,
                            ),
                            const SizedBox(width: Insets.sm),
                            Expanded(
                              child: Text(
                                '${fmtBytes(torrent.downloaded)} / ${fmtBytes(torrent.size)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isSelected
                                      ? cs.onPrimaryContainer
                                          .withValues(alpha: 0.8)
                                      : cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicatorM3E(
                        shape: ProgressM3EShape.flat,
                        value: progress,
                        activeColor: complete ? cs.tertiary : v.color,
                        trackColor: isSelected
                            ? cs.onPrimaryContainer.withValues(alpha: 0.15)
                            : cs.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isSelected ? cs.onPrimaryContainer : v.color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.md),
              Row(
                children: <Widget>[
                  _SpeedPill(
                    icon: Icons.south,
                    label: '${fmtBytes(torrent.dlspeed)}/s',
                    color: cs.primary,
                    active: dlActive,
                  ),
                  const SizedBox(width: Insets.sm),
                  _SpeedPill(
                    icon: Icons.north,
                    label: '${fmtBytes(torrent.upspeed)}/s',
                    color: cs.tertiary,
                    active: upActive,
                  ),
                  const Spacer(),
                  Icon(Icons.swap_vert, size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 2),
                  Text(
                    torrent.ratio.toStringAsFixed(2),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  if (!complete) ...<Widget>[
                    const SizedBox(width: Insets.sm),
                    Icon(
                      Icons.schedule,
                      size: 14,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      _formatEta(torrent.eta),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (selectionMode) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          Insets.md,
          Insets.xs,
          Insets.md,
          Insets.xs,
        ),
        child: tile,
      );
    }

    return Padding(
      padding:
          const EdgeInsets.fromLTRB(Insets.md, Insets.xs, Insets.md, Insets.xs),
      child: tile,
    );
  }

  void _showContextMenu(BuildContext context) {
    final Instance inst = widget.instance;
    final String hash = widget.torrent.hash;
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    Widget buildItem(
      IconData icon,
      String label,
      VoidCallback onTap, {
      Color? color,
    }) {
      return ListTile(
        leading: Icon(icon, color: color ?? cs.onSurfaceVariant),
        title: Text(label, style: TextStyle(color: color)),
        onTap: () {
          Navigator.of(context).pop();
          onTap();
        },
      );
    }

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
      ) {
        return Dialog(
          clipBehavior: Clip.antiAlias,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  buildItem(Icons.check_circle_outline, 'Select', () {
                    ref.read(qbitSelectionProvider(inst).notifier).update(
                          (Set<String> s) => <String>{...s, hash},
                        );
                  }),
                  buildItem(Icons.pause, 'Pause', () {
                    QbittorrentActionUtils.run(
                      ref,
                      inst,
                      (QbittorrentClient c) => c.pause(<String>[hash]),
                    );
                  }),
                  buildItem(Icons.play_arrow, 'Resume', () {
                    QbittorrentActionUtils.run(
                      ref,
                      inst,
                      (QbittorrentClient c) => c.resume(<String>[hash]),
                    );
                  }),
                  buildItem(Icons.copy, 'Copy Hash', () async {
                    await Clipboard.setData(ClipboardData(text: hash));
                  }),
                  buildItem(Icons.refresh, 'Force Recheck', () {
                    QbittorrentActionUtils.run(
                      ref,
                      inst,
                      (QbittorrentClient c) => c.recheck(<String>[hash]),
                    );
                  }),
                  buildItem(Icons.vertical_align_top, 'Queue to Top', () {
                    QbittorrentActionUtils.run(
                      ref,
                      inst,
                      (QbittorrentClient c) => c.queueTop(<String>[hash]),
                    );
                  }),
                  buildItem(Icons.arrow_upward, 'Queue Up', () {
                    QbittorrentActionUtils.run(
                      ref,
                      inst,
                      (QbittorrentClient c) => c.queueUp(<String>[hash]),
                    );
                  }),
                  buildItem(Icons.arrow_downward, 'Queue Down', () {
                    QbittorrentActionUtils.run(
                      ref,
                      inst,
                      (QbittorrentClient c) => c.queueDown(<String>[hash]),
                    );
                  }),
                  buildItem(Icons.vertical_align_bottom, 'Queue to Bottom', () {
                    QbittorrentActionUtils.run(
                      ref,
                      inst,
                      (QbittorrentClient c) => c.queueBottom(<String>[hash]),
                    );
                  }),
                  buildItem(Icons.edit, 'Rename', () {
                    QbittorrentActionUtils.rename(
                      context,
                      ref,
                      inst,
                      <String>{hash},
                    );
                  }),
                  buildItem(Icons.folder, 'Set SavePath', () {
                    QbittorrentActionUtils.editSavePath(
                      context,
                      ref,
                      inst,
                      <String>{hash},
                    );
                  }),
                  buildItem(Icons.label, 'Set Category', () {
                    QbittorrentActionUtils.editCategory(
                      context,
                      ref,
                      inst,
                      <String>{hash},
                    );
                  }),
                  buildItem(
                    Icons.delete,
                    'Delete',
                    () {
                      QbittorrentActionUtils.confirmDelete(
                        context,
                        ref,
                        inst,
                        <String>{hash},
                      );
                    },
                    color: Colors.red,
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
        Widget child,
      ) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.fastOutSlowIn,
          ),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }
}

/// Per-state color + icon mapping for the torrent card (downloading -> primary,
/// seeding -> tertiary, completed/queued -> secondary, error -> error, and a
/// muted outline look for paused/stalled).
class _QbitVisual {
  const _QbitVisual({
    required this.color,
    required this.container,
    required this.onContainer,
    required this.icon,
  });

  final Color color;
  final Color container;
  final Color onContainer;
  final IconData icon;
}

_QbitVisual _visualFor(String state, ColorScheme cs) {
  switch (state) {
    case 'downloading':
    case 'forcedDL':
    case 'metaDL':
      return _QbitVisual(
        color: cs.primary,
        container: cs.primaryContainer,
        onContainer: cs.onPrimaryContainer,
        icon: Icons.download_rounded,
      );
    case 'uploading':
    case 'forcedUP':
    case 'stalledUP':
      return _QbitVisual(
        color: cs.tertiary,
        container: cs.tertiaryContainer,
        onContainer: cs.onTertiaryContainer,
        icon: Icons.upload_rounded,
      );
    case 'pausedUP':
    case 'stoppedUP':
      return _QbitVisual(
        color: cs.secondary,
        container: cs.secondaryContainer,
        onContainer: cs.onSecondaryContainer,
        icon: Icons.check_rounded,
      );
    case 'queuedDL':
    case 'queuedUP':
      return _QbitVisual(
        color: cs.secondary,
        container: cs.secondaryContainer,
        onContainer: cs.onSecondaryContainer,
        icon: Icons.schedule_rounded,
      );
    case 'checkingDL':
    case 'checkingUP':
    case 'checkingResumeData':
      return _QbitVisual(
        color: cs.tertiary,
        container: cs.tertiaryContainer,
        onContainer: cs.onTertiaryContainer,
        icon: Icons.sync_rounded,
      );
    case 'error':
    case 'missingFiles':
      return _QbitVisual(
        color: cs.error,
        container: cs.errorContainer,
        onContainer: cs.onErrorContainer,
        icon: Icons.error_outline_rounded,
      );
    default:
      return _QbitVisual(
        color: cs.outline,
        container: cs.surfaceContainerHighest,
        onContainer: cs.onSurfaceVariant,
        icon: state.contains('paused') || state.contains('stopped')
            ? Icons.pause_rounded
            : Icons.hourglass_empty_rounded,
      );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.label, required this.visual});

  final String label;
  final _QbitVisual visual;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: visual.container,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: visual.onContainer,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _SpeedPill extends StatelessWidget {
  const _SpeedPill({
    required this.icon,
    required this.label,
    required this.color,
    this.active = true,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color fg = active ? color : cs.onSurfaceVariant;
    final Color bg =
        active ? color.withValues(alpha: 0.12) : cs.surfaceContainerHighest;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

/// Maps a raw qBittorrent state to a short friendly label.
String friendlyState(String state) {
  switch (state) {
    case 'downloading':
    case 'forcedDL':
      return 'Downloading';
    case 'uploading':
    case 'forcedUP':
      return 'Seeding';
    case 'stalledDL':
      return 'Stalled';
    case 'stalledUP':
      return 'Seeding (idle)';
    case 'pausedDL':
    case 'stoppedDL':
      return 'Paused';
    case 'pausedUP':
    case 'stoppedUP':
      return 'Completed';
    case 'queuedDL':
    case 'queuedUP':
      return 'Queued';
    case 'checkingDL':
    case 'checkingUP':
    case 'checkingResumeData':
      return 'Checking';
    case 'metaDL':
      return 'Fetching metadata';
    case 'error':
    case 'missingFiles':
      return 'Error';
    default:
      return state;
  }
}

/// Human-readable byte size (decimal units, matching qBittorrent's display).
String fmtBytes(num bytes) {
  if (bytes <= 0) {
    return '0 B';
  }
  const List<String> units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
  double value = bytes.toDouble();
  int unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final String text = value >= 100 || unit == 0
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$text ${units[unit]}';
}

class _ExpandableFab extends StatefulWidget {
  const _ExpandableFab({required this.builder});

  final List<Widget> Function(BuildContext context, VoidCallback close) builder;

  @override
  State<_ExpandableFab> createState() => _ExpandableFabState();
}

class _ExpandableFabState extends State<_ExpandableFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      value: _open ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      curve: Curves.fastOutSlowIn,
      reverseCurve: Curves.easeOutQuad,
      parent: _controller,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _open = !_open;
      if (_open) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _close() {
    if (_open) {
      _toggle();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (BuildContext context, Widget? child) {
        return SizedBox(
          width: 56,
          height: 56.0 + (_expandAnimation.value * 136.0),
          child: child,
        );
      },
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: <Widget>[
          ..._buildExpandingActionButtons(),
          FloatingActionButton(
            heroTag: null,
            onPressed: _toggle,
            child: AnimatedBuilder(
              animation: _expandAnimation,
              builder: (BuildContext context, Widget? child) {
                return Transform.rotate(
                  angle: _expandAnimation.value * 0.7853981633974483,
                  child: const Icon(Icons.add),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildExpandingActionButtons() {
    final List<Widget> children = widget.builder(context, _close);
    final int count = children.length;
    const double step = 68.0;
    for (int i = 0; i < count; i++) {
      children[i] = _ExpandingActionButton(
        maxDistance: (i + 1) * step,
        progress: _expandAnimation,
        child: children[i],
      );
    }
    return children;
  }
}

class _ExpandingActionButton extends StatelessWidget {
  const _ExpandingActionButton({
    required this.maxDistance,
    required this.progress,
    required this.child,
  });

  final double maxDistance;
  final Animation<double> progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (BuildContext context, Widget? child) {
        final double offset = maxDistance * progress.value;
        return Positioned(
          bottom: offset,
          left: 0,
          right: 0,
          child: Transform.scale(
            scale: progress.value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
