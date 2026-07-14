import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sonarr_providers.dart';
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
    _tabController = TabController(length: 4, vsync: this);
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
          isScrollable: true,
          tabs: const [
            Tab(text: 'Quality Profiles'),
            Tab(text: 'Delay Profiles'),
            Tab(text: 'Release Profiles'),
            Tab(text: 'Custom Formats'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _QualityProfilesTab(instance: widget.instance),
          _DelayProfilesTab(instance: widget.instance),
          _ReleaseProfilesTab(instance: widget.instance),
          _CustomFormatsTab(instance: widget.instance),
        ],
      ),
    );
  }
}

// ==========================================
// 1. QUALITY PROFILES TAB
// ==========================================
class _QualityProfilesTab extends ConsumerWidget {
  const _QualityProfilesTab({required this.instance});

  final Instance instance;

  Future<void> _showProfileDialog(
    BuildContext context,
    WidgetRef ref, [
    Map<String, dynamic>? profile,
  ]) async {
    // Fetch schema to get all available quality items
    Map<String, dynamic>? schema;
    try {
      schema =
          await ref.read(sonarrQualityProfileSchemaProvider(instance).future);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to load quality profile schema')),
        );
      }
      return;
    }

    if (!context.mounted) return;

    final isEdit = profile != null;
    final nameController = TextEditingController(
      text: (profile?['name'] as String?) ?? '',
    );

    // Build the items list from profile (edit) or schema (new)
    final sourceItems =
        (profile?['items'] ?? schema!['items']) as List<dynamic>;
    // Deep copy so we can toggle allowed flags
    final editableItems = sourceItems
        .map(
            (dynamic e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
        .toList();

    // Deep copy nested quality groups
    for (var i = 0; i < editableItems.length; i++) {
      final subItems = editableItems[i]['items'] as List<dynamic>?;
      if (subItems != null && subItems.isNotEmpty) {
        editableItems[i]['items'] = subItems
            .map((dynamic e) =>
                Map<String, dynamic>.from(e as Map<String, dynamic>))
            .toList();
      }
    }

    bool upgradeAllowed = profile?['upgradeAllowed'] as bool? ?? false;
    int cutoffId = profile?['cutoff'] as int? ?? 0;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Collect all quality items with their id for cutoff dropdown
            final cutoffOptions = <Map<String, dynamic>>[];
            for (final item in editableItems) {
              final quality = item['quality'] as Map<String, dynamic>?;
              if (quality != null) {
                cutoffOptions.add(quality);
              } else {
                // It's a group - add it as a selectable cutoff
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
                      const SizedBox(height: 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Allow Upgrades'),
                        value: upgradeAllowed,
                        onChanged: (val) =>
                            setDialogState(() => upgradeAllowed = val),
                      ),
                      if (upgradeAllowed) ...[
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            labelText: 'Upgrade Until (Cutoff)',
                            border: OutlineInputBorder(),
                          ),
                          initialValue:
                              cutoffOptions.any((q) => q['id'] == cutoffId)
                                  ? cutoffId
                                  : null,
                          items: cutoffOptions.map((q) {
                            return DropdownMenuItem<int>(
                              value: q['id'] as int,
                              child: Text(q['name'] as String? ?? 'Unknown'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null)
                              setDialogState(() => cutoffId = val);
                          },
                        ),
                      ],
                      const Divider(height: 32),
                      Text(
                        'Qualities',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      // Render each quality item with a checkbox
                      ...editableItems.map((item) {
                        final quality =
                            item['quality'] as Map<String, dynamic>?;
                        final isGroup = quality == null;
                        final name = isGroup
                            ? (item['name'] as String? ?? 'Group')
                            : (quality['name'] as String? ?? 'Unknown');
                        final allowed = item['allowed'] as bool? ?? false;

                        return CheckboxListTile(
                          contentPadding:
                              EdgeInsets.only(left: isGroup ? 0 : 16),
                          title: Text(
                            name,
                            style: TextStyle(
                              fontWeight:
                                  isGroup ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          value: allowed,
                          onChanged: (val) {
                            setDialogState(() {
                              item['allowed'] = val ?? false;
                              // If it's a group, propagate to sub-items
                              if (isGroup) {
                                final subItems =
                                    item['items'] as List<dynamic>?;
                                if (subItems != null) {
                                  for (final sub in subItems) {
                                    (sub as Map<String, dynamic>)['allowed'] =
                                        val ?? false;
                                  }
                                }
                              }
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
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;

                    // Sonarr requires the cutoff to reference an allowed
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
                          await ref.read(sonarrApiProvider(instance).future);
                      final payload = isEdit
                          ? Map<String, dynamic>.from(profile)
                          : Map<String, dynamic>.from(schema!);

                      payload['name'] = name;
                      payload['upgradeAllowed'] = upgradeAllowed;
                      payload['cutoff'] = effectiveCutoff;
                      payload['items'] = editableItems;

                      if (isEdit) {
                        await api.updateQualityProfile(payload);
                      } else {
                        // Remove id for creation
                        payload.remove('id');
                        await api.createQualityProfile(payload);
                      }

                      ref.invalidate(sonarrQualityProfilesProvider(instance));
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Quality profile ${isEdit ? 'updated' : 'created'}!')),
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

  Future<void> _deleteProfile(
      BuildContext context, WidgetRef ref, int id) async {
    if (!await confirmDelete(context, 'this quality profile')) return;
    try {
      final api = await ref.read(sonarrApiProvider(instance).future);
      await api.deleteQualityProfile(id);
      ref.invalidate(sonarrQualityProfilesProvider(instance));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quality profile deleted!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete quality profile: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profilesAsync = ref.watch(sonarrQualityProfilesProvider(instance));
    // Warm up the schema so it's ready when user taps Add
    ref.watch(sonarrQualityProfileSchemaProvider(instance));

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProfileDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: profilesAsync.when(
        loading: () => const Center(child: ExpressiveProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (profiles) {
          if (profiles.isEmpty) {
            return const Center(child: Text('No quality profiles configured.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(Insets.md),
            itemCount: profiles.length,
            itemBuilder: (context, index) {
              final profile = profiles[index];
              final id = profile['id'] as int;
              final name = (profile['name'] as String?) ?? 'Unknown Profile';
              final upgradesAllowed =
                  profile['upgradeAllowed'] as bool? ?? false;

              final cutoffItem = profile['cutoff'];
              final itemsList = (profile['items'] as List<dynamic>?)
                  ?.cast<Map<String, dynamic>>();
              final cutoffMap = itemsList?.firstWhere(
                (item) {
                  final quality = item['quality'] as Map<String, dynamic>?;
                  return quality?['id'] == cutoffItem ||
                      item['id'] == cutoffItem;
                },
                orElse: () => <String, dynamic>{},
              );
              final cutoffQuality =
                  cutoffMap?['quality'] as Map<String, dynamic>?;
              final cutoffName = (cutoffQuality?['name'] as String?) ??
                  (cutoffMap?['name'] as String?) ??
                  'Unknown';

              final rawItems = itemsList ?? const <Map<String, dynamic>>[];
              final enabledQualities = rawItems
                  .where((item) => item['allowed'] as bool? ?? false)
                  .map((item) {
                final quality = item['quality'] as Map<String, dynamic>?;
                return (quality?['name'] as String?) ??
                    (item['name'] as String?) ??
                    'Unknown';
              }).toList();

              return Card(
                margin: const EdgeInsets.only(bottom: Insets.md),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                  borderRadius: Radii.card,
                ),
                child: ExpansionTile(
                  title: Text(
                    name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Cutoff: $cutoffName • Upgrades: ${upgradesAllowed ? 'Allowed' : 'Disabled'}',
                    style: theme.textTheme.bodySmall,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        left: Insets.md,
                        right: Insets.md,
                        bottom: Insets.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(),
                          const SizedBox(height: Insets.xs),
                          Text(
                            'Allowed Qualities (Sorted by priority):',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: Insets.sm),
                          if (enabledQualities.isEmpty)
                            const Text('No qualities allowed')
                          else
                            Wrap(
                              spacing: Insets.xs,
                              runSpacing: Insets.xs,
                              children: enabledQualities.map((q) {
                                final isCutoff = q == cutoffName;
                                return Chip(
                                  label: Text(
                                    q,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: isCutoff
                                          ? theme
                                              .colorScheme.onSecondaryContainer
                                          : null,
                                      fontWeight:
                                          isCutoff ? FontWeight.bold : null,
                                    ),
                                  ),
                                  backgroundColor: isCutoff
                                      ? theme.colorScheme.secondaryContainer
                                      : null,
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                );
                              }).toList(),
                            ),
                          const SizedBox(height: Insets.sm),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () =>
                                    _showProfileDialog(context, ref, profile),
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                label: const Text('Edit'),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () =>
                                    _deleteProfile(context, ref, id),
                                icon:
                                    const Icon(Icons.delete_outline, size: 18),
                                label: const Text('Delete'),
                                style: TextButton.styleFrom(
                                  foregroundColor: theme.colorScheme.error,
                                ),
                              ),
                            ],
                          ),
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
    );
  }
}

// ==========================================
// 2. DELAY PROFILES TAB
// ==========================================
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
                    const SizedBox(height: Insets.md),
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
                    const SizedBox(height: Insets.md),
                    DropdownButtonFormField<String>(
                      initialValue: preferredProtocol,
                      decoration: const InputDecoration(
                        labelText: 'Preferred Protocol',
                        border: OutlineInputBorder(),
                      ),
                      // Sonarr only accepts usenet or torrent here. Keep any
                      // unexpected fetched value selectable so the dropdown
                      // never hits the missing-value assert.
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
                    const SizedBox(height: Insets.md),
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
                          await ref.read(sonarrApiProvider(instance).future);
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
                        await api.updateDelayProfile(payload);
                      } else {
                        await api.createDelayProfile(payload);
                      }

                      ref.invalidate(sonarrDelayProfilesProvider(instance));
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Delay profile ${isEdit ? 'updated' : 'created'}!')),
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
      final api = await ref.read(sonarrApiProvider(instance).future);
      await api.deleteDelayProfile(id);
      ref.invalidate(sonarrDelayProfilesProvider(instance));
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
    final delayProfilesAsync = ref.watch(sonarrDelayProfilesProvider(instance));

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDelayProfileDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: delayProfilesAsync.when(
        loading: () => const Center(child: ExpressiveProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (profiles) {
          if (profiles.isEmpty) {
            return const Center(child: Text('No delay profiles configured.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(Insets.md),
            itemCount: profiles.length,
            itemBuilder: (context, index) {
              final profile = profiles[index];
              final id = profile['id'] as int;
              final usenetDelay = profile['usenetDelay'] as int? ?? 0;
              final torrentDelay = profile['torrentDelay'] as int? ?? 0;
              final preferred =
                  profile['preferredProtocol'] as String? ?? 'usenet';
              final bypass =
                  profile['bypassIfHighestQuality'] as bool? ?? false;

              return Card(
                margin: const EdgeInsets.only(bottom: Insets.md),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                  borderRadius: Radii.card,
                ),
                child: ListTile(
                  title: Text(
                    'Preferred: ${preferred.toUpperCase()}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Usenet Delay: ${usenetDelay}m • Torrent Delay: ${torrentDelay}m\nBypass Highest Quality: ${bypass ? 'Yes' : 'No'}',
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () =>
                            _showDelayProfileDialog(context, ref, profile),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
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

// ==========================================
// 3. RELEASE PROFILES TAB
// ==========================================
class _ReleaseProfilesTab extends ConsumerWidget {
  const _ReleaseProfilesTab({required this.instance});

  final Instance instance;

  /// Sonarr v3.0.6+ returns `required`/`ignored` as arrays of terms; older
  /// versions used a single comma separated string. Accept both shapes.
  static String _termsToText(dynamic value) {
    if (value is List) return value.join(', ');
    return (value as String?) ?? '';
  }

  /// Sonarr expects `required`/`ignored` to be saved as arrays of terms.
  static List<String> _textToTerms(String text) => text
      .split(',')
      .map((term) => term.trim())
      .where((term) => term.isNotEmpty)
      .toList();

  Future<void> _showReleaseProfileDialog(
    BuildContext context,
    WidgetRef ref, [
    Map<String, dynamic>? profile,
  ]) async {
    final isEdit = profile != null;

    final nameController =
        TextEditingController(text: profile?['name'] as String? ?? '');
    final requiredController = TextEditingController(
      text: _termsToText(profile?['required']),
    );
    final ignoredController = TextEditingController(
      text: _termsToText(profile?['ignored']),
    );
    bool enabled = profile?['enabled'] as bool? ?? true;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title:
                  Text(isEdit ? 'Edit Release Profile' : 'Add Release Profile'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Profile Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: Insets.md),
                    TextField(
                      controller: requiredController,
                      decoration: const InputDecoration(
                        labelText: 'Must Contain (Comma separated)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: Insets.md),
                    TextField(
                      controller: ignoredController,
                      decoration: const InputDecoration(
                        labelText: 'Must Not Contain (Comma separated)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: Insets.md),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enabled'),
                      value: enabled,
                      onChanged: (val) => setDialogState(() => enabled = val),
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
                          await ref.read(sonarrApiProvider(instance).future);
                      final payload = profile != null
                          ? Map<String, dynamic>.from(profile)
                          : <String, dynamic>{
                              'indexerId': 0,
                              'tags': <int>[],
                            };

                      payload['name'] = nameController.text.trim();
                      payload['required'] =
                          _textToTerms(requiredController.text);
                      payload['ignored'] = _textToTerms(ignoredController.text);
                      payload['enabled'] = enabled;

                      if (isEdit) {
                        await api.updateReleaseProfile(payload);
                      } else {
                        await api.createReleaseProfile(payload);
                      }

                      ref.invalidate(sonarrReleaseProfilesProvider(instance));
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Release profile ${isEdit ? 'updated' : 'created'}!')),
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

  Future<void> _deleteReleaseProfile(
    BuildContext context,
    WidgetRef ref,
    int id,
  ) async {
    if (!await confirmDelete(context, 'this release profile')) return;
    try {
      final api = await ref.read(sonarrApiProvider(instance).future);
      await api.deleteReleaseProfile(id);
      ref.invalidate(sonarrReleaseProfilesProvider(instance));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Release profile deleted!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete release profile: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final releaseProfilesAsync =
        ref.watch(sonarrReleaseProfilesProvider(instance));

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showReleaseProfileDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: releaseProfilesAsync.when(
        loading: () => const Center(child: ExpressiveProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (profiles) {
          if (profiles.isEmpty) {
            return const Center(child: Text('No release profiles configured.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(Insets.md),
            itemCount: profiles.length,
            itemBuilder: (context, index) {
              final profile = profiles[index];
              final id = profile['id'] as int;
              final name = (profile['name'] as String?) ?? 'Release Profile';
              final requiredStr = _termsToText(profile['required']);
              final ignoredStr = _termsToText(profile['ignored']);
              final isEnabled = profile['enabled'] as bool? ?? false;

              return Card(
                margin: const EdgeInsets.only(bottom: Insets.md),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                  borderRadius: Radii.card,
                ),
                child: ListTile(
                  title: Text(
                    name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Status: ${isEnabled ? 'Enabled' : 'Disabled'}\nMust Contain: ${requiredStr.isNotEmpty ? requiredStr : 'None'}\nMust Not Contain: ${ignoredStr.isNotEmpty ? ignoredStr : 'None'}',
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () =>
                            _showReleaseProfileDialog(context, ref, profile),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () =>
                            _deleteReleaseProfile(context, ref, id),
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

// ==========================================
// 4. CUSTOM FORMATS TAB
// ==========================================
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
                    const SizedBox(height: Insets.md),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Include in Rename'),
                      subtitle: const Text(
                          'Incorporate format in renaming output tokens'),
                      value: includeWhenRenaming,
                      onChanged: (val) =>
                          setDialogState(() => includeWhenRenaming = val),
                    ),
                    if (!isEdit) ...[
                      const SizedBox(height: Insets.md),
                      Text(
                        'Creating custom formats needs specifications - use the Sonarr web UI for now.',
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
                  // Sonarr rejects custom formats without specifications and
                  // this app has no specification editor yet, so creating new
                  // formats is disabled. Editing an existing format round-trips
                  // its fetched specifications untouched.
                  onPressed: !isEdit
                      ? null
                      : () async {
                          try {
                            final api = await ref
                                .read(sonarrApiProvider(instance).future);
                            final payload = Map<String, dynamic>.from(format);

                            payload['name'] = nameController.text.trim();
                            payload['includeCustomFormatWhenRenaming'] =
                                includeWhenRenaming;

                            await api.updateCustomFormat(payload);

                            ref.invalidate(
                                sonarrCustomFormatsProvider(instance));
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Custom format updated!')),
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
      final api = await ref.read(sonarrApiProvider(instance).future);
      await api.deleteCustomFormat(id);
      ref.invalidate(sonarrCustomFormatsProvider(instance));
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
    final customFormatsAsync = ref.watch(sonarrCustomFormatsProvider(instance));

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCustomFormatDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: customFormatsAsync.when(
        loading: () => const Center(child: ExpressiveProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (formats) {
          if (formats.isEmpty) {
            return const Center(child: Text('No custom formats configured.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(Insets.md),
            itemCount: formats.length,
            itemBuilder: (context, index) {
              final format = formats[index];
              final id = format['id'] as int;
              final name = (format['name'] as String?) ?? 'Custom Format';
              final includeRename =
                  format['includeCustomFormatWhenRenaming'] as bool? ?? false;

              return Card(
                margin: const EdgeInsets.only(bottom: Insets.md),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                  borderRadius: Radii.card,
                ),
                child: ListTile(
                  title: Text(
                    name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Include in renaming: ${includeRename ? 'Yes' : 'No'}',
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () =>
                            _showCustomFormatDialog(context, ref, format),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
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
