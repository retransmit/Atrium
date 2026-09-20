import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/ombi_models.dart';
import 'ombi_discover_tab.dart';
import 'ombi_failure.dart';
import 'ombi_providers.dart';
import 'ombi_request_actions.dart';
import 'widgets/ombi_request_tile.dart';

/// Ombi for one instance: its requests, filtered by kind and by where each
/// one stands, and a Discover tab to find something new to request.
class OmbiHome extends ConsumerStatefulWidget {
  const OmbiHome({required this.instance, super.key});

  final Instance instance;

  @override
  ConsumerState<OmbiHome> createState() => _OmbiHomeState();
}

class _OmbiHomeState extends ConsumerState<OmbiHome> {
  OmbiMediaKind _kind = OmbiMediaKind.movie;
  OmbiRequestFilter _filter = OmbiRequestFilter.pending;

  static const Map<OmbiRequestFilter, String> _filterLabels =
      <OmbiRequestFilter, String>{
    OmbiRequestFilter.pending: 'Pending',
    OmbiRequestFilter.processing: 'Processing',
    OmbiRequestFilter.available: 'Available',
    OmbiRequestFilter.denied: 'Denied',
    OmbiRequestFilter.all: 'All',
  };

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: <Widget>[
          const TabBar(
            tabs: <Widget>[
              Tab(text: 'Requests', icon: Icon(Icons.playlist_play)),
              Tab(text: 'Discover', icon: Icon(Icons.explore_outlined)),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                // Built from this state rather than a tab widget of its own,
                // so the chosen kind and filter survive a trip to Discover.
                _requests(),
                OmbiDiscoverTab(instance: widget.instance),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _requests() {
    final bool music =
        ref.watch(ombiMusicEnabledProvider(widget.instance)).value ?? false;
    // Lidarr switched off while Music was showing: fall back to movies
    // rather than ask for a list Ombi no longer serves.
    final OmbiMediaKind kind =
        !music && _kind == OmbiMediaKind.music ? OmbiMediaKind.movie : _kind;
    final OmbiListKey key =
        (instance: widget.instance, kind: kind, filter: _filter);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.lg,
            Insets.md,
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
              for (final OmbiRequestFilter f
                  in OmbiRequestFilter.values) ...<Widget>[
                ChoiceChip(
                  label: Text(_filterLabels[f]!),
                  selected: f == _filter,
                  onSelected: (bool _) => setState(() => _filter = f),
                ),
                const SizedBox(width: Insets.sm),
              ],
            ],
          ),
        ),
        const SizedBox(height: Insets.sm),
        Expanded(child: _RequestList(listKey: key)),
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
                  padding: const EdgeInsets.only(bottom: Insets.xl),
                  itemCount: state.items.length + (state.loadingMore ? 1 : 0),
                  itemBuilder: (BuildContext context, int i) {
                    if (i >= state.items.length) {
                      return const Padding(
                        padding: EdgeInsets.all(Insets.md),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final OmbiRequest request = state.items[i];
                    return OmbiRequestTile(
                      request: request,
                      onApprove: () =>
                          approveOmbiRequest(context, ref, instance, request),
                      onDeny: () =>
                          denyOmbiRequest(context, ref, instance, request),
                      onDelete: () =>
                          deleteOmbiRequest(context, ref, instance, request),
                    );
                  },
                ),
              ),
            );
          },
        );
  }
}
