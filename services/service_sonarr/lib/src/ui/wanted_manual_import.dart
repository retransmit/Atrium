part of '../sonarr_home.dart';

class _WantedManualImportSubTab extends ConsumerStatefulWidget {
  const _WantedManualImportSubTab({required this.instance});

  final Instance instance;

  @override
  ConsumerState<_WantedManualImportSubTab> createState() =>
      _WantedManualImportSubTabState();
}

class _WantedManualImportSubTabState
    extends ConsumerState<_WantedManualImportSubTab> with WidgetsBindingObserver {
  final TextEditingController _folderController = TextEditingController();
  final TextEditingController _downloadIdController = TextEditingController();
  late final FocusNode _folderFocusNode;
  late final FocusNode _downloadIdFocusNode;
  double _lastBottomInset = 0;
  bool _filterExistingFiles = true;
  bool _isScanning = false;
  bool _isImporting = false;
  List<SonarrManualImport>? _scanResults;
  final Set<int> _selectedIds = <int>{};
  final Map<int, SonarrManualImportReprocess> _customizations =
      <int, SonarrManualImportReprocess>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _folderFocusNode = FocusNode();
    _downloadIdFocusNode = FocusNode();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (mounted) {
      _lastBottomInset = View.of(context).viewInsets.bottom / View.of(context).devicePixelRatio;
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) return;
    final double bottomInset = View.of(context).viewInsets.bottom / View.of(context).devicePixelRatio;
    if (bottomInset == 0 && _lastBottomInset > 0) {
      // Keyboard went from open to closed
      final bool hadFocus = _folderFocusNode.hasFocus || _downloadIdFocusNode.hasFocus;
      if (_folderFocusNode.hasFocus) {
        _folderFocusNode.unfocus();
      }
      if (_downloadIdFocusNode.hasFocus) {
        _downloadIdFocusNode.unfocus();
      }
      if (hadFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ScrollController? controller = PrimaryScrollController.maybeOf(context);
          if (controller != null && controller.hasClients) {
            controller.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
            );
          }
        });
      }
    }
    _lastBottomInset = bottomInset;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _folderFocusNode.dispose();
    _downloadIdFocusNode.dispose();
    _folderController.dispose();
    _downloadIdController.dispose();
    super.dispose();
  }

  Future<void> _pickRootFolder() async {
    try {
      final SonarrApi api = await ref.read(sonarrApiProvider(widget.instance).future);
      final List<SonarrRootFolder> folders = await api.getRootFolders();
      if (!mounted) return;
      if (folders.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No root folders configured in Sonarr.')),
        );
        return;
      }
      final SonarrRootFolder? picked = await showDialog<SonarrRootFolder>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Select Root Folder'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: folders.length,
                itemBuilder: (BuildContext context, int index) {
                  final f = folders[index];
                  return ListTile(
                    title: Text(f.path),
                    subtitle: Text('Free: ${_formatBytes(f.freeSpace)}'),
                    onTap: () => Navigator.pop(context, f),
                  );
                },
              ),
            ),
          );
        },
      );

      if (picked != null) {
        setState(() {
          _folderController.text = picked.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching root folders: $e')),
        );
      }
    }
  }

  Future<void> _runScan() async {
    final String folder = _folderController.text.trim();
    final String downloadId = _downloadIdController.text.trim();
    if (folder.isEmpty && downloadId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please specify a Folder Path or a Download ID to scan.')),
      );
      return;
    }

    setState(() {
      _isScanning = true;
      _scanResults = null;
      _selectedIds.clear();
      _customizations.clear();
    });

    try {
      final SonarrApi api = await ref.read(sonarrApiProvider(widget.instance).future);
      final List<SonarrManualImport> results = await api.getManualImports(
        folder: folder.isNotEmpty ? folder : null,
        downloadId: downloadId.isNotEmpty ? downloadId : null,
        filterExistingFiles: _filterExistingFiles,
      );

      setState(() {
        _scanResults = results;
        for (final item in results) {
          if (item.rejections == null || item.rejections!.isEmpty) {
            _selectedIds.add(item.id);
          }
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  Future<void> _executeImport() async {
    if (_selectedIds.isEmpty || _scanResults == null) return;
    setState(() {
      _isImporting = true;
    });

    try {
      final List<SonarrManualImportReprocess> payload = [];
      for (final item in _scanResults!) {
        if (!_selectedIds.contains(item.id)) continue;
        
        final customized = _customizations[item.id];
        if (customized != null) {
          payload.add(customized);
        } else {
          payload.add(
            SonarrManualImportReprocess(
              id: item.id,
              path: item.path,
              seriesId: item.series?.id ?? 0,
              seasonNumber: item.seasonNumber,
              episodes: item.episodes,
              episodeIds: item.episodes?.map((e) => e.id).toList(),
              quality: item.quality,
              languages: item.languages,
              releaseGroup: item.releaseGroup,
              downloadId: item.downloadId,
              customFormats: item.customFormats,
              customFormatScore: item.customFormatScore,
              indexerFlags: item.indexerFlags,
              releaseType: item.releaseType,
              rejections: item.rejections,
            ),
          );
        }
      }

      final missingSeries = payload.any((item) => item.seriesId == 0);
      if (missingSeries) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please assign a Series to all selected files.')),
        );
        setState(() {
          _isImporting = false;
        });
        return;
      }

      final SonarrApi api = await ref.read(sonarrApiProvider(widget.instance).future);
      final List<dynamic> reprocessed = await api.reprocessManualImports(payload);
      final List<dynamic> files = reprocessed.map((dynamic e) {
        final m = e as Map<String, dynamic>;
        return <String, dynamic>{
          'path': m['path'],
          'folderName': m['folderName'],
          'seriesId': (m['series'] as Map<String, dynamic>?)?['id'],
          'episodeIds': ((m['episodes'] as List<dynamic>?) ?? const <dynamic>[])
              .map((dynamic ep) => (ep as Map<String, dynamic>)['id'])
              .toList(),
          'quality': m['quality'],
          'languages': m['languages'],
          'releaseGroup': m['releaseGroup'],
          'downloadId': m['downloadId'],
          'indexerFlags': m['indexerFlags'],
          'releaseType': m['releaseType'],
        };
      }).toList();
      await api.manualImport(files: files);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Manual import triggered successfully!')),
        );
        setState(() {
          _scanResults = null;
          _selectedIds.clear();
          _customizations.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  void _editAssignment(SonarrManualImport item) {
    final current = _customizations[item.id] ??
        SonarrManualImportReprocess(
          id: item.id,
          path: item.path,
          seriesId: item.series?.id ?? 0,
          seasonNumber: item.seasonNumber,
          episodes: item.episodes,
          episodeIds: item.episodes?.map((e) => e.id).toList() ?? const [],
          quality: item.quality,
          languages: item.languages,
          releaseGroup: item.releaseGroup,
          downloadId: item.downloadId,
          customFormats: item.customFormats,
          customFormatScore: item.customFormatScore,
          indexerFlags: item.indexerFlags,
          releaseType: item.releaseType,
          rejections: item.rejections,
        );

    showModalBottomSheet<SonarrManualImportReprocess>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (BuildContext context) {
        return _AssignmentEditorSheet(
          instance: widget.instance,
          item: item,
          current: current,
        );
      },
    ).then((updated) {
      if (updated != null && mounted) {
        setState(() {
          _customizations[item.id] = updated;
          _selectedIds.add(item.id);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return NotificationListener<ScrollStartNotification>(
      onNotification: (ScrollStartNotification notification) {
        if (notification.dragDetails != null) {
          FocusScope.of(context).unfocus();
        }
        return false;
      },
      child: CustomScrollView(
        slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.md),
          sliver: SliverToBoxAdapter(
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _folderController,
                            focusNode: _folderFocusNode,
                            scrollPadding: const EdgeInsets.only(top: 140, bottom: 40),
                            decoration: InputDecoration(
                              labelText: 'Folder Path',
                              hintText: 'e.g. /data/downloads',
                              border: const OutlineInputBorder(),
                              isDense: true,
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.folder_open),
                                onPressed: _pickRootFolder,
                                tooltip: 'Use configured root folder',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Insets.sm),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _downloadIdController,
                            focusNode: _downloadIdFocusNode,
                            scrollPadding: const EdgeInsets.only(top: 140, bottom: 40),
                            decoration: const InputDecoration(
                              labelText: 'Download ID (optional)',
                              hintText: 'e.g. torrent hash or Usenet ID',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Insets.xs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Checkbox(
                              value: _filterExistingFiles,
                              onChanged: (bool? val) {
                                if (val != null) {
                                  setState(() {
                                    _filterExistingFiles = val;
                                  });
                                }
                              },
                            ),
                            Text(
                              'Filter existing files',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                        _isScanning
                            ? const Padding(
                                padding: EdgeInsets.only(right: 16),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : FilledButton(
                                onPressed: _runScan,
                                child: const Text('Scan Folder'),
                              ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        ..._buildResultsSlivers(theme, colors),
      ],
    ),
    );
  }

  List<Widget> _buildResultsSlivers(ThemeData theme, ColorScheme colors) {
    if (_scanResults == null) {
      return <Widget>[
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: EmptyView(
              icon: Icons.folder_open,
              title: 'Manual Import',
              message: 'Specify a folder to scan for files to import manually.',
            ),
          ),
        ),
      ];
    }

    if (_scanResults!.isEmpty) {
      return <Widget>[
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: EmptyView(
              icon: Icons.search_off,
              title: 'No files found',
              message: 'No importable files found in the specified path.',
            ),
          ),
        ),
      ];
    }

    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.only(left: Insets.lg, right: Insets.lg, bottom: Insets.sm),
        sliver: SliverToBoxAdapter(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Found ${_scanResults!.length} files',
                style: theme.textTheme.titleSmall?.copyWith(color: colors.outline),
              ),
              Row(
                children: <Widget>[
                  TextButton(
                    onPressed: () {
                      setState(() {
                        for (final item in _scanResults!) {
                          _selectedIds.add(item.id);
                        }
                      });
                    },
                    child: const Text('Select All'),
                  ),
                  TextButton(
                    onPressed: () => setState(_selectedIds.clear),
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              final item = _scanResults![index];
              final customized = _customizations[item.id];
              final isSelected = _selectedIds.contains(item.id);

              String mappingText = 'Unknown Series';
              bool isMapped = false;
              if (customized != null) {
                if (customized.seriesId != 0) {
                  isMapped = true;
                  final String epText = customized.episodeIds != null && customized.episodeIds!.isNotEmpty
                      ? 'Episodes ${customized.episodeIds!.join(', ')}'
                      : (customized.seasonNumber != null ? 'Season ${customized.seasonNumber}' : 'Mapped');
                  mappingText = epText;
                }
              } else if (item.series != null) {
                isMapped = true;
                final String epText = item.episodes != null && item.episodes!.isNotEmpty
                    ? 'S${item.seasonNumber?.toString().padLeft(2, '0') ?? '00'}E${item.episodes!.map((e) => e.episodeNumber).join(', ')}'
                    : (item.seasonNumber != null ? 'Season ${item.seasonNumber}' : 'Mapped');
                mappingText = '${item.series!.title} - $epText';
              }

              final qualityName = customized?.quality?.quality?.name ?? item.quality?.quality?.name ?? 'Unknown Quality';
              final languageName = customized?.languages != null && customized!.languages!.isNotEmpty
                  ? customized.languages!.map((l) => l.name ?? '').join(', ')
                  : (item.languages != null && item.languages!.isNotEmpty
                      ? item.languages!.map((l) => l.name ?? '').join(', ')
                      : 'Unknown Language');

              return Card(
                margin: const EdgeInsets.only(bottom: Insets.sm),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected
                        ? colors.primary
                        : colors.outlineVariant.withValues(alpha: 0.5),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(Insets.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Checkbox(
                        value: isSelected,
                        onChanged: (bool? val) {
                          if (val != null) {
                            setState(() {
                              if (val) {
                                _selectedIds.add(item.id);
                              } else {
                                _selectedIds.remove(item.id);
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(width: Insets.xs),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              item.name ?? 'File ${item.id}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.path ?? '',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.outline,
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: Insets.xs,
                              runSpacing: Insets.xs,
                              children: <Widget>[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _formatBytes(item.size),
                                    style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isMapped
                                        ? Colors.green.withValues(alpha: 0.15)
                                        : colors.error.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isMapped
                                          ? Colors.green.withValues(alpha: 0.3)
                                          : colors.error.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    customized != null && customized.seriesId != 0
                                        ? 'Custom: $mappingText'
                                        : mappingText,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: isMapped ? Colors.green[800] : colors.error,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '$qualityName • $languageName',
                                    style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
                                  ),
                                ),
                              ],
                            ),
                            if (item.rejections != null && item.rejections!.isNotEmpty) ...<Widget>[
                              const SizedBox(height: Insets.sm),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(Insets.xs),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.orange.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  item.rejections!.map((r) => '• ${r.reason ?? "Rejected"}').join('\n'),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.orange[800],
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: Insets.xs),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _editAssignment(item),
                        tooltip: 'Edit Assignment',
                      ),
                    ],
                  ),
                ),
              );
            },
            childCount: _scanResults!.length,
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.only(left: Insets.lg, right: Insets.lg, top: Insets.sm, bottom: 100),
        sliver: SliverToBoxAdapter(
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: _isImporting
                  ? const Center(child: CircularProgressIndicator())
                  : FilledButton.icon(
                      onPressed: _selectedIds.isEmpty ? null : _executeImport,
                      icon: const Icon(Icons.download),
                      label: Text('Import ${_selectedIds.length} Selected Files'),
                    ),
            ),
          ),
        ),
      ),
    ];
  }
}

class _AssignmentEditorSheet extends ConsumerStatefulWidget {
  const _AssignmentEditorSheet({
    required this.instance,
    required this.item,
    required this.current,
  });

  final Instance instance;
  final SonarrManualImport item;
  final SonarrManualImportReprocess current;

  @override
  ConsumerState<_AssignmentEditorSheet> createState() =>
      __AssignmentEditorSheetState();
}

class __AssignmentEditorSheetState extends ConsumerState<_AssignmentEditorSheet> {
  int? _seriesId;
  String _seriesTitle = 'Select Series';
  int? _seasonNumber;
  List<int> _episodeIds = [];
  SonarrQualityModel? _quality;
  List<SonarrLanguage>? _languages;

  @override
  void initState() {
    super.initState();
    _seriesId = widget.current.seriesId != 0 ? widget.current.seriesId : widget.item.series?.id;
    _seriesTitle = widget.current.seriesId != 0
        ? (widget.item.series?.id == widget.current.seriesId ? (widget.item.series?.title ?? 'Mapped Series') : 'Selected Series')
        : (widget.item.series?.title ?? 'Select Series');
    _seasonNumber = widget.current.seasonNumber ?? widget.item.seasonNumber;
    _episodeIds = List<int>.from(widget.current.episodeIds ?? widget.item.episodes?.map((e) => e.id).toList() ?? <int>[]);
    _quality = widget.current.quality ?? widget.item.quality;
    _languages = widget.current.languages ?? widget.item.languages;
  }

  Future<void> _selectSeries() async {
    final SonarrSeries? selected = await showModalBottomSheet<SonarrSeries>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (BuildContext context) {
        return _SeriesSelectionSheet(instance: widget.instance);
      },
    );

    if (selected != null && mounted) {
      setState(() {
        _seriesId = selected.id;
        _seriesTitle = selected.title;
        _episodeIds = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final AsyncValue<List<SonarrQualityDefinition>> qualitiesVal =
        ref.watch(sonarrQualityDefinitionsProvider(widget.instance));

    return Padding(
      padding: EdgeInsets.only(
        left: Insets.lg,
        right: Insets.lg,
        top: Insets.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + Insets.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Customize Assignment',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Text(
            widget.item.name ?? 'File',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: colors.outline,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Divider(height: 24),
          
          Text('Series', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          InkWell(
            onTap: _selectSeries,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
              decoration: BoxDecoration(
                border: Border.all(color: colors.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _seriesTitle,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: _seriesId == null ? colors.outline : colors.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
          const SizedBox(height: Insets.md),

          Text('Season Number', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          TextFormField(
            initialValue: _seasonNumber?.toString() ?? '',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'e.g. 1',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (String val) {
              setState(() {
                _seasonNumber = int.tryParse(val);
                _episodeIds = [];
              });
            },
          ),
          const SizedBox(height: Insets.md),

          if (_seriesId != null && _seasonNumber != null) ...<Widget>[
            Text('Episodes', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: colors.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Consumer(
                  builder: (BuildContext context, WidgetRef ref, Widget? child) {
                    final AsyncValue<List<SonarrEpisode>> episodesVal =
                        ref.watch(sonarrEpisodesProvider((widget.instance, _seriesId!)));

                    return episodesVal.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(Insets.md),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (err, stack) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(Insets.md),
                          child: Text('Error: $err'),
                        ),
                      ),
                      data: (List<SonarrEpisode> list) {
                        final seasonEpisodes = list
                            .where((ep) => ep.seasonNumber == _seasonNumber)
                            .toList();

                        if (seasonEpisodes.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(Insets.md),
                              child: Text('No episodes found for this season.'),
                            ),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: seasonEpisodes.length,
                          itemBuilder: (BuildContext context, int index) {
                            final ep = seasonEpisodes[index];
                            final isChecked = _episodeIds.contains(ep.id);

                            return CheckboxListTile(
                              value: isChecked,
                              title: Text('Episode ${ep.episodeNumber}: ${ep.title ?? ""}'),
                              dense: true,
                              onChanged: (bool? val) {
                                if (val != null) {
                                  setState(() {
                                    if (val) {
                                      _episodeIds.add(ep.id);
                                    } else {
                                      _episodeIds.remove(ep.id);
                                    }
                                  });
                                }
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: Insets.md),
          ],

          Text('Quality Override', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          qualitiesVal.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Text('Error: $err'),
            data: (List<SonarrQualityDefinition> list) {
              return DropdownButtonFormField<int>(
                initialValue: _quality?.quality?.id,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                hint: const Text('Keep Original Quality'),
                items: list.map((q) {
                  return DropdownMenuItem<int>(
                    value: q.quality['id'] as int?,
                    child: Text(q.name),
                  );
                }).toList(),
                onChanged: (int? qualityId) {
                  if (qualityId != null) {
                    final definition = list.firstWhere((q) => q.quality['id'] == qualityId);
                    setState(() {
                      _quality = SonarrQualityModel(
                        quality: SonarrQuality(
                          id: qualityId,
                          name: definition.name,
                        ),
                        revision: const SonarrRevision(version: 1, real: 0),
                      );
                    });
                  }
                },
              );
            },
          ),
          const SizedBox(height: Insets.lg),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: Insets.sm),
              FilledButton(
                onPressed: _seriesId == null
                    ? null
                    : () {
                        final updated = SonarrManualImportReprocess(
                          id: widget.item.id,
                          path: widget.item.path,
                          seriesId: _seriesId!,
                          seasonNumber: _seasonNumber,
                          episodeIds: _episodeIds,
                          quality: _quality,
                          languages: _languages,
                          releaseGroup: widget.current.releaseGroup,
                          downloadId: widget.current.downloadId,
                          customFormats: widget.current.customFormats,
                          customFormatScore: widget.current.customFormatScore,
                          indexerFlags: widget.current.indexerFlags,
                          releaseType: widget.current.releaseType,
                          rejections: widget.current.rejections,
                        );
                        Navigator.pop(context, updated);
                      },
                child: const Text('Apply Assignment'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SeriesSelectionSheet extends ConsumerStatefulWidget {
  const _SeriesSelectionSheet({required this.instance});

  final Instance instance;

  @override
  ConsumerState<_SeriesSelectionSheet> createState() => __SeriesSelectionSheetState();
}

class __SeriesSelectionSheetState extends ConsumerState<_SeriesSelectionSheet> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<SonarrSeries>> seriesVal = ref.watch(sonarrSeriesProvider(widget.instance));

    return Padding(
      padding: const EdgeInsets.all(Insets.lg),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Select Mapped Series',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Search Library Series',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (String val) {
              setState(() {
                _searchQuery = val.trim().toLowerCase();
              });
            },
          ),
          const SizedBox(height: Insets.md),
          Expanded(
            child: seriesVal.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (List<SonarrSeries> list) {
                final filtered = list.where((s) {
                  return s.title.toLowerCase().contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No series match your search.'));
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (BuildContext context, int index) {
                    final s = filtered[index];
                    return ListTile(
                      title: Text(s.title),
                      subtitle: Text('${s.year ?? "Unknown Year"} • ${s.network ?? "Unknown Network"}'),
                      onTap: () => Navigator.pop(context, s),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
