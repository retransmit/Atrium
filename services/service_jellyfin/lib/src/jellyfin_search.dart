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
          return PopupMenuButton<double>(
            icon: const Icon(Icons.grid_view),
            tooltip: 'Grid Size',
            onSelected: (double value) {
              ref.read(jellyfinGridScaleProvider.notifier).state = value;
            },
            itemBuilder: (BuildContext context) {
              final double current = ref.read(jellyfinGridScaleProvider);
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
    final JellyfinClient? client =
        ref.watch(jellyfinClientProvider(instance)).value;

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

        final double scale = ref.watch(jellyfinGridScaleProvider);
        return MasonryGridView.extent(
          padding: Insets.page,
          maxCrossAxisExtent: scale,
          crossAxisSpacing: Insets.md,
          mainAxisSpacing: Insets.md,
          itemCount: list.length,
          itemBuilder: (BuildContext context, int index) {
            final JellyfinItem item = list[index];
            return JellyfinPosterCard(
              instance: instance,
              item: item,
              imageUrl: client.imageUrl(item),
              onTap: () {
                // pushScreen = root navigator; branch-navigator pushes get
                // swept by GoRouter shell rebuilds.
                if (item.type == 'MusicAlbum') {
                  pushScreen<void>(
                    context,
                    JellyfinAlbumScreen(
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
                    JellyfinItemDetailScreen(instance: instance, itemId: item.id),
                  );
                } else if (item.type == 'Season') {
                  pushScreen<void>(
                    context,
                    JellyfinSeasonScreen(
                      instance: instance,
                      seriesId: item.seriesId ?? '',
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
              },
            );
          },
        );
      },
    );
  }
}



