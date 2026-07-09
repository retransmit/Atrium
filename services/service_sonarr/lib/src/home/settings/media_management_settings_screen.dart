import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sonarr_providers.dart';

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

  // Naming controller state
  late final TextEditingController _standardEpisodeController;
  late final TextEditingController _dailyEpisodeController;
  late final TextEditingController _animeEpisodeController;
  late final TextEditingController _seriesFolderController;
  late final TextEditingController _seasonFolderController;
  late final TextEditingController _specialsFolderController;

  // Naming config options
  bool _renameEpisodes = false;
  bool _replaceIllegalCharacters = false;
  int _colonReplacementFormat = 4;

  // Media management config state
  bool _createEmptySeriesFolders = false;
  bool _deleteEmptyFolders = false;
  bool _copyUsingHardlinks = false;
  bool _importExtraFiles = false;
  late final TextEditingController _extraFileExtensionsController;
  bool _enableMediaInfo = false;
  late final TextEditingController _minimumFreeSpaceController;
  bool _autoUnmonitorPreviouslyDownloadedEpisodes = false;
  bool _skipFreeSpaceCheckWhenImporting = false;
  bool _setPermissionsLinux = false;

  late final TextEditingController _recycleBinController;
  late final TextEditingController _recycleBinCleanupDaysController;
  late final TextEditingController _chmodFolderController;
  late final TextEditingController _chownGroupController;

  String _downloadPropersAndRepacks = 'preferAndUpgrade';
  String _fileDate = 'none';
  String _rescanAfterRefresh = 'always';
  String _episodeTitleRequired = 'always';

  bool _saving = false;
  bool _initialized = false;

  // Raw configs for PUT payloads
  Map<String, dynamic>? _rawNamingConfig;
  Map<String, dynamic>? _rawMediaManagementConfig;

  @override
  void initState() {
    super.initState();
    _standardEpisodeController = TextEditingController();
    _dailyEpisodeController = TextEditingController();
    _animeEpisodeController = TextEditingController();
    _seriesFolderController = TextEditingController();
    _seasonFolderController = TextEditingController();
    _specialsFolderController = TextEditingController();
    _extraFileExtensionsController = TextEditingController();
    _minimumFreeSpaceController = TextEditingController();
    _recycleBinController = TextEditingController();
    _recycleBinCleanupDaysController = TextEditingController();
    _chmodFolderController = TextEditingController();
    _chownGroupController = TextEditingController();
  }

  @override
  void dispose() {
    _standardEpisodeController.dispose();
    _dailyEpisodeController.dispose();
    _animeEpisodeController.dispose();
    _seriesFolderController.dispose();
    _seasonFolderController.dispose();
    _specialsFolderController.dispose();
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

    _renameEpisodes = naming['renameEpisodes'] as bool? ?? false;
    _replaceIllegalCharacters =
        naming['replaceIllegalCharacters'] as bool? ?? false;
    _colonReplacementFormat = naming['colonReplacementFormat'] as int? ?? 4;

    _standardEpisodeController.text =
        (naming['standardEpisodeFormat'] as String?) ?? '';
    _dailyEpisodeController.text =
        (naming['dailyEpisodeFormat'] as String?) ?? '';
    _animeEpisodeController.text =
        (naming['animeEpisodeFormat'] as String?) ?? '';
    _seriesFolderController.text =
        (naming['seriesFolderFormat'] as String?) ?? '';
    _seasonFolderController.text =
        (naming['seasonFolderFormat'] as String?) ?? '';
    _specialsFolderController.text =
        (naming['specialsFolderFormat'] as String?) ?? '';

    _createEmptySeriesFolders =
        mediaMgmt['createEmptySeriesFolders'] as bool? ?? false;
    _deleteEmptyFolders = mediaMgmt['deleteEmptyFolders'] as bool? ?? false;
    _copyUsingHardlinks = mediaMgmt['copyUsingHardlinks'] as bool? ?? false;
    _importExtraFiles = mediaMgmt['importExtraFiles'] as bool? ?? false;
    _extraFileExtensionsController.text =
        (mediaMgmt['extraFileExtensions'] as String?) ?? '';
    _enableMediaInfo = mediaMgmt['enableMediaInfo'] as bool? ?? false;
    _minimumFreeSpaceController.text =
        (mediaMgmt['minimumFreeSpaceWhenImporting'] as int? ?? 0).toString();

    _autoUnmonitorPreviouslyDownloadedEpisodes =
        mediaMgmt['autoUnmonitorPreviouslyDownloadedEpisodes'] as bool? ??
            false;
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
    _episodeTitleRequired =
        (mediaMgmt['episodeTitleRequired'] as String?) ?? 'always';
  }

  /// Builds dropdown items from known [options] (value to label) and appends
  /// the current server [value] as a raw extra item when it is not among the
  /// known ones, so the dropdown never hits the missing-value assert.
  static List<DropdownMenuItem<String>> _dropdownItems(
    Map<String, String> options,
    String value,
  ) {
    return [
      for (final entry in options.entries)
        DropdownMenuItem(value: entry.key, child: Text(entry.value)),
      if (!options.containsKey(value))
        DropdownMenuItem(value: value, child: Text(value)),
    ];
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_rawNamingConfig == null || _rawMediaManagementConfig == null) return;

    setState(() => _saving = true);

    try {
      final api = await ref.read(sonarrApiProvider(widget.instance).future);

      // 1. Prepare naming update payload
      final Map<String, dynamic> namingPayload =
          Map<String, dynamic>.from(_rawNamingConfig!);
      namingPayload['renameEpisodes'] = _renameEpisodes;
      namingPayload['replaceIllegalCharacters'] = _replaceIllegalCharacters;
      namingPayload['colonReplacementFormat'] = _colonReplacementFormat;
      namingPayload['standardEpisodeFormat'] =
          _standardEpisodeController.text.trim();
      namingPayload['dailyEpisodeFormat'] = _dailyEpisodeController.text.trim();
      namingPayload['animeEpisodeFormat'] = _animeEpisodeController.text.trim();
      namingPayload['seriesFolderFormat'] = _seriesFolderController.text.trim();
      namingPayload['seasonFolderFormat'] = _seasonFolderController.text.trim();
      namingPayload['specialsFolderFormat'] =
          _specialsFolderController.text.trim();

      // 2. Prepare media management update payload
      final Map<String, dynamic> mediaMgmtPayload =
          Map<String, dynamic>.from(_rawMediaManagementConfig!);
      mediaMgmtPayload['createEmptySeriesFolders'] = _createEmptySeriesFolders;
      mediaMgmtPayload['deleteEmptyFolders'] = _deleteEmptyFolders;
      mediaMgmtPayload['copyUsingHardlinks'] = _copyUsingHardlinks;
      mediaMgmtPayload['importExtraFiles'] = _importExtraFiles;
      mediaMgmtPayload['extraFileExtensions'] =
          _extraFileExtensionsController.text.trim();
      mediaMgmtPayload['enableMediaInfo'] = _enableMediaInfo;
      mediaMgmtPayload['minimumFreeSpaceWhenImporting'] =
          int.tryParse(_minimumFreeSpaceController.text.trim()) ?? 0;

      mediaMgmtPayload['autoUnmonitorPreviouslyDownloadedEpisodes'] =
          _autoUnmonitorPreviouslyDownloadedEpisodes;
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
      mediaMgmtPayload['episodeTitleRequired'] = _episodeTitleRequired;

      // 3. Dispatch calls
      await api.updateNamingConfig(namingPayload);
      await api.updateMediaManagementConfig(mediaMgmtPayload);

      // Invalidate providers
      ref.invalidate(sonarrNamingConfigProvider(widget.instance));
      ref.invalidate(sonarrMediaManagementConfigProvider(widget.instance));

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
    final namingAsync = ref.watch(sonarrNamingConfigProvider(widget.instance));
    final mediaMgmtAsync =
        ref.watch(sonarrMediaManagementConfigProvider(widget.instance));

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
      body: namingAsync.when(
        loading: () => const Center(child: ExpressiveProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (naming) {
          return mediaMgmtAsync.when(
            loading: () => const Center(child: ExpressiveProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
            data: (mediaMgmt) {
              _initializeValues(naming, mediaMgmt);

              return Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(Insets.md),
                  children: [
                    // --- Naming Section ---
                    Card(
                      margin: const EdgeInsets.only(bottom: Insets.md),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                        borderRadius: Radii.card,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(Insets.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Episode Naming',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: Insets.md),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Rename Episodes'),
                              subtitle: const Text(
                                'Change episode file names based on naming format',
                              ),
                              value: _renameEpisodes,
                              onChanged: (val) =>
                                  setState(() => _renameEpisodes = val),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Replace Illegal Characters'),
                              subtitle: const Text(
                                'Sanitize standard OS invalid filename characters',
                              ),
                              value: _replaceIllegalCharacters,
                              onChanged: (val) => setState(
                                () => _replaceIllegalCharacters = val,
                              ),
                            ),
                            const SizedBox(height: Insets.sm),
                            DropdownButtonFormField<int>(
                              initialValue: _colonReplacementFormat,
                              decoration: const InputDecoration(
                                labelText: 'Colon Replacement Format',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: 0,
                                  child: Text('Delete'),
                                ),
                                const DropdownMenuItem(
                                  value: 1,
                                  child: Text('Replace with Space'),
                                ),
                                const DropdownMenuItem(
                                  value: 2,
                                  child: Text('Replace with Dash'),
                                ),
                                const DropdownMenuItem(
                                  value: 3,
                                  child: Text('Replace with Space Dash Space'),
                                ),
                                const DropdownMenuItem(
                                  value: 4,
                                  child: Text('Smart Replace'),
                                ),
                                if (_colonReplacementFormat < 0 ||
                                    _colonReplacementFormat > 4)
                                  DropdownMenuItem(
                                    value: _colonReplacementFormat,
                                    child: Text('$_colonReplacementFormat'),
                                  ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _colonReplacementFormat = val);
                                }
                              },
                            ),
                            if (_renameEpisodes) ...[
                              const SizedBox(height: Insets.md),
                              TextFormField(
                                controller: _standardEpisodeController,
                                decoration: const InputDecoration(
                                  labelText: 'Standard Episode Format',
                                  border: OutlineInputBorder(),
                                  helperText:
                                      'e.g. {Series Title} - S{season:00}E{episode:00} - {Episode Title}',
                                ),
                              ),
                              const SizedBox(height: Insets.md),
                              TextFormField(
                                controller: _dailyEpisodeController,
                                decoration: const InputDecoration(
                                  labelText: 'Daily Episode Format',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: Insets.md),
                              TextFormField(
                                controller: _animeEpisodeController,
                                decoration: const InputDecoration(
                                  labelText: 'Anime Episode Format',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                            const SizedBox(height: Insets.md),
                            TextFormField(
                              controller: _seriesFolderController,
                              decoration: const InputDecoration(
                                labelText: 'Series Folder Format',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: Insets.md),
                            TextFormField(
                              controller: _seasonFolderController,
                              decoration: const InputDecoration(
                                labelText: 'Season Folder Format',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: Insets.md),
                            TextFormField(
                              controller: _specialsFolderController,
                              decoration: const InputDecoration(
                                labelText: 'Specials Folder Format',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // --- Folders & Importing Section ---
                    Card(
                      margin: const EdgeInsets.only(bottom: Insets.md),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                        borderRadius: Radii.card,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(Insets.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Folders & Importing',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: Insets.md),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Create Empty Series Folders'),
                              subtitle: const Text(
                                'Create directories automatically on disk scanner activity',
                              ),
                              value: _createEmptySeriesFolders,
                              onChanged: (val) => setState(
                                  () => _createEmptySeriesFolders = val),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Delete Empty Folders'),
                              subtitle: const Text(
                                'Remove folders that have no media assets remaining',
                              ),
                              value: _deleteEmptyFolders,
                              onChanged: (val) =>
                                  setState(() => _deleteEmptyFolders = val),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title:
                                  const Text('Use Hardlinks instead of Copy'),
                              subtitle: const Text(
                                'Highly recommended for same-pool storage seeding setups',
                              ),
                              value: _copyUsingHardlinks,
                              onChanged: (val) =>
                                  setState(() => _copyUsingHardlinks = val),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Auto Unmonitor Previously Downloaded',
                              ),
                              subtitle: const Text(
                                'Unmonitor episodes once they have been deleted from disk',
                              ),
                              value: _autoUnmonitorPreviouslyDownloadedEpisodes,
                              onChanged: (val) => setState(
                                () =>
                                    _autoUnmonitorPreviouslyDownloadedEpisodes =
                                        val,
                              ),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Skip Free Space Check When Importing',
                              ),
                              value: _skipFreeSpaceCheckWhenImporting,
                              onChanged: (val) => setState(
                                () => _skipFreeSpaceCheckWhenImporting = val,
                              ),
                            ),
                            const SizedBox(height: Insets.sm),
                            TextFormField(
                              controller: _minimumFreeSpaceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Minimum Free Space (MB)',
                                border: OutlineInputBorder(),
                                helperText:
                                    'Prevent imports if free space drops below threshold',
                              ),
                              validator: (val) {
                                if (val != null &&
                                    int.tryParse(val.trim()) == null) {
                                  return 'Must be a valid integer';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: Insets.md),
                            DropdownButtonFormField<String>(
                              initialValue: _downloadPropersAndRepacks,
                              decoration: const InputDecoration(
                                labelText: 'Propers and Repacks',
                                border: OutlineInputBorder(),
                              ),
                              items: _dropdownItems(
                                const {
                                  'preferAndUpgrade': 'Prefer and Upgrade',
                                  'doNotUpgrade':
                                      'Do Not Upgrade Automatically',
                                  'doNotPrefer': 'Do Not Prefer',
                                },
                                _downloadPropersAndRepacks,
                              ),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(
                                      () => _downloadPropersAndRepacks = val);
                                }
                              },
                            ),
                            const SizedBox(height: Insets.md),
                            DropdownButtonFormField<String>(
                              initialValue: _episodeTitleRequired,
                              decoration: const InputDecoration(
                                labelText: 'Episode Title Required',
                                border: OutlineInputBorder(),
                              ),
                              items: _dropdownItems(
                                const {
                                  'always': 'Always',
                                  'bulkSeasonReleases':
                                      'Only for Bulk Season Releases',
                                  'never': 'Never',
                                },
                                _episodeTitleRequired,
                              ),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _episodeTitleRequired = val);
                                }
                              },
                            ),
                            const SizedBox(height: Insets.md),
                            DropdownButtonFormField<String>(
                              initialValue: _fileDate,
                              decoration: const InputDecoration(
                                labelText: 'File Date',
                                border: OutlineInputBorder(),
                              ),
                              items: _dropdownItems(
                                const {
                                  'none': 'None',
                                  'localAirDate': 'Local Air Date',
                                  'utcAirDate': 'UTC Air Date',
                                },
                                _fileDate,
                              ),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _fileDate = val);
                                }
                              },
                            ),
                            const SizedBox(height: Insets.md),
                            DropdownButtonFormField<String>(
                              initialValue: _rescanAfterRefresh,
                              decoration: const InputDecoration(
                                labelText: 'Rescan After Refresh',
                                border: OutlineInputBorder(),
                              ),
                              items: _dropdownItems(
                                const {
                                  'always': 'Always',
                                  'afterManual': 'After Manual Refresh',
                                  'never': 'Never',
                                },
                                _rescanAfterRefresh,
                              ),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _rescanAfterRefresh = val);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    // --- Extra Files Section ---
                    Card(
                      margin: const EdgeInsets.only(bottom: Insets.md),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                        borderRadius: Radii.card,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(Insets.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Extra Files',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: Insets.md),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Import Extra Files'),
                              subtitle: const Text(
                                'Move subtitles, NFO, or metadata with video files',
                              ),
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
                                  border: OutlineInputBorder(),
                                  helperText:
                                      'Comma separated list, e.g. srt, nfo, txt',
                                ),
                              ),
                            ],
                            const SizedBox(height: Insets.md),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Enable Media Info'),
                              subtitle: const Text(
                                'Extract audio channels, video codec, and subtitle info',
                              ),
                              value: _enableMediaInfo,
                              onChanged: (val) =>
                                  setState(() => _enableMediaInfo = val),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // --- Recycle Bin Section ---
                    Card(
                      margin: const EdgeInsets.only(bottom: Insets.md),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                        borderRadius: Radii.card,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(Insets.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Recycle Bin',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: Insets.md),
                            TextFormField(
                              controller: _recycleBinController,
                              decoration: const InputDecoration(
                                labelText: 'Recycle Bin Path',
                                border: OutlineInputBorder(),
                                helperText:
                                    'Deleted files will be moved here instead of permanently deleted',
                              ),
                            ),
                            const SizedBox(height: Insets.md),
                            TextFormField(
                              controller: _recycleBinCleanupDaysController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Recycle Bin Cleanup Days',
                                border: OutlineInputBorder(),
                                helperText:
                                    'Number of days before files are purged. Use 0 to disable.',
                              ),
                              validator: (val) {
                                if (val != null &&
                                    int.tryParse(val.trim()) == null) {
                                  return 'Must be a valid integer';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    // --- Linux Permissions Section ---
                    Card(
                      margin: const EdgeInsets.only(bottom: Insets.md),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                        borderRadius: Radii.card,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(Insets.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Permissions',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: Insets.md),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Set Permissions (Linux)'),
                              value: _setPermissionsLinux,
                              onChanged: (val) =>
                                  setState(() => _setPermissionsLinux = val),
                            ),
                            if (_setPermissionsLinux) ...[
                              const SizedBox(height: Insets.md),
                              TextFormField(
                                controller: _chmodFolderController,
                                decoration: const InputDecoration(
                                  labelText: 'Folder CHMOD Mode',
                                  border: OutlineInputBorder(),
                                  helperText: 'Octal format, e.g. 755',
                                ),
                              ),
                              const SizedBox(height: Insets.md),
                              TextFormField(
                                controller: _chownGroupController,
                                decoration: const InputDecoration(
                                  labelText: 'Group CHOWN Group',
                                  border: OutlineInputBorder(),
                                  helperText: 'Group name or ID',
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
