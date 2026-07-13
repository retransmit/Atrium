import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/radarr_movie.dart';
import 'radarr_providers.dart';

class RadarrReleaseSearchScreen extends ConsumerStatefulWidget {
  const RadarrReleaseSearchScreen({
    required this.instance,
    required this.movie,
    super.key,
  });

  final Instance instance;
  final RadarrMovie movie;

  @override
  ConsumerState<RadarrReleaseSearchScreen> createState() =>
      _RadarrReleaseSearchScreenState();
}

class _ScrollBehavior extends ScrollBehavior {
  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class _RadarrReleaseSearchScreenState
    extends ConsumerState<RadarrReleaseSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedProtocol = 'All'; // 'All', 'Torrent', 'Usenet'
  bool _approvedOnly = false;
  String _sortBy = 'Age'; // 'Age', 'Size', 'Seeders'
  bool _sortAscending = true;
  final Map<String, bool> _downloadingMap = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  double _getAgeMinutes(Map<String, dynamic> r) {
    if (r['ageMinutes'] != null) return (r['ageMinutes'] as num).toDouble();
    if (r['ageHours'] != null) return (r['ageHours'] as num).toDouble() * 60;
    if (r['age'] != null) return (r['age'] as num).toDouble() * 1440;
    return double.maxFinite;
  }

  String _formatAge(Map<String, dynamic> r) {
    final double mins = _getAgeMinutes(r);
    if (mins == double.maxFinite) return 'Unknown age';
    if (mins < 60) return '${mins.toStringAsFixed(0)}m';
    final double hours = mins / 60;
    if (hours < 24) return '${hours.toStringAsFixed(0)}h';
    final double days = hours / 24;
    return '${days.toStringAsFixed(0)}d';
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  Future<void> _download(
    Map<String, dynamic> release, {
    bool bypassWarnings = false,
  }) async {
    final String guid =
        (release['guid'] as String?) ?? release['title'] as String;
    final rejections =
        List<String>.from((release['rejections'] as Iterable?) ?? <String>[]);

    if (rejections.isNotEmpty && !bypassWarnings) {
      final bool? proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Theme.of(ctx).colorScheme.secondary,
              ),
              const SizedBox(width: Insets.sm),
              const Text('Rejection Warnings'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'This release has warnings / rejections:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: Insets.sm),
              ...rejections.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text('• $r', style: const TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(height: Insets.md),
              const Text('Are you sure you want to download it anyway?'),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Proceed Download'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => _downloadingMap[guid] = true);

    try {
      final api = await ref.read(radarrApiProvider(widget.instance).future);
      await api.downloadRelease(release);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Release grabbed successfully!')),
        );
        ref.invalidate(
            radarrMovieByIdProvider((widget.instance, widget.movie.id)));
        ref.invalidate(radarrQueueProvider(widget.instance));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to grab release: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _downloadingMap[guid] = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Map<String, dynamic>>> releasesValue = ref.watch(
      radarrReleasesProvider((widget.instance, widget.movie.id)),
    );

    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Interactive Search'),
            Text(
              widget.movie.title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: <Widget>[
          Card(
            margin: const EdgeInsets.all(Insets.md),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.lg),
              side: BorderSide(
                color: colors.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            color: colors.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: Column(
                children: <Widget>[
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Filter by title or indexer...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(Radii.md),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor:
                          colors.surfaceContainerHighest.withValues(alpha: 0.5),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: Insets.md,
                        vertical: Insets.sm,
                      ),
                    ),
                    onChanged: (String val) =>
                        setState(() => _searchQuery = val),
                  ),
                  const SizedBox(height: Insets.md),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedProtocol,
                          decoration: InputDecoration(
                            labelText: 'Protocol',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(Radii.md),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'All', child: Text('All')),
                            DropdownMenuItem(
                              value: 'Torrent',
                              child: Text('Torrent'),
                            ),
                            DropdownMenuItem(
                              value: 'Usenet',
                              child: Text('Usenet'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedProtocol = val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: Insets.sm),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _sortBy,
                          decoration: InputDecoration(
                            labelText: 'Sort By',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(Radii.md),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Age', child: Text('Age')),
                            DropdownMenuItem(
                              value: 'Size',
                              child: Text('Size'),
                            ),
                            DropdownMenuItem(
                              value: 'Seeders',
                              child: Text('Seeders'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _sortBy = val;
                                _sortAscending = val != 'Seeders';
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: Insets.sm),
                      IconButton.filledTonal(
                        icon: Icon(
                          _sortAscending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                        ),
                        tooltip: 'Toggle Sort Order',
                        onPressed: () =>
                            setState(() => _sortAscending = !_sortAscending),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.xs),
                  CheckboxListTile(
                    title: const Text(
                      'Approved Releases Only',
                      style: TextStyle(fontSize: 14),
                    ),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: _approvedOnly,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _approvedOnly = val);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ScrollConfiguration(
              behavior: _ScrollBehavior(),
              child: AsyncValueView<List<Map<String, dynamic>>>(
                value: releasesValue,
                onRetry: () {
                  ref.invalidate(
                    radarrReleasesProvider(
                      (widget.instance, widget.movie.id),
                    ),
                  );
                },
                data: (releases) {
                  final filtered = releases.where((r) {
                    final String title =
                        (r['title'] as String?)?.toLowerCase() ?? '';
                    final String indexer =
                        (r['indexer'] as String?)?.toLowerCase() ?? '';
                    final String protocol =
                        (r['protocol'] as String?)?.toLowerCase() ?? '';
                    final rejections = List<String>.from(
                      (r['rejections'] as Iterable?) ?? <String>[],
                    );

                    if (_searchQuery.isNotEmpty) {
                      final q = _searchQuery.toLowerCase();
                      if (!title.contains(q) && !indexer.contains(q)) {
                        return false;
                      }
                    }
                    if (_selectedProtocol == 'Torrent' &&
                        protocol != 'torrent') {
                      return false;
                    }
                    if (_selectedProtocol == 'Usenet' && protocol != 'usenet') {
                      return false;
                    }
                    if (_approvedOnly && rejections.isNotEmpty) return false;

                    return true;
                  }).toList();

                  filtered.sort((a, b) {
                    int result = 0;
                    if (_sortBy == 'Age') {
                      result = _getAgeMinutes(a).compareTo(_getAgeMinutes(b));
                    } else if (_sortBy == 'Size') {
                      final aSize = a['size'] as int? ?? 0;
                      final bSize = b['size'] as int? ?? 0;
                      result = aSize.compareTo(bSize);
                    } else if (_sortBy == 'Seeders') {
                      final aSeeders = a['seeders'] as int? ?? 0;
                      final bSeeders = b['seeders'] as int? ?? 0;
                      result = aSeeders.compareTo(bSeeders);
                    }
                    return _sortAscending ? result : -result;
                  });

                  if (filtered.isEmpty) {
                    return const EmptyView(
                      icon: Icons.search_off,
                      title: 'No releases found',
                      message:
                          'Try modifying your filter settings or search query.',
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: Insets.md),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final r = filtered[index];
                      final title =
                          (r['title'] as String?) ?? 'Unknown release';
                      final indexer =
                          (r['indexer'] as String?) ?? 'Unknown Indexer';
                      final sizeBytes = r['size'] as int? ?? 0;
                      final seeders = r['seeders'] as int? ?? 0;
                      final leechers = r['leechers'] as int? ?? 0;
                      final protocol =
                          (r['protocol'] as String?)?.toLowerCase() ??
                              'torrent';
                      final rejections = List<String>.from(
                        (r['rejections'] as Iterable?) ?? <String>[],
                      );
                      final isApproved = rejections.isEmpty;
                      final guid = (r['guid'] as String?) ?? title;
                      final isDownloading = _downloadingMap[guid] ?? false;

                      final Map<String, dynamic>? qualityMap =
                          r['quality'] as Map<String, dynamic>?;
                      final Map<String, dynamic>? qualityInner =
                          qualityMap?['quality'] as Map<String, dynamic>?;
                      final String qualityName =
                          (qualityInner?['name'] as String?) ?? 'SD';

                      final List<dynamic>? langs =
                          r['languages'] as List<dynamic>?;
                      final String langText = langs != null && langs.isNotEmpty
                          ? langs
                              .map((dynamic l) {
                                final Map<String, dynamic> map =
                                    l as Map<String, dynamic>;
                                return (map['name'] as String?) ?? '';
                              })
                              .where((s) => s.isNotEmpty)
                              .join(', ')
                          : '';

                      return Card(
                        margin: const EdgeInsets.only(bottom: Insets.sm),
                        clipBehavior: Clip.antiAlias,
                        color: theme.colorScheme.surfaceContainerLow,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Radii.md),
                          side: BorderSide(
                            color:
                                colors.outlineVariant.withValues(alpha: 0.25),
                          ),
                        ),
                        child: ExpansionTile(
                          shape: const Border(),
                          title: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              title,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.primaryContainer
                                          .withValues(alpha: 0.4),
                                      borderRadius:
                                          BorderRadius.circular(Radii.sm),
                                    ),
                                    child: Text(
                                      qualityName,
                                      style:
                                          theme.textTheme.labelSmall?.copyWith(
                                        color: colors.onPrimaryContainer,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (langText.isNotEmpty) ...[
                                    const SizedBox(width: Insets.xs),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.secondaryContainer
                                            .withValues(alpha: 0.4),
                                        borderRadius:
                                            BorderRadius.circular(Radii.sm),
                                      ),
                                      child: Text(
                                        langText,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: colors.onSecondaryContainer,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    protocol == 'torrent'
                                        ? Icons.cloud_download
                                        : Icons.swap_calls,
                                    size: 14,
                                    color: theme.colorScheme.outline,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '$indexer • ${_formatSize(sizeBytes)} • ${_formatAge(r)}',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.outline,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if (protocol == 'torrent')
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.arrow_upward,
                                        size: 12,
                                        color: colors.tertiary,
                                      ),
                                      Text(
                                        ' $seeders',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: colors.tertiary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: Insets.sm),
                                      Icon(
                                        Icons.arrow_downward,
                                        size: 12,
                                        color: colors.error,
                                      ),
                                      Text(
                                        ' $leechers',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: colors.error,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 6),
                            ],
                          ),
                          trailing: isDownloading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: ExpressiveProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : IconButton(
                                  icon: Icon(
                                    isApproved
                                        ? Icons.download
                                        : Icons.warning_amber_rounded,
                                    color: isApproved
                                        ? colors.primary
                                        : colors.secondary,
                                  ),
                                  onPressed: () => _download(r),
                                ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 8.0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isApproved) ...[
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          size: 16,
                                          color: colors.error,
                                        ),
                                        const SizedBox(width: Insets.xs),
                                        Text(
                                          'Rejection Reasons:',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: colors.error,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    ...rejections.map(
                                      (rej) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 2.0,
                                          left: 20.0,
                                        ),
                                        child: Text(
                                          '• $rej',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(color: colors.error),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ] else
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline,
                                          size: 16,
                                          color: colors.tertiary,
                                        ),
                                        const SizedBox(width: Insets.xs),
                                        Text(
                                          'Approved for download.',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: colors.tertiary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  const SizedBox(height: 4),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
