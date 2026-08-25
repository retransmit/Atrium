import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/lidarr_formatters.dart';
import '../../generated/generated.dart';
import '../../lidarr_api.dart';
import '../../lidarr_providers.dart';

/// Sort options for interactive release search results.
enum ReleaseSortOption {
  qualityScore('Score / Quality', Icons.star_outline),
  seeders('Seeders', Icons.cloud_download_outlined),
  size('Size', Icons.storage_outlined),
  age('Age', Icons.schedule),
  indexer('Indexer', Icons.storage);

  const ReleaseSortOption(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Full-screen interactive release search results page displaying releases from all indexers
/// with in-memory filter, multi-attribute sorting, peer stats, rejection reasons, and manual grab capabilities.
class LidarrInteractiveSearchScreen extends ConsumerStatefulWidget {
  const LidarrInteractiveSearchScreen({
    required this.instance,
    required this.title,
    this.albumId,
    this.artistId,
    super.key,
  }) : assert(
          albumId != null || artistId != null,
          'Either albumId or artistId must be provided',
        );

  final Instance instance;
  final String title;
  final int? albumId;
  final int? artistId;

  /// Convenience helper to display this interactive search screen full-screen.
  static Future<void> show(
    BuildContext context, {
    required Instance instance,
    required String title,
    int? albumId,
    int? artistId,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LidarrInteractiveSearchScreen(
          instance: instance,
          title: title,
          albumId: albumId,
          artistId: artistId,
        ),
      ),
    );
  }

  @override
  ConsumerState<LidarrInteractiveSearchScreen> createState() =>
      _LidarrInteractiveSearchScreenState();
}

/// Backward compatibility alias.
typedef LidarrInteractiveSearchSheet = LidarrInteractiveSearchScreen;

class _LidarrInteractiveSearchScreenState
    extends ConsumerState<LidarrInteractiveSearchScreen>
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  double _lastBottomInset = 0.0;
  String _filterQuery = '';
  ReleaseSortOption _sortOption = ReleaseSortOption.qualityScore;
  bool _sortAscending = false;
  String _selectedFilter =
      'all'; // 'all', 'approved', 'torrent', 'usenet', 'freeleech'
  final Set<String> _grabbingGuids = {};
  final Set<String> _grabbedGuids = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _searchController.addListener(() {
      if (_filterQuery != _searchController.text) {
        setState(() {
          _filterQuery = _searchController.text;
        });
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

  int get _activeFilterCount {
    int count = 0;
    if (_selectedFilter != 'all') count++;
    if (_sortOption != ReleaseSortOption.qualityScore || _sortAscending) {
      count++;
    }
    if (_filterQuery.trim().isNotEmpty) count++;
    return count;
  }

  String _formatAge(int? ageDays, double? ageHours) {
    if (ageHours != null && ageHours < 24) {
      return '${ageHours.toInt()}h ago';
    }
    if (ageDays != null) {
      if (ageDays > 365) return '${(ageDays / 365).floor()}y ago';
      if (ageDays > 30) return '${(ageDays / 30).floor()}mo ago';
      return '${ageDays}d ago';
    }
    return '';
  }

  String? _getReleaseWebUrl(ReleaseResource release) {
    if (release.infoUrl != null && release.infoUrl!.trim().isNotEmpty) {
      return release.infoUrl!.trim();
    }
    if (release.commentUrl != null && release.commentUrl!.trim().isNotEmpty) {
      return release.commentUrl!.trim();
    }
    if (release.guid != null &&
        (release.guid!.startsWith('http://') ||
            release.guid!.startsWith('https://'))) {
      return release.guid!.trim();
    }
    return null;
  }

  Future<void> _grabRelease(ReleaseResource release) async {
    final String? guid = release.guid;
    if (guid == null) return;

    final bool isRejected = release.rejected == true ||
        (release.rejections != null && release.rejections!.isNotEmpty);

    if (isRejected) {
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Force Grab Release?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This release was marked as rejected by Lidarr for the following reasons:',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: Insets.sm),
              if (release.rejections != null)
                ...release.rejections!.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '• ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Expanded(child: Text(r)),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: Insets.sm),
              const Text(
                'Do you want to send this release to the download client anyway?',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.primary,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Grab Anyway'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    setState(() {
      _grabbingGuids.add(guid);
    });

    try {
      final LidarrApi api =
          await ref.read(lidarrApiProvider(widget.instance).future);
      final ReleaseResource payload = release.copyWith(
        // A search result carries no id of its own, and Lidarr deserialises
        // this as a non-nullable int before it validates anything, so a null
        // fails the request outright. That is true of every branch, not just
        // nightly. LidarrApi strips nulls as well, but this path is explicit
        // about it because it is the one that always relies on it.
        id: release.id ?? 0,
        albumId: release.albumId ?? widget.albumId,
        artistId: release.artistId ?? widget.artistId,
      );
      final ApiResponse<ReleaseResource> resp =
          await api.release.postRelease(body: payload);

      if (!resp.isSuccess) {
        throw Exception(resp.error?.message ?? 'Failed to grab release');
      }

      setState(() {
        _grabbedGuids.add(guid);
      });

      ref.invalidate(lidarrQueueProvider(widget.instance));
      ref.invalidate(lidarrHistoryProvider(widget.instance));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Grabbed "${release.title ?? 'Release'}"'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to grab release: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _grabbingGuids.remove(guid);
        });
      }
    }
  }

  void _showFilterAndSortSheet(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: cs.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetCtx) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setSheetState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        Icon(Icons.tune_rounded, size: 22, color: cs.primary),
                        const SizedBox(width: 10),
                        Text(
                          'Filter & Sort Releases',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_activeFilterCount > 0)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedFilter = 'all';
                                _sortOption = ReleaseSortOption.qualityScore;
                                _sortAscending = false;
                                _filterQuery = '';
                                _searchController.clear();
                              });
                              setSheetState(() {});
                            },
                            child: const Text('Reset'),
                          ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.of(sheetCtx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Filter section
                    Text(
                      'Filter',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _buildFilterChip(
                          'all',
                          'All Releases',
                          Icons.all_inclusive,
                          setSheetState,
                          cs,
                        ),
                        _buildFilterChip(
                          'approved',
                          'Approved Only',
                          Icons.check_circle_outline,
                          setSheetState,
                          cs,
                        ),
                        _buildFilterChip(
                          'torrent',
                          'Torrents Only',
                          Icons.cloud_download_outlined,
                          setSheetState,
                          cs,
                        ),
                        _buildFilterChip(
                          'usenet',
                          'Usenet Only',
                          Icons.storage_outlined,
                          setSheetState,
                          cs,
                        ),
                        _buildFilterChip(
                          'freeleech',
                          'Freeleech',
                          Icons.star_outline,
                          setSheetState,
                          cs,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Sort By section with inline order toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Sort By',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: Icon(
                            _sortAscending
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            size: 16,
                          ),
                          label: Text(
                            _sortAscending ? 'Ascending' : 'Descending',
                            style: const TextStyle(fontSize: 13),
                          ),
                          onPressed: () {
                            setState(() {
                              _sortAscending = !_sortAscending;
                            });
                            setSheetState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children:
                          ReleaseSortOption.values.map((ReleaseSortOption opt) {
                        final bool isSelected = _sortOption == opt;
                        final IconData directionIcon = _sortAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward;
                        return ChoiceChip(
                          avatar: Icon(
                            isSelected ? directionIcon : opt.icon,
                            size: 16,
                            color: isSelected
                                ? cs.onPrimaryContainer
                                : cs.onSurfaceVariant,
                          ),
                          label: Text(
                            opt.label,
                            style: const TextStyle(fontSize: 12.5),
                          ),
                          selected: isSelected,
                          onSelected: (bool selected) {
                            if (isSelected) {
                              // Tapping active sort toggles direction immediately
                              setState(() {
                                _sortAscending = !_sortAscending;
                              });
                            } else {
                              setState(() {
                                _sortOption = opt;
                              });
                            }
                            setSheetState(() {});
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Apply Button
                    FilledButton(
                      onPressed: () => Navigator.of(sheetCtx).pop(),
                      child: const Text('Apply & Close'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip(
    String key,
    String label,
    IconData icon,
    StateSetter setSheetState,
    ColorScheme cs,
  ) {
    final bool isSelected = _selectedFilter == key;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
      ),
      label: Text(label, style: const TextStyle(fontSize: 12.5)),
      selected: isSelected,
      onSelected: (bool selected) {
        if (selected) {
          setState(() {
            _selectedFilter = key;
          });
          setSheetState(() {});
        }
      },
    );
  }

  void _showReleaseDetailsSheet(BuildContext context, ReleaseResource release) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final String qualityName = release.quality?.quality?.name ?? 'Unknown';
    final int seeders = release.seeders ?? 0;
    final int leechers = release.leechers ?? 0;
    final String sizeStr = LidarrFormatters.formatBytes(release.size);
    final String ageStr = _formatAge(release.age, release.ageHours);
    final String protocolStr =
        release.protocol?.value.toUpperCase() ?? 'TORRENT';
    final int score = release.customFormatScore ?? 0;
    final bool isRejected = release.rejected == true ||
        (release.rejections != null && release.rejections!.isNotEmpty);
    final String? webUrl = _getReleaseWebUrl(release);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: ListView(
            controller: scrollController,
            children: [
              // Header Row
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Release Details',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      backgroundColor:
                          isRejected ? cs.errorContainer : cs.primary,
                      foregroundColor:
                          isRejected ? cs.onErrorContainer : cs.onPrimary,
                    ),
                    icon: Icon(
                      isRejected
                          ? Icons.warning_amber_outlined
                          : Icons.download_outlined,
                      size: 16,
                    ),
                    label: Text(isRejected ? 'Force Grab' : 'Grab'),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _grabRelease(release);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Multi-line Release Title (No cutoff, selectable)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SelectableText(
                  release.title ?? 'Unknown Release',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),

              // Action buttons bar: Open torrent page, copy magnet / download URL
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (webUrl != null)
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.open_in_browser, size: 18),
                      label: const Text('Open Torrent Page'),
                      onPressed: () async {
                        final uri = Uri.tryParse(webUrl);
                        if (uri != null) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                    ),
                  if (release.downloadUrl != null &&
                      release.downloadUrl!.isNotEmpty)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy Download URL'),
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: release.downloadUrl!),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Download URL copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  if (release.magnetUrl != null &&
                      release.magnetUrl!.isNotEmpty)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.link, size: 16),
                      label: const Text('Copy Magnet URI'),
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: release.magnetUrl!),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Magnet URI copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                ],
              ),
              const Divider(height: 24),

              // Attributes List
              _buildDetailRow('Indexer', release.indexer ?? 'Unknown', cs),
              _buildDetailRow('Protocol', protocolStr, cs),
              _buildDetailRow('Quality', qualityName, cs),
              _buildDetailRow('Size', sizeStr, cs),
              _buildDetailRow(
                'Peers',
                '↑ $seeders seeders  •  ↓ $leechers leechers',
                cs,
              ),
              if (ageStr.isNotEmpty) _buildDetailRow('Age', ageStr, cs),
              if (release.publishDate != null)
                _buildDetailRow('Published', release.publishDate!, cs),
              if (score != 0)
                _buildDetailRow(
                  'Custom Format Score',
                  '${score > 0 ? "+$score" : score}',
                  cs,
                ),
              if (release.releaseGroup != null &&
                  release.releaseGroup!.isNotEmpty)
                _buildDetailRow('Release Group', release.releaseGroup!, cs),
              if (release.guid != null)
                _buildDetailRow('GUID', release.guid!, cs),
              if (release.downloadUrl != null &&
                  release.downloadUrl!.isNotEmpty)
                _buildDetailRow('Download URL', release.downloadUrl!, cs),
              if (release.infoUrl != null && release.infoUrl!.isNotEmpty)
                _buildDetailRow('Info URL', release.infoUrl!, cs),
              if (release.commentUrl != null && release.commentUrl!.isNotEmpty)
                _buildDetailRow('Comment URL', release.commentUrl!, cs),

              // Custom Formats section
              if (release.customFormats != null &&
                  release.customFormats!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Custom Formats',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: release.customFormats!
                      .where((cf) => cf.name != null && cf.name!.isNotEmpty)
                      .map(
                        (cf) => Chip(
                          label: Text(
                            cf.name!,
                            style: const TextStyle(fontSize: 11),
                          ),
                          backgroundColor: cs.surfaceContainerHighest,
                          side: BorderSide.none,
                        ),
                      )
                      .toList(),
                ),
              ],

              // Rejection reasons section (No text cutoff, fully scrollable)
              if (release.rejections != null &&
                  release.rejections!.isNotEmpty) ...[
                const Divider(height: 24),
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 20,
                      color: cs.error,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Rejection Reasons (${release.rejections!.length})',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: cs.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...release.rejections!.map(
                  (r) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.errorContainer.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: cs.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline, size: 16, color: cs.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SelectableText(
                            r,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: cs.error,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, ColorScheme cs) {
    final bool isUrl =
        value.startsWith('http://') || value.startsWith('https://');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SelectableText(
                    value,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: isUrl ? cs.primary : null,
                    ),
                  ),
                ),
                if (isUrl)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                    icon: const Icon(Icons.open_in_new, size: 15),
                    tooltip: 'Open in browser',
                    onPressed: () async {
                      final uri = Uri.tryParse(value);
                      if (uri != null) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<ReleaseResource> _filterAndSort(List<ReleaseResource> releases) {
    List<ReleaseResource> list = List.of(releases);

    // Apply status and protocol filter
    switch (_selectedFilter) {
      case 'approved':
        list = list
            .where(
              (r) =>
                  r.rejected != true &&
                  (r.rejections == null || r.rejections!.isEmpty),
            )
            .toList();
        break;
      case 'torrent':
        list = list
            .where(
              (r) =>
                  (r.protocol?.value.toLowerCase() ?? '') == 'torrent' ||
                  r.protocol == null,
            )
            .toList();
        break;
      case 'usenet':
        list = list
            .where(
              (r) => (r.protocol?.value.toLowerCase() ?? '') == 'usenet',
            )
            .toList();
        break;
      case 'freeleech':
        list = list
            .where(
              (r) =>
                  (r.downloadUrl ?? '').contains('freeleech') ||
                  (r.title ?? '').toLowerCase().contains('freeleech'),
            )
            .toList();
        break;
      default:
        break;
    }

    if (_filterQuery.trim().isNotEmpty) {
      final q = _filterQuery.trim().toLowerCase();
      list = list.where((r) {
        final title = (r.title ?? '').toLowerCase();
        final indexer = (r.indexer ?? '').toLowerCase();
        final releaseGroup = (r.releaseGroup ?? '').toLowerCase();
        final quality = (r.quality?.quality?.name ?? '').toLowerCase();
        return title.contains(q) ||
            indexer.contains(q) ||
            releaseGroup.contains(q) ||
            quality.contains(q);
      }).toList();
    }

    switch (_sortOption) {
      case ReleaseSortOption.qualityScore:
        list.sort((a, b) {
          final int scoreA = a.customFormatScore ?? a.qualityWeight ?? 0;
          final int scoreB = b.customFormatScore ?? b.qualityWeight ?? 0;
          final int cmp = scoreB.compareTo(scoreA); // Default: Highest first
          return _sortAscending ? -cmp : cmp;
        });
        break;
      case ReleaseSortOption.seeders:
        list.sort((a, b) {
          final int seedersA = a.seeders ?? 0;
          final int seedersB = b.seeders ?? 0;
          final int cmp =
              seedersB.compareTo(seedersA); // Default: Highest first
          return _sortAscending ? -cmp : cmp;
        });
        break;
      case ReleaseSortOption.size:
        list.sort((a, b) {
          final int sizeA = a.size ?? 0;
          final int sizeB = b.size ?? 0;
          final int cmp = sizeB.compareTo(sizeA); // Default: Largest first
          return _sortAscending ? -cmp : cmp;
        });
        break;
      case ReleaseSortOption.age:
        list.sort((a, b) {
          final int ageA = a.age ?? 0;
          final int ageB = b.age ?? 0;
          final int cmp = ageA.compareTo(ageB); // Default: Newest first
          return _sortAscending ? -cmp : cmp;
        });
        break;
      case ReleaseSortOption.indexer:
        list.sort((a, b) {
          final String indA = (a.indexer ?? '').toLowerCase();
          final String indB = (b.indexer ?? '').toLowerCase();
          final int cmp = indA.compareTo(indB); // Default: A-Z
          return _sortAscending ? -cmp : cmp;
        });
        break;
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    final AsyncValue<List<ReleaseResource>> asyncReleases = widget.albumId !=
            null
        ? ref.watch(
            lidarrReleasesForAlbumProvider((widget.instance, widget.albumId!)),
          )
        : ref.watch(
            lidarrReleasesForArtistProvider(
              (widget.instance, widget.artistId!),
            ),
          );

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        elevation: 0,
        leading: const BackButton(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Interactive Search',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Releases',
            onPressed: () {
              if (widget.albumId != null) {
                ref.invalidate(
                  lidarrReleasesForAlbumProvider(
                    (widget.instance, widget.albumId!),
                  ),
                );
              } else {
                ref.invalidate(
                  lidarrReleasesForArtistProvider(
                    (widget.instance, widget.artistId!),
                  ),
                );
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFilterAndSortSheet(context),
        icon: _activeFilterCount > 0
            ? Badge(
                label: Text('$_activeFilterCount'),
                backgroundColor: cs.error,
                child: const Icon(Icons.tune_rounded),
              )
            : const Icon(Icons.tune_rounded),
        label: Text(
          _activeFilterCount > 0
              ? 'Filtered ($_activeFilterCount)'
              : 'Filter & Sort',
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Column(
          children: [
            // Search Input Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: 'Filter releases by title, indexer, group...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _filterQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            setState(() {
                              _filterQuery = '';
                              _searchController.clear();
                            });
                            _searchFocusNode.unfocus();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (String val) {
                  setState(() {
                    _filterQuery = val;
                  });
                },
              ),
            ),

            // Active filter indicator bar
            if (_activeFilterCount > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: cs.primaryContainer.withValues(alpha: 0.15),
                child: Row(
                  children: [
                    Icon(Icons.filter_list, size: 16, color: cs.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Sort: ${_sortOption.label} (${_sortAscending ? '↑ Asc' : '↓ Desc'})',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                    if (_selectedFilter != 'all') ...[
                      Text(
                        ' • Status: ${_selectedFilter.isNotEmpty ? _selectedFilter[0].toUpperCase() + _selectedFilter.substring(1) : ''}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: cs.secondary,
                        ),
                      ),
                    ],
                    const Spacer(),
                    InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () {
                        setState(() {
                          _selectedFilter = 'all';
                          _sortOption = ReleaseSortOption.qualityScore;
                          _sortAscending = false;
                          _filterQuery = '';
                          _searchController.clear();
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Text(
                          'Clear',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: cs.error,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Content List
            Expanded(
              child: asyncReleases.when(
                data: (List<ReleaseResource> rawReleases) {
                  final List<ReleaseResource> releases =
                      _filterAndSort(rawReleases);

                  if (releases.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off_outlined,
                              size: 56,
                              color: cs.outline,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              rawReleases.isEmpty
                                  ? 'No Releases Found'
                                  : 'No Matching Releases',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              rawReleases.isEmpty
                                  ? 'No releases were returned by indexers for "${widget.title}".'
                                  : 'Try changing your search query or filter criteria.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            if (_activeFilterCount > 0) ...[
                              const SizedBox(height: 16),
                              FilledButton.tonalIcon(
                                icon: const Icon(Icons.clear_all),
                                label: const Text('Reset Filters'),
                                onPressed: () {
                                  setState(() {
                                    _selectedFilter = 'all';
                                    _sortOption =
                                        ReleaseSortOption.qualityScore;
                                    _filterQuery = '';
                                    _searchController.clear();
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }

                  return EasyRefresh(
                    onRefresh: () {
                      if (widget.albumId != null) {
                        return ref.refresh(
                          lidarrReleasesForAlbumProvider(
                            (widget.instance, widget.albumId!),
                          ),
                        );
                      } else {
                        return ref.refresh(
                          lidarrReleasesForArtistProvider(
                            (widget.instance, widget.artistId!),
                          ),
                        );
                      }
                    },
                    child: ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                      itemCount: releases.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final ReleaseResource release = releases[index];
                        final String guid = release.guid ?? '$index';
                        final bool isGrabbing = _grabbingGuids.contains(guid);
                        final bool isGrabbed = _grabbedGuids.contains(guid);

                        return _ReleaseCard(
                          release: release,
                          isGrabbing: isGrabbing,
                          isGrabbed: isGrabbed,
                          formatAge: _formatAge,
                          onTap: () =>
                              _showReleaseDetailsSheet(context, release),
                          onGrab: () => _grabRelease(release),
                        );
                      },
                    ),
                  );
                },
                loading: () => const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ExpressiveProgressIndicator(),
                      SizedBox(height: Insets.md),
                      Text('Querying indexers for releases...'),
                    ],
                  ),
                ),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(Insets.lg),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: cs.error),
                        const SizedBox(height: 12),
                        Text(
                          'Search Failed',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: cs.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Failed to search releases: $err',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          onPressed: () {
                            if (widget.albumId != null) {
                              ref.invalidate(
                                lidarrReleasesForAlbumProvider(
                                  (widget.instance, widget.albumId!),
                                ),
                              );
                            } else {
                              ref.invalidate(
                                lidarrReleasesForArtistProvider(
                                  (widget.instance, widget.artistId!),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReleaseCard extends StatefulWidget {
  const _ReleaseCard({
    required this.release,
    required this.isGrabbing,
    required this.isGrabbed,
    required this.formatAge,
    required this.onTap,
    required this.onGrab,
  });

  final ReleaseResource release;
  final bool isGrabbing;
  final bool isGrabbed;
  final String Function(int?, double?) formatAge;
  final VoidCallback onTap;
  final VoidCallback onGrab;

  @override
  State<_ReleaseCard> createState() => _ReleaseCardState();
}

class _ReleaseCardState extends State<_ReleaseCard> {
  bool _showRejections = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final ReleaseResource release = widget.release;

    final bool isRejected = release.rejected == true ||
        (release.rejections != null && release.rejections!.isNotEmpty);
    final String qualityName = release.quality?.quality?.name ?? 'Unknown';
    final int seeders = release.seeders ?? 0;
    final int leechers = release.leechers ?? 0;
    final String sizeStr = LidarrFormatters.formatBytes(release.size);
    final String ageStr = widget.formatAge(release.age, release.ageHours);
    final String protocolStr =
        release.protocol?.value.toUpperCase() ?? 'TORRENT';
    final int score = release.customFormatScore ?? 0;

    return Card(
      elevation: 0,
      color: isRejected
          ? cs.errorContainer.withValues(alpha: 0.15)
          : cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isRejected
              ? cs.error.withValues(alpha: 0.3)
              : cs.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Badge Row
              Row(
                children: [
                  // Protocol badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: protocolStr == 'USENET'
                          ? cs.tertiaryContainer
                          : cs.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      protocolStr,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: protocolStr == 'USENET'
                            ? cs.onTertiaryContainer
                            : cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Quality Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      qualityName,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: cs.onSecondaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Score Badge (if non-zero)
                  if (score != 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: score > 0
                            ? cs.tertiaryContainer.withValues(alpha: 0.6)
                            : cs.errorContainer.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Score: ${score > 0 ? "+$score" : score}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: score > 0
                              ? cs.onTertiaryContainer
                              : cs.onErrorContainer,
                        ),
                      ),
                    ),

                  const Spacer(),

                  // Indexer
                  if (release.indexer != null)
                    Text(
                      release.indexer!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.outline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Insets.xs),

              // Release Title
              Text(
                release.title ?? 'Unknown Release',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (release.customFormats != null &&
                  release.customFormats!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final cf in release.customFormats!)
                      if (cf.name != null && cf.name!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            cf.name!,
                            style: TextStyle(
                              fontSize: 10,
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                  ],
                ),
              ],
              const SizedBox(height: Insets.xs),

              // Metadata Row: Size, Peers, Age & Grab Button
              Row(
                children: [
                  Text(
                    sizeStr,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('•', style: TextStyle(color: cs.outline)),
                  const SizedBox(width: 8),

                  // Peers
                  Row(
                    children: [
                      Icon(
                        Icons.arrow_upward,
                        size: 14,
                        color: seeders > 0 ? cs.tertiary : cs.outline,
                      ),
                      Text(
                        '$seeders',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: seeders > 0 ? cs.tertiary : cs.outline,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_downward, size: 14, color: cs.outline),
                      Text(
                        '$leechers',
                        style: TextStyle(fontSize: 12, color: cs.outline),
                      ),
                    ],
                  ),
                  if (ageStr.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text('•', style: TextStyle(color: cs.outline)),
                    const SizedBox(width: 8),
                    Text(ageStr, style: theme.textTheme.bodySmall),
                  ],

                  const Spacer(),

                  // Grab Action Button
                  if (widget.isGrabbed)
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: cs.tertiary,
                        foregroundColor: cs.onTertiary,
                      ),
                      icon: const Icon(Icons.check, size: 18),
                      onPressed: null,
                      tooltip: 'Grabbed',
                    )
                  else if (widget.isGrabbing)
                    const SizedBox(
                      width: 36,
                      height: 36,
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: ExpressiveProgressIndicator(),
                      ),
                    )
                  else
                    IconButton.filledTonal(
                      style: IconButton.styleFrom(
                        backgroundColor: isRejected
                            ? cs.errorContainer
                            : cs.primaryContainer,
                        foregroundColor: isRejected
                            ? cs.onErrorContainer
                            : cs.onPrimaryContainer,
                      ),
                      icon: Icon(
                        isRejected
                            ? Icons.warning_amber_outlined
                            : Icons.download_outlined,
                        size: 20,
                      ),
                      onPressed: widget.onGrab,
                      tooltip:
                          isRejected ? 'Rejected (Force Grab)' : 'Grab Release',
                    ),
                ],
              ),

              // Rejection Warning Section
              if (isRejected &&
                  release.rejections != null &&
                  release.rejections!.isNotEmpty) ...[
                const SizedBox(height: 4),
                InkWell(
                  onTap: () {
                    setState(() {
                      _showRejections = !_showRejections;
                    });
                  },
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: cs.error),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _showRejections
                              ? 'Rejection reasons:'
                              : release.rejections!.first,
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.error,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: _showRejections ? null : 1,
                          overflow:
                              _showRejections ? null : TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        _showRejections ? Icons.expand_less : Icons.expand_more,
                        size: 16,
                        color: cs.error,
                      ),
                    ],
                  ),
                ),
                if (_showRejections)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0, left: 18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: release.rejections!
                          .map(
                            (r) => Text(
                              '• $r',
                              style: TextStyle(fontSize: 11, color: cs.error),
                            ),
                          )
                          .toList(),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
