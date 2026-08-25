import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/lidarr_formatters.dart';
import '../../generated/generated.dart';
import '../../lidarr_api.dart';
import '../../lidarr_providers.dart';
import 'manual_import_dialog.dart';

/// Full screen to inspect and manage unmapped audio files found in an artist folder.
class LidarrUnmappedFilesScreen extends ConsumerStatefulWidget {
  const LidarrUnmappedFilesScreen({
    required this.instance,
    required this.artistId,
    this.artistName,
    super.key,
  });

  final Instance instance;
  final int artistId;
  final String? artistName;

  static Future<void> show(
    BuildContext context, {
    required Instance instance,
    required int artistId,
    String? artistName,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext ctx) => LidarrUnmappedFilesScreen(
          instance: instance,
          artistId: artistId,
          artistName: artistName,
        ),
      ),
    );
  }

  @override
  ConsumerState<LidarrUnmappedFilesScreen> createState() =>
      _LidarrUnmappedFilesScreenState();
}

/// Backwards compatibility alias for [LidarrUnmappedFilesScreen].
typedef LidarrUnmappedFilesSheet = LidarrUnmappedFilesScreen;

class _LidarrUnmappedFilesScreenState
    extends ConsumerState<LidarrUnmappedFilesScreen>
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final Set<int> _selectedIds = <int>{};
  double _lastBottomInset = 0.0;
  String _searchQuery = '';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _searchController.addListener(() {
      final query = _searchController.text.trim().toLowerCase();
      if (query != _searchQuery) {
        setState(() => _searchQuery = query);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final double bottomInset = WidgetsBinding
        .instance.platformDispatcher.views.first.viewInsets.bottom;
    if (bottomInset == 0 && _lastBottomInset > 0) {
      if (_searchFocusNode.hasFocus) {
        _searchFocusNode.unfocus();
      }
    }
    _lastBottomInset = bottomInset;
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.userScrollDirection !=
            ScrollDirection.idle) {
      if (_searchFocusNode.hasFocus) {
        _searchFocusNode.unfocus();
      }
    }
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<TrackFileResource> files) {
    setState(() {
      _selectedIds.clear();
      _selectedIds.addAll(
        files.where((f) => f.id != null).map((f) => f.id!),
      );
    });
  }

  void _deselectAll() {
    setState(_selectedIds.clear);
  }

  Future<void> _deleteUnmappedFile(TrackFileResource file) async {
    if (file.id == null) return;
    final messenger = ScaffoldMessenger.of(context);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dCtx) {
        final cs = Theme.of(dCtx).colorScheme;
        return AlertDialog(
          title: const Text('Delete Unmapped File?'),
          content: Text(
            'Are you sure you want to delete "${file.path ?? 'this file'}" from disk?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
              ),
              onPressed: () => Navigator.pop(dCtx, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final LidarrApi api =
          await ref.read(lidarrApiProvider(widget.instance).future);
      final ApiResponse<void> resp =
          await api.trackFile.deleteTrackfileById(id: file.id!);
      if (!resp.isSuccess) {
        throw Exception(resp.error?.message ?? 'Failed to delete file');
      }

      ref.invalidate(
        lidarrUnmappedTrackFilesForArtistProvider(
          (widget.instance, widget.artistId),
        ),
      );
      ref.invalidate(
        lidarrTrackFilesForArtistProvider((widget.instance, widget.artistId)),
      );

      setState(() {
        _selectedIds.remove(file.id);
      });

      messenger.showSnackBar(
        const SnackBar(content: Text('Unmapped audio file deleted.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to delete file: $e')),
      );
    }
  }

  Future<void> _bulkDeleteFiles(List<TrackFileResource> allFiles) async {
    if (_selectedIds.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dCtx) {
        final cs = Theme.of(dCtx).colorScheme;
        return AlertDialog(
          title: Text('Delete ${_selectedIds.length} Unmapped Files?'),
          content: Text(
            'Are you sure you want to permanently delete ${_selectedIds.length} unmapped file(s) from disk? This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
              ),
              onPressed: () => Navigator.pop(dCtx, true),
              child: const Text('Delete Permanently'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      final LidarrApi api =
          await ref.read(lidarrApiProvider(widget.instance).future);

      final payload = TrackFileListResource(
        trackFileIds: _selectedIds.toList(),
      );

      final ApiResponse<void> resp =
          await api.trackFile.deleteTrackfileBulk(body: payload);
      if (!resp.isSuccess) {
        throw Exception(resp.error?.message ?? 'Failed to bulk delete files');
      }

      ref.invalidate(
        lidarrUnmappedTrackFilesForArtistProvider(
          (widget.instance, widget.artistId),
        ),
      );
      ref.invalidate(
        lidarrTrackFilesForArtistProvider((widget.instance, widget.artistId)),
      );

      final int deletedCount = _selectedIds.length;
      setState(() {
        _selectedIds.clear();
        _isProcessing = false;
      });

      messenger.showSnackBar(
        SnackBar(content: Text('Deleted $deletedCount unmapped file(s).')),
      );
    } catch (e) {
      setState(() => _isProcessing = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to delete files: $e')),
      );
    }
  }

  String _formatAudioExtension(String? path) {
    if (path == null) return 'AUDIO';
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex != -1 && dotIndex < path.length - 1) {
      return path.substring(dotIndex + 1).toUpperCase();
    }
    return 'AUDIO';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final AsyncValue<List<TrackFileResource>> asyncUnmapped = ref.watch(
      lidarrUnmappedTrackFilesForArtistProvider(
        (widget.instance, widget.artistId),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.artistName != null
                  ? 'Unmapped Files — ${widget.artistName}'
                  : 'Unmapped Audio Files',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            asyncUnmapped.maybeWhen(
              data: (files) => Text(
                '${files.length} audio file(s) not matched',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.drive_folder_upload_outlined),
            tooltip: 'Manual Import All',
            onPressed: () {
              final files = asyncUnmapped.value ?? <TrackFileResource>[];
              String? folder;
              if (files.isNotEmpty && files.first.path != null) {
                final String p = files.first.path!;
                final int idx = p.lastIndexOf(RegExp(r'[\\/]'));
                if (idx != -1) {
                  folder = p.substring(0, idx);
                }
              }
              showLidarrManualImportFlow(
                context,
                ref,
                widget.instance,
                artistId: widget.artistId,
                initialFolder: folder,
              );
            },
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: asyncUnmapped.when(
          loading: () => const Center(child: ExpressiveProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
          data: (List<TrackFileResource> files) {
            if (files.isEmpty) {
              return const Center(
                child: EmptyView(
                  icon: Icons.check_circle_outline,
                  title: 'No Unmapped Files',
                  message:
                      'All audio files in the artist folder are mapped to albums and tracks.',
                ),
              );
            }

            // Filter files based on search query
            final filteredFiles = files.where((f) {
              if (_searchQuery.isEmpty) return true;
              final name = (f.path ?? '').toLowerCase();
              final tagArtist = (f.audioTags?.artistTitle ?? '').toLowerCase();
              final tagAlbum = (f.audioTags?.albumTitle ?? '').toLowerCase();
              final tagTitle = (f.audioTags?.title ?? '').toLowerCase();
              return name.contains(_searchQuery) ||
                  tagArtist.contains(_searchQuery) ||
                  tagAlbum.contains(_searchQuery) ||
                  tagTitle.contains(_searchQuery);
            }).toList();

            final bool allSelected = filteredFiles.isNotEmpty &&
                filteredFiles.every(
                  (f) => f.id != null && _selectedIds.contains(f.id!),
                );

            return Column(
              children: [
                // Search & Multi-select header row
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          decoration: InputDecoration(
                            hintText: 'Search unmapped files...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      _searchFocusNode.unfocus();
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: cs.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                        ),
                        icon: Icon(
                          allSelected
                              ? Icons.deselect_outlined
                              : Icons.select_all_outlined,
                          size: 18,
                        ),
                        label: Text(
                          allSelected ? 'Deselect' : 'Select All',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () {
                          if (allSelected) {
                            _deselectAll();
                          } else {
                            _selectAll(filteredFiles);
                          }
                        },
                      ),
                    ],
                  ),
                ),

                // Files List
                Expanded(
                  child: filteredFiles.isEmpty
                      ? Center(
                          child: Text(
                            'No unmapped files match "$_searchQuery"',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        )
                      : ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: filteredFiles.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final TrackFileResource file = filteredFiles[index];
                            final int? fileId = file.id;
                            final bool isSelected =
                                fileId != null && _selectedIds.contains(fileId);

                            final String fileName = file.path != null
                                ? file.path!.split(RegExp(r'[\\/]')).last
                                : 'Unmapped Audio File';
                            final ParsedTrackInfo? tags = file.audioTags;
                            final MediaInfoResource? media = file.mediaInfo;
                            final String ext = _formatAudioExtension(file.path);

                            return Card(
                              elevation: 0,
                              color: isSelected
                                  ? cs.primaryContainer.withValues(alpha: 0.25)
                                  : cs.surfaceContainerLow,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: isSelected
                                      ? cs.primary
                                      : cs.outlineVariant
                                          .withValues(alpha: 0.35),
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: fileId != null
                                    ? () => _toggleSelection(fileId)
                                    : null,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (fileId != null) ...[
                                            Checkbox(
                                              value: isSelected,
                                              visualDensity:
                                                  VisualDensity.compact,
                                              onChanged: (_) =>
                                                  _toggleSelection(fileId),
                                            ),
                                            const SizedBox(width: 4),
                                          ],
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: cs.secondaryContainer,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              ext,
                                              style: TextStyle(
                                                color: cs.onSecondaryContainer,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  fileName,
                                                  style: theme
                                                      .textTheme.bodyMedium
                                                      ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 3),
                                                Wrap(
                                                  spacing: 8,
                                                  runSpacing: 4,
                                                  children: [
                                                    Text(
                                                      LidarrFormatters
                                                          .formatBytes(
                                                        file.size,
                                                      ),
                                                      style: theme
                                                          .textTheme.bodySmall
                                                          ?.copyWith(
                                                        color:
                                                            cs.onSurfaceVariant,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    if (file.quality?.quality
                                                            ?.name !=
                                                        null)
                                                      Text(
                                                        '•  ${file.quality!.quality!.name}',
                                                        style: theme
                                                            .textTheme.bodySmall
                                                            ?.copyWith(
                                                          color: cs
                                                              .onSurfaceVariant,
                                                        ),
                                                      ),
                                                    if (media?.audioBitRate !=
                                                        null)
                                                      Text(
                                                        '•  ${media!.audioBitRate}${media.audioBitRate!.toLowerCase().contains('kb') ? '' : ' kbps'}',
                                                        style: theme
                                                            .textTheme.bodySmall
                                                            ?.copyWith(
                                                          color: cs
                                                              .onSurfaceVariant,
                                                        ),
                                                      ),
                                                    if (media?.audioChannels !=
                                                        null)
                                                      Text(
                                                        '•  ${media!.audioChannels == 2.0 ? 'Stereo' : media.audioChannels == 1.0 ? 'Mono' : '${media.audioChannels} ch'}',
                                                        style: theme
                                                            .textTheme.bodySmall
                                                            ?.copyWith(
                                                          color: cs
                                                              .onSurfaceVariant,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.copy_outlined,
                                              size: 16,
                                            ),
                                            tooltip: 'Copy Path',
                                            visualDensity:
                                                VisualDensity.compact,
                                            onPressed: file.path != null
                                                ? () {
                                                    Clipboard.setData(
                                                      ClipboardData(
                                                        text: file.path!,
                                                      ),
                                                    );
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'File path copied to clipboard',
                                                        ),
                                                        duration: Duration(
                                                          seconds: 1,
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                : null,
                                          ),
                                        ],
                                      ),

                                      // File Path Monospace
                                      if (file.path != null) ...[
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: cs.surfaceContainerHighest
                                                .withValues(alpha: 0.4),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.folder_outlined,
                                                size: 13,
                                                color: cs.onSurfaceVariant,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  file.path!,
                                                  style: theme
                                                      .textTheme.bodySmall
                                                      ?.copyWith(
                                                    fontFamily: 'monospace',
                                                    fontSize: 11,
                                                    color: cs.onSurfaceVariant,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],

                                      // Audio Tags
                                      if (tags != null &&
                                          (tags.title != null ||
                                              tags.albumTitle != null ||
                                              tags.artistTitle != null)) ...[
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: cs.tertiaryContainer
                                                .withValues(alpha: 0.35),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.tag,
                                                size: 13,
                                                color: cs.onTertiaryContainer,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  [
                                                    if (tags.artistTitle !=
                                                        null)
                                                      tags.artistTitle,
                                                    if (tags.albumTitle != null)
                                                      tags.albumTitle,
                                                    if (tags.title != null)
                                                      tags.title,
                                                  ].join(' — '),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color:
                                                        cs.onTertiaryContainer,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],

                                      const SizedBox(height: 8),

                                      // Actions Row
                                      Wrap(
                                        alignment: WrapAlignment.end,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 6,
                                              ),
                                            ),
                                            icon: const Icon(
                                              Icons.download_outlined,
                                              size: 16,
                                            ),
                                            label: const Text('Manual Import'),
                                            onPressed: () {
                                              showLidarrManualImportFlow(
                                                context,
                                                ref,
                                                widget.instance,
                                                artistId: widget.artistId,
                                                initialFolder: file.path,
                                              );
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline,
                                            ),
                                            color: cs.error,
                                            tooltip: 'Delete File',
                                            onPressed: () =>
                                                _deleteUnmappedFile(file),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: asyncUnmapped.maybeWhen(
        data: (files) {
          if (_selectedIds.isEmpty) return null;
          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              border: Border(
                top: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
            ),
            child: SafeArea(
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Text(
                    '${_selectedIds.length} selected',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                        ),
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Import'),
                        onPressed: () {
                          final TrackFileResource? sel = files
                              .where((f) => _selectedIds.contains(f.id))
                              .firstOrNull;
                          String? folder;
                          if (sel?.path != null) {
                            final String p = sel!.path!;
                            final int idx = p.lastIndexOf(RegExp(r'[\\/]'));
                            if (idx != -1) {
                              folder = p.substring(0, idx);
                            }
                          }
                          showLidarrManualImportFlow(
                            context,
                            ref,
                            widget.instance,
                            artistId: widget.artistId,
                            initialFolder: folder,
                          );
                        },
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: cs.error,
                          foregroundColor: cs.onError,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                        ),
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.delete_outline,
                                size: 16,
                              ),
                        label: Text('Delete (${_selectedIds.length})'),
                        onPressed: _isProcessing
                            ? null
                            : () => _bulkDeleteFiles(files),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
        orElse: () => null,
      ),
    );
  }
}
