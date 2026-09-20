import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navidrome_api.dart';
import '../navidrome_providers.dart';
import '../screens/navidrome_album_screen.dart';
import '../screens/navidrome_artist_screen.dart';
import 'navidrome_playlist_dialogs.dart';

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

/// Minimalist Overview Tab displaying last listened to artist,
/// last listened to song, and top albums, separated by dividers.
class NavidromeOverviewTab extends ConsumerWidget {
  const NavidromeOverviewTab({
    required this.instance,
    super.key,
  });

  final Instance instance;

  Widget _buildSectionHeader({
    required BuildContext context,
    required String title,
    required IconData icon,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.md,
        Insets.xs,
        Insets.md,
        Insets.xs,
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: cs.primary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    final AsyncValue<NavidromeClient> clientAsync =
        ref.watch(navidromeClientProvider(instance));
    final NavidromeClient? client = clientAsync.value;

    final AsyncValue<NavidromeLastListened> lastListenedAsync =
        ref.watch(navidromeLastListenedProvider(instance));
    final AsyncValue<List<NavidromeAlbum>> frequentAlbumsAsync =
        ref.watch(navidromeFrequentAlbumsProvider(instance));

    return EasyRefresh(
      onRefresh: () async {
        await hardRefreshNavidrome(ref, instance);
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: Insets.md),
        children: <Widget>[
          // 1. Last Listened to Artist
          _buildSectionHeader(
            context: context,
            title: 'Last Listened Artist',
            icon: Icons.person_rounded,
          ),
          lastListenedAsync.when(
            data: (NavidromeLastListened data) {
              final String artistName = data.artist?.trim() ?? '';
              if (artistName.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.md,
                    vertical: Insets.xs,
                  ),
                  child: Text(
                    'No recently played artist',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                );
              }

              final String? artistId = data.artistId;
              final String? coverUrl = artistId != null && artistId.isNotEmpty
                  ? client?.getCoverArtUrl(
                      artistId.startsWith('ar-')
                          ? artistId
                          : 'ar-$artistId',
                      size: 200,
                    )
                  : null;

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.md,
                  vertical: Insets.xs,
                ),
                child: Card(
                  elevation: 0,
                  color: cs.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: Insets.md,
                      vertical: Insets.xs,
                    ),
                    leading: CircleAvatar(
                      radius: 26,
                      backgroundColor: cs.surfaceContainerHighest,
                      child: ClipOval(
                        child: coverUrl != null
                            ? AtriumNetworkImage(
                                imageUrl: coverUrl,
                                fit: BoxFit.cover,
                                width: 52,
                                height: 52,
                                errorWidget: (_, __, ___) => Icon(
                                  Icons.person_rounded,
                                  color: cs.onSurfaceVariant,
                                ),
                              )
                            : Icon(
                                Icons.person_rounded,
                                color: cs.onSurfaceVariant,
                              ),
                      ),
                    ),
                    title: Text(
                      artistName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Recently played',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    trailing: artistId != null && artistId.isNotEmpty
                        ? const Icon(Icons.chevron_right_rounded)
                        : null,
                    onTap: (artistId != null && artistId.isNotEmpty)
                        ? () {
                            pushScreen<void>(
                              context,
                              NavidromeArtistScreen(
                                instance: instance,
                                artistId: artistId,
                                initialArtistName: artistName,
                              ),
                            );
                          }
                        : null,
                  ),
                ),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(Insets.md),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (Object err, _) => Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: Text('Failed to load recent artist: $err'),
            ),
          ),

          // Separator 1
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Insets.sm),
            child: Divider(
              height: 1,
              indent: Insets.md,
              endIndent: Insets.md,
              color: cs.outlineVariant.withValues(alpha: 0.4),
            ),
          ),

          // 2. Last Listened to Song
          _buildSectionHeader(
            context: context,
            title: 'Last Listened Song',
            icon: Icons.music_note_rounded,
          ),
          lastListenedAsync.when(
            data: (NavidromeLastListened data) {
              final NavidromeSong? song = data.song;
              if (song == null) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.md,
                    vertical: Insets.xs,
                  ),
                  child: Text(
                    'No recently played song',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                );
              }

              final String? coverUrl =
                  client?.getCoverArtUrl(song.coverArt, size: 150);

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.md,
                  vertical: Insets.xs,
                ),
                child: Card(
                  elevation: 0,
                  color: cs.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: Insets.md,
                      vertical: Insets.xs,
                    ),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 50,
                        height: 50,
                        child: coverUrl != null
                            ? AtriumNetworkImage(
                                imageUrl: coverUrl,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                  color: cs.surfaceContainerHighest,
                                  child: const Icon(Icons.music_note_rounded),
                                ),
                              )
                            : Container(
                                color: cs.surfaceContainerHighest,
                                child: const Icon(Icons.music_note_rounded),
                              ),
                      ),
                    ),
                    title: Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${song.artist}${song.album.isNotEmpty ? ' • ${song.album}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          _formatDuration(song.duration),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.playlist_add_rounded),
                          tooltip: 'Add to playlist',
                          onPressed: () {
                            showNavidromePlaylistPicker(
                              context: context,
                              ref: ref,
                              instance: instance,
                              song: song,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(Insets.md),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (Object err, _) => Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: Text('Failed to load recent song: $err'),
            ),
          ),

          // Separator 2
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Insets.sm),
            child: Divider(
              height: 1,
              indent: Insets.md,
              endIndent: Insets.md,
              color: cs.outlineVariant.withValues(alpha: 0.4),
            ),
          ),

          // 3. Top Albums
          _buildSectionHeader(
            context: context,
            title: 'Top Albums',
            icon: Icons.album_rounded,
          ),
          frequentAlbumsAsync.when(
            data: (List<NavidromeAlbum> albums) {
              if (albums.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.md,
                    vertical: Insets.xs,
                  ),
                  child: Text(
                    'No played albums yet',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                );
              }

              final int count = albums.length > 9 ? 9 : albums.length;
              return GridView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.md,
                  vertical: Insets.xs,
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.68,
                  crossAxisSpacing: Insets.sm,
                  mainAxisSpacing: Insets.sm,
                ),
                itemCount: count,
                itemBuilder: (BuildContext ctx, int index) {
                  final NavidromeAlbum album = albums[index];
                  final int rank = index + 1;
                  final String? coverUrl =
                      client?.getCoverArtUrl(album.coverArt, size: 300);

                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      pushScreen<void>(
                        context,
                        NavidromeAlbumScreen(
                          instance: instance,
                          albumId: album.id,
                          initialAlbum: album,
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Stack(
                          children: <Widget>[
                            AspectRatio(
                              aspectRatio: 1.0,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: coverUrl != null
                                    ? AtriumNetworkImage(
                                        imageUrl: coverUrl,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => Container(
                                          color: cs.surfaceContainerHighest,
                                          child: const Icon(
                                            Icons.album_rounded,
                                            size: 32,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        color: cs.surfaceContainerHighest,
                                        child: const Icon(
                                          Icons.album_rounded,
                                          size: 32,
                                        ),
                                      ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: rank <= 3
                                      ? cs.primaryContainer
                                      : cs.surfaceContainerHighest
                                          .withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  '#$rank',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 9.5,
                                    color: rank <= 3
                                        ? cs.onPrimaryContainer
                                        : cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                            if (album.playCount > 0)
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(
                                      alpha: 0.65,
                                    ),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    '${album.playCount}',
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          album.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          album.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(Insets.md),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (Object err, _) => Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: Text('Failed to load top albums: $err'),
            ),
          ),
        ],
      ),
    );
  }
}
