import 'package:cached_network_image/cached_network_image.dart';
import 'package:core_models/core_models.dart';
import 'package:core_player/core_player.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'emby_client.dart';
import 'emby_providers.dart';
import 'models/emby_item.dart';
import 'models/emby_view.dart';

/// Container types - tapping drills into children. Everything else plays.
/// (See the note in JellyfinHome: we dispatch on "is it a container?" so an
/// item with a missing/odd `Type` still plays rather than dead-ending.)
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

/// Emby's per-instance UI: library chips + poster grid. Mirrors JellyfinHome,
/// including tap-to-play and drill-into-folder.
class EmbyHome extends ConsumerStatefulWidget {
  const EmbyHome({required this.instance, super.key});

  final Instance instance;

  @override
  ConsumerState<EmbyHome> createState() => _EmbyHomeState();
}

class _EmbyHomeState extends ConsumerState<EmbyHome> {
  String? _selectedLibraryId;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<EmbyView>> views =
        ref.watch(embyViewsProvider(widget.instance));

    return AsyncValueView<List<EmbyView>>(
      value: views,
      onRetry: () => ref.invalidate(embyViewsProvider(widget.instance)),
      data: (List<EmbyView> libraries) {
        if (libraries.isEmpty) {
          return const EmptyView(
            icon: Icons.theaters_outlined,
            title: 'No libraries',
            message: 'This Emby server has no libraries to show.',
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

  final List<EmbyView> libraries;
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
          final EmbyView lib = libraries[index];
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

class _ItemsGrid extends ConsumerWidget {
  const _ItemsGrid({required this.instance, required this.libraryId});

  final Instance instance;
  final String libraryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<EmbyItem>> items =
        ref.watch(embyItemsProvider((instance, libraryId)));
    final EmbyClient? client =
        ref.watch(embyClientProvider(instance)).valueOrNull;

    return RefreshIndicator(
      onRefresh: () async =>
          ref.invalidate(embyItemsProvider((instance, libraryId))),
      child: AsyncValueView<List<EmbyItem>>(
        value: items,
        onRetry: () =>
            ref.invalidate(embyItemsProvider((instance, libraryId))),
        data: (List<EmbyItem> list) {
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
              final EmbyItem item = list[index];
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

  void _openItem(BuildContext context, EmbyClient client, EmbyItem item) {
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

class _FolderScreen extends StatelessWidget {
  const _FolderScreen({required this.instance, required this.item});

  final Instance instance;
  final EmbyItem item;

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

  final EmbyItem item;
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
      errorWidget: (BuildContext context, String url, Object error) =>
          fallback,
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
