import 'package:cached_network_image/cached_network_image.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import 'models/plex_models.dart';
import 'models/plex_session.dart';
import 'plex_api.dart';
import 'plex_item_detail.dart';
import 'plex_music_screens.dart';
import 'plex_providers.dart';
import 'plex_season_screen.dart';
import 'plex_session_detail_screen.dart';

/// Plex item types that open the detail screen; everything else is a container
/// we drill into. Plex types are reliable and lowercase, so an allowlist is
/// safe here (unlike Jellyfin/Emby, which use a container denylist).
const Set<String> plexPlayableTypes = <String>{'movie', 'episode', 'clip'};

/// Plex's per-instance UI: a Home tab (Continue Watching + Recently Added)
/// plus a chip per library backed by a poster grid with genre filter chips.
/// Tapping a movie/episode opens its detail screen; a show opens its seasons,
/// an artist its albums, and other containers drill into their children.
class PlexHome extends ConsumerStatefulWidget {
  const PlexHome({required this.instance, super.key});

  final Instance instance;

  @override
  ConsumerState<PlexHome> createState() => _PlexHomeState();
}

class _PlexHomeState extends ConsumerState<PlexHome> {
  /// 'home' selects the hub view; any other value is a library section key.
  String _selectedKey = 'home';

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<PlexLibrary>> libraries =
        ref.watch(plexLibrariesProvider(widget.instance));

    return AsyncValueView<List<PlexLibrary>>(
      value: libraries,
      onRetry: () => ref.invalidate(plexLibrariesProvider(widget.instance)),
      data: (List<PlexLibrary> libs) {
        return Column(
          children: <Widget>[
            _LibraryChips(
              libraries: libs,
              selectedKey: _selectedKey,
              onSelect: (String k) => setState(() => _selectedKey = k),
            ),
            Expanded(
              child: _selectedKey == 'home'
                  ? _HomeSections(instance: widget.instance)
                  : _ItemsGrid(
                      instance: widget.instance,
                      id: _selectedKey,
                      isSection: true,
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
    required this.selectedKey,
    required this.onSelect,
  });

  final List<PlexLibrary> libraries;
  final String selectedKey;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
        itemCount: libraries.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: Insets.sm),
        itemBuilder: (BuildContext context, int index) {
          if (index == 0) {
            return Center(
              child: ChoiceChip(
                label: const Text('Home'),
                selected: selectedKey == 'home',
                onSelected: (_) => onSelect('home'),
              ),
            );
          }
          final PlexLibrary lib = libraries[index - 1];
          return Center(
            child: ChoiceChip(
              label: Text(lib.title),
              selected: lib.key == selectedKey,
              onSelected: (_) => onSelect(lib.key),
            ),
          );
        },
      ),
    );
  }
}

/// Grid of items, sourced either from a library section ([isSection] true,
/// [id] = sectionKey) or from a parent's children ([isSection] false, [id] =
/// ratingKey). Section grids carry a genre-chip strip that swaps the grid to
/// a genre-filtered source.
class _ItemsGrid extends ConsumerStatefulWidget {
  const _ItemsGrid({
    required this.instance,
    required this.id,
    required this.isSection,
  });

  final Instance instance;
  final String id;
  final bool isSection;

  @override
  ConsumerState<_ItemsGrid> createState() => _ItemsGridState();
}

class _ItemsGridState extends ConsumerState<_ItemsGrid> {
  /// Selected genre directory key; null means unfiltered ("All").
  String? _genreKey;

  FutureProvider<List<PlexMetadata>> get _provider {
    if (!widget.isSection) {
      return plexChildrenProvider((widget.instance, widget.id));
    }
    final String? genreKey = _genreKey;
    if (genreKey != null) {
      return plexGenreItemsProvider((widget.instance, widget.id, genreKey));
    }
    return plexItemsProvider((widget.instance, widget.id));
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<PlexMetadata>> items = ref.watch(_provider);
    final PlexApi? api = ref.watch(plexApiProvider(widget.instance)).value;

    final Widget grid = RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(_provider);
        if (widget.isSection) {
          ref.invalidate(plexGenresProvider((widget.instance, widget.id)));
        }
      },
      child: AsyncValueView<List<PlexMetadata>>(
        value: items,
        onRetry: () => ref.invalidate(_provider),
        data: (List<PlexMetadata> list) {
          if (list.isEmpty) {
            return const EmptyView(
              icon: Icons.movie_outlined,
              title: 'Empty',
              message: 'Nothing here yet.',
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
              final PlexMetadata item = list[index];
              return PlexPosterCard(
                instance: widget.instance,
                item: item,
                imageUrl: api?.imageUrl(item.thumb),
                onTap: () => openPlexItem(context, widget.instance, item),
              );
            },
          );
        },
      ),
    );

    if (!widget.isSection) {
      return grid;
    }
    return Column(
      children: <Widget>[
        _genreStrip(),
        Expanded(child: grid),
      ],
    );
  }

  /// Horizontal genre filter chips for a section. Renders nothing while the
  /// genre list is empty, loading, or errored so the grid is never blocked.
  Widget _genreStrip() {
    final List<PlexGenreDir> genres = ref
            .watch(plexGenresProvider((widget.instance, widget.id)))
            .value ??
        const <PlexGenreDir>[];
    if (genres.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
        itemCount: genres.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: Insets.sm),
        itemBuilder: (BuildContext context, int index) {
          if (index == 0) {
            return Center(
              child: FilterChip(
                label: const Text('All'),
                selected: _genreKey == null,
                onSelected: (_) => setState(() => _genreKey = null),
              ),
            );
          }
          final PlexGenreDir genre = genres[index - 1];
          return Center(
            child: FilterChip(
              label: Text(genre.title),
              selected: _genreKey == genre.key,
              onSelected: (bool selected) =>
                  setState(() => _genreKey = selected ? genre.key : null),
            ),
          );
        },
      ),
    );
  }
}

/// Opens [item]: a playable type goes to its detail screen, a show to its
/// season list, an artist/album into the music flow, and any other container
/// drills into a child grid. Uses the root navigator so GoRouter's shell
/// rebuilds don't sweep the pushed route.
void openPlexItem(BuildContext context, Instance instance, PlexMetadata item) {
  if (plexPlayableTypes.contains(item.type)) {
    pushScreen<void>(
      context,
      PlexItemDetailScreen(instance: instance, ratingKey: item.ratingKey),
    );
  } else if (item.type == 'show') {
    pushScreen<void>(
      context,
      PlexSeasonScreen(instance: instance, show: item),
    );
  } else if (item.type == 'artist') {
    pushScreen<void>(
      context,
      PlexArtistScreen(instance: instance, artist: item),
    );
  } else if (item.type == 'album') {
    pushScreen<void>(
      context,
      PlexAlbumScreen(instance: instance, album: item),
    );
  } else {
    pushScreen<void>(
      context,
      _FolderScreen(instance: instance, item: item),
    );
  }
}

class _FolderScreen extends StatelessWidget {
  const _FolderScreen({required this.instance, required this.item});

  final Instance instance;
  final PlexMetadata item;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(item.title)),
      body: _ItemsGrid(
        instance: instance,
        id: item.ratingKey,
        isSection: false,
      ),
    );
  }
}

/// Hub view: Now Streaming (active sessions), Continue Watching (on deck),
/// then Recently Added.
class _HomeSections extends ConsumerWidget {
  const _HomeSections({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(plexSessionsProvider(instance));
        ref.invalidate(plexOnDeckProvider(instance));
        ref.invalidate(plexRecentlyAddedProvider(instance));
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: Insets.md),
        children: <Widget>[
          _NowStreamingSection(instance: instance),
          _PlexSection(
            instance: instance,
            title: 'Continue Watching',
            provider: plexOnDeckProvider(instance),
          ),
          _PlexSection(
            instance: instance,
            title: 'Recently Added',
            provider: plexRecentlyAddedProvider(instance),
          ),
        ],
      ),
    );
  }
}

/// "Now Streaming" - active sessions, polled while the hub is visible.
/// Additive row: empty, loading, and error all render nothing so the hub is
/// never blocked by the sessions poller. Tapping a card opens the
/// now-playing controller for that stream.
class _NowStreamingSection extends ConsumerWidget {
  const _NowStreamingSection({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<PlexSession> sessions =
        ref.watch(plexSessionsProvider(instance)).value ?? const <PlexSession>[];
    final PlexApi? api = ref.watch(plexApiProvider(instance)).value;
    if (sessions.isEmpty) {
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
            'Now Streaming',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
            itemCount: sessions.length,
            separatorBuilder: (_, __) => const SizedBox(width: Insets.md),
            itemBuilder: (BuildContext context, int index) {
              final PlexSession session = sessions[index];
              return _SessionCard(
                instance: instance,
                session: session,
                imageUrl: api?.imageUrl(session.thumb),
              );
            },
          ),
        ),
        const SizedBox(height: Insets.lg),
      ],
    );
  }
}

/// Compact card for one active stream: poster, title, player, live progress.
class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.instance,
    required this.session,
    required this.imageUrl,
  });

  final Instance instance;
  final PlexSession session;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String title = session.grandparentTitle ?? session.title;
    final List<String> subtitleParts = <String>[
      if (session.player != null && session.player!.title.isNotEmpty)
        session.player!.title,
      if (session.user != null && session.user!.title.isNotEmpty)
        session.user!.title,
    ];
    return SizedBox(
      width: 240,
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: theme.colorScheme.surfaceContainerLow,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
        child: InkWell(
          onTap: () => pushScreen<void>(
            context,
            PlexSessionDetailScreen(instance: instance, initialSession: session),
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 56,
                height: double.infinity,
                child: _poster(theme),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (subtitleParts.isNotEmpty) ...<Widget>[
                      const SizedBox(height: Insets.xs),
                      Text(
                        subtitleParts.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ],
                    const SizedBox(height: Insets.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: session.progress,
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Insets.md),
            ],
          ),
        ),
      ),
    );
  }

  Widget _poster(ThemeData theme) {
    final Widget fallback = Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        session.player?.state == 'paused'
            ? Icons.pause_circle_outline
            : Icons.play_circle_outline,
        color: theme.colorScheme.outline,
      ),
    );
    if (imageUrl == null) {
      return fallback;
    }
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      fit: BoxFit.cover,
      memCacheWidth: 120,
      placeholder: (BuildContext context, String url) =>
          Container(color: theme.colorScheme.surfaceContainerHighest),
      errorWidget: (BuildContext context, String url, Object error) => fallback,
    );
  }
}

/// One horizontal poster row on the hub view. Renders nothing when empty so a
/// server with no on-deck items doesn't show a stray header.
class _PlexSection extends ConsumerWidget {
  const _PlexSection({
    required this.instance,
    required this.title,
    required this.provider,
  });

  final Instance instance;
  final String title;
  final ProviderListenable<AsyncValue<List<PlexMetadata>>> provider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<PlexMetadata>> items = ref.watch(provider);
    final PlexApi? api = ref.watch(plexApiProvider(instance)).value;

    return items.maybeWhen(
      data: (List<PlexMetadata> list) {
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
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
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
                  final PlexMetadata item = list[index];
                  return SizedBox(
                    width: 120,
                    child: PlexPosterCard(
                      instance: instance,
                      item: item,
                      imageUrl: api?.imageUrl(item.thumb),
                      onTap: () => openPlexItem(context, instance, item),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: Insets.lg),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// A poster tile for a Plex item, with a watched badge, resume-progress bar,
/// and a long-press menu to toggle watched state.
class PlexPosterCard extends ConsumerWidget {
  const PlexPosterCard({
    required this.instance,
    required this.item,
    required this.imageUrl,
    required this.onTap,
    super.key,
  });

  final Instance instance;
  final PlexMetadata item;
  final String? imageUrl;
  final VoidCallback? onTap;

  bool get _watched =>
      item.viewCount > 0 ||
      (item.leafCount != null &&
          item.leafCount! > 0 &&
          item.viewedLeafCount == item.leafCount);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final double progress = (item.viewOffset != null &&
            item.duration != null &&
            item.duration! > 0)
        ? item.viewOffset! / item.duration!
        : 0;
    final bool isEpisode = item.grandparentTitle != null;

    return InkWell(
      onTap: onTap,
      onLongPress: () => _showActions(context, ref),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    _poster(theme),
                    if (_watched)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Icon(
                            Icons.check,
                            size: 14,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    if (!_watched && progress > 0.02)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.all(Insets.sm),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progress.clamp(0, 1),
                              minHeight: 6,
                              backgroundColor:
                                  Colors.black.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: Insets.xs),
          Text(
            isEpisode ? item.grandparentTitle! : item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium,
          ),
          if (isEpisode)
            Text(
              _episodeLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.outline),
            )
          else if (item.year != null)
            Text(
              '${item.year}',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
        ],
      ),
    );
  }

  String get _episodeLabel {
    final String se = (item.parentIndex != null && item.index != null)
        ? 'S${item.parentIndex}:E${item.index}'
        : '';
    return se.isEmpty ? item.title : '$se - ${item.title}';
  }

  Widget _poster(ThemeData theme) {
    final Widget fallback = Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(Icons.movie_outlined, color: theme.colorScheme.outline),
    );
    if (imageUrl == null) {
      return fallback;
    }
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      fit: BoxFit.cover,
      memCacheWidth: 200,
      placeholder: (BuildContext context, String url) =>
          Container(color: theme.colorScheme.surfaceContainerHighest),
      errorWidget: (BuildContext context, String url, Object error) => fallback,
    );
  }

  void _showActions(BuildContext context, WidgetRef ref) {
    final bool watched = _watched;
    showModalBottomSheet<void>(
      context: context,
      // Root navigator: a branch-navigator sheet gets swept by GoRouter's
      // shell rebuilds.
      useRootNavigator: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: Icon(watched ? Icons.remove_done : Icons.done_all),
                title: Text(watched ? 'Mark as unwatched' : 'Mark as watched'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final PlexApi? api =
                      ref.read(plexApiProvider(instance)).value;
                  if (api == null) {
                    return;
                  }
                  await api.setWatched(item.ratingKey, watched: !watched);
                  ref.invalidate(plexItemsProvider);
                  ref.invalidate(plexOnDeckProvider(instance));
                  ref.invalidate(plexRecentlyAddedProvider(instance));
                  ref.invalidate(
                    plexItemDetailProvider((instance, item.ratingKey)),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
