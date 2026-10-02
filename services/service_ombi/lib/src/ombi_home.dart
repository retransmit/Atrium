import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'models/ombi_models.dart';
import 'ombi_discover_tab.dart';
import 'ombi_failure.dart';
import 'ombi_providers.dart';
import 'ombi_request_actions.dart';
import 'ombi_request_sheet.dart';
import 'ombi_search.dart';
import 'widgets/ombi_request_card.dart';

/// Ombi for one instance: its requests, filtered by kind and by where each
/// one stands, and a Discover tab to find something new to request.
///
/// The screen owns its scaffold so that it also owns the back press: the
/// app's service shell would otherwise leave for the dashboard on the first
/// press. Back closes the drawer, then returns to Requests, and only then
/// leaves.
class OmbiHome extends ConsumerStatefulWidget {
  const OmbiHome({required this.instance, this.drawer, super.key});

  final Instance instance;

  /// The app's services drawer. The shell passes it; tests leave it out.
  final Widget? drawer;

  @override
  ConsumerState<OmbiHome> createState() => _OmbiHomeState();
}

class _OmbiHomeState extends ConsumerState<OmbiHome> {
  int _tab = 0;

  /// Discover is built when its tab is first opened and kept from then on.
  /// Each of its rows costs Ombi a round trip through TheMovieDB, which
  /// someone who came to approve a request should not pay for.
  bool _discoverOpened = false;

  OmbiMediaKind _kind = OmbiMediaKind.movie;

  /// The filter picked by hand. It then holds for every kind.
  OmbiRequestFilter? _picked;

  /// The filter each kind opened on, decided once its counts came in.
  final Map<OmbiMediaKind, OmbiRequestFilter> _openedOn =
      <OmbiMediaKind, OmbiRequestFilter>{};

  /// All comes first: it is what an instance with nothing waiting opens on,
  /// and a chosen chip scrolled off the edge tells nobody what they see.
  static const List<(OmbiRequestFilter, String)> _filters =
      <(OmbiRequestFilter, String)>[
    (OmbiRequestFilter.all, 'All'),
    (OmbiRequestFilter.pending, 'Pending'),
    (OmbiRequestFilter.processing, 'Processing'),
    (OmbiRequestFilter.available, 'Available'),
    (OmbiRequestFilter.denied, 'Denied'),
  ];

  void _openTab(int tab) => setState(() {
        _tab = tab;
        _discoverOpened = _discoverOpened || tab == 1;
      });

  @override
  Widget build(BuildContext context) {
    final Instance instance = widget.instance;
    return Scaffold(
      drawer: widget.drawer,
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            Flexible(
              child: Text(instance.name, overflow: TextOverflow.ellipsis),
            ),
            if (instance.kind.isBeta) ...<Widget>[
              const SizedBox(width: Insets.sm),
              const BetaBadge(),
            ],
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: () => showSearch<void>(
              context: context,
              // Root navigator: the search page is pushed imperatively, so
              // it must not ride the branch navigator, which the router
              // rebuilds and sweeps.
              useRootNavigator: true,
              delegate: OmbiSearchDelegate(instance: instance),
            ),
          ),
        ],
      ),
      body: Builder(
        builder: (BuildContext context) => PopScope<Object?>(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, Object? _) {
            if (didPop) {
              return;
            }
            final ScaffoldState scaffold = Scaffold.of(context);
            if (scaffold.isDrawerOpen) {
              scaffold.closeDrawer();
              return;
            }
            if (_tab != 0) {
              _openTab(0);
              return;
            }
            GoRouter.of(context).goNamed(AtriumRoutes.dashboardName);
          },
          child: IndexedStack(
            index: _tab,
            children: <Widget>[
              // Built from this state rather than a tab widget of its own,
              // so the chosen kind and filter survive a trip to Discover.
              _requests(),
              if (_discoverOpened)
                OmbiDiscoverTab(instance: instance)
              else
                const SizedBox.shrink(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AtriumBottomNav(
        visible: true,
        selectedIndex: _tab,
        onDestinationSelected: _openTab,
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.playlist_play),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Discover',
          ),
        ],
      ),
    );
  }

  /// The filter [kind] shows: the one picked by hand, else the one it
  /// opened on. Null while there is nothing to decide that by yet.
  ///
  /// A kind opens on Pending when something is waiting, since that is what
  /// there is to act on, and on All otherwise, since an empty list with
  /// everything else a chip away reads as an empty server. That is decided
  /// once, so dealing with the last pending request does not swap the list
  /// out from under whoever just dealt with it.
  OmbiRequestFilter? _filterFor(
    OmbiMediaKind kind,
    AsyncValue<Map<OmbiRequestFilter, int>> counts,
  ) {
    final OmbiRequestFilter? decided = _picked ?? _openedOn[kind];
    if (decided != null) {
      return decided;
    }
    final Map<OmbiRequestFilter, int>? known = counts.value;
    if (known == null && !counts.hasError) {
      return null;
    }
    return _openedOn[kind] = (known?[OmbiRequestFilter.pending] ?? 0) > 0
        ? OmbiRequestFilter.pending
        : OmbiRequestFilter.all;
  }

  Widget _requests() {
    final Instance instance = widget.instance;
    final bool music =
        ref.watch(ombiMusicEnabledProvider(instance)).value ?? false;
    // Lidarr switched off while Music was showing: fall back to movies
    // rather than ask for a list Ombi no longer serves.
    final OmbiMediaKind kind =
        !music && _kind == OmbiMediaKind.music ? OmbiMediaKind.movie : _kind;
    final AsyncValue<Map<OmbiRequestFilter, int>> counts =
        ref.watch(ombiFilterCountsProvider((instance: instance, kind: kind)));
    final Map<OmbiRequestFilter, int>? known = counts.value;
    final OmbiRequestFilter? filter = _filterFor(kind, counts);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.lg,
            Insets.sm,
            Insets.lg,
            Insets.sm,
          ),
          child: SegmentedButton<OmbiMediaKind>(
            segments: <ButtonSegment<OmbiMediaKind>>[
              const ButtonSegment<OmbiMediaKind>(
                value: OmbiMediaKind.movie,
                label: Text('Movies'),
                icon: Icon(Icons.movie_outlined),
              ),
              const ButtonSegment<OmbiMediaKind>(
                value: OmbiMediaKind.tv,
                label: Text('TV'),
                icon: Icon(Icons.live_tv_outlined),
              ),
              if (music)
                const ButtonSegment<OmbiMediaKind>(
                  value: OmbiMediaKind.music,
                  label: Text('Music'),
                  icon: Icon(Icons.album_outlined),
                ),
            ],
            selected: <OmbiMediaKind>{kind},
            onSelectionChanged: (Set<OmbiMediaKind> picked) =>
                setState(() => _kind = picked.first),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
          child: Row(
            children: <Widget>[
              for (final (OmbiRequestFilter f, String label)
                  in _filters) ...<Widget>[
                ChoiceChip(
                  // Without the counts the chips still filter; they just do
                  // not say how much is behind each.
                  label: Text(
                    known == null ? label : '$label (${known[f] ?? 0})',
                  ),
                  selected: f == filter,
                  onSelected: (bool _) => setState(() => _picked = f),
                ),
                const SizedBox(width: Insets.sm),
              ],
            ],
          ),
        ),
        const SizedBox(height: Insets.sm),
        Expanded(
          child: filter == null
              ? const Center(child: CircularProgressIndicator())
              : _RequestList(
                  listKey: (instance: instance, kind: kind, filter: filter),
                ),
        ),
      ],
    );
  }
}

class _RequestList extends ConsumerWidget {
  const _RequestList({required this.listKey});

  final OmbiListKey listKey;

  static const Map<OmbiRequestFilter, String> _emptyTitles =
      <OmbiRequestFilter, String>{
    OmbiRequestFilter.pending: 'Nothing waiting for approval',
    OmbiRequestFilter.processing: 'Nothing on its way',
    OmbiRequestFilter.available: 'Nothing available yet',
    OmbiRequestFilter.denied: 'Nothing denied',
    OmbiRequestFilter.all: 'No requests yet',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Instance instance = listKey.instance;

    Future<void> refresh() async {
      ref
        ..invalidate(ombiRequestListProvider(listKey))
        ..invalidate(
          ombiFilterCountsProvider((instance: instance, kind: listKey.kind)),
        )
        ..invalidate(ombiCountsProvider(instance));
      await ref.read(ombiRequestListProvider(listKey).future);
    }

    return ref.watch(ombiRequestListProvider(listKey)).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace _) => ErrorView(
            message: describeOmbiFailure(error),
            onRetry: () => ref.invalidate(ombiRequestListProvider(listKey)),
          ),
          data: (OmbiRequestListState state) {
            if (state.items.isEmpty) {
              return EasyRefresh(
                onRefresh: refresh,
                child: ListView(
                  children: <Widget>[
                    const SizedBox(height: Insets.xl),
                    EmptyView(title: _emptyTitles[listKey.filter]!),
                  ],
                ),
              );
            }
            return NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification n) {
                if (n.metrics.extentAfter < 400) {
                  unawaited(
                    ref
                        .read(ombiRequestListProvider(listKey).notifier)
                        .loadMore(),
                  );
                }
                return false;
              },
              child: EasyRefresh(
                onRefresh: refresh,
                child: ListView.builder(
                  padding: const EdgeInsets.only(
                    top: Insets.xs,
                    bottom: Insets.xl,
                  ),
                  itemCount: state.items.length + (state.loadingMore ? 1 : 0),
                  itemBuilder: (BuildContext context, int i) {
                    if (i >= state.items.length) {
                      return const Padding(
                        padding: EdgeInsets.all(Insets.md),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final OmbiRequest request = state.items[i];
                    final OmbiSearchHit? title = request.asSearchHit;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Insets.lg,
                        0,
                        Insets.lg,
                        Insets.md,
                      ),
                      child: OmbiRequestCard(
                        request: request,
                        onOpen: title == null
                            ? null
                            : () => showOmbiRequestSheet(
                                  context: context,
                                  instance: instance,
                                  hit: title,
                                ),
                        onApprove: () =>
                            approveOmbiRequest(context, ref, instance, request),
                        onDeny: () =>
                            denyOmbiRequest(context, ref, instance, request),
                        onDelete: () =>
                            deleteOmbiRequest(context, ref, instance, request),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
  }
}
