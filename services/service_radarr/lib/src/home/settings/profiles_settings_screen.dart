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

    final isEdit = profile != null;
    final nameController = TextEditingController(
      text: (profile?['name'] as String?) ?? '',
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final delayProfilesAsync = ref.watch(radarrDelayProfilesProvider(instance));

    return delayProfilesAsync.when(
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
            final int usenet = p['usenetDelay'] as int? ?? 0;
            final int torrent = p['torrentDelay'] as int? ?? 0;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: theme.colorScheme.surfaceContainerLow,
              child: ListTile(
                title: Text(
                  'Delay Profile (Usenet: ${usenet}m, Torrent: ${torrent}m)',
                ),
                subtitle: Text(
                  'Protocol preference: ${p['preferredProtocol'] ?? 'None'}',
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _CustomFormatsTab extends ConsumerWidget {
  const _CustomFormatsTab({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final formatsAsync = ref.watch(radarrCustomFormatsProvider(instance));

    return formatsAsync.when(
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
            final String name = f['name'] as String? ?? 'Unnamed Format';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: theme.colorScheme.surfaceContainerLow,
              child: ListTile(
                title: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(f['description'] as String? ?? ''),
              ),
            );
          },
        );
      },
    );
  }
}
