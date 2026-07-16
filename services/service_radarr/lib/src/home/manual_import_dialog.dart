import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/radarr_movie.dart';
import '../radarr_providers.dart';

/// Starts the Radarr Manual Import user flow.
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
        ref.read(radarrManualImportPathProvider(widget.instance));
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
      ref.read(radarrManualImportPathProvider(widget.instance).notifier).state =
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
                    const Text('Scanning files...'),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        cancelToken.cancel('User cancelled scan');
                        nav.pop();
                      },
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    List<dynamic> scanResults;
    try {
      final api = await ref.read(radarrApiProvider(widget.instance).future);
      final bool filterExisting =
          ref.read(radarrManualImportFilterProvider(widget.instance));
      scanResults = await api.getManualImport(
        folder: folder,
        filterExistingFiles: filterExisting,
        cancelToken: cancelToken,
      );
      nav.pop(); // Pop loading dialog
    } catch (e) {
      nav.pop(); // Pop loading dialog
      if (mounted && e is! NetworkCancelledException) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e')),
        );
      }
      return;
    }

    if (!mounted) return;

    if (scanResults.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('No Files Found'),
          content: Text(
            'No videos were found in "$folder" that are eligible for import.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Dismiss the setup dialog and open the mapping screen on the root
    // navigator (captured before the pop) so the full-screen route survives
    // shell rebuilds and does not depend on the just-popped dialog's context.
    nav.pop();

    unawaited(
      nav.push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => _ManualImportMappingScreen(
            instance: widget.instance,
            folderPath: folder,
            initialFiles: scanResults,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(radarrManualImportModeProvider(widget.instance));
    final filterExisting =
        ref.watch(radarrManualImportFilterProvider(widget.instance));

    return AlertDialog(
      title: const Text('Manual Import'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _pathController,
                    decoration: const InputDecoration(
                      labelText: 'Folder Path',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (String val) {
                      ref
                          .read(
                            radarrManualImportPathProvider(widget.instance)
                                .notifier,
                          )
                          .state = val;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _browseFolder,
                  icon: const Icon(Icons.folder_open),
                  tooltip: 'Browse server folders',
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
                      .read(
                        radarrManualImportModeProvider(widget.instance)
                            .notifier,
                      )
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
                    .read(
                      radarrManualImportFilterProvider(widget.instance)
                          .notifier,
                    )
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
      final api = await ref.read(radarrApiProvider(widget.instance).future);
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

    final isWindows = _currentPath.contains('\\');
    final separator = isWindows ? '\\' : '/';

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
    required this.folderPath,
    required this.initialFiles,
  });

  final Instance instance;
  final String folderPath;
  final List<dynamic> initialFiles;

  @override
  ConsumerState<_ManualImportMappingScreen> createState() =>
      __ManualImportMappingScreenState();
}

class __ManualImportMappingScreenState
    extends ConsumerState<_ManualImportMappingScreen> {
  late final List<dynamic> _files;
  final Set<String> _selectedPaths = <String>{};
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _files = List<dynamic>.from(widget.initialFiles);
    for (final dynamic f in _files) {
      final Map<String, dynamic> item = f as Map<String, dynamic>;
      final String path = item['path'] as String;
      final movie = item['movie'] as Map<String, dynamic>?;
      final rejections = item['rejections'] as List<dynamic>?;
      if (movie != null && (rejections == null || rejections.isEmpty)) {
        _selectedPaths.add(path);
      }
    }
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    var doubleBytes = bytes.toDouble();
    while (doubleBytes >= 1024 && i < suffixes.length - 1) {
      doubleBytes /= 1024;
      i++;
    }
    return '${doubleBytes.toStringAsFixed(1)} ${suffixes[i]}';
  }

  Future<void> _selectMovieForFile(int index) async {
    final f = _files[index] as Map<String, dynamic>;

    final NavigatorState nav = Navigator.of(context, rootNavigator: true);
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) => const PopScope<Object?>(
          canPop: false,
          child: Center(
            child: Card(
              margin: EdgeInsets.symmetric(horizontal: 32),
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ExpressiveProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading library movies...'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    try {
      final api = await ref.read(radarrApiProvider(widget.instance).future);
      final List<RadarrMovie> movies = await api.getMovies();
      nav.pop(); // Pop loading dialog

      if (!mounted) return;

      final RadarrMovie? selected = await showDialog<RadarrMovie>(
        context: context,
        builder: (BuildContext context) => _MoviePickerDialog(
          moviesList: movies,
        ),
      );

      if (selected != null) {
        setState(() {
          f['movie'] = <String, dynamic>{
            'id': selected.id,
            'title': selected.title,
          };
          _selectedPaths.add(f['path'] as String);
        });
      }
    } catch (e) {
      nav.pop(); // Pop loading dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load movies: $e')),
        );
      }
    }
  }

  Future<void> _executeImport() async {
    if (_selectedPaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one file to import.'),
        ),
      );
      return;
    }

    setState(() {
      _importing = true;
    });

    try {
      final api = await ref.read(radarrApiProvider(widget.instance).future);
      final mode = ref.read(radarrManualImportModeProvider(widget.instance));
      final List<Map<String, dynamic>> payload = <Map<String, dynamic>>[];

      for (final String path in _selectedPaths) {
        final f = _files
                .firstWhere((x) => (x as Map<String, dynamic>)['path'] == path)
            as Map<String, dynamic>;
        final movie = f['movie'] as Map<String, dynamic>?;

        if (movie == null) continue;

        payload.add(<String, dynamic>{
          'path': path,
          'movieId': movie['id'],
          'quality': f['quality'],
          'languages': f['languages'],
          'releaseGroup': f['releaseGroup'],
          'downloadId': f['downloadId'],
          'indexerFlags': f['indexerFlags'] ?? 0,
        });
      }

      await api.executeManualImport(files: payload, importMode: mode);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Manual import instruction submitted.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _importing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual Import Mappings'),
      ),
      body: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(12),
            color: theme.colorScheme.surfaceContainerHigh,
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
                      final movie = f['movie'] as Map<String, dynamic>?;
                      final List<dynamic>? rejections =
                          f['rejections'] as List<dynamic>?;
                      final bool isSelected = _selectedPaths.contains(pathStr);

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
                              Row(
                                children: <Widget>[
                                  Checkbox(
                                    value: isSelected,
                                    onChanged: movie == null
                                        ? null
                                        : (bool? val) {
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
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: <Widget>[
                                  ActionChip(
                                    avatar: const Icon(
                                      Icons.movie_outlined,
                                      size: 14,
                                    ),
                                    label: Text(
                                      movie != null
                                          ? (movie['title'] as String)
                                          : 'Select Movie',
                                    ),
                                    backgroundColor: movie == null
                                        ? theme.colorScheme.errorContainer
                                            .withValues(alpha: 0.3)
                                        : null,
                                    onPressed: () => _selectMovieForFile(index),
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

class _MoviePickerDialog extends StatefulWidget {
  const _MoviePickerDialog({required this.moviesList});

  final List<RadarrMovie> moviesList;

  @override
  State<_MoviePickerDialog> createState() => _MoviePickerDialogState();
}

class _MoviePickerDialogState extends State<_MoviePickerDialog> {
  late final TextEditingController _filterController;
  List<RadarrMovie> _filtered = <RadarrMovie>[];

  @override
  void initState() {
    super.initState();
    _filterController = TextEditingController();
    _filtered = widget.moviesList;
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  void _onFilterChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = widget.moviesList;
      } else {
        final String q = query.toLowerCase();
        _filtered = widget.moviesList
            .where((m) => m.title.toLowerCase().contains(q))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Movie'),
      content: SizedBox(
        width: double.maxFinite,
        height: 350,
        child: Column(
          children: <Widget>[
            TextField(
              controller: _filterController,
              decoration: const InputDecoration(
                hintText: 'Search movies...',
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
                  final RadarrMovie m = _filtered[index];
                  return ListTile(
                    title: Text(m.title),
                    subtitle:
                        Text('${m.studio ?? 'Unknown'} • ${m.year ?? ''}'),
                    onTap: () {
                      Navigator.pop(context, m);
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
