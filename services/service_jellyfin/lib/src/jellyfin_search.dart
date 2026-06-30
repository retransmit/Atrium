import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'jellyfin_client.dart';
import 'jellyfin_home.dart';
import 'jellyfin_item_detail.dart';
import 'jellyfin_music_screens.dart';
import 'jellyfin_providers.dart';
import 'jellyfin_season_screen.dart';
import 'models/jellyfin_item.dart';

class JellyfinSearchDelegate extends SearchDelegate<void> {
  JellyfinSearchDelegate({required this.instance});

  final Instance instance;

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context);
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return <Widget>[
      Consumer(
        builder: (BuildContext context, WidgetRef ref, _) {
          final JellyfinViewMode viewMode =
              ref.watch(jellyfinViewModeProvider(instance));
          return IconButton(
            icon: Icon(viewMode == JellyfinViewMode.grid
                ? Icons.view_headline
                : Icons.grid_view,),
            tooltip: viewMode == JellyfinViewMode.grid
                ? 'Switch to List View'
                : 'Switch to Grid View',
            onPressed: () {
              ref.read(jellyfinViewModeProvider(instance).notifier).state =
                  viewMode == JellyfinViewMode.grid
                      ? JellyfinViewMode.list
                      : JellyfinViewMode.grid;
            },
          );
        },
      ),
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _SearchResults(instance: instance, query: query);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().isEmpty) {
      return const Center(child: Text('Search for movies or shows.'));
    }
    return _SearchResults(instance: instance, query: query);
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.instance, required this.query});

  final Instance instance;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final JellyfinClient? client = ref.watch(jellyfinClientProvider(instance)).value;

    if (client == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (query.trim().isEmpty) {
      return const Center(child: Text('Search for movies or shows.'));
    }

    return FutureBuilder<List<JellyfinItem>>(
      future: client.searchItems(query.trim()),
      builder: (BuildContext context, AsyncSnapshot<List<JellyfinItem>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final List<JellyfinItem> list = snapshot.data ?? <JellyfinItem>[];
        if (list.isEmpty) {
          return const EmptyView(
            icon: Icons.search_off,
            title: 'No results',
            message: 'No items found matching your search.',
          );
        }

        final JellyfinViewMode viewMode = ref.watch(jellyfinViewModeProvider(instance));

        if (viewMode == JellyfinViewMode.list) {
          return ListView.builder(
            padding: Insets.page,
            itemCount: list.length,
            itemBuilder: (BuildContext context, int index) {
              final JellyfinItem item = list[index];
              return JellyfinBannerCard(
                instance: instance,
                item: item,
                imageUrl: client.imageUrl(item),
                backdropUrl: client.bannerOrPosterUrl(item),
                onTap: () => _openItem(context, client, item),
              );
            },
          );
        }

        return MasonryGridView.extent(
          padding: Insets.page,
          maxCrossAxisExtent: 140.0,
          crossAxisSpacing: Insets.md,
          mainAxisSpacing: Insets.md,
          itemCount: list.length,
          itemBuilder: (BuildContext context, int index) {
            final JellyfinItem item = list[index];
            return JellyfinPosterCard(
              instance: instance,
              item: item,
              imageUrl: client.imageUrl(item),
              onTap: () => _openItem(context, client, item),
            );
          },
        );
      },
    );
  }

  void _openItem(BuildContext context, JellyfinClient client, JellyfinItem item) {
    if (item.type == 'MusicAlbum') {
      pushScreen<void>(
        context,
        JellyfinAlbumScreen(
          instance: instance,
          albumId: item.id,
          albumName: item.name,
          albumArtist:
              item.artists.isNotEmpty ? item.artists.first : 'Unknown Artist',
          albumOverview: item.overview,
          albumImageUrl: client.imageUrl(item),
        ),
      );
    } else if (item.type == 'Series') {
      pushScreen<void>(
        context,
        JellyfinItemDetailScreen(instance: instance, itemId: item.id),
      );
    } else if (item.type == 'Season') {
      pushScreen<void>(
        context,
        JellyfinSeasonScreen(
          instance: instance,
          seriesId: item.seriesId ?? item.parentId ?? '',
          seasonId: item.id,
          seasonName: item.name,
          seasonImageUrl: client.imageUrl(item),
        ),
      );
    } else if (jellyfinContainerTypes.contains(item.type)) {
      pushScreen<void>(
        context,
        JellyfinFolderScreen(instance: instance, item: item),
      );
    } else {
      pushScreen<void>(
        context,
        JellyfinItemDetailScreen(instance: instance, itemId: item.id),
      );
    }
  }
}
