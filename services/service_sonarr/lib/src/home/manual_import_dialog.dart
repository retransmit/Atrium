import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/sonarr_episode.dart';
import '../models/sonarr_series.dart';
import '../sonarr_providers.dart';

/// Starts the Sonarr Manual Import user flow.
void showManualImportFlow(
  BuildContext context,
  WidgetRef ref,
  Instance instance,
) {
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => _ManualImportSetupDialog(
        instance: instance,
      ),
    ),
  );
}

class _ManualImportSetupDialog extends ConsumerStatefulWidget {
  const _ManualImportSetupDialog({required this.instance});

  final Instance instance;

  @override
  ConsumerState<_ManualImportSetupDialog> createState() =>
      __ManualImportSetupDialogState();
}

class __ManualImportSetupDialogState
    extends ConsumerState<_ManualImportSetupDialog> {
  late final TextEditingController _pathController;

  @override
  void initState() {
    super.initState();
    final String initialPath =
        ref.read(sonarrManualImportPathProvider(widget.instance));
    _pathController = TextEditingController(text: initialPath);
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
      ref.read(sonarrManualImportPathProvider(widget.instance).notifier).state =
          selectedPath;
    }
  }

  Future<void> _startScan() async {
    final String folder = _pathController.text.trim();
    if (folder.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or enter a folder path.')),
      );
      return;
    }

    final CancelToken cancelToken = CancelToken();

    // Show loading overlay
    final NavigatorState nav = Navigator.of(context, rootNavigator: true);
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) => PopScope<Object?>(
          canPop: false,
          child: Center(
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const ExpressiveProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text('Scanning folder contents...'),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        TextButton(
                          onPressed: () async {
                            final bool? confirm = await showDialog<bool>(
                              context: dialogContext,
                              builder: (BuildContext confirmContext) =>
                                  AlertDialog(
                                title: const Text('Cancel Scan?'),
                                content: const Text(
                                  'Are you sure you want to stop scanning this folder?',
                                ),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(confirmContext, false),
                                    child: const Text('No'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(confirmContext, true),
                                    child: const Text('Yes, Cancel'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              cancelToken.cancel('user_cancelled');
                            }
                          },
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Object? error;
    List<dynamic> scanResults = const <dynamic>[];
    try {
      final api = await ref.read(sonarrApiProvider(widget.instance).future);
      final bool filterExisting =
          ref.read(sonarrManualImportFilterProvider(widget.instance));
      scanResults = await api.getManualImport(
        folder: folder,
        filterExistingFiles: filterExisting,
        cancelToken: cancelToken,
      );
    } catch (e) {
      error = e;
    } finally {
      if (nav.mounted) nav.pop(); // Pop the loading dialog
    }

    if (!mounted) return;
    if (error != null) {
      if (error is NetworkCancelledException) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scan cancelled.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $error')),
        );
      }
      return;
    }

    if (scanResults.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No importable files found in the folder.'),
        ),
      );
      return;
    }

    // Close setup dialog and open mapping screen
    Navigator.pop(context);
    unawaited(
      nav.push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => _ManualImportMappingScreen(
            instance: widget.instance,
            initialFiles: scanResults,
            folderPath: folder,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String mode =
        ref.watch(sonarrManualImportModeProvider(widget.instance));
    final bool filterExisting =
        ref.watch(sonarrManualImportFilterProvider(widget.instance));

    return AlertDialog(
      title: const Row(
        children: <Widget>[
          Icon(Icons.folder_open, size: 28),
          SizedBox(width: 12),
          Text('Manual Import'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Select a directory on the Sonarr host to scan for video files to import into your library.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _pathController,
                    decoration: const InputDecoration(
                      labelText: 'Folder Path',
                      hintText: 'e.g. /data/torrents/name',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (String val) {
                      ref
                          .read(sonarrManualImportPathProvider(widget.instance)
                              .notifier,)
                          .state = val;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  icon: const Icon(Icons.folder),
                  onPressed: _browseFolder,
                  tooltip: 'Browse Folder',
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: mode,
              decoration: const InputDecoration(
                labelText: 'Import Mode',
                border: OutlineInputBorder(),
              ),
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: 'Move',
                  child: Text('Move (recommended)'),
                ),
                DropdownMenuItem<String>(
                  value: 'Copy',
                  child: Text('Copy'),
                ),
              ],
              onChanged: (String? val) {
                if (val != null) {
                  ref
                      .read(sonarrManualImportModeProvider(widget.instance)
                          .notifier,)
                      .state = val;
                }
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Filter Existing Files'),
              subtitle: const Text('Do not show files already in the library'),
              value: filterExisting,
              onChanged: (bool val) {
                ref
                    .read(sonarrManualImportFilterProvider(widget.instance)
                        .notifier,)
                    .state = val;
              },
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
          onPressed: _startScan,
          child: const Text('Interactive Import'),
        ),
      ],
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
  List<dynamic> _directories = <dynamic>[];
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
      final api = await ref.read(sonarrApiProvider(widget.instance).future);
      final List<dynamic> result = await api.getFileSystem(
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

    // Handle slash type
    final isWindows = _currentPath.contains('\\');
    final separator = isWindows ? '\\' : '/';

    // Remove trailing slash if present
    String path = _currentPath;
    if (path.endsWith(separator)) {
      path = path.substring(0, path.length - 1);
    }

    final index = path.lastIndexOf(separator);
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

    // Build breadcrumbs
    final isWindows = _currentPath.contains('\\');
    final separator = isWindows ? '\\' : '/';
    final List<String> segments =
        _currentPath.split(separator).where((s) => s.isNotEmpty).toList();

    return AlertDialog(
      title: const Text('Browse Folder'),
      content: SizedBox(
        width: double.maxFinite,
        height: 450,
        child: Column(
          children: <Widget>[
            // Breadcrumbs Bar
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    IconButton(
                      icon: const Icon(Icons.computer, size: 18),
                      onPressed: () {
                        _navigateTo('');
                      },
                      tooltip: 'Root / Drives',
                    ),
                    if (segments.isNotEmpty && !isWindows)
                      Text('/', style: theme.textTheme.bodyMedium),
                    for (int i = 0; i < segments.length; i++) ...<Widget>[
                      if (i > 0)
                        Text(separator, style: theme.textTheme.bodyMedium),
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          final List<String> subSegments =
                              segments.sublist(0, i + 1);
                          final String target = isWindows
                              ? subSegments.join('\\')
                              : '/${subSegments.join('/')}';
                          _navigateTo(target);
                        },
                        child: Text(segments[i]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Current path text input for manual overrides
            TextField(
              decoration: const InputDecoration(
                labelText: 'Selected Path',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: _currentPath)
                ..selection = TextSelection.fromPosition(
                  TextPosition(offset: _currentPath.length),
                ),
              onSubmitted: (String val) {
                _navigateTo(val.trim());
              },
            ),
            const SizedBox(height: 12),
            // Directories List
            Expanded(
              child: _loading
                  ? const Center(child: ExpressiveProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.error_outline,
                                color: theme.colorScheme.error,
                                size: 40,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Error: $_error',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.tonal(
                                onPressed: _loadDirectoryContents,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _directories.isEmpty
                          ? const Center(child: Text('No directories found.'))
                          : ListView.builder(
                              itemCount: _directories.length +
                                  (segments.isNotEmpty ? 1 : 0),
                              itemBuilder: (BuildContext context, int index) {
                                if (segments.isNotEmpty && index == 0) {
                                  return ListTile(
                                    leading: const Icon(Icons.arrow_upward),
                                    title: const Text('.. (Parent Folder)'),
                                    onTap: _navigateBack,
                                  );
                                }

                                final int dataIndex =
                                    segments.isNotEmpty ? index - 1 : index;
                                final dir = _directories[dataIndex]
                                    as Map<String, dynamic>;
                                final String name =
                                    (dir['name'] as String?) ?? 'Unknown';
                                final String fullPath =
                                    (dir['path'] as String?) ?? '';

                                return ListTile(
                                  leading: const Icon(Icons.folder),
                                  title: Text(name),
                                  trailing:
                                      const Icon(Icons.chevron_right, size: 16),
                                  onTap: () {
                                    _navigateTo(fullPath);
                                  },
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
          onPressed:
              _loading ? null : () => Navigator.pop(context, _currentPath),
          child: const Text('Select Folder'),
        ),
      ],
    );
  }
}

class _ManualImportMappingScreen extends ConsumerStatefulWidget {
  const _ManualImportMappingScreen({
    required this.instance,
    required this.initialFiles,
    required this.folderPath,
  });

  final Instance instance;
  final List<dynamic> initialFiles;
  final String folderPath;

  @override
  ConsumerState<_ManualImportMappingScreen> createState() =>
      __ManualImportMappingScreenState();
}

class __ManualImportMappingScreenState
    extends ConsumerState<_ManualImportMappingScreen> {
  late List<dynamic> _files;
  final Set<String> _selectedPaths = <String>{};
  bool _importing = false;

  bool _isVideoFile(Map<String, dynamic> f) {
    final String? path = (f['path'] as String?)?.toLowerCase();
    if (path == null) return false;

    // TypeScript definition files are never videos
    if (path.endsWith('.d.ts')) return false;

    // Standard video extensions supported by Sonarr / Radarr / typical players
    const Set<String> videoExtensions = <String>{
      '.mkv',
      '.mp4',
      '.avi',
      '.m4v',
      '.mov',
      '.wmv',
      '.mpg',
      '.mpeg',
      '.flv',
      '.webm',
      '.ts',
    };

    final bool hasVideoExtension = videoExtensions.any(path.endsWith);
    if (!hasVideoExtension) return false;

    // If it's a .ts file, ensure it's not a tiny TypeScript file.
    // Real video .ts files are typically at least 1MB (1,048,576 bytes).
    if (path.endsWith('.ts')) {
      final int size = (f['size'] as num?)?.toInt() ?? 0;
      if (size < 1024 * 1024) {
        return false;
      }
    }

    return true;
  }

  @override
  void initState() {
    super.initState();
    // Copy the items locally so they are mutable, filtering out non-video files
    final List<Map<String, dynamic>> rawFiles = List<Map<String, dynamic>>.from(
      widget.initialFiles
          .map((dynamic f) => Map<String, dynamic>.from(f as Map)),
    );
    _files = rawFiles.where(_isVideoFile).toList();

    // Auto-select items that are parsed successfully and have no rejections
    for (final f in _files.cast<Map<String, dynamic>>()) {
      final String? path = f['path'] as String?;
      final List<dynamic>? rejections = f['rejections'] as List<dynamic>?;
      final dynamic series = f['series'];
      final List<dynamic>? episodes = f['episodes'] as List<dynamic>?;

      if (path != null &&
          (rejections == null || rejections.isEmpty) &&
          series != null &&
          episodes != null &&
          episodes.isNotEmpty) {
        _selectedPaths.add(path);
      }
    }
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const List<String> suffixes = <String>['B', 'KB', 'MB', 'GB', 'TB'];
    int i = 0;
    double dBytes = bytes.toDouble();
    while (dBytes >= 1024 && i < suffixes.length - 1) {
      dBytes /= 1024;
      i++;
    }
    return '${dBytes.toStringAsFixed(1)} ${suffixes[i]}';
  }

  /// Season numbers of the mapped series (including 0 for Specials). The
  /// series map either comes from the scan payload (season entries are JSON
  /// maps) or from the series picker (entries are [SonarrSeason] objects).
  List<int> _seasonNumbersFor(Map<String, dynamic> series) {
    final dynamic rawSeasons = series['seasons'];
    final List<int> numbers = <int>[];
    if (rawSeasons is List<dynamic>) {
      for (final dynamic s in rawSeasons) {
        if (s is SonarrSeason) {
          numbers.add(s.seasonNumber);
        } else if (s is Map<String, dynamic>) {
          final dynamic n = s['seasonNumber'];
          if (n is int) numbers.add(n);
        }
      }
    }
    numbers.sort();
    if (numbers.isEmpty) {
      // Fallback when the series payload carries no season list.
      return List<int>.generate(20, (int i) => i + 1);
    }
    return numbers;
  }

  Future<void> _selectSeriesForFile(int index) async {
    final List<SonarrSeries> seriesList = await ref.read(
      sonarrSeriesProvider(widget.instance).future,
    );

    if (!mounted) return;

    final SonarrSeries? selected = await showDialog<SonarrSeries>(
      context: context,
      builder: (BuildContext context) => _SeriesPickerDialog(
        seriesList: seriesList,
      ),
    );

    if (selected != null) {
      setState(() {
        final Map<String, dynamic> f = _files[index] as Map<String, dynamic>;
        f['series'] = selected.toJson();
        f['seasonNumber'] = 1; // reset mapping
        f['episodes'] = <dynamic>[];
        f['rejections'] = <dynamic>[]; // Clear match rejections
      });
    }
  }

  Future<void> _selectEpisodesForFile(int index) async {
    final Map<String, dynamic> f = _files[index] as Map<String, dynamic>;
    final series = f['series'] as Map<String, dynamic>?;
    if (series == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Series first.')),
      );
      return;
    }

    final int seriesId = series['id'] as int;
    final int seasonNumber = f['seasonNumber'] as int? ?? 1;

    // Show loading spinner
    final NavigatorState nav = Navigator.of(context, rootNavigator: true);
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => const PopScope<Object?>(
          canPop: false,
          child: Center(child: ExpressiveProgressIndicator()),
        ),
      ),
    );

    Object? error;
    List<SonarrEpisode> allEpisodes = const <SonarrEpisode>[];
    try {
      allEpisodes = await ref.read(
        sonarrEpisodesProvider((widget.instance, seriesId)).future,
      );
    } catch (e) {
      error = e;
    } finally {
      if (nav.mounted) nav.pop(); // Pop the loading spinner
    }

    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load episodes: $error')),
      );
      return;
    }

    final List<SonarrEpisode> seasonEpisodes =
        allEpisodes.where((e) => e.seasonNumber == seasonNumber).toList();

    if (seasonEpisodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No episodes found for Season $seasonNumber.')),
      );
      return;
    }

    final List<dynamic>? currentMapped = f['episodes'] as List<dynamic>?;
    final Set<int> currentMappedIds = currentMapped
            ?.cast<Map<String, dynamic>>()
            .map((e) => e['id'] as int)
            .toSet() ??
        <int>{};

    final List<SonarrEpisode>? selected = await showDialog<List<SonarrEpisode>>(
      context: context,
      builder: (BuildContext context) => _EpisodePickerDialog(
        episodes: seasonEpisodes,
        initialSelectedIds: currentMappedIds,
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        f['episodes'] = selected.map((e) => e.toJson()).toList();
        f['rejections'] = <dynamic>[]; // Clear rejections
        final String? path = f['path'] as String?;
        if (path != null && selected.isNotEmpty) {
          _selectedPaths.add(path);
        }
      });
    }
  }

  Future<void> _executeImport() async {
    final List<Map<String, dynamic>> importList =
        _files.cast<Map<String, dynamic>>().where((f) {
      final String? path = f['path'] as String?;
      final dynamic series = f['series'];
      final List<dynamic>? episodes = f['episodes'] as List<dynamic>?;

      return path != null &&
          _selectedPaths.contains(path) &&
          series != null &&
          episodes != null &&
          episodes.isNotEmpty;
    }).toList();

    if (importList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid mapped files selected for import.'),
        ),
      );
      return;
    }

    setState(() => _importing = true);

    try {
      final api = await ref.read(sonarrApiProvider(widget.instance).future);
      final mode = ref.read(sonarrManualImportModeProvider(widget.instance));

      final List<Map<String, dynamic>> payload = importList.map((f) {
        final List<dynamic> eps = f['episodes'] as List<dynamic>;
        final List<int> epIds = eps
            .cast<Map<String, dynamic>>()
            .map((e) => e['id'] as int)
            .toList();
        final series = f['series'] as Map<String, dynamic>;

        return <String, dynamic>{
          'path': f['path'],
          'seriesId': series['id'],
          'seasonNumber': f['seasonNumber'],
          'episodeIds': epIds,
          'quality': f['quality'],
          'languages': f['languages'],
          'releaseGroup': f['releaseGroup'],
          'downloadId': f['downloadId'],
        };
      }).toList();

      await api.executeManualImport(files: payload, importMode: mode);

      // Invalidate Wanted providers so the lists reload
      ref.invalidate(sonarrWantedMissingProvider(widget.instance));
      ref.invalidate(sonarrWantedCutoffProvider(widget.instance));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Import command triggered for ${importList.length} files.',),),
        );
        Navigator.pop(context); // Close the mapping screen
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Interactive Import'),
        actions: <Widget>[
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onPrimaryContainer,
            ),
            icon: const Icon(Icons.select_all),
            label: const Text('Select All'),
            onPressed: () {
              setState(() {
                for (final f in _files.cast<Map<String, dynamic>>()) {
                  final String? p = f['path'] as String?;
                  if (p != null) _selectedPaths.add(p);
                }
              });
            },
          ),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onPrimaryContainer,
            ),
            icon: const Icon(Icons.deselect),
            label: const Text('None'),
            onPressed: () {
              setState(_selectedPaths.clear);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: <Widget>[
          // Header info banner
          Container(
            padding: const EdgeInsets.all(12),
            width: double.infinity,
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.info_outline,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Folder: ${widget.folderPath}\nScanned ${_files.length} files. Review and adjust mappings before executing import.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _importing
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        ExpressiveProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Sending manual import instruction...'),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _files.length,
                    itemBuilder: (BuildContext context, int index) {
                      final f = _files[index] as Map<String, dynamic>;
                      final String pathStr = (f['path'] as String?) ?? '';
                      final String relativePath =
                          (f['relativePath'] as String?) ?? pathStr;
                      final int bytes = (f['size'] as int?) ?? 0;
                      final series = f['series'] as Map<String, dynamic>?;
                      final int? season = f['seasonNumber'] as int?;
                      final List<dynamic>? episodes =
                          f['episodes'] as List<dynamic>?;
                      final List<dynamic>? rejections =
                          f['rejections'] as List<dynamic>?;
                      final bool isSelected = _selectedPaths.contains(pathStr);

                      // Parse quality
                      String qName = 'Unknown Quality';
                      final qObj = f['quality'] as Map<String, dynamic>?;
                      if (qObj != null && qObj['quality'] != null) {
                        final innerQ = qObj['quality'] as Map<String, dynamic>;
                        qName = (innerQ['name'] as String?) ?? qName;
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        clipBehavior: Clip.antiAlias,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outlineVariant
                                    .withValues(alpha: 0.5),
                            width: isSelected ? 2.0 : 1.0,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              // File selection row
                              Row(
                                children: <Widget>[
                                  Checkbox(
                                    value: isSelected,
                                    onChanged: (bool? val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedPaths.add(pathStr);
                                        } else {
                                          _selectedPaths.remove(pathStr);
                                        }
                                      });
                                    },
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          relativePath,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${_formatSize(bytes)} • $qName',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 16),
                              // Rejection notes if any
                              if (rejections != null &&
                                  rejections.isNotEmpty) ...<Widget>[
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.errorContainer
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: theme.colorScheme.error
                                          .withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      Icon(
                                        Icons.warning_amber_rounded,
                                        color: theme.colorScheme.error,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          rejections
                                              .cast<Map<String, dynamic>>()
                                              .map((r) => r['reason'] as String)
                                              .join(', '),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme
                                                .colorScheme.onErrorContainer,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              // Mapping adjust row
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: <Widget>[
                                  // Series field
                                  ActionChip(
                                    avatar: const Icon(Icons.tv, size: 14),
                                    label: Text(
                                      series != null
                                          ? (series['title'] as String)
                                          : 'Select Series',
                                    ),
                                    backgroundColor: series == null
                                        ? theme.colorScheme.errorContainer
                                            .withValues(alpha: 0.3)
                                        : null,
                                    onPressed: () =>
                                        _selectSeriesForFile(index),
                                  ),
                                  // Season number dropdown
                                  if (series != null)
                                    ActionChip(
                                      avatar: const Icon(
                                          Icons.calendar_view_day,
                                          size: 14,),
                                      label: Text(
                                        season != null
                                            ? 'Season $season'
                                            : 'Season ?',
                                      ),
                                      onPressed: () async {
                                        final int? nextSeason =
                                            await showDialog<int>(
                                          context: context,
                                          builder: (BuildContext context) =>
                                              _SeasonPickerDialog(
                                            seasonNumbers:
                                                _seasonNumbersFor(series),
                                            initialSeason: season ?? 1,
                                          ),
                                        );
                                        if (nextSeason != null) {
                                          setState(() {
                                            f['seasonNumber'] = nextSeason;
                                            f['episodes'] =
                                                <dynamic>[]; // Reset mapped ep
                                          });
                                        }
                                      },
                                    ),
                                  // Episodes list
                                  if (series != null)
                                    ActionChip(
                                      avatar:
                                          const Icon(Icons.numbers, size: 14),
                                      label: Text(
                                        episodes != null && episodes.isNotEmpty
                                            ? 'Episode ${episodes.cast<Map<String, dynamic>>().map((e) => e['episodeNumber'].toString()).join(', ')}'
                                            : 'Select Episode(s)',
                                      ),
                                      backgroundColor:
                                          episodes == null || episodes.isEmpty
                                              ? theme.colorScheme.errorContainer
                                                  .withValues(alpha: 0.3)
                                              : null,
                                      onPressed: () =>
                                          _selectEpisodesForFile(index),
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
          // Action footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              border: Border(
                top: BorderSide(
                  color:
                      theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: Row(
              children: <Widget>[
                Text(
                  '${_selectedPaths.length} of ${_files.length} selected',
                  style: theme.textTheme.bodyMedium,
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _importing ? null : _executeImport,
                  icon: const Icon(Icons.download),
                  label: const Text('Import Selected'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeriesPickerDialog extends StatefulWidget {
  const _SeriesPickerDialog({required this.seriesList});

  final List<SonarrSeries> seriesList;

  @override
  State<_SeriesPickerDialog> createState() => _SeriesPickerDialogState();
}

class _SeriesPickerDialogState extends State<_SeriesPickerDialog> {
  late final TextEditingController _filterController;
  List<SonarrSeries> _filtered = <SonarrSeries>[];

  @override
  void initState() {
    super.initState();
    _filterController = TextEditingController();
    _filtered = widget.seriesList;
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  void _onFilterChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = widget.seriesList;
      } else {
        final String q = query.toLowerCase();
        _filtered = widget.seriesList
            .where((s) => s.title.toLowerCase().contains(q))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Series'),
      content: SizedBox(
        width: double.maxFinite,
        height: 350,
        child: Column(
          children: <Widget>[
            TextField(
              controller: _filterController,
              decoration: const InputDecoration(
                hintText: 'Search series...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: _onFilterChanged,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _filtered.length,
                itemBuilder: (BuildContext context, int index) {
                  final SonarrSeries s = _filtered[index];
                  return ListTile(
                    title: Text(s.title),
                    subtitle:
                        Text('${s.network ?? 'Unknown'} • ${s.year ?? ''}'),
                    onTap: () {
                      Navigator.pop(context, s);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeasonPickerDialog extends StatelessWidget {
  const _SeasonPickerDialog({
    required this.seasonNumbers,
    required this.initialSeason,
  });

  final List<int> seasonNumbers;
  final int initialSeason;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Season'),
      content: SizedBox(
        width: 150,
        height: 250,
        child: ListView.builder(
          itemCount: seasonNumbers.length,
          itemBuilder: (BuildContext context, int index) {
            final int seasonNum = seasonNumbers[index];
            return ListTile(
              title: Text(seasonNum == 0 ? 'Specials' : 'Season $seasonNum'),
              selected: seasonNum == initialSeason,
              onTap: () {
                Navigator.pop(context, seasonNum);
              },
            );
          },
        ),
      ),
    );
  }
}

class _EpisodePickerDialog extends StatefulWidget {
  const _EpisodePickerDialog({
    required this.episodes,
    required this.initialSelectedIds,
  });

  final List<SonarrEpisode> episodes;
  final Set<int> initialSelectedIds;

  @override
  State<_EpisodePickerDialog> createState() => _EpisodePickerDialogState();
}

class _EpisodePickerDialogState extends State<_EpisodePickerDialog> {
  final Set<int> _selectedIds = <int>{};

  @override
  void initState() {
    super.initState();
    _selectedIds.addAll(widget.initialSelectedIds);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Episode(s)'),
      content: SizedBox(
        width: double.maxFinite,
        height: 350,
        child: ListView.builder(
          itemCount: widget.episodes.length,
          itemBuilder: (BuildContext context, int index) {
            final SonarrEpisode ep = widget.episodes[index];
            final bool isChecked = _selectedIds.contains(ep.id);

            return CheckboxListTile(
              title: Text('Ep ${ep.episodeNumber}: ${ep.title}'),
              value: isChecked,
              onChanged: (bool? val) {
                setState(() {
                  if (val == true) {
                    _selectedIds.add(ep.id);
                  } else {
                    _selectedIds.remove(ep.id);
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
            // Find all matching SonarrEpisode structures
            final List<SonarrEpisode> mapped = widget.episodes
                .where((e) => _selectedIds.contains(e.id))
                .toList();
            Navigator.pop(context, mapped);
          },
          child: const Text('Done'),
        ),
      ],
    );
  }
}
