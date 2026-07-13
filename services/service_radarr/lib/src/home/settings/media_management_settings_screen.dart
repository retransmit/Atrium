import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../radarr_providers.dart';

class MediaManagementSettingsScreen extends ConsumerStatefulWidget {
  const MediaManagementSettingsScreen({
    required this.instance,
    super.key,
  });

  final Instance instance;

  @override
  ConsumerState<MediaManagementSettingsScreen> createState() =>
      _MediaManagementSettingsScreenState();
}

class _MediaManagementSettingsScreenState
    extends ConsumerState<MediaManagementSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _standardMovieFormatController;
  late final TextEditingController _movieFolderFormatController;
  late final TextEditingController _extraFileExtensionsController;
  late final TextEditingController _minimumFreeSpaceController;
  late final TextEditingController _recycleBinController;
  late final TextEditingController _recycleBinCleanupDaysController;
  late final TextEditingController _chmodFolderController;
  late final TextEditingController _chownGroupController;

  bool _renameMovies = false;
  bool _replaceIllegalCharacters = false;
  String _colonReplacementFormat = 'smart';

  bool _createEmptyMovieFolders = false;
  bool _deleteEmptyFolders = false;
  bool _copyUsingHardlinks = false;
  bool _importExtraFiles = false;
  bool _enableMediaInfo = false;
  bool _autoUnmonitorPreviouslyDownloadedMovies = false;
  bool _skipFreeSpaceCheckWhenImporting = false;
  bool _setPermissionsLinux = false;

  String _downloadPropersAndRepacks = 'preferAndUpgrade';
  String _fileDate = 'none';
  String _rescanAfterRefresh = 'always';

  bool _saving = false;
  bool _initialized = false;

  Map<String, dynamic>? _rawNamingConfig;
  Map<String, dynamic>? _rawMediaManagementConfig;

  @override
  void initState() {
    super.initState();
    _standardMovieFormatController = TextEditingController();
    _movieFolderFormatController = TextEditingController();
    _extraFileExtensionsController = TextEditingController();
    _minimumFreeSpaceController = TextEditingController();
    _recycleBinController = TextEditingController();
    _recycleBinCleanupDaysController = TextEditingController();
    _chmodFolderController = TextEditingController();
    _chownGroupController = TextEditingController();
  }

  @override
  void dispose() {
    _standardMovieFormatController.dispose();
    _movieFolderFormatController.dispose();
    _extraFileExtensionsController.dispose();
    _minimumFreeSpaceController.dispose();
    _recycleBinController.dispose();
    _recycleBinCleanupDaysController.dispose();
    _chmodFolderController.dispose();
    _chownGroupController.dispose();
    super.dispose();
  }

  void _initializeValues(
    Map<String, dynamic> naming,
    Map<String, dynamic> mediaMgmt,
  ) {
    if (_initialized) return;
    _initialized = true;

    _rawNamingConfig = naming;
    _rawMediaManagementConfig = mediaMgmt;

    _renameMovies = naming['renameMovies'] as bool? ?? false;
    _replaceIllegalCharacters =
        naming['replaceIllegalCharacters'] as bool? ?? false;
    _colonReplacementFormat =
        naming['colonReplacementFormat'] as String? ?? 'smart';

    _standardMovieFormatController.text =
        (naming['standardMovieFormat'] as String?) ?? '';
    _movieFolderFormatController.text =
        (naming['movieFolderFormat'] as String?) ?? '';

    _createEmptyMovieFolders =
        mediaMgmt['createEmptyMovieFolders'] as bool? ?? false;
    _deleteEmptyFolders = mediaMgmt['deleteEmptyFolders'] as bool? ?? false;
    _copyUsingHardlinks = mediaMgmt['copyUsingHardlinks'] as bool? ?? false;
    _importExtraFiles = mediaMgmt['importExtraFiles'] as bool? ?? false;
    _extraFileExtensionsController.text =
        (mediaMgmt['extraFileExtensions'] as String?) ?? '';
    _enableMediaInfo = mediaMgmt['enableMediaInfo'] as bool? ?? false;
    _minimumFreeSpaceController.text =
        (mediaMgmt['minimumFreeSpaceWhenImporting'] as int? ?? 0).toString();

    _autoUnmonitorPreviouslyDownloadedMovies =
        mediaMgmt['autoUnmonitorPreviouslyDownloadedMovies'] as bool? ?? false;
    _skipFreeSpaceCheckWhenImporting =
        mediaMgmt['skipFreeSpaceCheckWhenImporting'] as bool? ?? false;
    _setPermissionsLinux = mediaMgmt['setPermissionsLinux'] as bool? ?? false;

    _recycleBinController.text = (mediaMgmt['recycleBin'] as String?) ?? '';
    _recycleBinCleanupDaysController.text =
        (mediaMgmt['recycleBinCleanupDays'] as int? ?? 7).toString();
    _chmodFolderController.text = (mediaMgmt['chmodFolder'] as String?) ?? '';
    _chownGroupController.text = (mediaMgmt['chownGroup'] as String?) ?? '';

    _downloadPropersAndRepacks =
        (mediaMgmt['downloadPropersAndRepacks'] as String?) ??
            'preferAndUpgrade';
    _fileDate = (mediaMgmt['fileDate'] as String?) ?? 'none';
    _rescanAfterRefresh =
        (mediaMgmt['rescanAfterRefresh'] as String?) ?? 'always';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_rawNamingConfig == null || _rawMediaManagementConfig == null) return;

    setState(() => _saving = true);

    try {
      final api = await ref.read(radarrApiProvider(widget.instance).future);

      final Map<String, dynamic> namingPayload =
          Map<String, dynamic>.from(_rawNamingConfig!);
      namingPayload['renameMovies'] = _renameMovies;
      namingPayload['replaceIllegalCharacters'] = _replaceIllegalCharacters;
      namingPayload['colonReplacementFormat'] = _colonReplacementFormat;
      namingPayload['standardMovieFormat'] =
          _standardMovieFormatController.text.trim();
      namingPayload['movieFolderFormat'] =
          _movieFolderFormatController.text.trim();

      final Map<String, dynamic> mediaMgmtPayload =
          Map<String, dynamic>.from(_rawMediaManagementConfig!);
      mediaMgmtPayload['createEmptyMovieFolders'] = _createEmptyMovieFolders;
      mediaMgmtPayload['deleteEmptyFolders'] = _deleteEmptyFolders;
      mediaMgmtPayload['copyUsingHardlinks'] = _copyUsingHardlinks;
      mediaMgmtPayload['importExtraFiles'] = _importExtraFiles;
      mediaMgmtPayload['extraFileExtensions'] =
          _extraFileExtensionsController.text.trim();
      mediaMgmtPayload['enableMediaInfo'] = _enableMediaInfo;
      mediaMgmtPayload['minimumFreeSpaceWhenImporting'] =
          int.tryParse(_minimumFreeSpaceController.text.trim()) ?? 0;
      mediaMgmtPayload['autoUnmonitorPreviouslyDownloadedMovies'] =
          _autoUnmonitorPreviouslyDownloadedMovies;
      mediaMgmtPayload['skipFreeSpaceCheckWhenImporting'] =
          _skipFreeSpaceCheckWhenImporting;
      mediaMgmtPayload['setPermissionsLinux'] = _setPermissionsLinux;
      mediaMgmtPayload['recycleBin'] = _recycleBinController.text.trim();
      mediaMgmtPayload['recycleBinCleanupDays'] =
          int.tryParse(_recycleBinCleanupDaysController.text.trim()) ?? 7;
      mediaMgmtPayload['chmodFolder'] = _chmodFolderController.text.trim();
      mediaMgmtPayload['chownGroup'] = _chownGroupController.text.trim();
      mediaMgmtPayload['downloadPropersAndRepacks'] =
          _downloadPropersAndRepacks;
      mediaMgmtPayload['fileDate'] = _fileDate;
      mediaMgmtPayload['rescanAfterRefresh'] = _rescanAfterRefresh;

      await api.updateNamingConfig(namingPayload);
      await api.updateMediaManagementConfig(mediaMgmtPayload);

      ref.invalidate(radarrNamingConfigProvider(widget.instance));
      ref.invalidate(radarrMediaManagementConfigProvider(widget.instance));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Media management settings saved!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final namingConfigAsync =
        ref.watch(radarrNamingConfigProvider(widget.instance));
    final mediaMgmtConfigAsync =
        ref.watch(radarrMediaManagementConfigProvider(widget.instance));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Management'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: ExpressiveProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _save,
            ),
        ],
      ),
      body: namingConfigAsync.when(
        loading: () => const Center(child: ExpressiveProgressIndicator()),
        error: (err, _) =>
            Center(child: Text('Error loading naming settings: $err')),
        data: (naming) {
          return mediaMgmtConfigAsync.when(
            loading: () => const Center(child: ExpressiveProgressIndicator()),
            error: (err, _) =>
                Center(child: Text('Error loading media management: $err')),
            data: (mediaMgmt) {
              _initializeValues(naming, mediaMgmt);

              return Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(Insets.md),
                  children: [
                    Card(
                      elevation: 0,
                      color: theme.colorScheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side:
                            BorderSide(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(Insets.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Movie Naming',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: Insets.md),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Rename Movies'),
                              value: _renameMovies,
                              onChanged: (val) =>
                                  setState(() => _renameMovies = val),
                            ),
                            if (_renameMovies) ...[
                              const SizedBox(height: Insets.md),
                              TextFormField(
                                controller: _standardMovieFormatController,
                                decoration: const InputDecoration(
                                  labelText: 'Standard Movie Format',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: Insets.md),
                              TextFormField(
                                controller: _movieFolderFormatController,
                                decoration: const InputDecoration(
                                  labelText: 'Movie Folder Format',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: Insets.md),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Replace Illegal Characters'),
                                value: _replaceIllegalCharacters,
                                onChanged: (val) => setState(
                                    () => _replaceIllegalCharacters = val),
                              ),
                              if (_replaceIllegalCharacters) ...[
                                const SizedBox(height: Insets.md),
                                DropdownButtonFormField<String>(
                                  initialValue: _colonReplacementFormat,
                                  decoration: const InputDecoration(
                                    labelText: 'Colon Replacement Format',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'delete',
                                      child: Text('Delete'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'dash',
                                      child: Text('Dash (-)'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'spaceDash',
                                      child: Text('Space Dash ( -)'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'spaceDashSpace',
                                      child: Text('Space Dash Space ( - )'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'smart',
                                      child: Text(
                                          'Smart (Replace with Dash or Space Dash)'),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(
                                          () => _colonReplacementFormat = val);
                                    }
                                  },
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.md),
                    Card(
                      elevation: 0,
                      color: theme.colorScheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side:
                            BorderSide(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(Insets.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'File Management',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: Insets.md),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Create Empty Movie Folders'),
                              value: _createEmptyMovieFolders,
                              onChanged: (val) => setState(
                                  () => _createEmptyMovieFolders = val),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Delete Empty Folders'),
                              value: _deleteEmptyFolders,
                              onChanged: (val) =>
                                  setState(() => _deleteEmptyFolders = val),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title:
                                  const Text('Use Hardlinks instead of Copy'),
                              value: _copyUsingHardlinks,
                              onChanged: (val) =>
                                  setState(() => _copyUsingHardlinks = val),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Import Extra Files'),
                              value: _importExtraFiles,
                              onChanged: (val) =>
                                  setState(() => _importExtraFiles = val),
                            ),
                            if (_importExtraFiles) ...[
                              const SizedBox(height: Insets.md),
                              TextFormField(
                                controller: _extraFileExtensionsController,
                                decoration: const InputDecoration(
                                  labelText: 'Extra File Extensions',
                                  helperText: 'Comma separated e.g. srt, nfo',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.md),
                    Card(
                      elevation: 0,
                      color: theme.colorScheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side:
                            BorderSide(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(Insets.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Permissions',
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: Insets.md),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Set Permissions Linux'),
                              value: _setPermissionsLinux,
                              onChanged: (val) =>
                                  setState(() => _setPermissionsLinux = val),
                            ),
                            if (_setPermissionsLinux) ...[
                              const SizedBox(height: Insets.md),
                              TextFormField(
                                controller: _chmodFolderController,
                                decoration: const InputDecoration(
                                  labelText: 'Folder CHMOD',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: Insets.md),
                              TextFormField(
                                controller: _chownGroupController,
                                decoration: const InputDecoration(
                                  labelText: 'Group CHOWN',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
