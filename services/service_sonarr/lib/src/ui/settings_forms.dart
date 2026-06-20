part of '../sonarr_home.dart';

class _HostSettingsPanel extends ConsumerWidget {
  const _HostSettingsPanel({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final AsyncValue<SonarrHostConfig> config = ref.watch(sonarrHostConfigProvider(instance));

    return _OneUISettingsCard(
      child: ExpansionTile(
        title: Text('General / Host Settings', style: theme.textTheme.titleMedium),
        childrenPadding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        children: [
          AsyncValueView<SonarrHostConfig>(
            value: config,
            data: (c) => _HostSettingsForm(instance: instance, config: c),
          ),
        ],
      ),
    );
  }
}

class _HostSettingsForm extends ConsumerStatefulWidget {
  const _HostSettingsForm({required this.instance, required this.config});

  final Instance instance;
  final SonarrHostConfig config;

  @override
  ConsumerState<_HostSettingsForm> createState() => _HostSettingsFormState();
}

class _HostSettingsFormState extends ConsumerState<_HostSettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _portController;
  late final TextEditingController _branchController;
  late final TextEditingController _backupIntervalController;
  late final TextEditingController _backupRetentionController;
  late String _logLevel;
  late bool _enableSsl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _portController = TextEditingController(text: widget.config.port.toString());
    _branchController = TextEditingController(text: widget.config.branch);
    _backupIntervalController = TextEditingController(text: widget.config.backupInterval.toString());
    _backupRetentionController = TextEditingController(text: widget.config.backupRetention.toString());
    _logLevel = widget.config.logLevel;
    _enableSsl = widget.config.enableSsl;
  }

  @override
  void dispose() {
    _portController.dispose();
    _branchController.dispose();
    _backupIntervalController.dispose();
    _backupRetentionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final api = await ref.read(sonarrApiProvider(widget.instance).future);
    final newRaw = Map<String, dynamic>.of(widget.config.raw)
      ..['port'] = int.tryParse(_portController.text) ?? widget.config.port
      ..['branch'] = _branchController.text.trim()
      ..['backupInterval'] = int.tryParse(_backupIntervalController.text) ?? widget.config.backupInterval
      ..['backupRetention'] = int.tryParse(_backupRetentionController.text) ?? widget.config.backupRetention
      ..['logLevel'] = _logLevel
      ..['enableSsl'] = _enableSsl;

    try {
      await api.updateHostConfigRaw(newRaw);
      ref.invalidate(sonarrHostConfigProvider(widget.instance));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Host settings saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _portController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Server Port',
              border: OutlineInputBorder(),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Required';
              if (int.tryParse(val) == null) return 'Must be a valid integer';
              return null;
            },
          ),
          const SizedBox(height: Insets.md),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable SSL'),
            value: _enableSsl,
            onChanged: (val) => setState(() => _enableSsl = val),
          ),
          const SizedBox(height: Insets.sm),
          DropdownButtonFormField<String>(
            initialValue: _logLevel,
            decoration: const InputDecoration(
              labelText: 'Log Level',
              border: OutlineInputBorder(),
            ),
            items: ['trace', 'debug', 'info', 'warn', 'error'].map((level) {
              return DropdownMenuItem<String>(
                value: level,
                child: Text(level.toUpperCase()),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _logLevel = val);
              }
            },
          ),
          const SizedBox(height: Insets.md),
          TextFormField(
            controller: _branchController,
            decoration: const InputDecoration(
              labelText: 'Update Branch',
              border: OutlineInputBorder(),
            ),
            validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: Insets.md),
          TextFormField(
            controller: _backupIntervalController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Backup Interval (days)',
              border: OutlineInputBorder(),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Required';
              if (int.tryParse(val) == null) return 'Must be a valid integer';
              return null;
            },
          ),
          const SizedBox(height: Insets.md),
          TextFormField(
            controller: _backupRetentionController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Backup Retention (backups)',
              border: OutlineInputBorder(),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Required';
              if (int.tryParse(val) == null) return 'Must be a valid integer';
              return null;
            },
          ),
          const SizedBox(height: Insets.lg),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_outlined),
            label: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }
}

class _NamingSettingsPanel extends ConsumerWidget {
  const _NamingSettingsPanel({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final AsyncValue<SonarrNamingConfig> config = ref.watch(sonarrNamingConfigProvider(instance));

    return _OneUISettingsCard(
      child: ExpansionTile(
        title: Text('Episode Naming', style: theme.textTheme.titleMedium),
        childrenPadding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        children: [
          AsyncValueView<SonarrNamingConfig>(
            value: config,
            data: (c) => _NamingSettingsForm(instance: instance, config: c),
          ),
        ],
      ),
    );
  }
}

class _NamingSettingsForm extends ConsumerStatefulWidget {
  const _NamingSettingsForm({required this.instance, required this.config});

  final Instance instance;
  final SonarrNamingConfig config;

  @override
  ConsumerState<_NamingSettingsForm> createState() => _NamingSettingsFormState();
}

class _NamingSettingsFormState extends ConsumerState<_NamingSettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _standardFormatController;
  late final TextEditingController _dailyFormatController;
  late final TextEditingController _animeFormatController;
  late final TextEditingController _seriesFolderFormatController;
  late bool _renameEpisodes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _standardFormatController = TextEditingController(text: widget.config.standardEpisodeFormat);
    _dailyFormatController = TextEditingController(text: widget.config.dailyEpisodeFormat);
    _animeFormatController = TextEditingController(text: widget.config.animeEpisodeFormat);
    _seriesFolderFormatController = TextEditingController(text: widget.config.seriesFolderFormat);
    _renameEpisodes = widget.config.renameEpisodes;
  }

  @override
  void dispose() {
    _standardFormatController.dispose();
    _dailyFormatController.dispose();
    _animeFormatController.dispose();
    _seriesFolderFormatController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final api = await ref.read(sonarrApiProvider(widget.instance).future);
    final newRaw = Map<String, dynamic>.of(widget.config.raw)
      ..['renameEpisodes'] = _renameEpisodes
      ..['standardEpisodeFormat'] = _standardFormatController.text.trim()
      ..['dailyEpisodeFormat'] = _dailyFormatController.text.trim()
      ..['animeEpisodeFormat'] = _animeFormatController.text.trim()
      ..['seriesFolderFormat'] = _seriesFolderFormatController.text.trim();

    try {
      await api.updateNamingConfigRaw(newRaw);
      ref.invalidate(sonarrNamingConfigProvider(widget.instance));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Naming settings saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Rename Episodes'),
            value: _renameEpisodes,
            onChanged: (val) => setState(() => _renameEpisodes = val),
          ),
          const SizedBox(height: Insets.sm),
          TextFormField(
            controller: _standardFormatController,
            decoration: const InputDecoration(
              labelText: 'Standard Episode Format',
              border: OutlineInputBorder(),
            ),
            validator: (val) => (_renameEpisodes && (val == null || val.trim().isEmpty)) ? 'Required when Rename is enabled' : null,
          ),
          const SizedBox(height: Insets.md),
          TextFormField(
            controller: _dailyFormatController,
            decoration: const InputDecoration(
              labelText: 'Daily Episode Format',
              border: OutlineInputBorder(),
            ),
            validator: (val) => (_renameEpisodes && (val == null || val.trim().isEmpty)) ? 'Required when Rename is enabled' : null,
          ),
          const SizedBox(height: Insets.md),
          TextFormField(
            controller: _animeFormatController,
            decoration: const InputDecoration(
              labelText: 'Anime Episode Format',
              border: OutlineInputBorder(),
            ),
            validator: (val) => (_renameEpisodes && (val == null || val.trim().isEmpty)) ? 'Required when Rename is enabled' : null,
          ),
          const SizedBox(height: Insets.md),
          TextFormField(
            controller: _seriesFolderFormatController,
            decoration: const InputDecoration(
              labelText: 'Series Folder Format',
              border: OutlineInputBorder(),
            ),
            validator: (val) => (val == null || val.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: Insets.lg),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_outlined),
            label: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }
}

class _MediaManagementSettingsPanel extends ConsumerWidget {
  const _MediaManagementSettingsPanel({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final AsyncValue<SonarrMediaManagementConfig> config = ref.watch(sonarrMediaManagementConfigProvider(instance));

    return _OneUISettingsCard(
      child: ExpansionTile(
        title: Text('Media Management', style: theme.textTheme.titleMedium),
        childrenPadding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        children: [
          AsyncValueView<SonarrMediaManagementConfig>(
            value: config,
            data: (c) => _MediaManagementSettingsForm(instance: instance, config: c),
          ),
        ],
      ),
    );
  }
}

class _MediaManagementSettingsForm extends ConsumerStatefulWidget {
  const _MediaManagementSettingsForm({required this.instance, required this.config});

  final Instance instance;
  final SonarrMediaManagementConfig config;

  @override
  ConsumerState<_MediaManagementSettingsForm> createState() => _MediaManagementSettingsFormState();
}

class _MediaManagementSettingsFormState extends ConsumerState<_MediaManagementSettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late bool _autoUnmonitor;
  late String _downloadPropers;
  late bool _createEmptySeriesFolders;
  late bool _deleteEmptyFolders;
  late bool _copyUsingHardlinks;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _autoUnmonitor = widget.config.autoUnmonitorPreviouslyDownloadedEpisodes;
    _downloadPropers = widget.config.downloadPropersAndRepacks;
    _createEmptySeriesFolders = widget.config.createEmptySeriesFolders;
    _deleteEmptyFolders = widget.config.deleteEmptyFolders;
    _copyUsingHardlinks = widget.config.copyUsingHardlinks;
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final api = await ref.read(sonarrApiProvider(widget.instance).future);
    final newRaw = Map<String, dynamic>.of(widget.config.raw)
      ..['autoUnmonitorPreviouslyDownloadedEpisodes'] = _autoUnmonitor
      ..['downloadPropersAndRepacks'] = _downloadPropers
      ..['createEmptySeriesFolders'] = _createEmptySeriesFolders
      ..['deleteEmptyFolders'] = _deleteEmptyFolders
      ..['copyUsingHardlinks'] = _copyUsingHardlinks;

    try {
      await api.updateMediaManagementConfigRaw(newRaw);
      ref.invalidate(sonarrMediaManagementConfigProvider(widget.instance));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Media management settings saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto Unmonitor Downloaded'),
            value: _autoUnmonitor,
            onChanged: (val) => setState(() => _autoUnmonitor = val),
          ),
          DropdownButtonFormField<String>(
            initialValue: _downloadPropers,
            decoration: const InputDecoration(
              labelText: 'Download Propers & Repacks',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'preferAndUpgrade',
                child: Text('Prefer and Upgrade'),
              ),
              DropdownMenuItem(
                value: 'doNotUpgrade',
                child: Text('Do Not Upgrade'),
              ),
              DropdownMenuItem(
                value: 'doNotPrefer',
                child: Text('Do Not Prefer'),
              ),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _downloadPropers = val);
              }
            },
          ),
          const SizedBox(height: Insets.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Create Empty Series Folders'),
            value: _createEmptySeriesFolders,
            onChanged: (val) => setState(() => _createEmptySeriesFolders = val),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Delete Empty Folders'),
            value: _deleteEmptyFolders,
            onChanged: (val) => setState(() => _deleteEmptyFolders = val),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Use Hardlinks instead of Copy'),
            value: _copyUsingHardlinks,
            onChanged: (val) => setState(() => _copyUsingHardlinks = val),
          ),
          const SizedBox(height: Insets.lg),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_outlined),
            label: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }
}

class _UiSettingsPanel extends ConsumerWidget {
  const _UiSettingsPanel({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final AsyncValue<SonarrUiConfig> config = ref.watch(sonarrUiConfigProvider(instance));

    return _OneUISettingsCard(
      child: ExpansionTile(
        title: Text('UI Configuration', style: theme.textTheme.titleMedium),
        childrenPadding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        children: [
          AsyncValueView<SonarrUiConfig>(
            value: config,
            data: (c) => _UiSettingsForm(instance: instance, config: c),
          ),
        ],
      ),
    );
  }
}

class _UiSettingsForm extends ConsumerStatefulWidget {
  const _UiSettingsForm({required this.instance, required this.config});

  final Instance instance;
  final SonarrUiConfig config;

  @override
  ConsumerState<_UiSettingsForm> createState() => _UiSettingsFormState();
}

class _UiSettingsFormState extends ConsumerState<_UiSettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late String _theme;
  late String _timeFormat;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _theme = widget.config.theme;

    // Normalize timeFormat dropdown value
    final currentFormat = widget.config.timeFormat;
    if (currentFormat.contains('a') || currentFormat.contains('t')) {
      _timeFormat = 'h:mm a';
    } else {
      _timeFormat = 'HH:mm';
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final api = await ref.read(sonarrApiProvider(widget.instance).future);
    final newRaw = Map<String, dynamic>.of(widget.config.raw)
      ..['theme'] = _theme
      ..['timeFormat'] = _timeFormat;

    try {
      await api.updateUiConfigRaw(newRaw);
      ref.invalidate(sonarrUiConfigProvider(widget.instance));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('UI settings saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _theme,
            decoration: const InputDecoration(
              labelText: 'Theme',
              border: OutlineInputBorder(),
            ),
            items: ['auto', 'dark', 'light'].map((themeName) {
              return DropdownMenuItem<String>(
                value: themeName,
                child: Text(themeName.toUpperCase()),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _theme = val);
              }
            },
          ),
          const SizedBox(height: Insets.md),
          DropdownButtonFormField<String>(
            initialValue: _timeFormat,
            decoration: const InputDecoration(
              labelText: 'Time Format',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'h:mm a', child: Text('12h')),
              DropdownMenuItem(value: 'HH:mm', child: Text('24h')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _timeFormat = val);
              }
            },
          ),
          const SizedBox(height: Insets.lg),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_outlined),
            label: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }
}
