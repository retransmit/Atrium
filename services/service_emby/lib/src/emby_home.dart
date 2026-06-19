import 'package:cached_network_image/cached_network_image.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'emby_client.dart';
import 'emby_item_detail.dart';
import 'emby_music_screens.dart';
import 'emby_providers.dart';
import 'emby_season_screen.dart';
import 'models/emby_item.dart';
import 'models/emby_session.dart';
import 'models/emby_view.dart';

/// Container types - tapping drills into children. Everything else plays.
/// (See the note in JellyfinHome: we dispatch on "is it a container?" so an
/// item with a missing/odd `Type` still plays rather than dead-ending.)
const Set<String> embyContainerTypes = <String>{
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
        final String selected = _selectedLibraryId ?? 'home';
        return Column(
          children: <Widget>[
            _LibraryChips(
              libraries: libraries,
              selectedId: selected,
              onSelect: (String id) => setState(() => _selectedLibraryId = id),
            ),
            Expanded(
              child: selected == 'home'
                  ? _HomeSections(instance: widget.instance)
                  : (selected == 'watched' || selected == 'unwatched')
                      ? EmbyItemsGrid(
                          instance: widget.instance,
                          libraryId: selected,
                        )
                      : EmbyLibraryGrid(
                          instance: widget.instance,
                          view: libraries.firstWhere((lib) => lib.id == selected),
                        ),
            ),
          ],
        );
      },
    );
  }
}

class _LibraryChips extends ConsumerWidget {
  const _LibraryChips({
    required this.libraries,
    required this.selectedId,
    required this.onSelect,
  });

  final List<EmbyView> libraries;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 48,
      child: Row(
        children: <Widget>[
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
              itemCount: libraries.length + 3,
              separatorBuilder: (_, __) => const SizedBox(width: Insets.sm),
              itemBuilder: (BuildContext context, int index) {
                if (index == 0) {
                  return Center(
                    child: ChoiceChip(
                      label: const Text('Home'),
                      selected: 'home' == selectedId,
                      onSelected: (_) => onSelect('home'),
                    ),
                  );
                }
                
                if (index <= libraries.length) {
                  final EmbyView lib = libraries[index - 1];
                  return Center(
                    child: ChoiceChip(
                      label: Text(lib.name),
                      selected: lib.id == selectedId,
                      onSelected: (_) => onSelect(lib.id),
                    ),
                  );
                }

                if (index == libraries.length + 1) {
                  return Center(
                    child: ChoiceChip(
                      label: const Text('Watched'),
                      selected: 'watched' == selectedId,
                      onSelected: (_) => onSelect('watched'),
                    ),
                  );
                }

                if (index == libraries.length + 2) {
                  return Center(
                    child: ChoiceChip(
                      label: const Text('Unwatched'),
                      selected: 'unwatched' == selectedId,
                      onSelected: (_) => onSelect('unwatched'),
                    ),
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
          if (selectedId != 'home')
            PopupMenuButton<double>(
              icon: const Icon(Icons.grid_view),
              tooltip: 'Grid Size',
              onSelected: (double value) {
                ref.read(embyGridScaleProvider.notifier).state = value;
              },
              itemBuilder: (BuildContext context) {
                final double current = ref.read(embyGridScaleProvider);
                return <PopupMenuEntry<double>>[
                  PopupMenuItem<double>(
                    value: 80.0,
                    child: Text('Small ${current == 80.0 ? '(Active)' : ''}'),
                  ),
                  PopupMenuItem<double>(
                    value: 140.0,
                    child: Text('Medium ${current == 140.0 ? '(Active)' : ''}'),
                  ),
                  PopupMenuItem<double>(
                    value: 200.0,
                    child: Text('Large ${current == 200.0 ? '(Active)' : ''}'),
                  ),
                ];
              },
            ),
          const SizedBox(width: Insets.sm),
        ],
      ),
    );
  }
}

class EmbyLibraryGrid extends ConsumerWidget {
  const EmbyLibraryGrid({required this.instance, required this.view, super.key});

  final Instance instance;
  final EmbyView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<EmbyItem>> items =
        ref.watch(embyLibraryItemsProvider((instance, view)));
    final EmbyClient? client =
        ref.watch(embyClientProvider(instance)).value;

    return RefreshIndicator(
      onRefresh: () async =>
          ref.invalidate(embyLibraryItemsProvider((instance, view))),
      child: AsyncValueView<List<EmbyItem>>(
        value: items,
        onRetry: () => ref.invalidate(embyLibraryItemsProvider((instance, view))),
        data: (List<EmbyItem> list) {
          if (list.isEmpty) {
            return const EmptyView(
              icon: Icons.movie_outlined,
              title: 'Empty library',
              message: 'Nothing in this library yet.',
            );
          }
          final double scale = ref.watch(embyGridScaleProvider);
          return MasonryGridView.extent(
            padding: Insets.page,
            maxCrossAxisExtent: scale,
            crossAxisSpacing: Insets.md,
            mainAxisSpacing: Insets.md,
            itemCount: list.length,
            itemBuilder: (BuildContext context, int index) {
              final EmbyItem item = list[index];
              return EmbyPosterCard(
                instance: instance,
                item: item,
                imageUrl: client?.imageUrl(item),
                onTap: client == null
                    ? null
                    : () {
                        if (item.type == 'MusicAlbum') {
                          pushScreen<void>(
                            context,
                            EmbyAlbumScreen(
                              instance: instance,
                              albumId: item.id,
                              albumName: item.name,
                              albumArtist: item.artists.isNotEmpty ? item.artists.first : 'Unknown Artist',
                              albumOverview: item.overview,
                              albumImageUrl: client.imageUrl(item),
                            ),
                          );
                        } else if (item.type == 'Series') {
                          pushScreen<void>(
                            context,
                            EmbyItemDetailScreen(instance: instance, itemId: item.id),
                          );
                        } else if (item.type == 'Season') {
                          pushScreen<void>(
                            context,
                            EmbySeasonScreen(
                              instance: instance,
                              seasonId: item.id,
                              seasonName: item.name,
                              seasonImageUrl: client.imageUrl(item),
                            ),
                          );
                        } else if (embyContainerTypes.contains(item.type)) {
                          pushScreen<void>(
                            context,
                            EmbyFolderScreen(instance: instance, item: item),
                          );
                        } else {
                          pushScreen<void>(
                            context,
                            EmbyItemDetailScreen(instance: instance, itemId: item.id),
                          );
                        }
                      },
              );
            },
          );
        },
      ),
    );
  }
}

class EmbyItemsGrid extends ConsumerWidget {
  const EmbyItemsGrid({required this.instance, required this.libraryId, super.key});

  final Instance instance;
  final String libraryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<EmbyItem>> items =
        ref.watch(embyItemsProvider((instance, libraryId)));
    final EmbyClient? client =
        ref.watch(embyClientProvider(instance)).value;

    return RefreshIndicator(
      onRefresh: () async =>
          ref.invalidate(embyItemsProvider((instance, libraryId))),
      child: AsyncValueView<List<EmbyItem>>(
        value: items,
        onRetry: () => ref.invalidate(embyItemsProvider((instance, libraryId))),
        data: (List<EmbyItem> list) {
          if (list.isEmpty) {
            return const EmptyView(
              icon: Icons.movie_outlined,
              title: 'Empty library',
              message: 'Nothing in this library yet.',
            );
          }
          final double scale = ref.watch(embyGridScaleProvider);
          return MasonryGridView.extent(
            padding: Insets.page,
            maxCrossAxisExtent: scale,
            crossAxisSpacing: Insets.md,
            mainAxisSpacing: Insets.md,
            itemCount: list.length,
            itemBuilder: (BuildContext context, int index) {
              final EmbyItem item = list[index];
              return EmbyPosterCard(
                instance: instance,
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
    if (item.type == 'MusicAlbum') {
      pushScreen<void>(
        context,
        EmbyAlbumScreen(
          instance: instance,
          albumId: item.id,
          albumName: item.name,
          albumArtist: item.artists.isNotEmpty ? item.artists.first : 'Unknown Artist',
          albumOverview: item.overview,
          albumImageUrl: client.imageUrl(item),
        ),
      );
      return;
    }
    if (item.type == 'Series') {
      pushScreen<void>(
        context,
        EmbyItemDetailScreen(instance: instance, itemId: item.id),
      );
      return;
    }
    if (item.type == 'Season') {
      pushScreen<void>(
        context,
        EmbySeasonScreen(
          instance: instance,
          seasonId: item.id,
          seasonName: item.name,
          seasonImageUrl: client.imageUrl(item),
        ),
      );
      return;
    }
    if (embyContainerTypes.contains(item.type)) {
      // pushScreen = root navigator; branch-navigator pushes get swept by
      // GoRouter shell rebuilds.
      pushScreen<void>(
        context,
        EmbyFolderScreen(instance: instance, item: item),
      );
      return;
    }
    pushScreen<void>(
      context,
      EmbyItemDetailScreen(instance: instance, itemId: item.id),
    );
  }
}

class EmbyFolderScreen extends ConsumerWidget {
  const EmbyFolderScreen({required this.instance, required this.item, super.key});

  final Instance instance;
  final EmbyItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final EmbyClient? client =
        ref.watch(embyClientProvider(instance)).value;
    final AsyncValue<EmbyItem> itemAsync =
        ref.watch(embyItemDetailsProvider((instance, item.id)));
        
    final EmbyItem currentItem = itemAsync.value ?? item;

    return Scaffold(
      appBar: AppBar(
        title: Text(currentItem.name),
        actions: <Widget>[
          if (client != null)
            IconButton(
              icon: Icon(
                currentItem.userData?.isFavorite == true
                    ? Icons.favorite
                    : Icons.favorite_border,
                color: currentItem.userData?.isFavorite == true
                    ? Colors.red
                    : null,
              ),
              onPressed: () async {
                final bool isFav = currentItem.userData?.isFavorite == true;
                await client.markFavorite(currentItem.id, !isFav);
                ref.invalidate(embyItemDetailsProvider((instance, currentItem.id)));
                ref.invalidate(embyFavoritesProvider(instance));
              },
            ),
        ],
      ),
      body: EmbyItemsGrid(instance: instance, libraryId: currentItem.id),
    );
  }
}

class EmbyPosterCard extends ConsumerWidget {
  const EmbyPosterCard({
    required this.instance,
    required this.item,
    required this.imageUrl,
    required this.onTap,
    super.key,
  });

  final Instance instance;
  final EmbyItem item;
  final String? imageUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final double progress = (item.userData?.playedPercentage ?? 0) / 100.0;
    final bool played = item.userData?.played ?? false;

    return InkWell(
      onTap: onTap,
      onLongPress: () {
        showModalBottomSheet<void>(
          context: context,
          useRootNavigator: true,
          builder: (BuildContext context) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ListTile(
                    leading: Icon(
                      item.userData?.played == true
                          ? Icons.check_circle
                          : Icons.check_circle_outline,
                    ),
                    title: Text(item.userData?.played == true
                        ? 'Mark as Unwatched'
                        : 'Mark as Watched',),
                    onTap: () async {
                      Navigator.of(context).pop();
                      final toggle = ref.read(embyToggleWatchedProvider(instance));
                      await toggle(item.id, !(item.userData?.played == true));
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      item.userData?.isFavorite == true
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: item.userData?.isFavorite == true
                          ? Colors.red
                          : null,
                    ),
                    title: Text(item.userData?.isFavorite == true
                        ? 'Remove from Favorites'
                        : 'Add to Favorites',),
                    onTap: () async {
                      Navigator.of(context).pop();
                      final EmbyClient? client =
                          ref.read(embyClientProvider(instance)).value;
                      if (client != null) {
                        final bool isFav =
                            item.userData?.isFavorite == true;
                        await client.markFavorite(item.id, !isFav);
                        // Invalidate to refresh UI
                        ref.invalidate(
                            embyItemDetailsProvider((instance, item.id)),);
                        ref.invalidate(embyFavoritesProvider(instance));
                        ref.invalidate(embyItemsProvider);
                        ref.invalidate(embyNextUpProvider(instance));
                        ref.invalidate(embyResumeItemsProvider(instance));
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
      borderRadius: Radii.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AspectRatio(
            aspectRatio: item.type == 'Episode'
                ? (2 / 3)
                : ((item.primaryImageAspectRatio != null && item.primaryImageAspectRatio! > 0.0)
                    ? item.primaryImageAspectRatio!
                    : (item.type == 'MusicAlbum' || item.type == 'Audio' || item.type == 'MusicArtist'
                        ? 1.0
                        : (2 / 3))),
            child: ClipRRect(
              borderRadius: Radii.card,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  _poster(theme),
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
            item.seriesName ?? item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium,
          ),
          if (item.seriesName != null)
            Text(
              (item.parentIndexNumber != null && item.indexNumber != null)
                  ? 'S${item.parentIndexNumber}:E${item.indexNumber} — ${item.name}'
                  : item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.outline),
            )
          else if (item.productionYear != null)
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
    final bool isMusic = item.type == 'MusicAlbum' || item.type == 'MusicArtist' || item.type == 'Audio';
    final Widget fallback = Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        isMusic ? Icons.album_outlined : Icons.movie_outlined,
        color: theme.colorScheme.outline,
      ),
    );
    if (imageUrl == null) {
      return fallback;
    }
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      fit: BoxFit.cover,
      memCacheWidth: 200,
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

class _HomeSections extends ConsumerWidget {
  const _HomeSections({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(embySessionsProvider(instance));
        ref.invalidate(embyResumeItemsProvider(instance));
        ref.invalidate(embyLatestItemsProvider(instance));
        ref.invalidate(embyFavoritesProvider(instance));
        ref.invalidate(embyNextUpProvider(instance));
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: Insets.md),
        children: <Widget>[
          _ActiveSessionsSection(instance: instance),
          _HorizontalSection(
            instance: instance,
            title: 'Currently Watching',
            provider: embyResumeItemsProvider(instance),
          ),
          _HorizontalSection(
            instance: instance,
            title: 'Recently Added',
            provider: embyLatestItemsProvider(instance),
          ),
          _HorizontalSection(
            instance: instance,
            title: 'Favorites',
            provider: embyFavoritesProvider(instance),
          ),
        ],
      ),
    );
  }
}

class _HorizontalSection extends ConsumerWidget {
  const _HorizontalSection({
    required this.instance,
    required this.title,
    required this.provider,
  });

  final Instance instance;
  final String title;
  final ProviderListenable<AsyncValue<List<EmbyItem>>> provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<EmbyItem>> items = ref.watch(provider);
    final EmbyClient? client =
        ref.watch(embyClientProvider(instance)).value;

    return AsyncValueView<List<EmbyItem>>(
      value: items,
      onRetry: () {},
      data: (List<EmbyItem> list) {
        if (list.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.lg,
                vertical: Insets.sm,
              ),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            SizedBox(
              height: 240,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(width: Insets.md),
                itemBuilder: (BuildContext context, int index) {
                  final EmbyItem item = list[index];
                  final String type = item.type;
                  final double rawRatio = item.type == 'Episode' 
                      ? (2 / 3) 
                      : (item.primaryImageAspectRatio ?? 0.0);
                  final double ratio = rawRatio > 0.0 
                      ? rawRatio 
                      : (type == 'MusicAlbum' || type == 'Audio' || type == 'MusicArtist' ? 1.0 : (2 / 3));
                  
                  final double exactWidth = 190.0 * ratio;
                  final double cardWidth = exactWidth.clamp(80.0, 400.0);
                  
                  return SizedBox(
                    width: cardWidth,
                    child: EmbyPosterCard(
                      instance: instance,
                      item: item,
                      imageUrl: client?.imageUrl(item),
                      onTap: client == null
                          ? null
                          : () {
                              if (item.type == 'MusicAlbum') {
                                pushScreen<void>(
                                  context,
                                  EmbyAlbumScreen(
                                    instance: instance,
                                    albumId: item.id,
                                    albumName: item.name,
                                    albumArtist: item.artists.isNotEmpty ? item.artists.first : 'Unknown Artist',
                                    albumOverview: item.overview,
                                    albumImageUrl: client.imageUrl(item),
                                  ),
                                );
                              } else if (item.type == 'Series') {
                                pushScreen<void>(
                                  context,
                                  EmbyItemDetailScreen(instance: instance, itemId: item.id),
                                );
                              } else if (item.type == 'Season') {
                                pushScreen<void>(
                                  context,
                                  EmbySeasonScreen(
                                    instance: instance,
                                    seasonId: item.id,
                                    seasonName: item.name,
                                    seasonImageUrl: client.imageUrl(item),
                                  ),
                                );
                              } else if (embyContainerTypes.contains(item.type)) {
                                pushScreen<void>(
                                  context,
                                  EmbyFolderScreen(
                                    instance: instance,
                                    item: item,
                                  ),
                                );
                              } else {
                                pushScreen<void>(
                                  context,
                                  EmbyItemDetailScreen(
                                    instance: instance,
                                    itemId: item.id,
                                  ),
                                );
                              }
                            },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: Insets.lg),
          ],
        );
      },
    );
  }
}

class _ActiveSessionsSection extends ConsumerWidget {
  const _ActiveSessionsSection({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ActiveSession>> sessions =
        ref.watch(embySessionsProvider(instance));

    return AsyncValueView<List<ActiveSession>>(
      value: sessions,
      onRetry: () {},
      data: (List<ActiveSession> list) {
        if (list.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: Insets.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.lg,
                  vertical: Insets.sm,
                ),
                child: Text(
                  'Currently Streaming',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              SizedBox(
                height: 168, // Fixed height for horizontal scroll, leaves room for elevation shadow
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(width: Insets.md),
                  itemBuilder: (BuildContext context, int index) {
                    return SizedBox(
                      width: 330, // Limit width of the card so it fits nicely in the horizontal list
                      child: _SessionCard(session: list[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final ActiveSession session;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double pct = session.progressPercent / 100.0;
    final bool playing = session.status == 'Playing';

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.card,
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Stack(
        children: <Widget>[
          // Backdrop
          if (session.posterUrl != null)
            Positioned.fill(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Image.network(
                    session.posterUrl!,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          theme.colorScheme.surface,
                          theme.colorScheme.surface.withValues(alpha: 0.85),
                          theme.colorScheme.surface.withValues(alpha: 0.6),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
          // Content
          Padding(
            padding: const EdgeInsets.all(Insets.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Poster
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120, maxHeight: 126),
              child: AspectRatio(
                aspectRatio: session.aspectRatio != null && session.aspectRatio! > 0.0 ? session.aspectRatio! : (2 / 3),
                child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
                image: session.posterUrl != null
                    ? DecorationImage(
                        image: NetworkImage(session.posterUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: session.posterUrl == null
                  ? Icon(Icons.movie_outlined, color: theme.colorScheme.outline, size: 32)
                  : null,
                ),
              ),
            ),
            const SizedBox(width: Insets.lg),
            
            // Details
            Expanded(
              child: SizedBox(
                height: 126,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Title
                    Text(
                      session.showTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    
                    if (session.episodeName != null)
                      Text(
                        session.episodeName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    
                    const SizedBox(height: 4),
                    Text(
                      '${session.user}: ${session.device}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Progress Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          session.timePosition,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          session.timeDuration,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    
                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          playing ? theme.colorScheme.primary : theme.colorScheme.outline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  ),
);
  }
}

