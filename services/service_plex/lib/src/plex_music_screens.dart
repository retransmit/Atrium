import 'package:cached_network_image/cached_network_image.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/plex_models.dart';
import 'plex_api.dart';
import 'plex_providers.dart';

/// Albums of an artist as a cover grid; tapping an album opens its track
/// list. Browse only: Atrium is a controller, music plays in the Plex app.
class PlexArtistScreen extends ConsumerWidget {
  const PlexArtistScreen({
    required this.instance,
    required this.artist,
    super.key,
  });

  final Instance instance;
  final PlexMetadata artist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<PlexMetadata>> albums =
        ref.watch(plexChildrenProvider((instance, artist.ratingKey)));
    final PlexApi? api = ref.watch(plexApiProvider(instance)).value;

    return Scaffold(
      appBar: AppBar(title: Text(artist.title)),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.invalidate(plexChildrenProvider((instance, artist.ratingKey))),
        child: AsyncValueView<List<PlexMetadata>>(
          value: albums,
          onRetry: () => ref
              .invalidate(plexChildrenProvider((instance, artist.ratingKey))),
          data: (List<PlexMetadata> list) {
            if (list.isEmpty) {
              return const EmptyView(
                icon: Icons.album_outlined,
                title: 'No albums',
                message: 'This artist has no albums yet.',
              );
            }
            return GridView.builder(
              padding: Insets.page,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                childAspectRatio: 0.72,
                crossAxisSpacing: Insets.md,
                mainAxisSpacing: Insets.md,
              ),
              itemCount: list.length,
              itemBuilder: (BuildContext context, int index) {
                final PlexMetadata album = list[index];
                return _AlbumCard(
                  album: album,
                  imageUrl: api?.imageUrl(album.thumb),
                  onTap: () => pushScreen<void>(
                    context,
                    PlexAlbumScreen(instance: instance, album: album),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  const _AlbumCard({
    required this.album,
    required this.imageUrl,
    required this.onTap,
  });

  final PlexMetadata album;
  final String? imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
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
                child: SizedBox.expand(child: _cover(theme)),
              ),
            ),
          ),
          const SizedBox(height: Insets.xs),
          Text(
            album.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (album.year != null)
            Text(
              '${album.year}',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
        ],
      ),
    );
  }

  Widget _cover(ThemeData theme) {
    final Widget fallback = Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(Icons.album_outlined, color: theme.colorScheme.outline),
    );
    if (imageUrl == null) {
      return fallback;
    }
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      fit: BoxFit.cover,
      memCacheWidth: 320,
      placeholder: (BuildContext context, String url) =>
          Container(color: theme.colorScheme.surfaceContainerHighest),
      errorWidget: (BuildContext context, String url, Object error) => fallback,
    );
  }
}

/// Tracks of an album: track number, title, and duration. Display-only rows;
/// tracks are not playable in-app.
class PlexAlbumScreen extends ConsumerWidget {
  const PlexAlbumScreen({
    required this.instance,
    required this.album,
    super.key,
  });

  final Instance instance;
  final PlexMetadata album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<PlexMetadata>> tracks =
        ref.watch(plexChildrenProvider((instance, album.ratingKey)));

    return Scaffold(
      appBar: AppBar(title: Text(album.title)),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.invalidate(plexChildrenProvider((instance, album.ratingKey))),
        child: AsyncValueView<List<PlexMetadata>>(
          value: tracks,
          onRetry: () => ref
              .invalidate(plexChildrenProvider((instance, album.ratingKey))),
          data: (List<PlexMetadata> list) {
            if (list.isEmpty) {
              return const EmptyView(
                icon: Icons.music_note_outlined,
                title: 'No tracks',
                message: 'This album has no tracks yet.',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: Insets.sm),
              itemCount: list.length,
              itemBuilder: (BuildContext context, int index) {
                final PlexMetadata track = list[index];
                return _TrackRow(track: track);
              },
            );
          },
        ),
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({required this.track});

  final PlexMetadata track;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String duration = _formatTrackDuration(track.duration);
    return ListTile(
      leading: SizedBox(
        width: 32,
        child: Center(
          child: Text(
            track.index != null ? '${track.index}' : '-',
            style: theme.textTheme.labelLarge
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ),
      ),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: duration.isEmpty
          ? null
          : Text(
              duration,
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
    );
  }
}

/// Formats a track duration in milliseconds as `m:ss` (284000 -> '4:44').
String _formatTrackDuration(int? durationMs) {
  if (durationMs == null || durationMs <= 0) {
    return '';
  }
  final int totalSeconds = durationMs ~/ 1000;
  final int minutes = totalSeconds ~/ 60;
  final String seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
