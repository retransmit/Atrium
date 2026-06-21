part of '../sonarr_home.dart';

class _MetadataSettingsPanel extends ConsumerWidget {
  const _MetadataSettingsPanel({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final AsyncValue<List<SonarrMetadataProvider>> providers = ref.watch(sonarrMetadataProvidersProvider(instance));

    return _OneUISettingsCard(
      child: ExpansionTile(
        title: Text('Metadata Consumers', style: theme.textTheme.titleMedium),
        childrenPadding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        children: [
          AsyncValueView<List<SonarrMetadataProvider>>(
            value: providers,
            data: (list) {
              if (list.isEmpty) return const Text('No metadata consumers.');
              return Column(
                children: list.map((provider) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Switch(
                      value: provider.enable,
                      onChanged: (val) async {
                        final api = await ref.read(sonarrApiProvider(instance).future);
                        final newRaw = Map<String, dynamic>.of(provider.raw)..['enable'] = val;
                        await api.updateMetadataProviderRaw(newRaw);
                        ref.invalidate(sonarrMetadataProvidersProvider(instance));
                      },
                    ),
                    title: Text(provider.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.science_outlined),
                          tooltip: 'Test Metadata Consumer',
                          onPressed: () async {
                            final api = await ref.read(sonarrApiProvider(instance).future);
                            try {
                              await api.testMetadataProviderRaw(provider.raw);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Metadata consumer test successful!')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Metadata consumer test failed')),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DelayProfileSettingsPanel extends ConsumerWidget {
  const _DelayProfileSettingsPanel({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final AsyncValue<List<SonarrDelayProfile>> profiles = ref.watch(sonarrDelayProfilesProvider(instance));

    return _OneUISettingsCard(
      child: ExpansionTile(
        title: Text('Delay Profiles', style: theme.textTheme.titleMedium),
        childrenPadding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        children: [
          AsyncValueView<List<SonarrDelayProfile>>(
            value: profiles,
            data: (list) {
              if (list.isEmpty) return const Text('No delay profiles configured.');
              return Column(
                children: list.map((profile) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enable Torrent Delay'),
                        value: profile.enableTorrent,
                        onChanged: (val) async {
                          final api = await ref.read(sonarrApiProvider(instance).future);
                          final newRaw = Map<String, dynamic>.of(profile.raw)..['enableTorrent'] = val;
                          await api.updateDelayProfileRaw(newRaw);
                          ref.invalidate(sonarrDelayProfilesProvider(instance));
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enable Usenet Delay'),
                        value: profile.enableUsenet,
                        onChanged: (val) async {
                          final api = await ref.read(sonarrApiProvider(instance).future);
                          final newRaw = Map<String, dynamic>.of(profile.raw)..['enableUsenet'] = val;
                          await api.updateDelayProfileRaw(newRaw);
                          ref.invalidate(sonarrDelayProfilesProvider(instance));
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Preferred Protocol'),
                        trailing: DropdownButton<String>(
                          value: profile.preferredProtocol,
                          items: ['usenet', 'torrent'].map((protocol) {
                            return DropdownMenuItem<String>(
                              value: protocol,
                              child: Text(protocol.toUpperCase()),
                            );
                          }).toList(),
                          onChanged: (val) async {
                            if (val != null) {
                              final api = await ref.read(sonarrApiProvider(instance).future);
                              final newRaw = Map<String, dynamic>.of(profile.raw)..['preferredProtocol'] = val;
                              await api.updateDelayProfileRaw(newRaw);
                              ref.invalidate(sonarrDelayProfilesProvider(instance));
                            }
                          },
                        ),
                      ),
                      const Divider(),
                    ],
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CustomFormatSettingsPanel extends ConsumerWidget {
  const _CustomFormatSettingsPanel({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final AsyncValue<List<SonarrCustomFormat>> formats = ref.watch(sonarrCustomFormatsProvider(instance));

    return _OneUISettingsCard(
      child: ExpansionTile(
        title: Text('Custom Formats', style: theme.textTheme.titleMedium),
        childrenPadding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        children: [
          AsyncValueView<List<SonarrCustomFormat>>(
            value: formats,
            data: (list) {
              if (list.isEmpty) return const Text('No custom formats configured.');
              return Column(
                children: list.map((format) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(format.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                      tooltip: 'Delete Custom Format',
                      onPressed: () async {
                        final api = await ref.read(sonarrApiProvider(instance).future);
                        await api.deleteCustomFormat(format.id);
                        ref.invalidate(sonarrCustomFormatsProvider(instance));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Custom format deleted')),
                          );
                        }
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QualityDefinitionSettingsPanel extends ConsumerWidget {
  const _QualityDefinitionSettingsPanel({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final AsyncValue<List<SonarrQualityDefinition>> definitions = ref.watch(sonarrQualityDefinitionsProvider(instance));

    return _OneUISettingsCard(
      child: ExpansionTile(
        title: Text('Quality Definitions', style: theme.textTheme.titleMedium),
        childrenPadding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        children: [
          AsyncValueView<List<SonarrQualityDefinition>>(
            value: definitions,
            data: (list) {
              if (list.isEmpty) return const Text('No quality definitions.');
              return Column(
                children: list.map((def) {
                  return _QualityDefinitionRow(instance: instance, definition: def);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QualityDefinitionRow extends ConsumerStatefulWidget {
  const _QualityDefinitionRow({required this.instance, required this.definition});

  final Instance instance;
  final SonarrQualityDefinition definition;

  @override
  ConsumerState<_QualityDefinitionRow> createState() => _QualityDefinitionRowState();
}

class _QualityDefinitionRowState extends ConsumerState<_QualityDefinitionRow> {
  late bool _isUnlimited;
  bool _saving = false;

  late TextEditingController _minController;
  late TextEditingController _maxController;
  late TextEditingController _preferredController;

  @override
  void initState() {
    super.initState();
    _minController = TextEditingController();
    _maxController = TextEditingController();
    _preferredController = TextEditingController();
    _reset();
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    _preferredController.dispose();
    super.dispose();
  }

  void _reset() {
    final double minVal = widget.definition.minSize;
    final rawMax = widget.definition.raw['maxSize'];
    _isUnlimited = rawMax == null || rawMax == 0.0 || widget.definition.maxSize == 0.0;
    final double maxVal = _isUnlimited ? 0.0 : widget.definition.maxSize;
    final double prefVal = widget.definition.preferredSize;

    _minController.text = minVal.toStringAsFixed(1);
    _maxController.text = _isUnlimited ? '' : maxVal.toStringAsFixed(1);
    _preferredController.text = prefVal.toStringAsFixed(1);
  }

  @override
  void didUpdateWidget(covariant _QualityDefinitionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.definition != widget.definition) {
      _reset();
    }
  }

  String? get _minError {
    final val = double.tryParse(_minController.text);
    if (_minController.text.isEmpty) return 'Required';
    if (val == null) return 'Invalid';
    if (val < 0) return 'Must be >= 0';
    return null;
  }

  String? get _preferredError {
    final val = double.tryParse(_preferredController.text);
    if (_preferredController.text.isEmpty) return 'Required';
    if (val == null) return 'Invalid';
    final minVal = double.tryParse(_minController.text);
    if (minVal != null && val < minVal) return 'Must be >= Min';
    return null;
  }

  String? get _maxError {
    if (_isUnlimited) return null;
    final val = double.tryParse(_maxController.text);
    if (_maxController.text.isEmpty) return 'Required';
    if (val == null) return 'Invalid';
    final prefVal = double.tryParse(_preferredController.text);
    if (prefVal != null && val < prefVal) return 'Must be >= Preferred';
    return null;
  }

  bool get _isValid => _minError == null && _preferredError == null && _maxError == null;

  bool get _hasChanges {
    final double origMin = widget.definition.minSize;
    final double origPref = widget.definition.preferredSize;
    final bool origUnlimited = widget.definition.raw['maxSize'] == null || widget.definition.raw['maxSize'] == 0.0 || widget.definition.maxSize == 0.0;
    final double origMax = origUnlimited ? 0.0 : widget.definition.maxSize;

    final minVal = double.tryParse(_minController.text);
    final prefVal = double.tryParse(_preferredController.text);
    final maxVal = _isUnlimited ? 0.0 : double.tryParse(_maxController.text);

    if (minVal == null || prefVal == null || (!_isUnlimited && maxVal == null)) {
      return true;
    }

    return minVal != origMin || prefVal != origPref || _isUnlimited != origUnlimited || (!_isUnlimited && maxVal != origMax);
  }

  Future<void> _save() async {
    if (!_isValid) return;

    setState(() => _saving = true);
    final api = await ref.read(sonarrApiProvider(widget.instance).future);

    final double minVal = double.parse(_minController.text);
    final double prefVal = double.parse(_preferredController.text);
    final double maxVal = _isUnlimited ? 0.0 : double.parse(_maxController.text);

    final newRaw = Map<String, dynamic>.of(widget.definition.raw)
      ..['minSize'] = minVal
      ..['maxSize'] = maxVal
      ..['preferredSize'] = prefVal;

    try {
      await api.updateQualityDefinitionRaw(newRaw);
      ref.invalidate(sonarrQualityDefinitionsProvider(widget.instance));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Quality definition ${widget.definition.name} saved!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save quality definition: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: Material(
        color: isDark ? theme.colorScheme.surfaceContainerHigh : theme.colorScheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: _hasChanges ? theme.colorScheme.primary.withValues(alpha: 0.5) : theme.colorScheme.outlineVariant,
            width: _hasChanges ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.definition.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _hasChanges ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                    ),
                  ),
                  Row(
                    children: [
                      if (_hasChanges && !_saving)
                        IconButton(
                          icon: const Icon(Icons.undo, size: 20),
                          tooltip: 'Discard changes',
                          onPressed: () => setState(_reset),
                        ),
                      if (_saving)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else if (_hasChanges)
                        IconButton(
                          icon: Icon(
                            Icons.check,
                            color: _isValid ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                            size: 20,
                          ),
                          tooltip: _isValid ? 'Save changes' : 'Validation errors exist',
                          onPressed: _isValid ? _save : null,
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: Insets.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Min Size',
                        suffixText: 'MB/h',
                        errorText: _minError,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (val) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: TextFormField(
                      controller: _preferredController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Preferred',
                        suffixText: 'MB/h',
                        errorText: _preferredError,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (val) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: TextFormField(
                      controller: _maxController,
                      enabled: !_isUnlimited,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Max Size',
                        suffixText: _isUnlimited ? '' : 'MB/h',
                        hintText: _isUnlimited ? 'Unlimited' : null,
                        errorText: _maxError,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (val) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.sm),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Unlimited Max Size', style: theme.textTheme.bodyMedium),
                value: _isUnlimited,
                onChanged: (val) {
                  setState(() {
                    _isUnlimited = val ?? false;
                    if (_isUnlimited) {
                      _maxController.text = '';
                    } else {
                      final prefVal = double.tryParse(_preferredController.text) ?? widget.definition.preferredSize;
                      _maxController.text = prefVal.toStringAsFixed(1);
                    }
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReleaseProfileSettingsPanel extends ConsumerWidget {
  const _ReleaseProfileSettingsPanel({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final AsyncValue<List<SonarrReleaseProfile>> profiles = ref.watch(sonarrReleaseProfilesProvider(instance));

    return _OneUISettingsCard(
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Release Profiles', style: theme.textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Release Profile',
              onPressed: () => _showAddProfileDialog(context, ref),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        children: [
          AsyncValueView<List<SonarrReleaseProfile>>(
            value: profiles,
            data: (list) {
              if (list.isEmpty) return const Text('No release profiles configured.');
              return Column(
                children: list.map((profile) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Switch(
                      value: profile.enabled,
                      onChanged: (val) async {
                        final api = await ref.read(sonarrApiProvider(instance).future);
                        final newRaw = Map<String, dynamic>.of(profile.raw)..['enabled'] = val;
                        await api.updateReleaseProfileRaw(newRaw);
                        ref.invalidate(sonarrReleaseProfilesProvider(instance));
                      },
                    ),
                    title: Text(profile.name.isEmpty ? 'Unnamed Release Profile' : profile.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    subtitle: Text('Required: ${profile.requiredTerms.length} • Ignored: ${profile.ignoredTerms.length} • Preferred: ${profile.preferredTerms.length}'),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                      onPressed: () async {
                        final api = await ref.read(sonarrApiProvider(instance).future);
                        await api.deleteReleaseProfile(profile.id);
                        ref.invalidate(sonarrReleaseProfilesProvider(instance));
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAddProfileDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Release Profile'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Profile Name'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  final api = await ref.read(sonarrApiProvider(instance).future);
                  await api.createReleaseProfileRaw(<String, dynamic>{
                    'name': name,
                    'enabled': true,
                    'required': <dynamic>[],
                    'ignored': <dynamic>[],
                    'preferred': <dynamic>[],
                    'tags': <dynamic>[],
                  });
                  ref.invalidate(sonarrReleaseProfilesProvider(instance));
                }
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}

class _ImportListExclusionSettingsPanel extends ConsumerWidget {
  const _ImportListExclusionSettingsPanel({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final AsyncValue<List<SonarrImportListExclusion>> exclusions = ref.watch(sonarrImportListExclusionsProvider(instance));

    return _OneUISettingsCard(
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Import List Exclusions', style: theme.textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Exclusion',
              onPressed: () => _showAddExclusionDialog(context, ref),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        children: [
          AsyncValueView<List<SonarrImportListExclusion>>(
            value: exclusions,
            data: (list) {
              if (list.isEmpty) return const Text('No exclusions configured.');
              return Column(
                children: list.map((exclusion) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(exclusion.title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    subtitle: Text('TVDB ID: ${exclusion.tvdbId}'),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                      onPressed: () async {
                        final api = await ref.read(sonarrApiProvider(instance).future);
                        await api.deleteImportListExclusion(exclusion.id);
                        ref.invalidate(sonarrImportListExclusionsProvider(instance));
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAddExclusionDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final tvdbController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Import List Exclusion'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Series Title'),
                autofocus: true,
              ),
              TextField(
                controller: tvdbController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'TVDB ID'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final title = titleController.text.trim();
                final tvdbId = int.tryParse(tvdbController.text.trim()) ?? 0;
                if (title.isNotEmpty && tvdbId > 0) {
                  final api = await ref.read(sonarrApiProvider(instance).future);
                  await api.createImportListExclusionRaw(<String, dynamic>{
                    'title': title,
                    'tvdbId': tvdbId,
                  });
                  ref.invalidate(sonarrImportListExclusionsProvider(instance));
                }
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}

class _AutoTaggingSettingsPanel extends ConsumerWidget {
  const _AutoTaggingSettingsPanel({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final AsyncValue<List<SonarrAutoTaggingRule>> rules = ref.watch(sonarrAutoTaggingRulesProvider(instance));

    return _OneUISettingsCard(
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Auto Tagging Rules', style: theme.textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Auto Tagging Rule',
              onPressed: () => _showAddRuleDialog(context, ref),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        children: [
          AsyncValueView<List<SonarrAutoTaggingRule>>(
            value: rules,
            data: (list) {
              if (list.isEmpty) return const Text('No auto tagging rules.');
              return Column(
                children: list.map((rule) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(rule.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    subtitle: Text('Specifications: ${rule.specifications.length} • Tags: ${rule.tags.length}'),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                      onPressed: () async {
                        final api = await ref.read(sonarrApiProvider(instance).future);
                        await api.deleteAutoTaggingRule(rule.id);
                        ref.invalidate(sonarrAutoTaggingRulesProvider(instance));
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAddRuleDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Auto Tagging Rule'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Rule Name'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  final api = await ref.read(sonarrApiProvider(instance).future);
                  await api.createAutoTaggingRuleRaw(<String, dynamic>{
                    'name': name,
                    'tags': <dynamic>[],
                    'specifications': <dynamic>[],
                  });
                  ref.invalidate(sonarrAutoTaggingRulesProvider(instance));
                }
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}

class _QualityProfileSettingsPanel extends ConsumerWidget {
  const _QualityProfileSettingsPanel({required this.instance});

  final Instance instance;

  int _getItemId(Map<String, dynamic> item) {
    final int? id = (item['id'] as num?)?.toInt();
    if (id != null && id != 0) return id;
    final quality = item['quality'] as Map<String, dynamic>?;
    if (quality != null) {
      return ((quality['id'] as num?) ?? 0).toInt();
    }
    return 0;
  }

  String _getItemName(Map<String, dynamic> item) {
    final String? name = item['name'] as String?;
    if (name != null && name.isNotEmpty) return name;
    final quality = item['quality'] as Map<String, dynamic>?;
    if (quality != null) {
      return (quality['name'] as String?) ?? '';
    }
    return '';
  }

  List<Map<String, dynamic>> _getAllowedQualities(List<dynamic> items) {
    final List<Map<String, dynamic>> list = [];
    void helper(List<dynamic> listItems) {
      for (final dynamic item in listItems) {
        final Map<String, dynamic> itemMap = item as Map<String, dynamic>;
        final List<dynamic>? nested = itemMap['items'] as List<dynamic>?;
        if (nested != null && nested.isNotEmpty) {
          helper(nested);
        } else {
          if (itemMap['allowed'] == true) {
            list.add(itemMap);
          }
        }
      }
    }
    helper(items);
    return list;
  }

  Widget _buildQualityItemTile(BuildContext context, Map<String, dynamic> item, StateSetter setState, {bool readOnly = false}) {
    final List<dynamic>? nestedItems = item['items'] as List<dynamic>?;
    final String name = _getItemName(item);
    final bool allowed = (item['allowed'] as bool?) ?? false;

    if (nestedItems != null && nestedItems.isNotEmpty) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        child: ExpansionTile(
          initiallyExpanded: readOnly,
          title: Row(
            children: [
              Checkbox(
                value: allowed,
                onChanged: readOnly ? null : (val) {
                  setState(() {
                    item['allowed'] = val ?? false;
                    for (final dynamic sub in nestedItems) {
                      (sub as Map<String, dynamic>)['allowed'] = val ?? false;
                    }
                  });
                },
              ),
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          children: nestedItems.map((dynamic sub) => _buildQualityItemTile(context, sub as Map<String, dynamic>, setState, readOnly: readOnly)).toList(),
        ),
      );
    } else {
      return CheckboxListTile(
        title: Text(name),
        value: allowed,
        onChanged: readOnly ? null : (val) {
          setState(() {
            item['allowed'] = val ?? false;
          });
        },
      );
    }
  }

  void _showEditProfileDialog(BuildContext context, WidgetRef ref, Map<String, dynamic>? profile, {bool readOnly = false}) async {
    final api = await ref.read(sonarrApiProvider(instance).future);
    
    Map<String, dynamic> payload;
    if (profile != null) {
      payload = jsonDecode(jsonEncode(profile)) as Map<String, dynamic>;
    } else {
      final schema = await ref.read(sonarrQualityProfileSchemaProvider(instance).future);
      payload = jsonDecode(jsonEncode(schema)) as Map<String, dynamic>;
      payload['name'] = '';
      payload['upgradeAllowed'] = true;
    }

    if (!context.mounted) return;

    final nameController = TextEditingController(text: payload['name'] as String? ?? '');
    
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              final theme = Theme.of(context);
              final itemsList = (payload['items'] as List<dynamic>?) ?? [];
              final allowedQualities = _getAllowedQualities(itemsList);
              
              int cutoffId = (payload['cutoff'] as num? ?? 0).toInt();
              if (cutoffId == 0 && allowedQualities.isNotEmpty) {
                cutoffId = _getItemId(allowedQualities.first);
                payload['cutoff'] = cutoffId;
              } else if (allowedQualities.isNotEmpty && !allowedQualities.any((q) => _getItemId(q) == cutoffId)) {
                cutoffId = _getItemId(allowedQualities.first);
                payload['cutoff'] = cutoffId;
              }

              return AlertDialog(
                title: Text(profile != null ? (readOnly ? 'View Quality Profile' : 'Edit Quality Profile') : 'Add Quality Profile'),
                content: SizedBox(
                  width: double.maxFinite,
                  height: 500,
                  child: ListView(
                    children: [
                      TextField(
                        controller: nameController,
                        enabled: !readOnly,
                        decoration: const InputDecoration(
                          labelText: 'Profile Name',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) => payload['name'] = val.trim(),
                      ),
                      const SizedBox(height: Insets.md),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Upgrades Allowed'),
                        value: (payload['upgradeAllowed'] as bool?) ?? false,
                        onChanged: readOnly ? null : (val) => setState(() => payload['upgradeAllowed'] = val),
                      ),
                      if (payload['upgradeAllowed'] == true && allowedQualities.isNotEmpty) ...[
                        const SizedBox(height: Insets.sm),
                        DropdownButtonFormField<int>(
                          initialValue: cutoffId,
                          decoration: const InputDecoration(
                            labelText: 'Upgrade Cutoff',
                            border: OutlineInputBorder(),
                          ),
                          items: allowedQualities.map((q) {
                            final qId = _getItemId(q);
                            final qName = _getItemName(q);
                            return DropdownMenuItem<int>(
                              value: qId,
                              child: Text(qName),
                            );
                          }).toList(),
                          onChanged: readOnly ? null : (val) {
                            if (val != null) {
                              setState(() => payload['cutoff'] = val);
                            }
                          },
                        ),
                      ],
                      const SizedBox(height: Insets.md),
                      Text('Allowed Qualities', style: theme.textTheme.titleSmall),
                      const SizedBox(height: Insets.xs),
                      ...itemsList.map((dynamic item) => _buildQualityItemTile(context, item as Map<String, dynamic>, setState, readOnly: readOnly)),
                    ],
                  ),
                ),
                actions: [
                  if (readOnly)
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    )
                  else ...[
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () async {
                        final name = nameController.text.trim();
                        if (name.isNotEmpty) {
                          payload['name'] = name;
                          if (profile != null) {
                            await api.updateQualityProfileRaw(payload);
                          } else {
                            await api.createQualityProfileRaw(payload);
                          }
                          ref.invalidate(sonarrQualityProfilesRawProvider(instance));
                          ref.invalidate(sonarrQualityProfilesProvider(instance));
                        }
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      child: Text(profile != null ? 'Save' : 'Add'),
                    ),
                  ],
                ],
              );
            },
          );
        },
      );
    } finally {
      nameController.dispose();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final AsyncValue<List<Map<String, dynamic>>> profiles = ref.watch(sonarrQualityProfilesRawProvider(instance));
    final AsyncValue<List<SonarrQualityDefinition>> definitions = ref.watch(sonarrQualityDefinitionsProvider(instance));

    return _OneUISettingsCard(
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Quality Profiles', style: theme.textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Quality Profile',
              onPressed: () => _showEditProfileDialog(context, ref, null),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        children: [
          AsyncValueView<List<Map<String, dynamic>>>(
            value: profiles,
            data: (list) {
              if (list.isEmpty) return const Text('No quality profiles.');
              return Column(
                children: list.map((profile) {
                  final name = (profile['name'] as String?) ?? '';
                  final upgradeAllowed = (profile['upgradeAllowed'] as bool?) ?? false;
                  final cutoffId = (profile['cutoff'] as num? ?? 0).toInt();

                  final cutoffName = definitions.maybeWhen(
                    data: (defs) => defs.firstWhereOrNull((d) => d.id == cutoffId)?.name ?? 'Unknown',
                    orElse: () => '...',
                  );

                  final itemsList = (profile['items'] as List<dynamic>?) ?? [];
                  final allowedQualities = _getAllowedQualities(itemsList);

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () => _showEditProfileDialog(context, ref, profile, readOnly: true),
                    title: Text(name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      'Upgrades: ${upgradeAllowed ? "Yes (Cutoff: $cutoffName)" : "No"}\n'
                      'Allowed: ${allowedQualities.length} qualities',
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit Quality Profile',
                          onPressed: () => _showEditProfileDialog(context, ref, profile),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                          tooltip: 'Delete Quality Profile',
                          onPressed: () async {
                            final bool? confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Quality Profile?'),
                                content: Text('Are you sure you want to delete profile "$name"?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              final api = await ref.read(sonarrApiProvider(instance).future);
                              await api.deleteQualityProfile(profile['id'] as int);
                              ref.invalidate(sonarrQualityProfilesRawProvider(instance));
                              ref.invalidate(sonarrQualityProfilesProvider(instance));
                            }
                          },
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
