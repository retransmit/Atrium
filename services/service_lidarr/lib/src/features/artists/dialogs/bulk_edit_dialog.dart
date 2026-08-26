import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../generated/generated.dart';
import '../../../lidarr_api.dart';
import '../../../lidarr_providers.dart';

/// Dialog for mass editing monitored status, profiles, and root folder.
class BulkEditDialog extends ConsumerStatefulWidget {
  const BulkEditDialog({
    required this.instance,
    required this.selectedIds,
    required this.onSuccess,
    super.key,
  });

  final Instance instance;
  final Set<int> selectedIds;
  final VoidCallback onSuccess;

  @override
  ConsumerState<BulkEditDialog> createState() => _BulkEditDialogState();
}

class _BulkEditDialogState extends ConsumerState<BulkEditDialog> {
  bool? _monitored;
  NewItemMonitorTypes? _monitorNewItems;
  int? _qualityProfileId;
  int? _metadataProfileId;
  String? _rootFolderPath;
  bool _moveFiles = false;
  bool _submitting = false;

  Future<void> _submit() async {
    setState(() => _submitting = true);

    try {
      final LidarrApi api =
          await ref.read(lidarrApiProvider(widget.instance).future);
      final resource = ArtistEditorResource(
        artistIds: widget.selectedIds.toList(),
        monitored: _monitored,
        monitorNewItems: _monitorNewItems,
        qualityProfileId: _qualityProfileId,
        metadataProfileId: _metadataProfileId,
        rootFolderPath: _rootFolderPath,
        moveFiles: _moveFiles,
        deleteFiles: false,
        addImportListExclusion: false,
        applyTags: ApplyTags.add,
      );

      final ApiResponse<void> resp =
          await api.artistEditor.putArtistEditor(body: resource);
      if (!resp.isSuccess) {
        throw Exception(resp.error?.message ?? 'Failed to update artists');
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
            'Updated ${widget.selectedIds.length} ${_selectedIdsCountLabel()}.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bulk update failed: $e'),
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

  String _selectedIdsCountLabel() =>
      widget.selectedIds.length == 1 ? 'artist' : 'artists';

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<QualityProfileResource>> qualityProfilesAsync =
        ref.watch(lidarrQualityProfilesProvider(widget.instance));
    final AsyncValue<List<MetadataProfileResource>> metadataProfilesAsync =
        ref.watch(lidarrMetadataProfilesProvider(widget.instance));
    final AsyncValue<List<RootFolderResource>> rootFoldersAsync =
        ref.watch(lidarrRootFoldersProvider(widget.instance));

    return AlertDialog(
      scrollable: true,
      title:
          Text('Edit ${widget.selectedIds.length} ${_selectedIdsCountLabel()}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
            const SizedBox(height: Insets.xs),
            // Monitored
            DropdownButtonFormField<bool?>(
              isExpanded: true,
              initialValue: _monitored,
              decoration: const InputDecoration(
                labelText: 'Monitored',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(child: Text('Keep current')),
                DropdownMenuItem(value: true, child: Text('Monitored')),
                DropdownMenuItem(value: false, child: Text('Unmonitored')),
              ],
              onChanged: (val) => setState(() => _monitored = val),
            ),
            const SizedBox(height: Insets.md),
            // Monitor New Items
            DropdownButtonFormField<NewItemMonitorTypes?>(
              isExpanded: true,
              initialValue: _monitorNewItems,
              decoration: const InputDecoration(
                labelText: 'Monitor New Items',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(child: Text('Keep current')),
                DropdownMenuItem(
                  value: NewItemMonitorTypes.all,
                  child: Text('All Albums'),
                ),
                DropdownMenuItem(
                  value: NewItemMonitorTypes.newVal,
                  child: Text('New Albums'),
                ),
                DropdownMenuItem(
                  value: NewItemMonitorTypes.none,
                  child: Text('None'),
                ),
              ],
              onChanged: (val) => setState(() => _monitorNewItems = val),
            ),
            const SizedBox(height: Insets.md),
            // Quality Profile
            qualityProfilesAsync.when(
              data: (profiles) => DropdownButtonFormField<int?>(
                isExpanded: true,
                initialValue: _qualityProfileId,
                decoration: const InputDecoration(
                  labelText: 'Quality Profile',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(child: Text('Keep current')),
                  ...profiles.map(
                    (p) => DropdownMenuItem(
                      value: p.id,
                      child: Text(p.name ?? 'Profile ${p.id}'),
                    ),
                  ),
                ],
                onChanged: (val) => setState(() => _qualityProfileId = val),
              ),
              loading: () => const SizedBox(
                height: 50,
                child: Center(child: ExpressiveProgressIndicator()),
              ),
              error: (_, __) => const Text('Error loading quality profiles'),
            ),
            const SizedBox(height: Insets.md),
            // Metadata Profile
            metadataProfilesAsync.when(
              data: (profiles) => DropdownButtonFormField<int?>(
                isExpanded: true,
                initialValue: _metadataProfileId,
                decoration: const InputDecoration(
                  labelText: 'Metadata Profile',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(child: Text('Keep current')),
                  ...profiles.map(
                    (p) => DropdownMenuItem(
                      value: p.id,
                      child: Text(p.name ?? 'Profile ${p.id}'),
                    ),
                  ),
                ],
                onChanged: (val) => setState(() => _metadataProfileId = val),
              ),
              loading: () => const SizedBox(
                height: 50,
                child: Center(child: ExpressiveProgressIndicator()),
              ),
              error: (_, __) => const Text('Error loading metadata profiles'),
            ),
            const SizedBox(height: Insets.md),
            // Root Folder
            rootFoldersAsync.when(
              data: (folders) => Column(
                children: [
                  DropdownButtonFormField<String?>(
                    isExpanded: true,
                    initialValue: _rootFolderPath,
                    decoration: const InputDecoration(
                      labelText: 'Root Folder',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(child: Text('Keep current')),
                      ...folders.map(
                        (f) => DropdownMenuItem(
                          value: f.path,
                          child: Text(
                            f.path ?? 'Unknown',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) => setState(() {
                      _rootFolderPath = val;
                      if (val == null) _moveFiles = false;
                    }),
                  ),
                  if (_rootFolderPath != null)
                    CheckboxListTile(
                      title: const Text('Move existing files'),
                      subtitle: const Text(
                        'Automatically migrate audio files to the new root folder.',
                      ),
                      value: _moveFiles,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) =>
                          setState(() => _moveFiles = val ?? false),
                    ),
                ],
              ),
              loading: () => const SizedBox(
                height: 50,
                child: Center(child: ExpressiveProgressIndicator()),
              ),
              error: (_, __) => const Text('Error loading root folders'),
            ),
          ],
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
              : const Text('Apply Changes'),
        ),
      ],
    );
  }
}
