import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navidrome_api.dart';
import '../navidrome_providers.dart';
import '../screens/navidrome_playlist_screen.dart';

/// Shows a dialog to create a new custom playlist.
///
/// If [initialSongId] is provided, the song is automatically added to the
/// newly created playlist. Otherwise, the app navigates to the new playlist screen.
Future<NavidromePlaylist?> showNavidromeCreatePlaylistDialog({
  required BuildContext context,
  required WidgetRef ref,
  required Instance instance,
  String? initialSongId,
}) async {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController commentController = TextEditingController();
  bool isPublic = false;
  bool isSubmitting = false;
  String? errorText;

  return showDialog<NavidromePlaylist>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setDialogState) {
          final ThemeData theme = Theme.of(ctx);
          final ColorScheme cs = theme.colorScheme;

          return AlertDialog(
            title: const Row(
              children: <Widget>[
                Icon(Icons.playlist_add_rounded),
                SizedBox(width: Insets.sm),
                Text('New Playlist'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Playlist Name *',
                      hintText: 'e.g. Chill Vibes',
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
                      hintText: 'Add a comment or description...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: Insets.sm),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Public Playlist'),
                    subtitle: Text(
                      isPublic
                          ? 'Visible to all users on this server'
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
                            errorText = 'Please enter a playlist name';
                          });
                          return;
                        }

                        setDialogState(() {
                          isSubmitting = true;
                          errorText = null;
                        });

                        try {
                          final NavidromeClient client = await ref
                              .read(navidromeClientProvider(instance).future);
                          final NavidromePlaylist pl =
                              await client.createPlaylist(
                            name: name,
                            songIds: initialSongId != null
                                ? <String>[initialSongId]
                                : null,
                          );

                          final String comment = commentController.text.trim();
                          if (pl.id.isNotEmpty &&
                              (comment.isNotEmpty || isPublic)) {
                            await client.updatePlaylist(
                              playlistId: pl.id,
                              comment: comment.isNotEmpty ? comment : null,
                              public: isPublic ? true : null,
                            );
                          }

                          await hardRefreshNavidrome(ref, instance);

                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(pl);
                          }

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Playlist "$name" created'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );

                            if (initialSongId == null && pl.id.isNotEmpty) {
                              unawaited(
                                pushScreen<void>(
                                  context,
                                  NavidromePlaylistScreen(
                                    instance: instance,
                                    playlistId: pl.id,
                                    initialName: name,
                                  ),
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          setDialogState(() {
                            isSubmitting = false;
                            errorText = 'Failed to create playlist: $e';
                          });
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create'),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Shows a bottom sheet listing playlists to add [song] to.
Future<void> showNavidromePlaylistPicker({
  required BuildContext context,
  required WidgetRef ref,
  required Instance instance,
  required NavidromeSong song,
}) async {
  final ThemeData theme = Theme.of(context);
  final ColorScheme cs = theme.colorScheme;
  final NavidromeClient? client =
      ref.read(navidromeClientProvider(instance)).value;

  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (BuildContext sheetContext) {
      return Consumer(
        builder: (BuildContext ctx, WidgetRef sheetRef, _) {
          final AsyncValue<List<NavidromePlaylist>> playlistsAsync =
              sheetRef.watch(navidromePlaylistsProvider(instance));

          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.7,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: Insets.sm),
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Insets.lg,
                      Insets.md,
                      Insets.lg,
                      Insets.xs,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Add to Playlist',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${song.title} • ${song.artist}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: cs.primaryContainer,
                      child: Icon(
                        Icons.add_rounded,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                    title: const Text(
                      'New Playlist',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      await showNavidromeCreatePlaylistDialog(
                        context: context,
                        ref: ref,
                        instance: instance,
                        initialSongId: song.id,
                      );
                    },
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: playlistsAsync.when(
                      data: (List<NavidromePlaylist> playlists) {
                        if (playlists.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(Insets.lg),
                              child: Text(
                                'No custom playlists yet.\nCreate one above to get started.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: playlists.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (BuildContext _, int index) {
                            final NavidromePlaylist pl = playlists[index];
                            final String? coverUrl = client?.getCoverArtUrl(
                              pl.coverArt,
                              size: 160,
                            );

                            return ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  color: cs.surfaceContainerHighest,
                                  child: coverUrl != null
                                      ? AtriumNetworkImage(
                                          imageUrl: coverUrl,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) => Icon(
                                            Icons.queue_music_rounded,
                                            color: cs.onSurfaceVariant,
                                          ),
                                        )
                                      : Icon(
                                          Icons.queue_music_rounded,
                                          color: cs.onSurfaceVariant,
                                        ),
                                ),
                              ),
                              title: Text(
                                pl.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                '${pl.songCount} songs',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.add_circle_outline_rounded,
                                size: 22,
                              ),
                              onTap: () async {
                                Navigator.of(sheetContext).pop();
                                try {
                                  final NavidromeClient client = await ref
                                      .read(navidromeClientProvider(instance).future);
                                  await client.updatePlaylist(
                                    playlistId: pl.id,
                                    songIdsToAdd: <String>[song.id],
                                  );

                                  await hardRefreshNavidrome(ref, instance);

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Added "${song.title}" to ${pl.name}',
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to add to playlist: $e',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                            );
                          },
                        );
                      },
                      loading: () => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      error: (Object err, _) => Center(
                        child: Text('Failed to load playlists: $err'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
