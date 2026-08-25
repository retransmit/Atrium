import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../generated/generated.dart';
import '../../../lidarr_api.dart';
import '../../../lidarr_providers.dart';

/// Dialog for mass applying, adding, or replacing artist tags.
class BulkTagsDialog extends ConsumerStatefulWidget {
  const BulkTagsDialog({
    required this.instance,
    required this.selectedIds,
    required this.onSuccess,
    super.key,
  });

  final Instance instance;
  final Set<int> selectedIds;
  final VoidCallback onSuccess;

  @override
  ConsumerState<BulkTagsDialog> createState() => _BulkTagsDialogState();
}

class _BulkTagsDialogState extends ConsumerState<BulkTagsDialog> {
  final Set<int> _selectedTagIds = <int>{};
  ApplyTags _applyMode = ApplyTags.add;
  bool _submitting = false;

  Future<void> _submit() async {
    setState(() => _submitting = true);

    try {
      final LidarrApi api =
          await ref.read(lidarrApiProvider(widget.instance).future);
      final resource = ArtistEditorResource(
        artistIds: widget.selectedIds.toList(),
        tags: _selectedTagIds.toList(),
        applyTags: _applyMode,
        moveFiles: false,
        deleteFiles: false,
        addImportListExclusion: false,
      );

      final ApiResponse<void> resp =
          await api.artistEditor.putArtistEditor(body: resource);
      if (!resp.isSuccess) {
        throw Exception(resp.error?.message ?? 'Failed to update tags');
      }

      if (!mounted) return;

      ref.invalidate(lidarrArtistsProvider(widget.instance));
      for (final int id in widget.selectedIds) {
        ref.invalidate(lidarrArtistByIdProvider((widget.instance, id)));
      }

      widget.onSuccess();
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Updated tags for ${widget.selectedIds.length} artists.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tag update failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<TagResource>> tagsAsync =
        ref.watch(lidarrTagsProvider(widget.instance));

    return AlertDialog(
      title: Text('Tags (${widget.selectedIds.length} artists)'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Action mode:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            RadioGroup<ApplyTags>(
              groupValue: _applyMode,
              onChanged: (ApplyTags? val) {
                if (val != null) setState(() => _applyMode = val);
              },
              child: const Column(
                children: [
                  RadioListTile<ApplyTags>(
                    title: Text('Add tags'),
                    subtitle: Text('Append selected tags to existing tags'),
                    value: ApplyTags.add,
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<ApplyTags>(
                    title: Text('Remove tags'),
                    subtitle: Text('Remove selected tags if present'),
                    value: ApplyTags.remove,
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<ApplyTags>(
                    title: Text('Replace tags'),
                    subtitle: Text('Overwrite all tags with selected ones'),
                    value: ApplyTags.replace,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const Divider(),
            const Text(
              'Select Tags:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            tagsAsync.when(
              data: (tags) {
                if (tags.isEmpty) {
                  return const Text('No tags configured in Lidarr.');
                }
                return Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final TagResource tag in tags)
                      if (tag.id != null)
                        FilterChip(
                          label: Text(tag.label ?? 'Tag ${tag.id}'),
                          selected: _selectedTagIds.contains(tag.id!),
                          onSelected: (bool selected) {
                            setState(() {
                              if (selected) {
                                _selectedTagIds.add(tag.id!);
                              } else {
                                _selectedTagIds.remove(tag.id!);
                              }
                            });
                          },
                        ),
                  ],
                );
              },
              loading: () => const Center(child: ExpressiveProgressIndicator()),
              error: (err, _) => Text('Failed to load tags: $err'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: ExpressiveProgressIndicator(strokeWidth: 2),
                )
              : const Text('Apply Tags'),
        ),
      ],
    );
  }
}
