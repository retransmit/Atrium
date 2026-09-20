import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'navidrome_api.dart';
import 'navidrome_providers.dart';
import 'screens/navidrome_album_screen.dart';
import 'screens/navidrome_playlist_screen.dart';
import 'screens/navidrome_search_screen.dart';
import 'widgets/navidrome_artists_tab.dart';
import 'widgets/navidrome_overview_tab.dart';
import 'widgets/navidrome_playlist_dialogs.dart';

String _formatDuration(int seconds) {
  if (seconds <= 0) return '0:00';
  final int m = seconds ~/ 60;
  final int s = seconds % 60;
  if (m >= 60) {
    final int h = m ~/ 60;
    final int remM = m % 60;
    return '$h:${remM.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Filter categories for the Albums tab.
enum NavidromeAlbumCategory {
  all('All', 'alphabeticalByName'),
  random('Random', 'random'),
  favorites('Favorites', 'starred'),
  topRated('Top Rated', 'highest'),
  recentlyAdded('Recently Added', 'newest'),
  recentlyPlayed('Recently Played', 'recent'),
  mostPlayed('Most Played', 'frequent');

  const NavidromeAlbumCategory(this.label, this.type);
  final String label;
  final String type;
}

/// Main home screen for Navidrome music server instances.
class NavidromeHome extends ConsumerStatefulWidget {
  const NavidromeHome({
    required this.instance,
    this.onEdit,
    this.drawer,
    super.key,
  });

  final Instance instance;
  final VoidCallback? onEdit;
  final Widget? drawer;

  @override
  ConsumerState<NavidromeHome> createState() => _NavidromeHomeState();
}

class _NavidromeHomeState extends ConsumerState<NavidromeHome> {
  String _selectedAlbumCategory = NavidromeAlbumCategory.all.type;

  Future<void> _launchWeb(BuildContext context) async {
    final NavidromeClient? client =
        ref.read(navidromeClientProvider(widget.instance)).value;
    final String rawUrl =
        (client != null && client.dio.options.baseUrl.isNotEmpty)
            ? client.dio.options.baseUrl
            : (widget.instance.localUrl.isNotEmpty
                ? widget.instance.localUrl
                : widget.instance.externalUrl);
    final String url = rawUrl.trim();
    if (url.isEmpty) return;
    final Uri? uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _triggerScan(
    BuildContext context, {
    bool fullScan = false,
  }) async {
    try {
      final NavidromeClient client =
          await ref.read(navidromeClientProvider(widget.instance).future);
      await client.startScan(fullScan: fullScan);
      ref.invalidate(navidromeScanStatusProvider(widget.instance));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              fullScan
                  ? 'Full library scan started'
                  : 'Quick scan started (checking for new items)',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start scan: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final int currentIndex =
        ref.watch(navidromeActiveTabIndexProvider(widget.instance));
    final bool isNavbarVisible =
        ref.watch(navidromeBottomNavVisibleProvider(widget.instance));

    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AsyncValue<NavidromeClient> clientAsync =
        ref.watch(navidromeClientProvider(widget.instance));
    final NavidromeClient? client = clientAsync.value;

    final List<Widget> tabs = <Widget>[
      _buildAlbumsTab(theme, cs, client),
      NavidromeArtistsTab(instance: widget.instance),
      _buildPlaylistsTab(theme, cs, client),
      NavidromeOverviewTab(instance: widget.instance),
    ];

    return Scaffold(
      drawerEdgeDragWidth: widget.drawer != null
          ? MediaQuery.sizeOf(context).width * 0.15
          : null,
      drawer: widget.drawer,
      appBar: AppBar(
        leading: widget.drawer != null
            ? Builder(
                builder: (BuildContext context) {
                  return IconButton(
                    icon: const Icon(Icons.menu),
                    tooltip: 'Open navigation menu',
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  );
                },
              )
            : null,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: Text(
                widget.instance.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const BetaBadge(),
          ],
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search library',
            onPressed: () {
              showSearch<void>(
                context: context,
                useRootNavigator: true,
                delegate: NavidromeSearchDelegate(instance: widget.instance),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Quick scan library',
            onPressed: () => _triggerScan(context),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded),
            tooltip: 'Open Web UI',
            onPressed: () => _launchWeb(context),
          ),
        ],
      ),
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
                  final bool currentVisible = ref.read(
                    navidromeBottomNavVisibleProvider(widget.instance),
                  );
                  if (isScrollingDown && currentVisible) {
                    ref
                        .read(
                          navidromeBottomNavVisibleProvider(widget.instance)
                              .notifier,
                        )
                        .state = false;
                  } else if (!isScrollingDown &&
                      !currentVisible &&
                      !isAtBottom) {
                    ref
                        .read(
                          navidromeBottomNavVisibleProvider(widget.instance)
                              .notifier,
                        )
                        .state = true;
                  }
                }
              } else if (pixels <= 0.0) {
                final bool currentVisible = ref.read(
                  navidromeBottomNavVisibleProvider(widget.instance),
                );
                if (!currentVisible) {
                  ref
                      .read(
                        navidromeBottomNavVisibleProvider(widget.instance)
                            .notifier,
                      )
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

                if (ref.read(
                      navidromeActiveTabIndexProvider(widget.instance),
                    ) !=
                    0) {
                  ref
                      .read(
                        navidromeActiveTabIndexProvider(widget.instance)
                            .notifier,
                      )
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
                ref
                    .read(
                      navidromeActiveTabIndexProvider(widget.instance).notifier,
                    )
                    .state = index;
              },
              destinations: const <NavigationDestination>[
                NavigationDestination(
                  icon: Icon(Icons.album_outlined),
                  selectedIcon: Icon(Icons.album),
                  label: 'Albums',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outlined),
                  selectedIcon: Icon(Icons.person),
                  label: 'Artists',
                ),
                NavigationDestination(
                  icon: Icon(Icons.queue_music_outlined),
                  selectedIcon: Icon(Icons.queue_music),
                  label: 'Playlists',
                ),
                NavigationDestination(
                  icon: Icon(Icons.insights_outlined),
                  selectedIcon: Icon(Icons.insights_rounded),
                  label: 'Overview',
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: currentIndex == 2
          ? FloatingActionButton(
              tooltip: 'Create Playlist',
              onPressed: () => showNavidromeCreatePlaylistDialog(
                context: context,
                ref: ref,
                instance: widget.instance,
              ),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildAlbumsTab(
    ThemeData theme,
    ColorScheme cs,
    NavidromeClient? client,
  ) {
    final AsyncValue<List<NavidromeAlbum>> albumsAsync = ref.watch(
      navidromeAlbumsProvider((widget.instance, _selectedAlbumCategory)),
    );

    return Column(
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.md,
            vertical: Insets.sm,
          ),
          child: Row(
            children: NavidromeAlbumCategory.values.map((cat) {
              return Padding(
                padding: const EdgeInsets.only(right: Insets.xs),
                child: ChoiceChip(
                  label: Text(cat.label),
                  selected: _selectedAlbumCategory == cat.type,
                  onSelected: (bool selected) {
                    if (selected) {
                      setState(() => _selectedAlbumCategory = cat.type);
                      ref.invalidate(
                        navidromeAlbumsProvider(
                          (widget.instance, cat.type),
                        ),
                      );
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: EasyRefresh(
            onRefresh: () async {
              await hardRefreshNavidrome(ref, widget.instance);
            },
            child: albumsAsync.when(
              data: (List<NavidromeAlbum> albums) {
                if (albums.isEmpty) {
                  return const Center(child: Text('No albums found'));
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(Insets.md),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.74,
                    crossAxisSpacing: Insets.sm,
                    mainAxisSpacing: Insets.sm,
                  ),
                  itemCount: albums.length,
                  itemBuilder: (BuildContext ctx, int index) {
                    final NavidromeAlbum album = albums[index];
                    final String? coverUrl =
                        client?.getCoverArtUrl(album.coverArt, size: 300);

                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        await pushScreen<void>(
                          context,
                          NavidromeAlbumScreen(
                            instance: widget.instance,
                            albumId: album.id,
                            initialAlbum: album,
                          ),
                        );
                        ref.invalidate(navidromeAlbumsProvider);
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          AspectRatio(
                            aspectRatio: 1.0,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: coverUrl != null
                                  ? AtriumNetworkImage(
                                      imageUrl: coverUrl,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => Container(
                                        color: cs.surfaceContainerHighest,
                                        child: const Icon(
                                          Icons.album_rounded,
                                          size: 40,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: cs.surfaceContainerHighest,
                                      child: const Icon(
                                        Icons.album_rounded,
                                        size: 40,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            album.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            album.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object err, _) => Center(
                child: Text('Failed to load albums: $err'),
              ),
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildPlaylistsTab(
    ThemeData theme,
    ColorScheme cs,
    NavidromeClient? client,
  ) {
    final AsyncValue<List<NavidromePlaylist>> playlistsAsync =
        ref.watch(navidromePlaylistsProvider(widget.instance));

    return EasyRefresh(
      onRefresh: () async {
        await hardRefreshNavidrome(ref, widget.instance);
      },
      child: playlistsAsync.when(
        data: (List<NavidromePlaylist> playlists) {
          if (playlists.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.queue_music_rounded,
                    size: 64,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: Insets.md),
                  Text(
                    'No playlists found',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Insets.sm),
                  Text(
                    'Create custom playlists to organize your music',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),
                  FilledButton.icon(
                    onPressed: () => showNavidromeCreatePlaylistDialog(
                      context: context,
                      ref: ref,
                      instance: widget.instance,
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('New Playlist'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: Insets.sm),
            itemCount: playlists.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (BuildContext ctx, int index) {
              final NavidromePlaylist pl = playlists[index];
              final String? coverUrl =
                  client?.getCoverArtUrl(pl.coverArt, size: 160);

              return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 48,
                    height: 48,
                    color: cs.primaryContainer,
                    child: coverUrl != null
                        ? AtriumNetworkImage(
                            imageUrl: coverUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Icon(
                              Icons.queue_music_rounded,
                              size: 24,
                              color: cs.onPrimaryContainer,
                            ),
                          )
                        : Icon(
                            Icons.queue_music_rounded,
                            size: 24,
                            color: cs.onPrimaryContainer,
                          ),
                  ),
                ),
                title: Text(
                  pl.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${pl.songCount} songs • ${_formatDuration(pl.duration)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () {
                  pushScreen<void>(
                    context,
                    NavidromePlaylistScreen(
                      instance: widget.instance,
                      playlistId: pl.id,
                      initialName: pl.name,
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object err, _) => Center(
          child: Text('Failed to load playlists: $err'),
        ),
      ),
    );
  }
}
