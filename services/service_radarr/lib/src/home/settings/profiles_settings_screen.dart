import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../radarr_providers.dart';
import 'widgets/confirm_delete.dart';

class ProfilesSettingsScreen extends ConsumerStatefulWidget {
  const ProfilesSettingsScreen({
    required this.instance,
    super.key,
  });

  final Instance instance;

  @override
  ConsumerState<ProfilesSettingsScreen> createState() =>
      _ProfilesSettingsScreenState();
}

class _ProfilesSettingsScreenState extends ConsumerState<ProfilesSettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profiles & Formats'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Quality Profiles'),
            Tab(text: 'Delay Profiles'),
            Tab(text: 'Custom Formats'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _QualityProfilesTab(instance: widget.instance),
          _DelayProfilesTab(instance: widget.instance),
          _CustomFormatsTab(instance: widget.instance),
        ],
      ),
    );
  }
}

class _QualityProfilesTab extends ConsumerWidget {
  const _QualityProfilesTab({required this.instance});

  final Instance instance;

  Future<void> _showProfileDialog(
    BuildContext context,
    WidgetRef ref, [
    Map<String, dynamic>? profile,
  ]) async {
    Map<String, dynamic>? schema;
    try {
      schema =
          await ref.read(radarrQualityProfileSchemaProvider(instance).future);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load quality profile schema'),
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;

    final formats = ref.read(radarrCustomFormatsProvider(instance)).value ?? [];
    final minFormatScoreController = TextEditingController(
      text: profile?['minFormatScore']?.toString() ?? '0',
    );
    final cutoffFormatScoreController = TextEditingController(
      text: profile?['cutoffFormatScore']?.toString() ?? '0',
    );

    final List<dynamic> profileFormatItems = profile?['formatItems'] as List<dynamic>? ?? [];
    final editableFormatItems = formats.map((dynamic f) {
      final fMap = f as Map<String, dynamic>;
      final int formatId = fMap['id'] as int;
      final String formatName = fMap['name'] as String? ?? 'Unknown';

      final match = profileFormatItems.firstWhere(
        (dynamic item) {
          final itemMap = item as Map<String, dynamic>;
          return itemMap['format'] == formatId;
        },
        orElse: () => null,
      );
      final matchMap = match != null ? match as Map<String, dynamic> : null;

      return <String, dynamic>{
        'format': formatId,
        'name': formatName,
        'score': matchMap?['score'] as int? ?? 0,
        'required': matchMap?['required'] as bool? ?? false,
      };
    }).toList();

    final isEdit = profile != null;
    final nameController = TextEditingController(
      text: profile?['name'] as String? ?? '',
    );

    final sourceItems =
        (profile?['items'] ?? schema!['items']) as List<dynamic>;
    final editableItems = sourceItems
        .map(
          (dynamic e) => Map<String, dynamic>.from(e as Map<String, dynamic>),
        )
        .toList();

    bool upgradeAllowed = profile?['upgradeAllowed'] as bool? ?? false;
    int cutoffId = profile?['cutoff'] as int? ?? 0;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final cutoffOptions = <Map<String, dynamic>>[];
            for (final item in editableItems) {
              final quality = item['quality'] as Map<String, dynamic>?;
              if (quality != null) {
                cutoffOptions.add(quality);
              } else {
                final groupName = item['name'] as String? ?? '';
                final groupId = item['id'] as int? ?? 0;
                cutoffOptions.add({'id': groupId, 'name': groupName});
              }
            }

            return AlertDialog(
              title:
                  Text(isEdit ? 'Edit Quality Profile' : 'Add Quality Profile'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Profile Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: Insets.md),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Upgrades Allowed'),
                        value: upgradeAllowed,
                        onChanged: (val) =>
                            setDialogState(() => upgradeAllowed = val),
                      ),
                      if (upgradeAllowed && cutoffOptions.isNotEmpty) ...[
                        const SizedBox(height: Insets.md),
                        DropdownButtonFormField<int>(
                          initialValue:
                              cutoffOptions.any((q) => q['id'] == cutoffId)
                                  ? cutoffId
                                  : null,
                          decoration: const InputDecoration(
                            labelText: 'Upgrade Cutoff',
                            border: OutlineInputBorder(),
                          ),
                          items: cutoffOptions.map((opt) {
                            return DropdownMenuItem<int>(
                              value: opt['id'] as int,
                              child: Text(opt['name'] as String),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => cutoffId = val);
                            }
                          },
                        ),
                      ],
                      const SizedBox(height: Insets.md),
                      const Text(
                        'Qualities Allowed',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: Insets.sm),
                      ...editableItems.map((item) {
                        final qname = item['name'] as String? ?? '';
                        final allowed = item['allowed'] as bool? ?? false;
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(qname),
                          value: allowed,
                          onChanged: (val) {
                            setDialogState(() {
                              item['allowed'] = val ?? false;
                            });
                          },
                        );
                      }),
                      const SizedBox(height: Insets.md),
                      const Divider(),
                      const SizedBox(height: Insets.sm),
                      Text(
                        'Custom Formats Settings',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: Insets.md),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: minFormatScoreController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Minimum Score',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: Insets.md),
                          Expanded(
                            child: TextFormField(
                              controller: cutoffFormatScoreController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Cutoff Score',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (editableFormatItems.isNotEmpty) ...[
                        const SizedBox(height: Insets.md),
                        Text(
                          'Format Scores & Constraints',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: Insets.sm),
                        ...editableFormatItems.map((item) {
                          final String formatName = item['name'] as String;
                          final int score = item['score'] as int;
                          final bool required = item['required'] as bool;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    formatName,
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ),
                                const SizedBox(width: Insets.sm),
                                SizedBox(
                                  width: 80,
                                  child: TextFormField(
                                    initialValue: score.toString(),
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Score',
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8.0,
                                        vertical: 8.0,
                                      ),
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (val) {
                                      item['score'] = int.tryParse(val) ?? 0;
                                    },
                                  ),
                                ),
                                const SizedBox(width: Insets.sm),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Checkbox(
                                      value: required,
                                      onChanged: (val) {
                                        setDialogState(() {
                                          item['required'] = val ?? false;
                                        });
                                      },
                                    ),
                                    const Text('Req.', style: TextStyle(fontSize: 10)),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) return;

                    // Radarr requires the cutoff to reference an allowed
                    // quality or group id, even when upgrades are disabled.
                    final allowedIds = <int>[];
                    for (final item in editableItems) {
                      if (item['allowed'] as bool? ?? false) {
                        final quality =
                            item['quality'] as Map<String, dynamic>?;
                        final itemId = quality != null
                            ? quality['id'] as int?
                            : item['id'] as int?;
                        if (itemId != null) allowedIds.add(itemId);
                      }
                    }
                    if (allowedIds.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Allow at least one quality first.'),
                        ),
                      );
                      return;
                    }
                    final effectiveCutoff = allowedIds.contains(cutoffId)
                        ? cutoffId
                        : allowedIds.first;

                    try {
                      final api =
                          await ref.read(radarrApiProvider(instance).future);
                      final payload = isEdit
                          ? Map<String, dynamic>.from(profile)
                          : Map<String, dynamic>.from(schema!);

                      payload['name'] = nameController.text.trim();
                      payload['upgradeAllowed'] = upgradeAllowed;
                      payload['cutoff'] = effectiveCutoff;
                      payload['items'] = editableItems;
                      payload['minFormatScore'] = int.tryParse(minFormatScoreController.text) ?? 0;
                      payload['cutoffFormatScore'] = int.tryParse(cutoffFormatScoreController.text) ?? 0;
                      payload['formatItems'] = editableFormatItems.map((item) => {
                        'format': item['format'],
                        'score': item['score'],
                        'required': item['required'],
                      },).toList();

                      if (isEdit) {
                        await api.updateQualityProfile(
                          payload,
                          payload['id'] as int,
                        );
                      } else {
                        // Remove id for creation
                        payload.remove('id');
                        await api.createQualityProfile(payload);
                      }

                      ref.invalidate(radarrQualityProfilesProvider(instance));
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to save profile: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profilesAsync = ref.watch(radarrQualityProfilesProvider(instance));

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProfileDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: profilesAsync.when(
        loading: () => const Center(child: ExpressiveProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (profiles) {
          if (profiles.isEmpty) {
            return const Center(child: Text('No Quality Profiles found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(Insets.md),
            itemCount: profiles.length,
            itemBuilder: (context, index) {
              final p = profiles[index];
              final String name = p['name'] as String? ?? 'Unnamed Profile';
              final bool upgrade = p['upgradeAllowed'] as bool? ?? false;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: theme.colorScheme.surfaceContainerLow,
                child: ListTile(
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(upgrade ? 'Upgrades Allowed' : 'No Upgrades'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _showProfileDialog(context, ref, p),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: theme.colorScheme.error,
                        ),
                        onPressed: () async {
                          final ok = await confirmDelete(
                            context,
                            'Quality Profile "$name"',
                          );
                          if (ok) {
                            try {
                              final api = await ref
                                  .read(radarrApiProvider(instance).future);
                              await api.deleteQualityProfile(p['id'] as int);
                              ref.invalidate(
                                radarrQualityProfilesProvider(instance),
                              );
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to delete: $e'),
                                  ),
                                );
                              }
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _DelayProfilesTab extends ConsumerWidget {
  const _DelayProfilesTab({required this.instance});

  final Instance instance;

  Future<void> _showDelayProfileDialog(
    BuildContext context,
    WidgetRef ref, [
    Map<String, dynamic>? profile,
  ]) async {
    final isEdit = profile != null;

    bool enableUsenet = profile?['enableUsenet'] as bool? ?? true;
    bool enableTorrent = profile?['enableTorrent'] as bool? ?? true;
    String preferredProtocol =
        profile?['preferredProtocol'] as String? ?? 'usenet';
    final usenetDelayController = TextEditingController(
      text: (profile?['usenetDelay'] as int? ?? 0).toString(),
    );
    final torrentDelayController = TextEditingController(
      text: (profile?['torrentDelay'] as int? ?? 0).toString(),
    );
    bool bypassIfHighest = profile?['bypassIfHighestQuality'] as bool? ?? true;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Delay Profile' : 'Add Delay Profile'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enable Usenet'),
                      value: enableUsenet,
                      onChanged: (val) =>
                          setDialogState(() => enableUsenet = val),
                    ),
                    if (enableUsenet)
                      TextField(
                        controller: usenetDelayController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Usenet Delay (Minutes)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enable Torrent'),
                      value: enableTorrent,
                      onChanged: (val) =>
                          setDialogState(() => enableTorrent = val),
                    ),
                    if (enableTorrent)
                      TextField(
                        controller: torrentDelayController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Torrent Delay (Minutes)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: preferredProtocol,
                      decoration: const InputDecoration(
                        labelText: 'Preferred Protocol',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'usenet',
                          child: Text('Usenet'),
                        ),
                        const DropdownMenuItem(
                          value: 'torrent',
                          child: Text('Torrent'),
                        ),
                        if (preferredProtocol != 'usenet' &&
                            preferredProtocol != 'torrent')
                          DropdownMenuItem(
                            value: preferredProtocol,
                            child: Text(preferredProtocol),
                          ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => preferredProtocol = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Bypass if Highest Quality'),
                      value: bypassIfHighest,
                      onChanged: (val) =>
                          setDialogState(() => bypassIfHighest = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      final api =
                          await ref.read(radarrApiProvider(instance).future);
                      final payload = profile != null
                          ? Map<String, dynamic>.from(profile)
                          : <String, dynamic>{
                              'order': 1,
                              'tags': <int>[],
                            };

                      payload['enableUsenet'] = enableUsenet;
                      payload['enableTorrent'] = enableTorrent;
                      payload['usenetDelay'] =
                          int.tryParse(usenetDelayController.text) ?? 0;
                      payload['torrentDelay'] =
                          int.tryParse(torrentDelayController.text) ?? 0;
                      payload['preferredProtocol'] = preferredProtocol;
                      payload['bypassIfHighestQuality'] = bypassIfHighest;

                      if (isEdit) {
                        await api.updateDelayProfile(payload, payload['id'] as int);
                      } else {
                        await api.createDelayProfile(payload);
                      }

                      ref.invalidate(radarrDelayProfilesProvider(instance));
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Delay profile ${isEdit ? 'updated' : 'created'}!',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteDelayProfile(
    BuildContext context,
    WidgetRef ref,
    int id,
  ) async {
    if (!await confirmDelete(context, 'this delay profile')) return;
    try {
      final api = await ref.read(radarrApiProvider(instance).future);
      await api.deleteDelayProfile(id);
      ref.invalidate(radarrDelayProfilesProvider(instance));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delay profile deleted!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete delay profile: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final delayProfilesAsync = ref.watch(radarrDelayProfilesProvider(instance));

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDelayProfileDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: delayProfilesAsync.when(
        loading: () => const Center(child: ExpressiveProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (profiles) {
          if (profiles.isEmpty) {
            return const Center(child: Text('No Delay Profiles found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(Insets.md),
            itemCount: profiles.length,
            itemBuilder: (context, index) {
              final p = profiles[index];
              final id = p['id'] as int;
              final int usenet = p['usenetDelay'] as int? ?? 0;
              final int torrent = p['torrentDelay'] as int? ?? 0;
              final String preferred =
                  (p['preferredProtocol'] as String?) ?? 'None';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: theme.colorScheme.surfaceContainerLow,
                child: ListTile(
                  title: Text(
                    'Preferred: ${preferred.toUpperCase()}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Usenet Delay: ${usenet}m • Torrent Delay: ${torrent}m\nBypass Highest Quality: ${p['bypassIfHighestQuality'] == true ? 'Yes' : 'No'}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _showDelayProfileDialog(context, ref, p),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: theme.colorScheme.error,
                        ),
                        onPressed: () => _deleteDelayProfile(context, ref, id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CustomFormatsTab extends ConsumerWidget {
  const _CustomFormatsTab({required this.instance});

  final Instance instance;

  Future<void> _showCustomFormatDialog(
    BuildContext context,
    WidgetRef ref, [
    Map<String, dynamic>? format,
  ]) async {
    final isEdit = format != null;

    final nameController =
        TextEditingController(text: format?['name'] as String? ?? '');
    bool includeWhenRenaming =
        format?['includeCustomFormatWhenRenaming'] as bool? ?? false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Custom Format' : 'Add Custom Format'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Format Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Include in Rename'),
                      subtitle: const Text(
                        'Incorporate format in renaming output tokens',
                      ),
                      value: includeWhenRenaming,
                      onChanged: (val) =>
                          setDialogState(() => includeWhenRenaming = val),
                    ),
                    if (!isEdit) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Creating custom formats needs specifications - use the Radarr web UI for now.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: !isEdit
                      ? null
                      : () async {
                          try {
                            final api = await ref
                                .read(radarrApiProvider(instance).future);
                            final payload = Map<String, dynamic>.from(format);

                            payload['name'] = nameController.text.trim();
                            payload['includeCustomFormatWhenRenaming'] =
                                includeWhenRenaming;

                            await api.updateCustomFormat(payload, payload['id'] as int);

                            ref.invalidate(
                              radarrCustomFormatsProvider(instance),
                            );
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Custom format updated!'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteCustomFormat(
    BuildContext context,
    WidgetRef ref,
    int id,
  ) async {
    if (!await confirmDelete(context, 'this custom format')) return;
    try {
      final api = await ref.read(radarrApiProvider(instance).future);
      await api.deleteCustomFormat(id);
      ref.invalidate(radarrCustomFormatsProvider(instance));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Custom format deleted!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete custom format: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final formatsAsync = ref.watch(radarrCustomFormatsProvider(instance));

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCustomFormatDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: formatsAsync.when(
        loading: () => const Center(child: ExpressiveProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (formats) {
          if (formats.isEmpty) {
            return const Center(child: Text('No Custom Formats found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(Insets.md),
            itemCount: formats.length,
            itemBuilder: (context, index) {
              final f = formats[index];
              final id = f['id'] as int;
              final String name = f['name'] as String? ?? 'Unnamed Format';
              final includeRename =
                  f['includeCustomFormatWhenRenaming'] as bool? ?? false;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: theme.colorScheme.surfaceContainerLow,
                child: ListTile(
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Include in renaming: ${includeRename ? 'Yes' : 'No'}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _showCustomFormatDialog(context, ref, f),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: theme.colorScheme.error,
                        ),
                        onPressed: () => _deleteCustomFormat(context, ref, id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
