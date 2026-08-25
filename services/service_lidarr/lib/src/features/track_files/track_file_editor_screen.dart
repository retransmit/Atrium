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

/// Interactive full screen to view, bulk-edit quality/release group, and bulk-delete track files.
class LidarrTrackFileEditorScreen extends ConsumerStatefulWidget {
  const LidarrTrackFileEditorScreen({
    required this.instance,
    required this.artistId,
    this.albumId,
    this.albumTitle,
    this.artistName,
    super.key,
  });

  final Instance instance;
  final int artistId;
  final int? albumId;
  final String? albumTitle;
  final String? artistName;

  static Future<void> show(
    BuildContext context, {
    required Instance instance,
    required int artistId,
    int? albumId,
    String? albumTitle,
    String? artistName,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext ctx) => LidarrTrackFileEditorScreen(
          instance: instance,
          artistId: artistId,
          albumId: albumId,
          albumTitle: albumTitle,
          artistName: artistName,
        ),
      ),
    );
  }

  @override
  ConsumerState<LidarrTrackFileEditorScreen> createState() =>
      _LidarrTrackFileEditorScreenState();
}

/// Backwards compatibility alias for [LidarrTrackFileEditorScreen].
typedef LidarrTrackFileEditorSheet = LidarrTrackFileEditorScreen;

class _LidarrTrackFileEditorScreenState
    extends ConsumerState<LidarrTrackFileEditorScreen>
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final Set<int> _selectedIds = <int>{};
  double _lastBottomInset = 0.0;
  String _searchQuery = '';
  String? _selectedQualityFilter;
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

  void _invalidateAll() {
    ref.invalidate(
      lidarrTrackFilesForArtistProvider((widget.instance, widget.artistId)),
    );
    if (widget.albumId != null) {
      ref.invalidate(
        lidarrTrackFilesForAlbumProvider((widget.instance, widget.albumId!)),
      );
    }
    ref.invalidate(
      lidarrAlbumsForArtistProvider((widget.instance, widget.artistId)),
    );
    ref.invalidate(
      lidarrArtistByIdProvider((widget.instance, widget.artistId)),
    );
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

  Future<void> _bulkEditQuality(List<TrackFileResource> files) async {
    if (_selectedIds.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);

    final qualityProfilesAsync =
        ref.read(lidarrQualityProfilesProvider(widget.instance));
    final List<QualityProfileResource> profiles =
        qualityProfilesAsync.value ?? <QualityProfileResource>[];

    QualityModel? targetQuality;
    final releaseGroupController = TextEditingController();
    final sceneNameController = TextEditingController();

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dCtx) {
        final cs = Theme.of(dCtx).colorScheme;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(Icons.edit_note_outlined, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Edit ${_selectedIds.length} Track Files'),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Update quality metadata or release information for selected tracks:',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Insets.md),
                    DropdownButtonFormField<QualityModel>(
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Target Quality',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      initialValue: targetQuality,
                      items: [
                        const DropdownMenuItem(
                          child: Text('Keep existing quality'),
                        ),
                        ...profiles.where((p) => p.cutoff != null).map(
                              (p) => DropdownMenuItem(
                                value: QualityModel(
                                  quality: Quality(
                                    id: p.cutoff,
                                    name: p.name,
                                  ),
                                ),
                                child: Text(p.name ?? 'Quality ${p.cutoff}'),
                              ),
                            ),
                      ],
                      onChanged: (QualityModel? val) {
                        setDialogState(() {
                          targetQuality = val;
                        });
                      },
                    ),
                    const SizedBox(height: Insets.md),
                    TextField(
                      controller: releaseGroupController,
                      decoration: const InputDecoration(
                        labelText: 'Release Group (optional)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: Insets.md),
                    TextField(
                      controller: sceneNameController,
                      decoration: const InputDecoration(
                        labelText: 'Scene Name (optional)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dCtx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dCtx, true),
                  child: const Text('Apply Changes'),
                ),
              ],
            );
          },
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
        quality: targetQuality,
        releaseGroup: releaseGroupController.text.trim().isNotEmpty
            ? releaseGroupController.text.trim()
            : null,
        sceneName: sceneNameController.text.trim().isNotEmpty
            ? sceneNameController.text.trim()
            : null,
      );

      final ApiResponse<void> resp =
          await api.trackFile.putTrackfileEditor(body: payload);
      if (!resp.isSuccess) {
        throw Exception(resp.error?.message ?? 'Failed to update track files');
      }

      _invalidateAll();
      setState(() {
        _selectedIds.clear();
        _isProcessing = false;
      });

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Track files updated successfully!'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() => _isProcessing = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to edit track files: $e')),
      );
    }
  }

  Future<void> _bulkDeleteFiles() async {
    if (_selectedIds.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dCtx) {
        final cs = Theme.of(dCtx).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text('Delete ${_selectedIds.length} Audio Files?'),
          content: Text(
            'Are you sure you want to permanently delete ${_selectedIds.length} audio file(s) from disk? This cannot be undone.',
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
        throw Exception(resp.error?.message ?? 'Failed to delete track files');
      }

      _invalidateAll();
      setState(() {
        _selectedIds.clear();
        _isProcessing = false;
      });

      messenger.showSnackBar(
        const SnackBar(content: Text('Track files deleted successfully!')),
      );
    } catch (e) {
      setState(() => _isProcessing = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to delete track files: $e')),
      );
    }
  }

  Future<void> _deleteSingleFile(TrackFileResource file) async {
    if (file.id == null) return;
    final messenger = ScaffoldMessenger.of(context);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dCtx) {
        final cs = Theme.of(dCtx).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Delete Audio File?'),
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

      _invalidateAll();
      setState(() {
        _selectedIds.remove(file.id);
      });

      messenger.showSnackBar(
        const SnackBar(content: Text('Audio file deleted.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to delete file: $e')),
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

    final AsyncValue<List<TrackFileResource>> asyncFiles =
        widget.albumId != null
            ? ref.watch(
                lidarrTrackFilesForAlbumProvider(
                  (widget.instance, widget.albumId!),
                ),
              )
            : ref.watch(
                lidarrTrackFilesForArtistProvider(
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
              widget.albumTitle != null
                  ? 'Track Files — ${widget.albumTitle}'
                  : 'Track Files Editor',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            asyncFiles.maybeWhen(
              data: (files) {
                final int totalBytes =
                    files.fold(0, (sum, f) => sum + (f.size ?? 0));
                return Text(
                  '${files.length} track(s) • ${LidarrFormatters.formatBytes(totalBytes)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _invalidateAll,
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: asyncFiles.when(
          loading: () => const Center(child: ExpressiveProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
          data: (List<TrackFileResource> files) {
            if (files.isEmpty) {
              return const Center(
                child: EmptyView(
                  icon: Icons.audio_file_outlined,
                  title: 'No Track Files Found',
                  message: 'No downloaded audio files found on disk.',
                ),
              );
            }

            // Extract distinct qualities for chips
            final Set<String> qualities = files
                .map((f) => f.quality?.quality?.name)
                .whereType<String>()
                .toSet();

            // Filter files based on search & quality chip
            final filteredFiles = files.where((f) {
              if (_selectedQualityFilter != null &&
                  f.quality?.quality?.name != _selectedQualityFilter) {
                return false;
              }
              if (_searchQuery.isEmpty) return true;
              final name = (f.path ?? '').toLowerCase();
              final qName = (f.quality?.quality?.name ?? '').toLowerCase();
              final rGroup = (f.releaseGroup ?? '').toLowerCase();
              final sName = (f.sceneName ?? '').toLowerCase();
              final codec = (f.mediaInfo?.audioCodec ?? '').toLowerCase();
              return name.contains(_searchQuery) ||
                  qName.contains(_searchQuery) ||
                  rGroup.contains(_searchQuery) ||
                  sName.contains(_searchQuery) ||
                  codec.contains(_searchQuery);
            }).toList();

            final bool allSelected = filteredFiles.isNotEmpty &&
                filteredFiles.every(
                  (f) => f.id != null && _selectedIds.contains(f.id!),
                );

            return Column(
              children: [
                // Search and Select All Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          decoration: InputDecoration(
                            hintText: 'Search by title, path, codec...',
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
                      // The label doubles at large text scales, so the
                      // button has to be able to give ground rather than
                      // push the row past its width.
                      Flexible(
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: () {
                            if (allSelected) {
                              _deselectAll();
                            } else {
                              _selectAll(filteredFiles);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Quality Filter Chips (if multiple)
                if (qualities.length > 1)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        FilterChip(
                          selected: _selectedQualityFilter == null,
                          label: Text('All (${files.length})'),
                          onSelected: (_) {
                            setState(() => _selectedQualityFilter = null);
                          },
                        ),
                        const SizedBox(width: 8),
                        ...qualities.map((q) {
                          final count = files
                              .where((f) => f.quality?.quality?.name == q)
                              .length;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              selected: _selectedQualityFilter == q,
                              label: Text('$q ($count)'),
                              onSelected: (selected) {
                                setState(() {
                                  _selectedQualityFilter = selected ? q : null;
                                });
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                // Selection Toolbar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.md,
                    vertical: 6,
                  ),
                  color: cs.surfaceContainerLow,
                  child: Row(
                    children: [
                      Checkbox(
                        value: allSelected,
                        onChanged: (bool? val) {
                          if (val == true) {
                            _selectAll(filteredFiles);
                          } else {
                            _deselectAll();
                          }
                        },
                      ),
                      // Ahead of a Spacer, which cannot shrink below zero, so an
                      // unbounded count pushes the buttons after it off the edge.
                      Flexible(
                        child: Text(
                          '${_selectedIds.length} / ${files.length} selected',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Spacer(),
                      if (_selectedIds.isNotEmpty) ...[
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: 20,
                          ),
                          tooltip: 'Edit Quality',
                          onPressed: _isProcessing
                              ? null
                              : () => _bulkEditQuality(files),
                        ),
                        IconButton(
                          style: IconButton.styleFrom(
                            foregroundColor: cs.error,
                          ),
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 20,
                          ),
                          tooltip: 'Delete Selected',
                          onPressed: _isProcessing ? null : _bulkDeleteFiles,
                        ),
                      ],
                    ],
                  ),
                ),

                // Files List
                Expanded(
                  child: filteredFiles.isEmpty
                      ? Center(
                          child: Text(
                            'No track files match "$_searchQuery"',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        )
                      : ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                          itemCount: filteredFiles.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final TrackFileResource file = filteredFiles[index];
                            final int? fileId = file.id;
                            final bool isSelected =
                                fileId != null && _selectedIds.contains(fileId);
                            final MediaInfoResource? media = file.mediaInfo;
                            final String fileName = file.path != null
                                ? file.path!.split(RegExp(r'[\\/]')).last
                                : 'Track File';
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
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              size: 18,
                                            ),
                                            color: cs.error,
                                            tooltip: 'Delete file',
                                            onPressed: () =>
                                                _deleteSingleFile(file),
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

                                      // Scene / Release Group
                                      if (file.releaseGroup != null ||
                                          file.sceneName != null) ...[
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            if (file.releaseGroup != null)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: cs.tertiaryContainer
                                                      .withValues(alpha: 0.4),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'Group: ${file.releaseGroup}',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        cs.onTertiaryContainer,
                                                  ),
                                                ),
                                              ),
                                            if (file.sceneName != null)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: cs
                                                      .surfaceContainerHighest,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'Scene: ${file.sceneName}',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: cs.onSurfaceVariant,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
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
    );
  }
}
