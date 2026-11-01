import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/slskd_system_models.dart';
import '../slskd_api.dart';
import '../slskd_format.dart';
import '../slskd_providers.dart';

/// Modal bottom sheet allowing inspection and management of on-disk download and incomplete files.
class SlskdDiskFilesSheet extends ConsumerStatefulWidget {
  const SlskdDiskFilesSheet({
    required this.instance,
    this.initialSegment = 0,
    super.key,
  });

  final Instance instance;
  final int initialSegment; // 0 = Downloads, 1 = Incomplete

  static Future<void> show(
    BuildContext context, {
    required Instance instance,
    int initialSegment = 0,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SlskdDiskFilesSheet(
        instance: instance,
        initialSegment: initialSegment,
      ),
    );
  }

  @override
  ConsumerState<SlskdDiskFilesSheet> createState() =>
      _SlskdDiskFilesSheetState();
}

class _SlskdDiskFilesSheetState extends ConsumerState<SlskdDiskFilesSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final List<String> _pathSegments = [];
  bool _isActionInProgress = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialSegment.clamp(0, 1).toInt(),
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(_pathSegments.clear);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int get _selectedSegment => _tabController.index;

  String? get _currentSubdirectory =>
      _pathSegments.isEmpty ? null : _pathSegments.join('/');

  void _navigateToFolder(String folderName) {
    setState(() => _pathSegments.add(folderName));
  }

  void _navigateBack() {
    if (_pathSegments.isNotEmpty) {
      setState(_pathSegments.removeLast);
    }
  }

  void _navigateToIndex(int index) {
    setState(() => _pathSegments.removeRange(index + 1, _pathSegments.length));
  }

  Future<void> _deleteFile(SlskdDiskFile file) async {
    final messenger = ScaffoldMessenger.of(context);
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete File?'),
            content: Text(
              'Are you sure you want to delete "${file.name}" from host storage? This cannot be undone.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                  foregroundColor: Theme.of(ctx).colorScheme.onError,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;

    setState(() => _isActionInProgress = true);
    try {
      final SlskdApi api =
          await ref.read(slskdApiProvider(widget.instance).future);
      final String relativeFilePath = _pathSegments.isEmpty
          ? file.name
          : '${_pathSegments.join('/')}/${file.name}';

      if (_selectedSegment == 0) {
        await api.deleteDownloadFile(relativeFilePath);
      } else {
        await api.deleteIncompleteFile(relativeFilePath);
      }

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Deleted "${file.name}"'),
          duration: const Duration(seconds: 2),
        ),
      );
      _refreshDirectory();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Failed to delete file: $e',
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  Future<void> _deleteDirectory(SlskdDiskDirectory dir) async {
    final messenger = ScaffoldMessenger.of(context);
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Folder?'),
            content: Text(
              'Are you sure you want to permanently delete folder "${dir.name}" and all its contents?',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                  foregroundColor: Theme.of(ctx).colorScheme.onError,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete Folder'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;

    setState(() => _isActionInProgress = true);
    try {
      final SlskdApi api =
          await ref.read(slskdApiProvider(widget.instance).future);
      final String relativeDirPath = _pathSegments.isEmpty
          ? dir.name
          : '${_pathSegments.join('/')}/${dir.name}';

      if (_selectedSegment == 0) {
        await api.deleteDownloadDirectory(relativeDirPath);
      } else {
        await api.deleteIncompleteDirectory(relativeDirPath);
      }

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Deleted folder "${dir.name}"'),
          duration: const Duration(seconds: 2),
        ),
      );
      _refreshDirectory();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Failed to delete folder: $e',
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
    }
  }

  void _refreshDirectory() {
    if (_selectedSegment == 0) {
      ref.invalidate(
        slskdDownloadsDirectoryProvider((widget.instance, _currentSubdirectory)),
      );
    } else {
      ref.invalidate(
        slskdIncompleteDirectoryProvider((widget.instance, _currentSubdirectory)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final AsyncValue<SlskdDiskDirectory?> directoryAsync = _selectedSegment == 0
        ? ref.watch(
            slskdDownloadsDirectoryProvider((widget.instance, _currentSubdirectory)),
          )
        : ref.watch(
            slskdIncompleteDirectoryProvider((widget.instance, _currentSubdirectory)),
          );

    return PopScope(
      canPop: _pathSegments.isEmpty,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          _navigateBack();
        }
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
        return Material(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Sheet Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: Insets.sm),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.md),
                child: Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(Insets.xs),
                      decoration: BoxDecoration(
                        color: _selectedSegment == 0
                            ? colorScheme.primaryContainer
                            : colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _selectedSegment == 0
                            ? Icons.download_done_rounded
                            : Icons.pending_actions_rounded,
                        color: _selectedSegment == 0
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onTertiaryContainer,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Host Storage Explorer',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _selectedSegment == 0
                                ? 'Finished Downloads Folder'
                                : 'Incomplete Downloads Folder',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Refresh',
                      onPressed: _isActionInProgress ? null : _refreshDirectory,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: Insets.xs),

              // Normal TabBar
              TabBar(
                controller: _tabController,
                dividerColor: colorScheme.outlineVariant.withValues(alpha: 0.3),
                indicatorColor: colorScheme.primary,
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: colorScheme.primary,
                unselectedLabelColor: colorScheme.onSurfaceVariant,
                labelStyle: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: textTheme.titleSmall,
                tabs: const <Widget>[
                  Tab(text: 'Downloads'),
                  Tab(text: 'Incomplete'),
                ],
              ),

              const SizedBox(height: Insets.xs),

              // Breadcrumbs
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: Insets.md),
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      ActionChip(
                        avatar: const Icon(Icons.home_rounded, size: 16),
                        label: Text(_selectedSegment == 0 ? 'Downloads' : 'Incomplete'),
                        visualDensity: VisualDensity.compact,
                        onPressed: _pathSegments.isEmpty
                            ? null
                            : () => setState(_pathSegments.clear),
                      ),
                      for (int i = 0; i < _pathSegments.length; i++) ...<Widget>[
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        ActionChip(
                          label: Text(_pathSegments[i]),
                          visualDensity: VisualDensity.compact,
                          onPressed: i == _pathSegments.length - 1
                              ? null
                              : () => _navigateToIndex(i),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const Divider(height: 1),

              // Directory Content
              Expanded(
                child: directoryAsync.when(
                  loading: () => const Center(child: ExpressiveProgressIndicator()),
                  error: (err, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(Insets.xl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(Icons.folder_off_rounded,
                              size: 48, color: colorScheme.error),
                          const SizedBox(height: Insets.md),
                          Text(
                            'Directory Not Accessible',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: Insets.xs),
                          Text(
                            err.toString(),
                            textAlign: TextAlign.center,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (dir) {
                    if (dir == null ||
                        (dir.directories.isEmpty && dir.files.isEmpty)) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(Insets.xl),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(Icons.folder_open_rounded,
                                  size: 48, color: colorScheme.outline),
                              const SizedBox(height: Insets.md),
                              Text(
                                'Folder is Empty',
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: Insets.xs),
                              Text(
                                _selectedSegment == 0
                                    ? 'No completed files or subdirectories in this path.'
                                    : 'No incomplete partial downloads.',
                                textAlign: TextAlign.center,
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final List<SlskdDiskDirectory> subdirs = dir.directories.toList()
                      ..sort((a, b) => a.name.compareTo(b.name));
                    final List<SlskdDiskFile> files = dir.files.toList()
                      ..sort((a, b) => a.name.compareTo(b.name));

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: (_pathSegments.isNotEmpty ? 1 : 0) +
                          subdirs.length +
                          files.length,
                      itemBuilder: (context, index) {
                        int currentIdx = index;

                        // Up-navigation row
                        if (_pathSegments.isNotEmpty) {
                          if (currentIdx == 0) {
                            return ListTile(
                              leading: const Icon(Icons.arrow_upward_rounded),
                              title: const Text('..'),
                              subtitle: const Text('Back to parent folder'),
                              onTap: _navigateBack,
                            );
                          }
                          currentIdx--;
                        }

                        // Subdirectories
                        if (currentIdx < subdirs.length) {
                          final subdir = subdirs[currentIdx];
                          return ListTile(
                            leading: Icon(
                              Icons.folder_rounded,
                              color: colorScheme.primary,
                            ),
                            title: Text(
                              subdir.name,
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${slskdPluralize(subdir.files.length, 'file')} • ${slskdPluralize(subdir.directories.length, 'folder')}',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    size: 20,
                                    color: colorScheme.error,
                                  ),
                                  tooltip: 'Delete folder',
                                  onPressed: _isActionInProgress
                                      ? null
                                      : () => _deleteDirectory(subdir),
                                ),
                                const Icon(Icons.chevron_right_rounded),
                              ],
                            ),
                            onTap: () => _navigateToFolder(subdir.name),
                          );
                        }

                        // Files
                        final file = files[currentIdx - subdirs.length];
                        return ListTile(
                          leading: Icon(
                            _getFileIcon(file.name),
                            color: colorScheme.secondary,
                          ),
                          title: Text(
                            file.name,
                            style: textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            slskdFormatBytes(file.length),
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              size: 20,
                              color: colorScheme.error,
                            ),
                            tooltip: 'Delete file',
                            onPressed: _isActionInProgress
                                ? null
                                : () => _deleteFile(file),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

  IconData _getFileIcon(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.mp3') ||
        lower.endsWith('.flac') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.ogg')) {
      return Icons.music_note_rounded;
    }
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png')) {
      return Icons.image_rounded;
    }
    if (lower.endsWith('.log') ||
        lower.endsWith('.txt') ||
        lower.endsWith('.cue')) {
      return Icons.description_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }
}
