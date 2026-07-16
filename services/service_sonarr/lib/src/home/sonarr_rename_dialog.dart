import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sonarr_providers.dart';

class SonarrRenameDialog extends ConsumerStatefulWidget {
  const SonarrRenameDialog({
    required this.instance,
    required this.seriesId,
    super.key,
  });

  final Instance instance;
  final int seriesId;

  @override
  ConsumerState<SonarrRenameDialog> createState() => _SonarrRenameDialogState();
}

class _SonarrRenameDialogState extends ConsumerState<SonarrRenameDialog> {
  bool _renaming = false;

  Future<void> _executeRename(List<int> fileIds) async {
    setState(() => _renaming = true);

    try {
      final api = await ref.read(sonarrApiProvider(widget.instance).future);
      await api.renameFiles(widget.seriesId, fileIds);
      if (!mounted) return;

      ref.invalidate(
        sonarrSeriesByIdProvider((widget.instance, widget.seriesId)),
      );
      ref.invalidate(
        sonarrEpisodesProvider((widget.instance, widget.seriesId)),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Files renamed successfully!')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rename failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _renaming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewAsync = ref
        .watch(sonarrRenamePreviewProvider((widget.instance, widget.seriesId)));
    final ThemeData theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AlertDialog(
      title: const Text('Rename Files'),
      content: SizedBox(
        width: double.maxFinite,
        height: 350,
        child: previewAsync.when(
          loading: () => const Center(child: ExpressiveProgressIndicator()),
          error: (err, stack) =>
              Center(child: Text('Error loading rename preview: $err')),
          data: (files) {
            if (files.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: colors.tertiary,
                      size: 48,
                    ),
                    const SizedBox(height: Insets.sm),
                    const Text(
                      'All files are correctly named.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: files.length,
              itemBuilder: (context, index) {
                final f = files[index];
                final current =
                    (f['existingPath'] as String?)?.split('/').last ??
                        'Unknown Name';
                final proposed = (f['newPath'] as String?)?.split('/').last ??
                    'Unknown Name';

                return Padding(
                  padding: const EdgeInsets.only(bottom: Insets.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Season ${f['seasonNumber'] ?? '?'} • Episode ${(f['episodeNumbers'] as List?)?.first ?? '?'}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        current,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.error,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        proposed,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.tertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _renaming ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        previewAsync.maybeWhen(
          data: (files) => files.isEmpty
              ? const SizedBox.shrink()
              : ElevatedButton(
                  onPressed: _renaming
                      ? null
                      : () {
                          final List<int> ids = files
                              .map((f) => f['episodeFileId'] as int)
                              .toList();
                          _executeRename(ids);
                        },
                  child: _renaming
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: ExpressiveProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Rename'),
                ),
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
