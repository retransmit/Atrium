import 'jellyfin_client.dart';
import 'jellyfin_deep_link.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'jellyfin_providers.dart';
import 'models/jellyfin_item.dart';

class JellyfinAlbumScreen extends ConsumerWidget {
  const JellyfinAlbumScreen({
    required this.instance,
    required this.albumId,
    required this.albumName,
    required this.albumArtist,
    this.albumOverview,
    this.albumImageUrl,
    super.key,
  });

  final Instance instance;
  final String albumId;
  final String albumName;
  final String albumArtist;
  final String? albumOverview;
  final String? albumImageUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AlbumScreenData> dataAsync =
        ref.watch(jellyfinAlbumDataFutureProvider((instance, albumId, albumArtist)));
    final JellyfinClient? client = ref.watch(jellyfinClientProvider(instance)).value;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: CustomScrollView(
        slivers: <Widget>[
          // Top Section: Album Info
          SliverToBoxAdapter(
            child: albumImageUrl != null
                ? SizedBox(
                    height: 240,
                    child: Stack(
                      children: <Widget>[
                        Positioned.fill(
                          child: Opacity(
                            opacity: 0.45,
                            child: CachedNetworkImage(
                              imageUrl: albumImageUrl!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[
                                  Colors.black54,
                                  Colors.transparent,
                                  Theme.of(context).scaffoldBackgroundColor,
                                ],
                                stops: const <double>[0.0, 0.4, 1.0],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: _buildHeader(context, client),
                        ),
                      ],
                    ),
                  )
                : SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.only(top: Insets.lg),
                      child: _buildHeader(context, client),
                    ),
                  ),
          ),
          
          if (albumOverview != null && albumOverview!.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(Insets.lg),
                child: _ExpandableText(
                  text: albumOverview!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          
          // Data Section: Bio and Tracks
          SliverToBoxAdapter(
            child: AsyncValueView<AlbumScreenData>(
              value: dataAsync,
              onRetry: () => ref.invalidate(jellyfinAlbumDataFutureProvider((instance, albumId, albumArtist))),
              data: (AlbumScreenData data) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Bottom Section: Tracklist
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.sm),
                      child: Text(
                        'Tracks - ${data.tracks.length}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: data.tracks.length,
                      itemBuilder: (BuildContext context, int index) {
                        final JellyfinItem song = data.tracks[index];
                        
                        String duration = '';
                        if (song.runTimeTicks != null) {
                          final int totalSeconds = (song.runTimeTicks! / 10000000).round();
                          final int minutes = totalSeconds ~/ 60;
                          final int seconds = totalSeconds % 60;
                          duration = '$minutes:${seconds.toString().padLeft(2, '0')}';
                        }
                        
                        final String? imageUrl = albumImageUrl;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.xs),
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              SizedBox(
                                width: 24,
                                child: Text(
                                  song.indexNumber?.toString() ?? '${index + 1}',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.outline,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(width: Insets.md),
                              if (imageUrl != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) => Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Icon(Icons.music_note),
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(Icons.music_note),
                                ),
                            ],
                          ),
                          title: Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            song.artists.isNotEmpty
                                ? '${song.artists.join(', ')} • $duration'
                                : duration,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: Insets.xl),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, JellyfinClient? client) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          if (albumImageUrl != null)
            ClipRRect(
              borderRadius: Radii.card,
              child: CachedNetworkImage(
                imageUrl: albumImageUrl!,
                width: 140,
                height: 140,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: Radii.card,
              ),
              child: const Icon(Icons.album, size: 48),
            ),
          const SizedBox(width: Insets.lg),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  albumName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: Insets.xs),
                Text(
                  albumArtist,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: Insets.md),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (client != null) {
                        launchJellyfinDeepLink(context, client, albumId);
                      }
                    },
                    icon: const Icon(Icons.play_circle_fill),
                    label: const Text('Play'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: Insets.xs), // Add a small padding at the bottom so it aligns perfectly with the poster's bottom edge
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandableText extends StatefulWidget {
  const _ExpandableText({
    required this.text,
    this.style,
  });

  final String text;
  final TextStyle? style;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          widget.text,
          style: widget.style,
          maxLines: _expanded ? null : 4,
          overflow: _expanded ? null : TextOverflow.fade,
        ),
        const SizedBox(height: Insets.sm),
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Text(
            _expanded ? 'Collapse' : 'Read more',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

