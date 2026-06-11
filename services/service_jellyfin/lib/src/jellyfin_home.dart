import 'package:cached_network_image/cached_network_image.dart';
import 'package:core_models/core_models.dart';
import 'package:core_player/core_player.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'jellyfin_client.dart';
import 'jellyfin_providers.dart';
import 'models/jellyfin_item.dart';
import 'models/jellyfin_view.dart';

/// Item types that are containers - tapping them drills into their children.
/// Everything else is treated as playable and pushed to the video player
/// (libmpv errors gracefully if a stray type turns out not to be playable).
/// We dispatch on "is it a container?" rather than "is it playable?" because
/// a library listing may omit `Type` on some items, and a movie with no type
/// string should still play rather than dead-end in an empty folder.
const Set<String> _containerTypes = <String>{
  'Series',
  'Season',
  'BoxSet',
  'Folder',
  'CollectionFolder',
  'UserView',
  'MusicAlbum',
  'MusicArtist',
  'Playlist',
};

/// Jellyfin's per-instance UI: library chips across the top, a poster grid of
/// the selected library below. Tapping a movie/episode plays it; tapping a
/// series or folder drills into its children.
class JellyfinHome extends ConsumerStatefulWidget {
  const JellyfinHome({required this.instance, super.key});

  final Instance instance;

  @override
  ConsumerState<JellyfinHome> createState() => _JellyfinHomeState();
}

class _JellyfinHomeState extends ConsumerState<JellyfinHome> {
  String? _selectedLibraryId;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<JellyfinView>> views =
        ref.watch(jellyfinViewsProvider(widget.instance));

    return AsyncValueView<List<JellyfinView>>(
      value: views,
      onRetry: () => ref.invalidate(jellyfinViewsProvider(widget.instance)),
      data: (List<JellyfinView> libraries) {
        if (libraries.isEmpty) {
          return const EmptyView(
            icon: Icons.theaters_outlined,
            title: 'No libraries',
            message: 'This Jellyfin server has no libraries to show.',
          );
        }
        final String selected = _selectedLibraryId ?? libraries.first.id;
        return Column(
          children: <Widget>[
            _LibraryChips(
              libraries: libraries,
              selectedId: selected,
              onSelect: (String id) =>
                  setState(() => _selectedLibraryId = id),
            ),
            Expanded(
              child: _ItemsGrid(
                instance: widget.instance,
                libraryId: selected,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LibraryChips extends StatelessWidget {
  const _LibraryChips({
    required this.libraries,
    required this.selectedId,
    required this.onSelect,
  });

  final List<JellyfinView> libraries;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
        itemCount: libraries.length,
        separatorBuilder: (_, __) => const SizedBox(width: Insets.sm),
        itemBuilder: (BuildContext context, int index) {
          final JellyfinView lib = libraries[index];
          return Center(
            child: ChoiceChip(
              label: Text(lib.name),
              selected: lib.id == selectedId,
              onSelected: (_) => onSelect(lib.id),
            ),
          );
        },
      ),
    );
  }
}

/// A grid of items under one parent. Reused both for a top-level library and
/// for drilling into a series/season (via [_FolderScreen]).
class _ItemsGrid extends ConsumerWidget {
  const _ItemsGrid({required this.instance, required this.libraryId});

  final Instance instance;
  final String libraryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<JellyfinItem>> items =
        ref.watch(jellyfinItemsProvider((instance, libraryId)));
    final JellyfinClient? client =
        ref.watch(jellyfinClientProvider(instance)).valueOrNull;

    return RefreshIndicator(
      onRefresh: () async =>
          ref.invalidate(jellyfinItemsProvider((instance, libraryId))),
      child: AsyncValueView<List<JellyfinItem>>(
        value: items,
        onRetry: () =>
            ref.invalidate(jellyfinItemsProvider((instance, libraryId))),
        data: (List<JellyfinItem> list) {
          if (list.isEmpty) {
            return const EmptyView(
              icon: Icons.movie_outlined,
              title: 'Empty library',
              message: 'Nothing in this library yet.',
            );
          }
          return GridView.builder(
            padding: Insets.page,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 140,
              childAspectRatio: 0.52,
              crossAxisSpacing: Insets.md,
              mainAxisSpacing: Insets.md,
            ),
            itemCount: list.length,
            itemBuilder: (BuildContext context, int index) {
              final JellyfinItem item = list[index];
              return _PosterCard(
                item: item,
                imageUrl: client?.imageUrl(item),
                onTap: client == null
                    ? null
                    : () => _openItem(context, client, item),
              );
            },
          );
        },
      ),
    );
  }

  void _openItem(
    BuildContext context,
    JellyfinClient client,
    JellyfinItem item,
  ) {
    if (_containerTypes.contains(item.type)) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _FolderScreen(instance: instance, item: item),
        ),
      );
      return;
    }
    final Duration resume =
        Duration(microseconds: (item.userData?.positionTicks ?? 0) ~/ 10);
    // rootNavigator: the player must cover the bottom nav shell.
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => AtriumPlayerScreen(
          spec: PlaybackSpec(
            url: client.streamUrl(item.id),
            title: item.name,
            startPosition: resume,
            onStarted: (Duration p) =>
                client.reportPlaybackStart(item.id, position: p),
            onProgress: (Duration p, bool paused) =>
                client.reportPlaybackProgress(
              item.id,
              position: p,
              isPaused: paused,
            ),
            onStopped: (Duration p) =>
                client.reportPlaybackStopped(item.id, position: p),
          ),
        ),
      ),
    );
  }
}

/// Drill-down screen showing the children of a series/season/folder.
class _FolderScreen extends StatelessWidget {
  const _FolderScreen({required this.instance, required this.item});

  final Instance instance;
  final JellyfinItem item;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(item.name)),
      body: _ItemsGrid(instance: instance, libraryId: item.id),
    );
  }
}

class _PosterCard extends StatelessWidget {
  const _PosterCard({
    required this.item,
    required this.imageUrl,
    required this.onTap,
  });

  final JellyfinItem item;
  final String? imageUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double progress = (item.userData?.playedPercentage ?? 0) / 100.0;
    final bool played = item.userData?.played ?? false;

    return InkWell(
      onTap: onTap,
      borderRadius: Radii.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: ClipRRect(
              borderRadius: Radii.card,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  _poster(theme),
                  if (!_containerTypes.contains(item.type))
                    const Center(
                      child: Icon(
                        Icons.play_circle_outline,
                        size: 40,
                        color: Colors.white70,
                      ),
                    ),
                  if (played)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: _Badge(
                        color: theme.colorScheme.primary,
                        child: Icon(
                          Icons.check,
                          size: 14,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  if (!played && progress > 0.02)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: LinearProgressIndicator(
                        value: progress.clamp(0, 1),
                        minHeight: 3,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Insets.xs),
          Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium,
          ),
          if (item.productionYear != null)
            Text(
              '${item.productionYear}',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
        ],
      ),
    );
  }

  Widget _poster(ThemeData theme) {
    final Widget fallback = Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.movie_outlined,
        color: theme.colorScheme.outline,
      ),
    );
    if (imageUrl == null) {
      return fallback;
    }
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      fit: BoxFit.cover,
      placeholder: (BuildContext context, String url) => Container(
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      errorWidget: (BuildContext context, String url, Object error) => fallback,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.child, required this.color});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: child,
    );
  }
}
