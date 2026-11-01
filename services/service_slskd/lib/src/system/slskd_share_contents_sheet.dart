import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../browse/slskd_browse_models_ui.dart';
import '../models/slskd_browse_models.dart';
import '../models/slskd_search_models.dart';
import '../slskd_format.dart';
import '../slskd_providers.dart';

/// Modal bottom sheet allowing the user to browse indexed directories and files
/// within a specific local share or across all shared folders.
class SlskdShareContentsSheet extends ConsumerStatefulWidget {
  const SlskdShareContentsSheet({
    required this.instance,
    this.shareId,
    required this.title,
    this.sharePath,
    super.key,
  });

  final Instance instance;
  final String? shareId;
  final String title;
  final String? sharePath;

  static Future<void> show(
    BuildContext context, {
    required Instance instance,
    String? shareId,
    required String title,
    String? sharePath,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SlskdShareContentsSheet(
        instance: instance,
        shareId: shareId,
        title: title,
        sharePath: sharePath,
      ),
    );
  }

  @override
  ConsumerState<SlskdShareContentsSheet> createState() =>
      _SlskdShareContentsSheetState();
}

class _SlskdShareContentsSheetState
    extends ConsumerState<SlskdShareContentsSheet> {
  final List<String> _pathSegments = [];
  String _filterQuery = '';
  final TextEditingController _filterController = TextEditingController();

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  void _navigateToFolder(String folderName) {
    setState(() {
      _pathSegments.add(folderName);
      _filterQuery = '';
      _filterController.clear();
    });
  }

  void _navigateBack() {
    if (_pathSegments.isNotEmpty) {
      setState(() {
        _pathSegments.removeLast();
        _filterQuery = '';
        _filterController.clear();
      });
    }
  }

  void _navigateToIndex(int index) {
    setState(() {
      _pathSegments.removeRange(index + 1, _pathSegments.length);
      _filterQuery = '';
      _filterController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final AsyncValue<List<SlskdDirectory>> contentsAsync =
        (widget.shareId != null && widget.shareId!.isNotEmpty)
            ? ref.watch(slskdShareContentsProvider((widget.instance, widget.shareId!)))
            : ref.watch(slskdAllSharedContentsProvider(widget.instance));

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

              // Sheet Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.md),
                child: Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(Insets.xs),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.folder_shared_rounded,
                        color: colorScheme.onPrimaryContainer,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            widget.title,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.sharePath != null)
                            Text(
                              widget.sharePath!,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: Insets.xs),

              // Search Filter Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.md),
                child: TextField(
                  controller: _filterController,
                  decoration: InputDecoration(
                    hintText: 'Filter files & subfolders...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _filterQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              setState(() {
                                _filterQuery = '';
                                _filterController.clear();
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: Insets.md,
                      vertical: Insets.xs,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) => setState(() => _filterQuery = val.trim()),
                ),
              ),

              const SizedBox(height: Insets.xs),

              // Breadcrumb Navigation
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
                        label: const Text('Root'),
                        visualDensity: VisualDensity.compact,
                        onPressed: _pathSegments.isEmpty
                            ? null
                            : () => setState(() {
                                  _pathSegments.clear();
                                  _filterQuery = '';
                                  _filterController.clear();
                                }),
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

              // Folder & File Content
              Expanded(
                child: contentsAsync.when(
                  loading: () => const Center(child: ExpressiveProgressIndicator()),
                  error: (err, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(Insets.xl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(Icons.error_outline_rounded,
                              size: 48, color: colorScheme.error),
                          const SizedBox(height: Insets.md),
                          Text(
                            'Failed to load shared content',
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
                  data: (directories) {
                    if (directories.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(Insets.xl),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(Icons.folder_off_outlined,
                                  size: 48, color: colorScheme.outline),
                              const SizedBox(height: Insets.md),
                              Text(
                                'No files indexed in this share',
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // Build and traverse tree
                    final BrowseNode rootNode = BrowseNode.buildTree(directories);
                    BrowseNode currentNode = rootNode;
                    for (final seg in _pathSegments) {
                      if (currentNode.subfolders.containsKey(seg)) {
                        currentNode = currentNode.subfolders[seg]!;
                      } else {
                        break;
                      }
                    }

                    List<BrowseNode> folders = currentNode.subfolders.values.toList();
                    List<SlskdSearchFile> files = currentNode.files.toList();

                    if (_filterQuery.isNotEmpty) {
                      final q = _filterQuery.toLowerCase();
                      folders = folders
                          .where((f) => f.segment.toLowerCase().contains(q))
                          .toList();
                      files = files
                          .where((f) => f.trackTitle.toLowerCase().contains(q))
                          .toList();
                    }

                    folders.sort((a, b) => a.segment.compareTo(b.segment));

                    if (folders.isEmpty && files.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(Insets.xl),
                          child: Text(
                            _filterQuery.isNotEmpty
                                ? 'No matching folders or files'
                                : 'Empty folder',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: (_pathSegments.isNotEmpty ? 1 : 0) +
                          folders.length +
                          files.length,
                      itemBuilder: (context, index) {
                        int currentIdx = index;

                        // Up-folder navigation row
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

                        // Subfolders
                        if (currentIdx < folders.length) {
                          final folder = folders[currentIdx];
                          final totalFiles = folder.totalFiles;
                          return ListTile(
                            leading: Icon(
                              Icons.folder_rounded,
                              color: colorScheme.secondary,
                            ),
                            title: Text(
                              folder.segment,
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '$totalFiles files',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => _navigateToFolder(folder.segment),
                          );
                        }

                        // Files
                        final file = files[currentIdx - folders.length];
                        return ListTile(
                          leading: Icon(
                            _getFileIcon(file.extension),
                            color: colorScheme.primary,
                          ),
                          title: Text(
                            file.trackTitle,
                            style: textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${slskdFormatBytes(file.size)} • ${file.extension.toUpperCase()}${file.bitRate != null ? ' • ${file.bitRate} kbps' : ''}',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
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

  IconData _getFileIcon(String ext) {
    switch (ext.toLowerCase()) {
      case 'mp3':
      case 'flac':
      case 'm4a':
      case 'wav':
      case 'ogg':
      case 'aac':
        return Icons.music_note_rounded;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image_rounded;
      case 'cue':
      case 'log':
      case 'txt':
        return Icons.description_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }
}
