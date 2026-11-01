import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';

import '../browse/slskd_browse_file_tile.dart';
import '../browse/slskd_browse_folder_tile.dart';
import '../browse/slskd_browse_models_ui.dart';
import '../browse/slskd_browse_peer_card.dart';
import '../models/slskd_models.dart';
import '../searches/slskd_search_models_ui.dart';
import '../slskd_providers.dart';

/// User Share Browser tab in [SlskdHome].
/// Implements:
/// - Peer lookup SearchBar with suggested peer shortcuts
/// - Peer profile card with presence, slot indicators, and bio sheet
/// - Hierarchical folder tree explorer with interactive breadcrumb ribbon
/// - 1-Tap "Download Entire Folder" batch enqueueing
/// - Individual track downloads with audio format badges
/// - In-folder search filtering.
class SlskdBrowseTab extends ConsumerStatefulWidget {
  const SlskdBrowseTab({
    required this.instance,
    this.onOpenDrawer,
    super.key,
  });

  final Instance instance;
  final VoidCallback? onOpenDrawer;

  @override
  ConsumerState<SlskdBrowseTab> createState() => _SlskdBrowseTabState();
}

class _SlskdBrowseTabState extends ConsumerState<SlskdBrowseTab> {
  final TextEditingController _userSearchController = TextEditingController();
  final TextEditingController _filterController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _filterQuery = '';
  SlskdSearchFormatFilter _formatFilter = SlskdSearchFormatFilter.all;

  @override
  void dispose() {
    _scrollController.dispose();
    _userSearchController.dispose();
    _filterController.dispose();
    super.dispose();
  }

  void _selectUser(String username) {
    final trimmed = username.trim();
    if (trimmed.isEmpty) return;

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _filterQuery = '';
      _filterController.clear();
      _userSearchController.text = trimmed;
    });
    ref.read(slskdBrowsePathSegmentsProvider(widget.instance).notifier).state = const <String>[];
    ref.read(slskdBrowseUsernameProvider(widget.instance).notifier).state = trimmed;
  }

  void _clearUser() {
    setState(() {
      _filterQuery = '';
      _filterController.clear();
      _userSearchController.clear();
    });
    ref.read(slskdBrowsePathSegmentsProvider(widget.instance).notifier).state = const <String>[];
    ref.read(slskdBrowseUsernameProvider(widget.instance).notifier).state = null;
  }

  void _handleBack() {
    final segments = ref.read(slskdBrowsePathSegmentsProvider(widget.instance));
    if (segments.isNotEmpty) {
      ref.read(slskdBrowsePathSegmentsProvider(widget.instance).notifier).state =
          segments.sublist(0, segments.length - 1);
      setState(() {
        _filterQuery = '';
        _filterController.clear();
      });
    } else {
      _clearUser();
    }
  }

  Future<void> _downloadFolder(String username, BrowseNode node) async {
    final files = node.getDownloadableFilesRecursive();
    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nothing in "${node.segment}" can be downloaded')),
      );
      return;
    }

    try {
      final api = await ref.read(slskdApiProvider(widget.instance).future);
      final resp = await api.enqueueBatch(
        EnqueueDownloadBatchRequest(
          username: username,
          options: EnqueueDownloadBatchOptions(
            externalId:
                '${username}_${DateTime.now().millisecondsSinceEpoch}_${node.segment.hashCode.abs()}',
          ),
          files: files
              .map(
                (f) => EnqueueDownloadBatchItem(
                  filename: f.filename,
                  size: f.size,
                ),
              )
              .toList(),
        ),
      );
      if (!mounted) return;
      ref.invalidate(slskdDownloadsProvider(widget.instance));

      final enqueuedCount = resp.batch?.transfers.length ?? 0;
      final failureCount = resp.failures.length;

      if (enqueuedCount == 0 && failureCount > 0) {
        final firstFailure =
            resp.failures.first.message ?? 'already downloading or queued';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not queue "${node.segment}": $firstFailure'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } else {
        final summaryMsg = failureCount > 0
            ? 'Downloading "${node.segment}" ($enqueuedCount tracks queued, $failureCount failed/already queued)'
            : 'Downloading "${node.segment}" ($enqueuedCount tracks)';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(summaryMsg),
            action: SnackBarAction(
              label: 'View Transfers',
              onPressed: () {
                ref
                    .read(slskdActiveTabProvider(widget.instance).notifier)
                    .state = 0;
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to enqueue folder: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _downloadTrack(String username, SlskdSearchFile file) async {
    try {
      final api = await ref.read(slskdApiProvider(widget.instance).future);
      final resp = await api.enqueueBatch(
        EnqueueDownloadBatchRequest(
          username: username,
          files: <EnqueueDownloadBatchItem>[
            EnqueueDownloadBatchItem(filename: file.filename, size: file.size),
          ],
        ),
      );
      if (!mounted) return;
      ref.invalidate(slskdDownloadsProvider(widget.instance));

      if (resp.failures.isNotEmpty &&
          (resp.batch?.transfers.isEmpty ?? true)) {
        final failMsg =
            resp.failures.first.message ?? 'already downloading or queued';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not queue "${file.trackTitle}": $failMsg'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloading "${file.trackTitle}"'),
            action: SnackBarAction(
              label: 'View Transfers',
              onPressed: () {
                ref
                    .read(slskdActiveTabProvider(widget.instance).notifier)
                    .state = 0;
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to enqueue track: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final String? activeUsername = ref.watch(slskdBrowseUsernameProvider(widget.instance));

    ref.listen<String?>(slskdBrowseUsernameProvider(widget.instance), (prev, next) {
      if (next == null || next.isEmpty) {
        if (_userSearchController.text.isNotEmpty) {
          setState(() {
            _filterQuery = '';
            _filterController.clear();
            _userSearchController.clear();
          });
        }
      } else if (next != _userSearchController.text) {
        setState(() {
          _userSearchController.text = next;
        });
      }
    });

    if (activeUsername == null || activeUsername.isEmpty) {
      return _buildInitialLookupView(context);
    }

    return _buildPeerLibraryView(context, activeUsername, colorScheme);
  }

  // ---------------------------------------------------------------------------
  // 1. Initial Peer Lookup State
  // ---------------------------------------------------------------------------

  Widget _buildInitialLookupView(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: widget.onOpenDrawer ?? Scaffold.of(context).openDrawer,
        ),
        title: const Text('Peer Library Explorer'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: Insets.lg),
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.folder_shared_rounded,
                    size: 36,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: Insets.md),
              Text(
                'Browse Peer Shares',
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: Insets.xs),
              Text(
                'Explore full music libraries, discographies, and directories shared by any Soulseek user.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: Insets.xl),

              // Peer input SearchBar
              SearchBar(
                controller: _userSearchController,
                hintText: 'Enter Soulseek username...',
                elevation: const WidgetStatePropertyAll<double>(0),
                backgroundColor: WidgetStatePropertyAll<Color>(colorScheme.surfaceContainerHigh),
                padding: const WidgetStatePropertyAll<EdgeInsets>(
                  EdgeInsets.symmetric(horizontal: Insets.md),
                ),
                leading: const Icon(Icons.person_search_rounded, size: 22),
                trailing: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded),
                    onPressed: () => _selectUser(_userSearchController.text),
                  ),
                ],
                onSubmitted: _selectUser,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Active Peer Share Explorer View
  // ---------------------------------------------------------------------------

  Widget _buildPeerLibraryView(
    BuildContext context,
    String username,
    ColorScheme colorScheme,
  ) {
    final directoriesAsync =
        ref.watch(slskdUserDirectoriesProvider((widget.instance, username)));
    final userInfoAsync = ref.watch(slskdUserInfoProvider((widget.instance, username)));
    final userStatusAsync = ref.watch(slskdUserStatusProvider((widget.instance, username)));
    final currentPathSegments = ref.watch(slskdBrowsePathSegmentsProvider(widget.instance));

    ref.listen<int>(
      slskdScrollToTopProvider((widget.instance, 2)),
      (previous, next) {
        if (next > 0 && _scrollController.hasClients) {
          _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      },
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            // 1. Pinned App Bar with User name & Navigation
            SliverAppBar(
              floating: true,
              pinned: true,
              scrolledUnderElevation: 0,
              backgroundColor: colorScheme.surface,
              leading: IconButton(
                tooltip: currentPathSegments.isNotEmpty ? 'Back to parent folder' : 'Exit Peer Browse',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _handleBack,
              ),
              titleSpacing: 0,
              title: Text(
                username,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              actions: <Widget>[
                IconButton(
                  tooltip: 'Refresh peer shares',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () {
                    ref.invalidate(slskdUserDirectoriesProvider((widget.instance, username)));
                    ref.invalidate(slskdUserInfoProvider((widget.instance, username)));
                    ref.invalidate(slskdUserStatusProvider((widget.instance, username)));
                    ref.invalidate(slskdBrowseStatusProvider((widget.instance, username)));
                  },
                ),
                const SizedBox(width: Insets.xs),
              ],
            ),

            // 2. Peer Header Overview Card
            SliverToBoxAdapter(
              child: directoriesAsync.when(
                data: (dirs) => SlskdBrowsePeerCard(
                  username: username,
                  userInfo: userInfoAsync.value,
                  userStatus: userStatusAsync.value,
                  totalFolders: dirs.length,
                  totalFiles: dirs.fold<int>(0, (sum, d) => sum + d.files.length),
                ),
                loading: () => SlskdBrowsePeerCard(
                  username: username,
                  userInfo: userInfoAsync.value,
                  userStatus: userStatusAsync.value,
                ),
                error: (_, _) => SlskdBrowsePeerCard(
                  username: username,
                  userInfo: userInfoAsync.value,
                  userStatus: userStatusAsync.value,
                ),
              ),
            ),

            // 3. Tree Content or Loading/Error States
            ...directoriesAsync.when(
              data: (directories) => _buildExplorerTree(
                context,
                username: username,
                directories: directories,
                colorScheme: colorScheme,
              ),
              loading: () {
                final statusVal = ref.watch(slskdBrowseStatusProvider((widget.instance, username))).value;
                final bool hasProgress = statusVal != null && statusVal > 0;
                final double normalized = hasProgress
                    ? (statusVal > 1.0 ? statusVal / 100.0 : statusVal).clamp(0.0, 1.0).toDouble()
                    : 0.0;
                final int pct = hasProgress
                    ? (statusVal > 1.0 ? statusVal : statusVal * 100).round()
                    : 0;

                return <Widget>[
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(Insets.xl),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            if (hasProgress) ...<Widget>[
                              SizedBox(
                                width: 220,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicatorM3E(
                                    value: normalized,
                                    size: LinearProgressM3ESize.s,
                                    shape: ProgressM3EShape.flat,
                                    activeColor: colorScheme.primary,
                                    trackColor: colorScheme.surfaceContainerHighest,
                                  ),
                                ),
                              ),
                              const SizedBox(height: Insets.md),
                              Text(
                                'Retrieving shares ($pct% complete)...',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ] else ...<Widget>[
                              const ExpressiveProgressIndicator(),
                              const SizedBox(height: Insets.md),
                              Text(
                                'Requesting peer library...',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                            const SizedBox(height: Insets.xs),
                            Text(
                              'Connecting to $username across the Soulseek network',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ];
              },
              error: (err, _) => <Widget>[
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(Insets.xl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(Icons.cloud_off_rounded, size: 56, color: colorScheme.error),
                          const SizedBox(height: Insets.md),
                          Text(
                            'Unable to browse $username',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: Insets.xs),
                          Text(
                            'Peer might be offline, private, or their transfer port is blocked.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: Insets.md),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Retry'),
                            onPressed: () {
                              ref.invalidate(
                                slskdUserDirectoriesProvider((widget.instance, username)),
                              );
                              ref.invalidate(
                                slskdUserInfoProvider((widget.instance, username)),
                              );
                              ref.invalidate(
                                slskdUserStatusProvider((widget.instance, username)),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Clearance at bottom
            const SliverToBoxAdapter(
              child: SizedBox(height: Insets.xxl),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Explorer Tree Builder
  // ---------------------------------------------------------------------------

  List<Widget> _buildExplorerTree(
    BuildContext context, {
    required String username,
    required List<SlskdDirectory> directories,
    required ColorScheme colorScheme,
  }) {
    if (directories.isEmpty) {
      return <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(Insets.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.folder_off_outlined, size: 56, color: colorScheme.outline),
                  const SizedBox(height: Insets.md),
                  Text(
                    'No shared files found',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: Insets.xs),
                  Text(
                    '$username is not sharing any public files at this time.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    final List<String> currentPathSegments =
        ref.watch(slskdBrowsePathSegmentsProvider(widget.instance));

    // Build the hierarchical tree
    final BrowseNode rootNode = BrowseNode.buildTree(directories);

    // Resolve current node based on path segments
    BrowseNode currentNode = rootNode;
    for (final segment in currentPathSegments) {
      if (currentNode.subfolders.containsKey(segment)) {
        currentNode = currentNode.subfolders[segment]!;
      } else {
        break;
      }
    }

    // Filter subfolders and files if search query or format filter applied
    List<BrowseNode> displayFolders = currentNode.subfolders.values.toList();
    List<SlskdSearchFile> displayFiles = currentNode.files.toList();

    if (_filterQuery.isNotEmpty) {
      final q = _filterQuery.toLowerCase();
      displayFolders = displayFolders.where((f) => f.segment.toLowerCase().contains(q)).toList();
      displayFiles = displayFiles.where((f) => f.trackTitle.toLowerCase().contains(q)).toList();
    }

    if (_formatFilter != SlskdSearchFormatFilter.all) {
      displayFiles = displayFiles.where((f) => _formatFilter.matchesExtension(f.extension)).toList();
    }

    // Sort subfolders alphabetically
    displayFolders.sort((a, b) => a.segment.compareTo(b.segment));

    return <Widget>[
      // 1. Breadcrumb Navigation Ribbon
      SliverToBoxAdapter(
        child: _buildBreadcrumbs(context, currentPathSegments, colorScheme),
      ),

      // 2. Folder Action Bar (Download entire folder button & Filter bar)
      SliverToBoxAdapter(
        child: _buildFolderActionBar(
          context,
          username,
          currentNode,
          currentPathSegments,
          colorScheme,
        ),
      ),

      // 3. Subdirectories List
      if (displayFolders.isNotEmpty)
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              final folderNode = displayFolders[index];
              return SlskdBrowseFolderTile(
                key: ValueKey('folder_${folderNode.fullPath}'),
                node: folderNode,
                onTap: () {
                  ref.read(slskdBrowsePathSegmentsProvider(widget.instance).notifier).state = [
                    ...currentPathSegments,
                    folderNode.segment,
                  ];
                  setState(() {
                    _filterQuery = '';
                    _filterController.clear();
                  });
                },
                onDownloadFolder: () => _downloadFolder(username, folderNode),
              );
            },
            childCount: displayFolders.length,
          ),
        ),

      // 4. Audio Files in Current Directory
      if (displayFiles.isNotEmpty) ...<Widget>[
        if (displayFolders.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(left: Insets.lg, top: Insets.md, bottom: Insets.xs),
              child: Text(
                'Tracks (${displayFiles.length})',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.outline,
                    ),
              ),
            ),
          ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              final file = displayFiles[index];
              return SlskdBrowseFileTile(
                key: ValueKey('file_${file.filename}'),
                index: index + 1,
                file: file,
                onDownload: () => _downloadTrack(username, file),
              );
            },
            childCount: displayFiles.length,
          ),
        ),
      ],

      // 5. Empty search in folder
      if (displayFolders.isEmpty && displayFiles.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(Insets.xl),
            child: Center(
              child: Text(
                _filterQuery.isNotEmpty
                    ? 'No files or folders match "$_filterQuery"'
                    : 'This folder is empty',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.outline,
                    ),
              ),
            ),
          ),
        ),
    ];
  }

  // ---------------------------------------------------------------------------
  // 4. Breadcrumbs & Action Bar Widgets
  // ---------------------------------------------------------------------------

  Widget _buildBreadcrumbs(
    BuildContext context,
    List<String> currentPathSegments,
    ColorScheme colorScheme,
  ) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 4),
      child: ShaderMask(
        shaderCallback: (Rect bounds) {
          return const LinearGradient(
            colors: <Color>[Colors.white, Colors.white, Colors.transparent],
            stops: <double>[0.0, 0.92, 1.0],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: <Widget>[
            // Root chip
            ActionChip(
              avatar: const Icon(Icons.home_rounded, size: 16),
              label: const Text('Root'),
              visualDensity: VisualDensity.compact,
              onPressed: () {
                if (currentPathSegments.isNotEmpty) {
                  ref.read(slskdBrowsePathSegmentsProvider(widget.instance).notifier).state =
                      const <String>[];
                  setState(() {
                    _filterQuery = '';
                    _filterController.clear();
                  });
                }
              },
            ),
            for (int i = 0; i < currentPathSegments.length; i++) ...<Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.chevron_right_rounded, size: 16, color: colorScheme.outline),
              ),
              ActionChip(
                label: Text(currentPathSegments[i]),
                visualDensity: VisualDensity.compact,
                backgroundColor: i == currentPathSegments.length - 1
                    ? colorScheme.secondaryContainer
                    : null,
                onPressed: () {
                  ref.read(slskdBrowsePathSegmentsProvider(widget.instance).notifier).state =
                      currentPathSegments.sublist(0, i + 1);
                  setState(() {
                    _filterQuery = '';
                    _filterController.clear();
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFolderActionBar(
    BuildContext context,
    String username,
    BrowseNode node,
    List<String> currentPathSegments,
    ColorScheme colorScheme,
  ) {
    final int recursiveFiles = node.totalFiles;
    final String size = node.formattedTotalSize;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.xs),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              // Current folder segment & total stats
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      currentPathSegments.isNotEmpty ? currentPathSegments.last : 'Root Shares',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '$recursiveFiles tracks • $size',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),

              // 1-Tap "Download Entire Folder" batch action
              if (recursiveFiles > 0)
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
                  ),
                  icon: Icon(
                    node.isLocked ? Icons.lock_clock_outlined : Icons.download_rounded,
                    size: 16,
                  ),
                  label: Text(node.isLocked ? 'Locked' : 'Download Folder'),
                  onPressed: node.isLocked ? null : () => _downloadFolder(username, node),
                ),
            ],
          ),
          const SizedBox(height: Insets.xs),

          // In-folder search filter
          SearchBar(
            controller: _filterController,
            hintText: 'Filter files or subfolders...',
            elevation: const WidgetStatePropertyAll<double>(0),
            backgroundColor: WidgetStatePropertyAll<Color>(colorScheme.surfaceContainerHigh),
            padding: const WidgetStatePropertyAll<EdgeInsets>(
              EdgeInsets.symmetric(horizontal: Insets.sm),
            ),
            leading: const Icon(Icons.filter_list_rounded, size: 18),
            trailing: <Widget>[
              if (_filterQuery.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () {
                    setState(() {
                      _filterController.clear();
                      _filterQuery = '';
                    });
                  },
                ),
            ],
            onChanged: (val) {
              setState(() {
                _filterQuery = val.trim();
              });
            },
          ),
          const SizedBox(height: Insets.xs),

          // Format filter chips (All, FLAC, MP3)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: SlskdSearchFormatFilter.values.map((f) {
                return Padding(
                  padding: const EdgeInsets.only(right: Insets.xs),
                  child: ChoiceChip(
                    label: Text(f == SlskdSearchFormatFilter.all ? 'All' : f.label.replaceAll(' Only', '')),
                    visualDensity: VisualDensity.compact,
                    selected: _formatFilter == f,
                    onSelected: (sel) {
                      if (sel) setState(() => _formatFilter = f);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
