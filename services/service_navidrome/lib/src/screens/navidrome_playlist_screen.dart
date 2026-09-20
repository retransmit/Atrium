import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navidrome_api.dart';
import '../navidrome_providers.dart';
import '../widgets/navidrome_playlist_dialogs.dart';
import '../widgets/navidrome_rating_bar.dart';

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

String _formatAlbumDuration(int seconds) {
  if (seconds <= 0) return '';
  final int m = seconds ~/ 60;
  if (m >= 60) {
    final int h = m ~/ 60;
    final int remM = m % 60;
    return remM > 0 ? '$h hr $remM min' : '$h hr';
  }
  return '$m min';
}

class NavidromePlaylistScreen extends ConsumerWidget {
  const NavidromePlaylistScreen({
    required this.instance,
    required this.playlistId,
    this.initialName,
    super.key,
  });

  final Instance instance;
  final String playlistId;
  final String? initialName;

  void _showSongDetails(
    BuildContext context,
    WidgetRef ref,
    NavidromeSong song, {
    String? coverUrl,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    int currentRating = song.userRating ?? 0;
    bool isStarred = song.isStarred;

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.lg,
                  vertical: Insets.md,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.md),
                    Row(
                      children: <Widget>[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 48,
                            height: 48,
                            color: cs.primaryContainer,
                            child: coverUrl != null
                                ? AtriumNetworkImage(
                                    imageUrl: coverUrl,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Icon(
                                      Icons.music_note_rounded,
                                      color: cs.onPrimaryContainer,
                                    ),
                                  )
                                : Icon(
                                    Icons.music_note_rounded,
                                    color: cs.onPrimaryContainer,
                                  ),
                          ),
                        ),
                        const SizedBox(width: Insets.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                song.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                song.artist,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            isStarred
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: isStarred ? Colors.redAccent : null,
                          ),
                          tooltip: isStarred
                              ? 'Remove from favorites'
                              : 'Add to favorites',
                          onPressed: () async {
                            final bool willStar = !isStarred;
                            setModalState(() {
                              isStarred = willStar;
                            });
                            final NavidromeClient? client = ref
                                .read(navidromeClientProvider(instance))
                                .value;
                            try {
                              if (willStar) {
                                await client?.star(id: song.id);
                              } else {
                                await client?.unstar(id: song.id);
                              }
                              ref.invalidate(
                                navidromePlaylistDetailProvider(
                                  (instance, playlistId),
                                ),
                              );
                              ref.invalidate(navidromeAlbumsProvider);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text('Failed to update favorite: $e'),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: Insets.md),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.md,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color:
                            cs.surfaceContainerHighest.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(
                                'Rating',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                navidromeRatingLabel(currentRating),
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: currentRating > 0
                                      ? (Colors.amber[800] ?? Colors.amber)
                                      : cs.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Center(
                            child: NavidromeRatingBar(
                              rating: currentRating,
                              starSize: 34,
                              spacing: 6,
                              onRatingChanged: (int newRating) async {
                                setModalState(() {
                                  currentRating = newRating;
                                });
                                final NavidromeClient? client = ref
                                    .read(navidromeClientProvider(instance))
                                    .value;
                                try {
                                  await client?.setRating(song.id, newRating);
                                  ref.invalidate(
                                    navidromePlaylistDetailProvider(
                                      (instance, playlistId),
                                    ),
                                  );
                                  ref.invalidate(navidromeAlbumsProvider);
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content:
                                            Text('Failed to set rating: $e'),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Insets.sm),
                    ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      tileColor:
                          cs.surfaceContainerHighest.withValues(alpha: 0.45),
                      leading: const Icon(Icons.playlist_add_rounded),
                      title: const Text(
                        'Add to Another Playlist',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing:
                          const Icon(Icons.chevron_right_rounded, size: 20),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        showNavidromePlaylistPicker(
                          context: context,
                          ref: ref,
                          instance: instance,
                          song: song,
                        );
                      },
                    ),
                    const SizedBox(height: Insets.sm),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.schedule_rounded,
                            size: 18,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: Insets.sm),
                          Text(
                            'Duration',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatDuration(song.duration),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Insets.sm),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditPlaylistDialog(
    BuildContext context,
    WidgetRef ref,
    NavidromePlaylist playlist,
  ) {
    final TextEditingController nameController =
        TextEditingController(text: playlist.name);
    final TextEditingController commentController =
        TextEditingController(text: playlist.comment ?? '');
    bool isPublic = playlist.public;
    bool isSubmitting = false;
    String? errorText;

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setDialogState) {
            final ThemeData theme = Theme.of(ctx);
            final ColorScheme cs = theme.colorScheme;

            return AlertDialog(
              title: const Text('Edit Playlist'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Playlist Name *',
                        errorText: errorText,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        if (errorText != null) {
                          setDialogState(() => errorText = null);
                        }
                      },
                    ),
                    const SizedBox(height: Insets.md),
                    TextField(
                      controller: commentController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: Insets.sm),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Public Playlist'),
                      subtitle: Text(
                        isPublic
                            ? 'Visible to all users'
                            : 'Only visible to you',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      value: isPublic,
                      onChanged: (bool val) {
                        setDialogState(() => isPublic = val);
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final String name = nameController.text.trim();
                          if (name.isEmpty) {
                            setDialogState(() {
                              errorText = 'Please enter a name';
                            });
                            return;
                          }

                          setDialogState(() {
                            isSubmitting = true;
                            errorText = null;
                          });

                          final NavidromeClient? client =
                              ref.read(navidromeClientProvider(instance)).value;
                          try {
                            await client?.updatePlaylist(
                              playlistId: playlist.id,
                              name: name != playlist.name ? name : null,
                              comment: commentController.text.trim(),
                              public: isPublic,
                            );

                            ref.invalidate(
                              navidromePlaylistDetailProvider(
                                (instance, playlist.id),
                              ),
                            );
                            ref.invalidate(
                              navidromePlaylistsProvider(instance),
                            );

                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          } catch (e) {
                            setDialogState(() {
                              isSubmitting = false;
                              errorText = 'Failed to update: $e';
                            });
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    NavidromePlaylist playlist,
  ) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Playlist?'),
          content: Text(
            'Are you sure you want to delete "${playlist.name}"? This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                final NavidromeClient? client =
                    ref.read(navidromeClientProvider(instance)).value;
                try {
                  await client?.deletePlaylist(playlist.id);
                  ref.invalidate(navidromePlaylistsProvider(instance));
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Deleted playlist "${playlist.name}"'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to delete playlist: $e'),
                      ),
                    );
                  }
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  /// Builds a collage of album covers from songs if server coverArt is absent.
  Widget _buildCollageFallback(
    ColorScheme cs,
    List<NavidromeSong> songs,
    NavidromeClient? client,
  ) {
    final List<String> uniqueCovers = <String>[];
    for (final NavidromeSong s in songs) {
      if (s.coverArt != null &&
          s.coverArt!.isNotEmpty &&
          !uniqueCovers.contains(s.coverArt)) {
        uniqueCovers.add(s.coverArt!);
        if (uniqueCovers.length >= 4) break;
      }
    }

    if (uniqueCovers.isEmpty) {
      return Container(
        color: cs.surfaceContainerHighest,
        child: Icon(
          Icons.queue_music_rounded,
          size: 72,
          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      );
    }

    if (uniqueCovers.length == 1) {
      final String? url = client?.getCoverArtUrl(uniqueCovers[0], size: 1000);
      return url != null
          ? AtriumNetworkImage(imageUrl: url, fit: BoxFit.cover)
          : Container(color: cs.surfaceContainerHighest);
    }

    // 2x2 grid collage
    return Column(
      children: <Widget>[
        Expanded(
          child: Row(
            children: <Widget>[
              Expanded(
                child: _buildTileImage(uniqueCovers[0], client, cs),
              ),
              Expanded(
                child: _buildTileImage(uniqueCovers[1], client, cs),
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: <Widget>[
              Expanded(
                child: _buildTileImage(
                  uniqueCovers.length > 2
                      ? uniqueCovers[2]
                      : uniqueCovers[0],
                  client,
                  cs,
                ),
              ),
              Expanded(
                child: _buildTileImage(
                  uniqueCovers.length > 3
                      ? uniqueCovers[3]
                      : uniqueCovers[1],
                  client,
                  cs,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTileImage(
    String coverArtId,
    NavidromeClient? client,
    ColorScheme cs,
  ) {
    final String? url = client?.getCoverArtUrl(coverArtId, size: 500);
    if (url == null) {
      return Container(color: cs.surfaceContainerHighest);
    }
    return AtriumNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => Container(color: cs.surfaceContainerHighest),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    final AsyncValue<NavidromePlaylistDetail> detailAsync =
        ref.watch(navidromePlaylistDetailProvider((instance, playlistId)));
    final AsyncValue<NavidromeClient> clientAsync =
        ref.watch(navidromeClientProvider(instance));
    final NavidromeClient? client = clientAsync.value;
    final NavidromePlaylist? playlist = detailAsync.value?.playlist;

    final double bannerHeight = MediaQuery.sizeOf(context).height * 0.48;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: <Widget>[
          if (playlist != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              tooltip: 'Playlist options',
              onSelected: (String action) {
                if (action == 'edit') {
                  _showEditPlaylistDialog(context, ref, playlist);
                } else if (action == 'delete') {
                  _showDeleteConfirmation(context, ref, playlist);
                }
              },
              itemBuilder: (BuildContext _) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.edit_rounded, size: 20),
                      SizedBox(width: Insets.sm),
                      Text('Edit Details'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: Colors.redAccent,
                      ),
                      SizedBox(width: Insets.sm),
                      Text(
                        'Delete Playlist',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: detailAsync.when(
        data: (NavidromePlaylistDetail detail) {
          final NavidromePlaylist pl = detail.playlist;
          final String? coverUrl =
              client?.getCoverArtUrl(pl.coverArt, size: 1000);

          return RefreshIndicator(
            onRefresh: () async {
              await hardRefreshNavidrome(ref, instance);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: <Widget>[
                // Top Section: Half-page playlist cover banner matching album screen
                SliverToBoxAdapter(
                child: SizedBox(
                  height: bannerHeight,
                  child: Stack(
                    children: <Widget>[
                      // 1. Background cover image with automatic collage fallback
                      Positioned.fill(
                        child: coverUrl != null && coverUrl.isNotEmpty
                            ? AtriumNetworkImage(
                                key: ValueKey<String>(coverUrl),
                                imageUrl: coverUrl,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) =>
                                    _buildCollageFallback(
                                  cs,
                                  detail.songs,
                                  client,
                                ),
                              )
                            : _buildCollageFallback(
                                cs,
                                detail.songs,
                                client,
                              ),
                      ),
                      // 2. Dim overlay for readability
                      Positioned.fill(
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.35),
                        ),
                      ),
                      // 3. Bottom gradient fade into surface
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                cs.surface.withValues(alpha: 0.0),
                                cs.surface.withValues(alpha: 0.2),
                                cs.surface.withValues(alpha: 0.7),
                                cs.surface,
                              ],
                              stops: const <double>[0.3, 0.55, 0.85, 1.0],
                            ),
                          ),
                        ),
                      ),
                      // 4. Header info at bottom of banner
                      Positioned(
                        left: Insets.lg,
                        right: Insets.lg,
                        bottom: Insets.sm,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              pl.name,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                shadows: const <Shadow>[
                                  Shadow(
                                    color: Colors.black87,
                                    offset: Offset(0, 1.5),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (pl.owner != null && pl.owner!.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 4),
                              Text(
                                'Created by ${pl.owner}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  shadows: const <Shadow>[
                                    Shadow(
                                      color: Colors.black87,
                                      offset: Offset(0, 1),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (pl.comment != null &&
                                pl.comment!.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 4),
                              Text(
                                pl.comment!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                  shadows: const <Shadow>[
                                    Shadow(
                                      color: Colors.black87,
                                      offset: Offset(0, 1),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: <Widget>[
                                _PlaylistBadge(
                                  icon: Icons.queue_music_rounded,
                                  label:
                                      '${detail.songs.length} ${detail.songs.length == 1 ? 'Track' : 'Tracks'}',
                                ),
                                if (pl.duration > 0)
                                  _PlaylistBadge(
                                    icon: Icons.schedule_rounded,
                                    label: _formatAlbumDuration(pl.duration),
                                  ),
                                _PlaylistBadge(
                                  icon: pl.public
                                      ? Icons.public_rounded
                                      : Icons.lock_outline_rounded,
                                  label: pl.public ? 'Public' : 'Private',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: Insets.lg,
                  vertical: Insets.sm,
                ),
                sliver: SliverToBoxAdapter(
                  child: Divider(height: 1),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.lg,
                  Insets.xs,
                  Insets.lg,
                  Insets.xs,
                ),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Tracks',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (detail.songs.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(Insets.xl),
                      child: Text('This playlist has no songs yet.\nAdd songs from album or search views.'),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: Insets.xl),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (BuildContext ctx, int index) {
                        final NavidromeSong song = detail.songs[index];
                        final String? songCoverUrl = client?.getCoverArtUrl(
                          song.coverArt,
                          size: 160,
                        );

                        return ListTile(
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              SizedBox(
                                width: 24,
                                child: Text(
                                  '${index + 1}',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: Insets.xs),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: songCoverUrl != null
                                      ? AtriumNetworkImage(
                                          imageUrl: songCoverUrl,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) =>
                                              Container(
                                            color: cs.surfaceContainerHighest,
                                            child: const Icon(
                                              Icons.music_note_rounded,
                                              size: 22,
                                            ),
                                          ),
                                        )
                                      : Container(
                                          color: cs.surfaceContainerHighest,
                                          child: const Icon(
                                            Icons.music_note_rounded,
                                            size: 22,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                          title: Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Row(
                            children: <Widget>[
                              if (song.userRating != null &&
                                  song.userRating! > 0) ...<Widget>[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      const Icon(
                                        Icons.star_rounded,
                                        size: 11,
                                        color: Colors.amber,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${song.userRating}',
                                        style:
                                            theme.textTheme.labelSmall?.copyWith(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              Colors.amber[800] ?? Colors.amber,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(
                                  song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                _formatDuration(song.duration),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(
                                  Icons.more_vert_rounded,
                                  size: 18,
                                ),
                                onSelected: (String action) async {
                                  if (action == 'details') {
                                    _showSongDetails(
                                      context,
                                      ref,
                                      song,
                                      coverUrl: songCoverUrl,
                                    );
                                  } else if (action == 'add_to_playlist') {
                                    await showNavidromePlaylistPicker(
                                      context: context,
                                      ref: ref,
                                      instance: instance,
                                      song: song,
                                    );
                                  } else if (action == 'remove') {
                                    try {
                                      final NavidromeClient navClient =
                                          await ref.read(
                                        navidromeClientProvider(instance)
                                            .future,
                                      );
                                      await navClient.updatePlaylist(
                                        playlistId: playlistId,
                                        songIndexesToRemove: <int>[index],
                                      );
                                      await hardRefreshNavidrome(ref, instance);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Removed "${song.title}" from playlist',
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Failed to remove song: $e',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                                itemBuilder: (BuildContext _) =>
                                    <PopupMenuEntry<String>>[
                                  const PopupMenuItem<String>(
                                    value: 'details',
                                    child: Row(
                                      children: <Widget>[
                                        Icon(
                                          Icons.info_outline_rounded,
                                          size: 18,
                                        ),
                                        SizedBox(width: Insets.sm),
                                        Text('Song Details & Rate'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem<String>(
                                    value: 'add_to_playlist',
                                    child: Row(
                                      children: <Widget>[
                                        Icon(
                                          Icons.playlist_add_rounded,
                                          size: 18,
                                        ),
                                        SizedBox(width: Insets.sm),
                                        Text('Add to Playlist'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuDivider(),
                                  const PopupMenuItem<String>(
                                    value: 'remove',
                                    child: Row(
                                      children: <Widget>[
                                        Icon(
                                          Icons.remove_circle_outline_rounded,
                                          size: 18,
                                          color: Colors.redAccent,
                                        ),
                                        SizedBox(width: Insets.sm),
                                        Text(
                                          'Remove from Playlist',
                                          style: TextStyle(
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          onTap: () => _showSongDetails(
                            context,
                            ref,
                            song,
                            coverUrl: songCoverUrl,
                          ),
                        );
                      },
                      childCount: detail.songs.length,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(height: Insets.md),
              Text('Failed to load playlist: $err'),
              const SizedBox(height: Insets.md),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(
                  navidromePlaylistDetailProvider((instance, playlistId)),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistBadge extends StatelessWidget {
  const _PlaylistBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: cs.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
