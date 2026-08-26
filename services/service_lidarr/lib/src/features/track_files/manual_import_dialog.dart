import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/lidarr_formatters.dart';
import '../../generated/generated.dart';
import '../../lidarr_api.dart';
import '../../lidarr_providers.dart';

/// Starts the Lidarr Manual Import user flow.
void showLidarrManualImportFlow(
  BuildContext context,
  WidgetRef ref,
  Instance instance, {
  String? initialFolder,
  String? downloadId,
  int? artistId,
}) {
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => _ManualImportSetupDialog(
        instance: instance,
        initialFolder: initialFolder,
        downloadId: downloadId,
        artistId: artistId,
      ),
    ),
  );
}

class _ManualImportSetupDialog extends ConsumerStatefulWidget {
  const _ManualImportSetupDialog({
    required this.instance,
    this.initialFolder,
    this.downloadId,
    this.artistId,
  });

  final Instance instance;
  final String? initialFolder;
  final String? downloadId;
  final int? artistId;

  @override
  ConsumerState<_ManualImportSetupDialog> createState() =>
      __ManualImportSetupDialogState();
}

class __ManualImportSetupDialogState
    extends ConsumerState<_ManualImportSetupDialog> {
  late final TextEditingController _pathController;
  bool _filterExistingFiles = true;
  bool _replaceExistingFiles = true;
  String _importMode = 'auto'; // 'auto', 'move', 'copy'
  bool _scanning = false;
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    final String rememberedPath =
        ref.read(lidarrManualImportPathProvider(widget.instance));
    _pathController = TextEditingController(
      text: widget.initialFolder ?? rememberedPath,
    );
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  Future<void> _browseFolder() async {
    final String? selectedPath = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => _DirectoryBrowserDialog(
        instance: widget.instance,
        initialPath: _pathController.text,
      ),
    );

    if (selectedPath != null) {
      setState(() {
        _pathController.text = selectedPath;
      });
      ref.read(lidarrManualImportPathProvider(widget.instance).notifier).state =
          selectedPath;
    }
  }

  Future<void> _startScan() async {
    final String folder = _pathController.text.trim();
    if (folder.isEmpty && widget.downloadId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or enter a folder path.')),
      );
      return;
    }

    _cancelToken = CancelToken();
    setState(() => _scanning = true);

    List<ManualImportResource> files = <ManualImportResource>[];
    Object? scanError;

    try {
      final LidarrApi api =
          await ref.read(lidarrApiProvider(widget.instance).future);
      final ApiResponse<List<ManualImportResource>> resp =
          await api.manualImport.getManualimport(
        folder: folder.isNotEmpty ? folder : null,
        downloadId: widget.downloadId,
        artistId: widget.artistId,
        filterExistingFiles: _filterExistingFiles,
        replaceExistingFiles: _replaceExistingFiles,
      );

      if (!resp.isSuccess) {
        throw Exception(resp.error?.message ?? 'Failed to scan folder');
      }
      files = resp.data ?? <ManualImportResource>[];
    } catch (e) {
      scanError = e;
    }

    if (!mounted) return;

    if (scanError != null) {
      setState(() => _scanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scan failed: $scanError'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    if (files.isEmpty) {
      setState(() => _scanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No audio files found to import in this folder.'),
        ),
      );
      return;
    }

    // Save path preference
    ref.read(lidarrManualImportPathProvider(widget.instance).notifier).state =
        folder;

    // Pop setup dialog
    Navigator.of(context).pop();

    // Navigate to full-screen mapping screen
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext ctx) => LidarrManualImportScreen(
            instance: widget.instance,
            initialFiles: files,
            folder: folder,
            downloadId: widget.downloadId,
            replaceExistingFiles: _replaceExistingFiles,
            initialImportMode: _importMode,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: <Widget>[
          Icon(Icons.drive_folder_upload_outlined, color: cs.primary, size: 26),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Manual Import', overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      content: _scanning
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const ExpressiveProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(
                    'Scanning folder for audio tracks...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Querying server and matching tags...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Select a folder to scan for audio tracks to match and import into your Lidarr library.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _pathController,
                          decoration: InputDecoration(
                            labelText: 'Folder Path',
                            hintText: '/data/media/music/...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.folder_open),
                        tooltip: 'Browse Server Folders',
                        onPressed: _browseFolder,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _importMode,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Import Mode',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(
                        value: 'auto',
                        child: Text('Auto (Lidarr Default)'),
                      ),
                      DropdownMenuItem(
                        value: 'move',
                        child: Text('Move (Recommended)'),
                      ),
                      DropdownMenuItem(
                        value: 'copy',
                        child: Text('Copy'),
                      ),
                    ],
                    onChanged: (String? val) {
                      if (val != null) setState(() => _importMode = val);
                    },
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Filter Existing Files'),
                    subtitle:
                        const Text('Skip tracks already imported in library'),
                    value: _filterExistingFiles,
                    onChanged: (bool? val) {
                      setState(() => _filterExistingFiles = val ?? true);
                    },
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Replace Existing Files'),
                    subtitle: const Text('Allow upgrades of existing tracks'),
                    value: _replaceExistingFiles,
                    onChanged: (bool? val) {
                      setState(() => _replaceExistingFiles = val ?? true);
                    },
                  ),
                ],
              ),
            ),
      actions: _scanning
          ? <Widget>[
              TextButton(
                onPressed: () {
                  _cancelToken?.cancel('user_cancelled');
                  setState(() => _scanning = false);
                },
                child: const Text('Cancel'),
              ),
            ]
          : <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: _startScan,
                icon: const Icon(Icons.search),
                label: const Text('Scan Folder'),
              ),
            ],
    );
  }
}

/// Dedicated full-screen manual import mapping and matching screen.
class LidarrManualImportScreen extends ConsumerStatefulWidget {
  const LidarrManualImportScreen({
    required this.instance,
    required this.initialFiles,
    required this.folder,
    required this.replaceExistingFiles,
    this.downloadId,
    this.initialImportMode = 'auto',
    super.key,
  });

  final Instance instance;
  final List<ManualImportResource> initialFiles;
  final String folder;
  final String? downloadId;
  final bool replaceExistingFiles;
  final String initialImportMode;

  @override
  ConsumerState<LidarrManualImportScreen> createState() =>
      _LidarrManualImportScreenState();
}

class _LidarrManualImportScreenState
    extends ConsumerState<LidarrManualImportScreen>
    with WidgetsBindingObserver {
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  late List<ManualImportResource> _files;
  final Set<String> _selectedPaths = <String>{};
  double _lastBottomInset = 0.0;
  String _searchQuery = '';
  String _filterTab = 'all'; // 'all', 'matched', 'issues', 'selected'
  late String _importMode;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _importMode = widget.initialImportMode;
    _files = List<ManualImportResource>.from(widget.initialFiles);
    for (final ManualImportResource f in _files) {
      if (f.path != null && (f.rejections == null || f.rejections!.isEmpty)) {
        _selectedPaths.add(f.path!);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchFocusNode.dispose();
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

  void _toggleSelectAll(bool selectAll) {
    setState(() {
      if (selectAll) {
        for (final ManualImportResource f in _files) {
          if (f.path != null) _selectedPaths.add(f.path!);
        }
      } else {
        _selectedPaths.clear();
      }
    });
  }

  Future<void> _pickArtistForFile(int index) async {
    final List<ArtistResource> artists = await ref
        .read(lidarrArtistsProvider(widget.instance).future)
        .catchError((_) => <ArtistResource>[]);

    if (!mounted) return;

    final ArtistResource? picked = await showDialog<ArtistResource>(
      context: context,
      builder: (BuildContext ctx) => _ArtistPickerDialog(artists: artists),
    );

    if (picked != null) {
      setState(() {
        _files[index] = _files[index].copyWith(
          artist: picked,
          album: null,
          tracks: null,
        );
      });
    }
  }

  Future<void> _pickAlbumForFile(int index) async {
    final ArtistResource? artist = _files[index].artist;
    if (artist == null || artist.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an artist first.')),
      );
      return;
    }

    final List<AlbumResource> albums = await ref
        .read(
          lidarrAlbumsForArtistProvider((widget.instance, artist.id!)).future,
        )
        .catchError((_) => <AlbumResource>[]);

    if (!mounted) return;

    final AlbumResource? picked = await showDialog<AlbumResource>(
      context: context,
      builder: (BuildContext ctx) => _AlbumPickerDialog(albums: albums),
    );

    if (picked != null) {
      setState(() {
        _files[index] = _files[index].copyWith(
          album: picked,
          tracks: null,
        );
      });
    }
  }

  Future<void> _pickTracksForFile(int index) async {
    final ArtistResource? artist = _files[index].artist;
    final AlbumResource? album = _files[index].album;
    if (artist == null ||
        artist.id == null ||
        album == null ||
        album.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an artist and album first.'),
        ),
      );
      return;
    }

    final List<TrackResource> tracks = await ref
        .read(
          lidarrTracksForAlbumProvider(
            (widget.instance, artist.id!, album.id!),
          ).future,
        )
        .catchError((_) => <TrackResource>[]);

    if (!mounted) return;

    final List<TrackResource>? picked = await showDialog<List<TrackResource>>(
      context: context,
      builder: (BuildContext ctx) => _TrackPickerDialog(
        tracks: tracks,
        initialSelectedIds:
            _files[index].tracks?.map((t) => t.id).whereType<int>().toSet() ??
                <int>{},
      ),
    );

    if (picked != null) {
      setState(() {
        _files[index] = _files[index].copyWith(tracks: picked);
      });
    }
  }

  Future<void> _pickQualityForFile(int index) async {
    final List<QualityProfileResource> profiles = await ref
        .read(lidarrQualityProfilesProvider(widget.instance).future)
        .catchError((_) => <QualityProfileResource>[]);

    if (!mounted) return;

    final QualityModel? picked = await showDialog<QualityModel>(
      context: context,
      builder: (BuildContext ctx) =>
          _QualityPickerDialog(qualityProfiles: profiles),
    );

    if (picked != null) {
      setState(() {
        _files[index] = _files[index].copyWith(quality: picked);
      });
    }
  }

  Future<void> _executeImport() async {
    final List<ManualImportResource> selectedItems = _files
        .where((f) => f.path != null && _selectedPaths.contains(f.path))
        .toList();

    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No files selected to import.')),
      );
      return;
    }

    final List<Map<String, dynamic>> importFiles = <Map<String, dynamic>>[];
    for (final ManualImportResource item in selectedItems) {
      final List<int> trackIds = item.tracks
              ?.map((TrackResource t) => t.id)
              .whereType<int>()
              .toList() ??
          <int>[];

      importFiles.add(<String, dynamic>{
        'path': item.path,
        'artistId': item.artist?.id,
        'albumId': item.album?.id,
        'trackIds': trackIds,
        'quality': item.quality?.toJson(),
        'indexerFlags': item.indexerFlags ?? 0,
        'releaseGroup': item.releaseGroup,
        'downloadId': widget.downloadId ?? item.downloadId,
        'disableReleaseSwitching': item.disableReleaseSwitching ?? false,
      });
    }

    setState(() => _importing = true);

    try {
      final LidarrApi api =
          await ref.read(lidarrApiProvider(widget.instance).future);
      final ApiResponse<CommandResource> resp = await api.executeCommand(
        'ManualImport',
        <String, dynamic>{
          'files': importFiles,
          'importMode': _importMode,
          'replaceExistingFiles': widget.replaceExistingFiles,
        },
      );

      if (!resp.isSuccess) {
        throw Exception(resp.error?.message ?? 'Failed to trigger import');
      }

      ref.invalidate(lidarrQueueProvider(widget.instance));
      ref.invalidate(lidarrHistoryProvider(widget.instance));
      ref.invalidate(lidarrArtistsProvider(widget.instance));
      ref.invalidate(lidarrWantedMissingProvider);
      ref.invalidate(lidarrWantedCutoffProvider);

      if (mounted) {
        Navigator.pop(context); // Close results screen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Import triggered for ${importFiles.length} file(s). Check Activity tab for progress.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _importing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    final List<ManualImportResource> filtered = _files.where((f) {
      // 1. Search query filter
      if (_searchQuery.isNotEmpty) {
        final String q = _searchQuery.toLowerCase();
        final String name = (f.name ?? f.path ?? '').toLowerCase();
        final String artist = (f.artist?.artistName ?? '').toLowerCase();
        final String album = (f.album?.title ?? '').toLowerCase();
        final String track =
            (f.tracks?.map((t) => t.title).join(' ') ?? '').toLowerCase();
        if (!name.contains(q) &&
            !artist.contains(q) &&
            !album.contains(q) &&
            !track.contains(q)) {
          return false;
        }
      }

      // 2. Tab filter
      final bool hasRejections =
          f.rejections != null && f.rejections!.isNotEmpty;
      final bool isMatched = f.artist != null &&
          f.album != null &&
          f.tracks != null &&
          f.tracks!.isNotEmpty;
      final bool isSelected = f.path != null && _selectedPaths.contains(f.path);

      return switch (_filterTab) {
        'matched' => isMatched && !hasRejections,
        'issues' => hasRejections || !isMatched,
        'selected' => isSelected,
        _ => true,
      };
    }).toList();

    final int issuesCount = _files.where((f) {
      return (f.rejections != null && f.rejections!.isNotEmpty) ||
          f.artist == null ||
          f.album == null ||
          f.tracks == null ||
          f.tracks!.isEmpty;
    }).length;

    final int matchedCount = _files.where((f) {
      return f.artist != null &&
          f.album != null &&
          f.tracks != null &&
          f.tracks!.isNotEmpty &&
          (f.rejections == null || f.rejections!.isEmpty);
    }).length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Import Files (${_files.length})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.folder.isNotEmpty)
              Text(
                widget.folder,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: <Widget>[
          TextButton.icon(
            onPressed: () =>
                _toggleSelectAll(_selectedPaths.length != _files.length),
            icon: Icon(
              _selectedPaths.length == _files.length
                  ? Icons.deselect
                  : Icons.select_all,
              size: 18,
            ),
            label: Text(
              _selectedPaths.length == _files.length
                  ? 'Deselect All'
                  : 'Select All',
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Column(
          children: <Widget>[
            // Search & Filter Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText:
                      'Filter scanned audio files by title, artist, album...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            setState(() => _searchQuery = '');
                            _searchFocusNode.unfocus();
                          },
                        )
                      : null,
                  isDense: true,
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                onChanged: (String val) => setState(() => _searchQuery = val),
              ),
            ),

            // Filter Segment Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _buildSegmentChip('all', 'All (${_files.length})', cs),
                  const SizedBox(width: 8),
                  _buildSegmentChip('matched', 'Ready ($matchedCount)', cs),
                  const SizedBox(width: 8),
                  _buildSegmentChip(
                    'issues',
                    'Needs Review ($issuesCount)',
                    cs,
                  ),
                  const SizedBox(width: 8),
                  _buildSegmentChip(
                    'selected',
                    'Selected (${_selectedPaths.length})',
                    cs,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // Files list
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.filter_list_off,
                            size: 48,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No files matching this filter',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (BuildContext context, int index) {
                        final ManualImportResource item = filtered[index];
                        final int originalIndex = _files.indexOf(item);
                        final bool isSelected = item.path != null &&
                            _selectedPaths.contains(item.path);
                        final List<Rejection> rejections =
                            item.rejections ?? <Rejection>[];
                        final bool hasRejections = rejections.isNotEmpty;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: isSelected
                                  ? cs.primary
                                  : cs.outlineVariant.withValues(alpha: 0.35),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                // Header: Checkbox + File Name + Size + Quality
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Checkbox(
                                      value: isSelected,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      onChanged: item.path == null
                                          ? null
                                          : (bool? val) {
                                              setState(() {
                                                if (val == true) {
                                                  _selectedPaths
                                                      .add(item.path!);
                                                } else {
                                                  _selectedPaths
                                                      .remove(item.path!);
                                                }
                                              });
                                            },
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            item.name ??
                                                item.path ??
                                                'Unknown File',
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: <Widget>[
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 7,
                                                  vertical: 2.5,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: cs
                                                      .surfaceContainerHighest
                                                      .withValues(alpha: 0.6),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  LidarrFormatters.formatBytes(
                                                    item.size,
                                                  ),
                                                  style: theme
                                                      .textTheme.labelSmall
                                                      ?.copyWith(
                                                    color: cs.onSurfaceVariant,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              if (item.quality?.quality?.name !=
                                                  null)
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 7,
                                                    vertical: 2.5,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        cs.secondaryContainer,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      6,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    item.quality!.quality!
                                                        .name!,
                                                    style: theme
                                                        .textTheme.labelSmall
                                                        ?.copyWith(
                                                      color: cs
                                                          .onSecondaryContainer,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              if (item.qualityWeight != null &&
                                                  item.qualityWeight! > 0)
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 7,
                                                    vertical: 2.5,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: cs.tertiaryContainer,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      6,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    '+Score: ${item.qualityWeight}',
                                                    style: theme
                                                        .textTheme.labelSmall
                                                        ?.copyWith(
                                                      color: cs
                                                          .onTertiaryContainer,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                // Audio tags metadata preview if available
                                if (item.audioTags != null) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: cs.surfaceContainerHighest
                                          .withValues(alpha: 0.4),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: <Widget>[
                                        Icon(
                                          Icons.music_note,
                                          size: 15,
                                          color: cs.primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'ID3: ${item.audioTags?.artistTitle ?? 'Unknown'} • ${item.audioTags?.albumTitle ?? 'Unknown'} • ${item.audioTags?.title ?? 'Track'}',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: cs.onSurfaceVariant,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                // Rejection alert
                                if (hasRejections) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: cs.errorContainer
                                          .withValues(alpha: 0.35),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: cs.error.withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          size: 16,
                                          color: cs.error,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            rejections
                                                .map((r) => r.reason ?? '')
                                                .where((s) => s.isNotEmpty)
                                                .join('\n'),
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: cs.error,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 12),
                                Divider(
                                  height: 1,
                                  color:
                                      cs.outlineVariant.withValues(alpha: 0.3),
                                ),
                                const SizedBox(height: 10),

                                // Matching Action Chips: Artist, Album, Track, Quality
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: <Widget>[
                                    ActionChip(
                                      avatar: Icon(
                                        Icons.person_outline,
                                        size: 16,
                                        color: item.artist != null
                                            ? cs.primary
                                            : cs.onSurfaceVariant,
                                      ),
                                      label: Text(
                                        item.artist?.artistName ??
                                            'Select Artist',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: item.artist != null
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                      onPressed: () =>
                                          _pickArtistForFile(originalIndex),
                                    ),
                                    ActionChip(
                                      avatar: Icon(
                                        Icons.album_outlined,
                                        size: 16,
                                        color: item.album != null
                                            ? cs.primary
                                            : cs.onSurfaceVariant,
                                      ),
                                      label: Text(
                                        item.album?.title ?? 'Select Album',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: item.album != null
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                      onPressed: () =>
                                          _pickAlbumForFile(originalIndex),
                                    ),
                                    ActionChip(
                                      avatar: Icon(
                                        Icons.queue_music_outlined,
                                        size: 16,
                                        color: item.tracks?.isNotEmpty == true
                                            ? cs.primary
                                            : cs.onSurfaceVariant,
                                      ),
                                      label: Text(
                                        item.tracks?.isNotEmpty == true
                                            ? item.tracks!
                                                .map(
                                                  (t) =>
                                                      '${t.trackNumber ?? 1}. ${t.title ?? 'Track'}',
                                                )
                                                .join(', ')
                                            : 'Select Track',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight:
                                              item.tracks?.isNotEmpty == true
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                        ),
                                      ),
                                      onPressed: () =>
                                          _pickTracksForFile(originalIndex),
                                    ),
                                    ActionChip(
                                      avatar: Icon(
                                        Icons.tune_outlined,
                                        size: 16,
                                        color: item.quality != null
                                            ? cs.primary
                                            : cs.onSurfaceVariant,
                                      ),
                                      label: Text(
                                        item.quality?.quality?.name ??
                                            'Quality',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: item.quality != null
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                      onPressed: () =>
                                          _pickQualityForFile(originalIndex),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Footer actions bar
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  border: Border(
                    top: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: <Widget>[
                        // Import mode selector
                        DropdownButton<String>(
                          value: _importMode,
                          underline: const SizedBox.shrink(),
                          items: const <DropdownMenuItem<String>>[
                            DropdownMenuItem(
                              value: 'auto',
                              child: Text('Mode: Auto'),
                            ),
                            DropdownMenuItem(
                              value: 'move',
                              child: Text('Mode: Move'),
                            ),
                            DropdownMenuItem(
                              value: 'copy',
                              child: Text('Mode: Copy'),
                            ),
                          ],
                          onChanged: (String? val) {
                            if (val != null) setState(() => _importMode = val);
                          },
                        ),
                        const Spacer(),
                        Text(
                          '${_selectedPaths.length} selected',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _importing || _selectedPaths.isEmpty
                            ? null
                            : _executeImport,
                        icon: _importing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.download_done_rounded),
                        label: const Text('Import Selected'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentChip(String tab, String label, ColorScheme cs) {
    final bool isSelected = _filterTab == tab;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      onSelected: (bool selected) {
        if (selected) setState(() => _filterTab = tab);
      },
    );
  }
}

class _DirectoryBrowserDialog extends ConsumerStatefulWidget {
  const _DirectoryBrowserDialog({
    required this.instance,
    required this.initialPath,
  });

  final Instance instance;
  final String initialPath;

  @override
  ConsumerState<_DirectoryBrowserDialog> createState() =>
      __DirectoryBrowserDialogState();
}

class __DirectoryBrowserDialogState
    extends ConsumerState<_DirectoryBrowserDialog> {
  late String _currentPath;
  List<Map<String, dynamic>> _directories = <Map<String, dynamic>>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialPath.trim();
    _loadDirectoryContents();
  }

  Future<void> _loadDirectoryContents() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final LidarrApi api =
          await ref.read(lidarrApiProvider(widget.instance).future);
      final List<Map<String, dynamic>> result = await api.getFileSystem(
        path: _currentPath,
      );

      if (mounted) {
        setState(() {
          _directories = result;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _navigateBack() {
    if (_currentPath.isEmpty || _currentPath == '/' || _currentPath == '\\') {
      return;
    }

    final bool isWindows = _currentPath.contains('\\');
    final String separator = isWindows ? '\\' : '/';

    String path = _currentPath;
    if (path.endsWith(separator)) {
      path = path.substring(0, path.length - 1);
    }

    final int index = path.lastIndexOf(separator);
    if (index == -1) {
      _currentPath = '';
    } else {
      _currentPath = path.substring(0, index);
      if (_currentPath.isEmpty && !isWindows) {
        _currentPath = '/';
      }
    }

    _loadDirectoryContents();
  }

  void _navigateTo(String targetPath) {
    _currentPath = targetPath;
    _loadDirectoryContents();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.folder_outlined, color: cs.primary),
          const SizedBox(width: 10),
          const Text('Browse Server Folders'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 450,
        child: Column(
          children: <Widget>[
            // Path header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.arrow_upward, size: 18),
                    tooltip: 'Parent Folder',
                    onPressed: _currentPath.isNotEmpty ? _navigateBack : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _currentPath.isEmpty ? '/' : _currentPath,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _loading
                  ? const Center(child: ExpressiveProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Text(
                            'Error: $_error',
                            style: TextStyle(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        )
                      : _directories.isEmpty
                          ? const Center(child: Text('No folders found.'))
                          : ListView.separated(
                              itemCount: _directories.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (BuildContext context, int index) {
                                final Map<String, dynamic> dir =
                                    _directories[index];
                                final String name =
                                    dir['name']?.toString() ?? 'folder';
                                final String path =
                                    dir['path']?.toString() ?? name;

                                return ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.folder),
                                  title: Text(name),
                                  onTap: () => _navigateTo(path),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _currentPath),
          child: const Text('Select This Folder'),
        ),
      ],
    );
  }
}

class _ArtistPickerDialog extends StatefulWidget {
  const _ArtistPickerDialog({required this.artists});

  final List<ArtistResource> artists;

  @override
  State<_ArtistPickerDialog> createState() => _ArtistPickerDialogState();
}

class _ArtistPickerDialogState extends State<_ArtistPickerDialog> {
  late final TextEditingController _filterController;
  List<ArtistResource> _filtered = <ArtistResource>[];

  @override
  void initState() {
    super.initState();
    _filterController = TextEditingController();
    _filtered = widget.artists;
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  void _onFilterChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = widget.artists;
      } else {
        final String q = query.toLowerCase();
        _filtered = widget.artists
            .where((a) => (a.artistName ?? '').toLowerCase().contains(q))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Select Artist'),
      content: SizedBox(
        width: double.maxFinite,
        height: 380,
        child: Column(
          children: <Widget>[
            TextField(
              controller: _filterController,
              decoration: InputDecoration(
                hintText: 'Search artists...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _onFilterChanged,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _filtered.length,
                itemBuilder: (BuildContext context, int index) {
                  final ArtistResource a = _filtered[index];
                  return ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person, size: 18),
                    ),
                    title: Text(
                      a.artistName ?? 'Unknown Artist',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      a.genres?.isNotEmpty == true
                          ? a.genres!.join(', ')
                          : 'Artist',
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => Navigator.pop(context, a),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _AlbumPickerDialog extends StatelessWidget {
  const _AlbumPickerDialog({required this.albums});

  final List<AlbumResource> albums;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Select Album'),
      content: SizedBox(
        width: double.maxFinite,
        height: 380,
        child: albums.isEmpty
            ? const Center(child: Text('No albums found for this artist.'))
            : ListView.builder(
                itemCount: albums.length,
                itemBuilder: (BuildContext context, int index) {
                  final AlbumResource album = albums[index];
                  return ListTile(
                    leading: const Icon(Icons.album_outlined),
                    title: Text(
                      album.title ?? 'Unknown Album',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${album.albumType ?? 'Album'} • ${album.releaseDate != null && album.releaseDate!.length >= 4 ? album.releaseDate!.substring(0, 4) : ''}',
                      style: theme.textTheme.bodySmall,
                    ),
                    onTap: () => Navigator.pop(context, album),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _TrackPickerDialog extends StatefulWidget {
  const _TrackPickerDialog({
    required this.tracks,
    required this.initialSelectedIds,
  });

  final List<TrackResource> tracks;
  final Set<int> initialSelectedIds;

  @override
  State<_TrackPickerDialog> createState() => _TrackPickerDialogState();
}

class _TrackPickerDialogState extends State<_TrackPickerDialog> {
  final Set<int> _selectedIds = <int>{};

  @override
  void initState() {
    super.initState();
    _selectedIds.addAll(widget.initialSelectedIds);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Select Track(s)'),
      content: SizedBox(
        width: double.maxFinite,
        height: 380,
        child: widget.tracks.isEmpty
            ? const Center(child: Text('No tracks found for this album.'))
            : ListView.builder(
                itemCount: widget.tracks.length,
                itemBuilder: (BuildContext context, int index) {
                  final TrackResource track = widget.tracks[index];
                  final int trackId = track.id ?? index;
                  final bool isChecked = _selectedIds.contains(trackId);

                  return CheckboxListTile(
                    title: Text(
                      '${track.trackNumber ?? index + 1}. ${track.title ?? 'Track'}',
                    ),
                    value: isChecked,
                    onChanged: (bool? val) {
                      setState(() {
                        if (val == true) {
                          _selectedIds.add(trackId);
                        } else {
                          _selectedIds.remove(trackId);
                        }
                      });
                    },
                  );
                },
              ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final List<TrackResource> selected = widget.tracks
                .where((t) => _selectedIds.contains(t.id))
                .toList();
            Navigator.pop(context, selected);
          },
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _QualityPickerDialog extends StatelessWidget {
  const _QualityPickerDialog({required this.qualityProfiles});

  final List<QualityProfileResource> qualityProfiles;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Select Quality Profile'),
      content: SizedBox(
        width: double.maxFinite,
        height: 320,
        child: qualityProfiles.isEmpty
            ? const Center(child: Text('No quality profiles available.'))
            : ListView.builder(
                itemCount: qualityProfiles.length,
                itemBuilder: (BuildContext context, int index) {
                  final QualityProfileResource p = qualityProfiles[index];
                  return ListTile(
                    leading: const Icon(Icons.tune_outlined),
                    title: Text(p.name ?? 'Quality Profile'),
                    onTap: () {
                      final QualityModel q = QualityModel(
                        quality: Quality(id: p.id, name: p.name),
                        revision: const Revision(
                          version: 1,
                          real: 0,
                          isRepack: false,
                        ),
                      );
                      Navigator.pop(context, q);
                    },
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
