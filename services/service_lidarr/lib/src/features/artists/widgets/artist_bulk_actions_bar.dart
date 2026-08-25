import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../generated/generated.dart';
import '../../../lidarr_api.dart';
import '../../../lidarr_providers.dart';
import '../album_studio_screen.dart';
import '../dialogs/bulk_delete_dialog.dart';
import '../dialogs/bulk_edit_dialog.dart';
import '../dialogs/bulk_tags_dialog.dart';

/// Floating bottom action bar presenting bulk actions for selected artists.
class ArtistBulkActionsBar extends ConsumerWidget {
  const ArtistBulkActionsBar({
    required this.instance,
    required this.selectedIds,
    required this.onClear,
    super.key,
  });

  final Instance instance;
  final Set<int> selectedIds;
  final VoidCallback onClear;

  Future<void> _confirmAndExecuteCommand(
    BuildContext context,
    WidgetRef ref, {
    required String commandName,
    required String actionTitle,
    required String confirmMessage,
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(actionTitle),
        content: Text(confirmMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(actionTitle),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final LidarrApi api = await ref.read(lidarrApiProvider(instance).future);
      final ApiResponse<CommandResource> resp = await api.executeCommand(
        commandName,
        <String, dynamic>{
          'artistIds': selectedIds.toList(),
        },
      );

      if (!resp.isSuccess) {
        throw Exception(
          resp.error?.message ?? 'Failed to execute $commandName',
        );
      }

      ref.invalidate(lidarrArtistsProvider(instance));
      onClear();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$actionTitle command queued for selected artists.'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surfaceContainer,
      elevation: 4,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.md,
            vertical: Insets.xs,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: cs.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (BuildContext ctx) => BulkEditDialog(
                      instance: instance,
                      selectedIds: selectedIds,
                      onSuccess: onClear,
                    ),
                  );
                },
                icon: const Icon(Icons.edit_outlined, size: 20),
                label: const Text('Edit'),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: cs.error,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (BuildContext ctx) => BulkDeleteDialog(
                      instance: instance,
                      selectedIds: selectedIds,
                      onSuccess: onClear,
                    ),
                  );
                },
                icon: const Icon(Icons.delete_outline, size: 20),
                label: const Text('Delete'),
              ),
              Tooltip(
                message: 'More bulk actions',
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: cs.onSurfaceVariant,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                  icon: const Icon(Icons.more_horiz, size: 20),
                  label: const Text('More'),
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: context,
                      showDragHandle: true,
                      useRootNavigator: true,
                      builder: (BuildContext ctx) => SafeArea(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.grid_on_outlined),
                                title: const Text('Album Studio'),
                                subtitle: Text(
                                  'Configure album monitoring for ${selectedIds.length} selected ${selectedIds.length == 1 ? 'artist' : 'artists'}',
                                ),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => LidarrAlbumStudioScreen(
                                        instance: instance,
                                        initialArtistIds: selectedIds,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.label_outlined),
                                title: const Text('Edit Tags'),
                                subtitle: const Text('Apply or modify tags'),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  showDialog<void>(
                                    context: context,
                                    builder: (BuildContext dialogCtx) =>
                                        BulkTagsDialog(
                                      instance: instance,
                                      selectedIds: selectedIds,
                                      onSuccess: onClear,
                                    ),
                                  );
                                },
                              ),
                              ListTile(
                                leading:
                                    const Icon(Icons.drive_file_rename_outline),
                                title: const Text('Rename Files'),
                                subtitle: const Text('Rename tracks on disk'),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _confirmAndExecuteCommand(
                                    context,
                                    ref,
                                    commandName: 'RenameArtist',
                                    actionTitle: 'Rename Files',
                                    confirmMessage:
                                        'Rename audio files on disk for ${selectedIds.length} selected artists according to your naming format?',
                                  );
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.sell_outlined),
                                title: const Text('Write Audio Tags'),
                                subtitle: const Text(
                                  'Sync metadata to audio tags on disk',
                                ),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _confirmAndExecuteCommand(
                                    context,
                                    ref,
                                    commandName: 'RetagArtist',
                                    actionTitle: 'Write Audio Tags',
                                    confirmMessage:
                                        'Write metadata tags to audio files on disk for ${selectedIds.length} selected artists?',
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
