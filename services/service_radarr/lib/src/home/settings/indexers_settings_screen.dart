import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../radarr_providers.dart';
import 'widgets/confirm_delete.dart';
import 'widgets/dynamic_schema_form.dart';

class IndexersSettingsScreen extends ConsumerStatefulWidget {
  const IndexersSettingsScreen({
    required this.instance,
    super.key,
  });

  final Instance instance;

  @override
  ConsumerState<IndexersSettingsScreen> createState() =>
      _IndexersSettingsScreenState();
}

class _IndexersSettingsScreenState extends ConsumerState<IndexersSettingsScreen>
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
        title: const Text('Indexers & Import Lists'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Indexers'),
            Tab(text: 'Import Lists'),
            Tab(text: 'Options'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _IndexersTab(instance: widget.instance),
          _ImportListsTab(instance: widget.instance),
          _IndexerOptionsTab(instance: widget.instance),
        ],
      ),
    );
  }
}

class _IndexersTab extends ConsumerWidget {
  const _IndexersTab({required this.instance});

  final Instance instance;

  Future<void> _selectIndexerPresetAndAdd(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final schemasAsync = ref.read(radarrIndexerSchemaProvider(instance));

    final presets = schemasAsync.value ?? [];
    if (presets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading indexer presets...')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(Insets.md),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Indexer',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: Insets.md),
              Expanded(
                child: ListView.builder(
                  itemCount: presets.length,
                  itemBuilder: (context, index) {
                    final preset = presets[index];
                    final name = preset['name'] as String? ?? 'Indexer';
                    final implementation =
                        preset['implementationName'] as String? ?? '';

                    return ListTile(
                      title: Text(name),
                      subtitle: Text(implementation),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(context);
                        _showIndexerEditorDialog(context, ref, preset,
                            isNew: true);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showIndexerEditorDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> indexer, {
    bool isNew = false,
  }) async {
    final fields = (indexer['fields'] as List<dynamic>?)
            ?.map((dynamic f) => f as Map<String, dynamic>)
            .toList() ??
        [];

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(
              isNew ? 'Add ${indexer['name']}' : 'Edit ${indexer['name']}'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: DynamicSchemaForm(
                fields: fields,
                onTest: (updatedFields) async {
                  final api =
                      await ref.read(radarrApiProvider(instance).future);
                  final payload = Map<String, dynamic>.from(indexer);
                  payload['fields'] = updatedFields;
                  await api.testIndexer(payload);
                },
                onSave: (updatedFields) async {
                  try {
                    final api =
                        await ref.read(radarrApiProvider(instance).future);
                    final payload = Map<String, dynamic>.from(indexer);
                    payload['fields'] = updatedFields;

                    if (isNew) {
                      await api.createIndexer(payload);
                    } else {
                      await api.updateIndexer(payload, payload['id'] as int);
                    }

                    ref.invalidate(radarrIndexersProvider(instance));
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text('Indexer ${isNew ? 'added' : 'updated'}!'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to save indexer: $e')),
                      );
                    }
                  }
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteIndexer(
    BuildContext context,
    WidgetRef ref,
    int id,
    String name,
  ) async {
    final confirmed = await confirmDelete(context, 'Indexer "$name"');
    if (!confirmed) return;

    try {
      final api = await ref.read(radarrApiProvider(instance).future);
      await api.deleteIndexer(id);
      ref.invalidate(radarrIndexersProvider(instance));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Indexer deleted!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete indexer: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final indexersAsync = ref.watch(radarrIndexersProvider(instance));

    // Proactively fetch schema in background
    ref.watch(radarrIndexerSchemaProvider(instance));

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _selectIndexerPresetAndAdd(context, ref),
        child: const Icon(Icons.add),
      ),
      body: indexersAsync.when(
        loading: () => const Center(child: ExpressiveProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (indexers) {
          if (indexers.isEmpty) {
            return const Center(
                child: Text('No indexers configured. Tap + to add one.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(Insets.md),
            itemCount: indexers.length,
            itemBuilder: (context, index) {
              final idx = indexers[index];
              final name = idx['name'] as String? ?? 'Indexer';
              final proto = idx['protocol'] as String? ?? 'Torrent';
              final id = idx['id'] as int;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: theme.colorScheme.surfaceContainerLow,
                child: ListTile(
                  title: Text(name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Protocol: ${proto.toUpperCase()}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () =>
                            _showIndexerEditorDialog(context, ref, idx),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            color: theme.colorScheme.error),
                        onPressed: () => _deleteIndexer(context, ref, id, name),
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

class _ImportListsTab extends ConsumerWidget {
  const _ImportListsTab({required this.instance});

  final Instance instance;

  Future<void> _selectImportListPresetAndAdd(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final schemasAsync = ref.read(radarrImportListSchemaProvider(instance));

    final presets = schemasAsync.value ?? [];
    if (presets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading presets...')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(Insets.md),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Import List',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: Insets.md),
              Expanded(
                child: ListView.builder(
                  itemCount: presets.length,
                  itemBuilder: (context, index) {
                    final preset = presets[index];
                    final name = preset['name'] as String? ?? 'Import List';

                    return ListTile(
                      title: Text(name),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(context);
                        _showImportListEditorDialog(context, ref, preset,
                            isNew: true);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showImportListEditorDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> list, {
    bool isNew = false,
  }) async {
    final fields = (list['fields'] as List<dynamic>?)
            ?.map((dynamic f) => f as Map<String, dynamic>)
            .toList() ??
        [];
    final String listName = list['name'] as String? ??
        list['implementationName'] as String? ??
        'Import List';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(isNew ? 'Add $listName' : 'Edit $listName'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: DynamicSchemaForm(
                fields: fields,
                onTest: (updatedFields) async {
                  final api =
                      await ref.read(radarrApiProvider(instance).future);
                  final payload = Map<String, dynamic>.from(list);
                  payload['fields'] = updatedFields;
                  await api.testImportList(payload);
                },
                onSave: (updatedFields) async {
                  try {
                    final api =
                        await ref.read(radarrApiProvider(instance).future);
                    final payload = Map<String, dynamic>.from(list);
                    payload['fields'] = updatedFields;

                    if (isNew) {
                      // New lists need root folder, quality profile and
                      // movie defaults. Fill them from the server only
                      // when the schema payload lacks a value; if a lookup
                      // returns nothing, omit the key and let the server
                      // validate. Edits keep the fetched list's own values.
                      final dynamic existingRoot = payload['rootFolderPath'];
                      if (existingRoot == null ||
                          (existingRoot is String && existingRoot.isEmpty)) {
                        final rootFolders = await ref.read(
                          radarrRootFoldersProvider(instance).future,
                        );
                        final path = rootFolders.isNotEmpty
                            ? rootFolders.first['path'] as String?
                            : null;
                        if (path != null && path.isNotEmpty) {
                          payload['rootFolderPath'] = path;
                        }
                      }
                      final dynamic existingProfile =
                          payload['qualityProfileId'];
                      if (existingProfile == null || existingProfile == 0) {
                        final profiles = await ref.read(
                          radarrQualityProfilesProvider(instance).future,
                        );
                        final profileId = profiles.isNotEmpty
                            ? profiles.first['id'] as int?
                            : null;
                        if (profileId != null) {
                          payload['qualityProfileId'] = profileId;
                        }
                      }
                      payload['monitor'] ??= 'movieOnly';
                      payload['minimumAvailability'] ??= 'announced';
                      await api.createImportList(payload);
                    } else {
                      await api.updateImportList(payload, payload['id'] as int);
                    }

                    ref.invalidate(radarrImportListsProvider(instance));
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Import list ${isNew ? 'added' : 'updated'}!'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Failed to save import list: $e')),
                      );
                    }
                  }
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteImportList(
    BuildContext context,
    WidgetRef ref,
    int id,
    String name,
  ) async {
    final confirmed = await confirmDelete(context, 'Import List "$name"');
    if (!confirmed) return;

    try {
      final api = await ref.read(radarrApiProvider(instance).future);
      await api.deleteImportList(id);
      ref.invalidate(radarrImportListsProvider(instance));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Import list deleted!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete import list: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final listsAsync = ref.watch(radarrImportListsProvider(instance));

    ref.watch(radarrImportListSchemaProvider(instance));

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _selectImportListPresetAndAdd(context, ref),
        child: const Icon(Icons.add),
      ),
      body: listsAsync.when(
        loading: () => const Center(child: ExpressiveProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (lists) {
          if (lists.isEmpty) {
            return const Center(
                child: Text('No import lists configured. Tap + to add one.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(Insets.md),
            itemCount: lists.length,
            itemBuilder: (context, index) {
              final lst = lists[index];
              final name = lst['name'] as String? ?? 'Import List';
              final id = lst['id'] as int;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: theme.colorScheme.surfaceContainerLow,
                child: ListTile(
                  title: Text(name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () =>
                            _showImportListEditorDialog(context, ref, lst),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            color: theme.colorScheme.error),
                        onPressed: () =>
                            _deleteImportList(context, ref, id, name),
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

class _IndexerOptionsTab extends ConsumerStatefulWidget {
  const _IndexerOptionsTab({required this.instance});

  final Instance instance;

  @override
  ConsumerState<_IndexerOptionsTab> createState() => _IndexerOptionsTabState();
}

class _IndexerOptionsTabState extends ConsumerState<_IndexerOptionsTab> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _minAgeController;
  late final TextEditingController _retentionController;
  late final TextEditingController _maxSizeController;
  late final TextEditingController _rssIntervalController;
  bool _saving = false;
  bool _initialized = false;
  Map<String, dynamic>? _rawConfig;

  @override
  void initState() {
    super.initState();
    _minAgeController = TextEditingController();
    _retentionController = TextEditingController();
    _maxSizeController = TextEditingController();
    _rssIntervalController = TextEditingController();
  }

  @override
  void dispose() {
    _minAgeController.dispose();
    _retentionController.dispose();
    _maxSizeController.dispose();
    _rssIntervalController.dispose();
    super.dispose();
  }

  void _initialize(Map<String, dynamic> config) {
    if (_initialized) return;
    _initialized = true;
    _rawConfig = config;

    _minAgeController.text = (config['minimumAge'] as int? ?? 0).toString();
    _retentionController.text = (config['retention'] as int? ?? 0).toString();
    _maxSizeController.text = (config['maximumSize'] as int? ?? 0).toString();
    _rssIntervalController.text =
        (config['rssSyncInterval'] as int? ?? 15).toString();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _rawConfig == null) return;
    setState(() => _saving = true);

    try {
      final api = await ref.read(radarrApiProvider(widget.instance).future);
      final payload = Map<String, dynamic>.from(_rawConfig!);
      payload['minimumAge'] = int.tryParse(_minAgeController.text.trim()) ?? 0;
      payload['retention'] =
          int.tryParse(_retentionController.text.trim()) ?? 0;
      payload['maximumSize'] =
          int.tryParse(_maxSizeController.text.trim()) ?? 0;
      payload['rssSyncInterval'] =
          int.tryParse(_rssIntervalController.text.trim()) ?? 15;

      await api.updateIndexerConfig(payload);
      ref.invalidate(radarrIndexerConfigProvider(widget.instance));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Indexer options saved!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final configAsync = ref.watch(radarrIndexerConfigProvider(widget.instance));

    return configAsync.when(
      loading: () => const Center(child: ExpressiveProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (config) {
        _initialize(config);

        return Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(Insets.md),
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(Insets.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Indexer Options',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: Insets.md),
                      TextFormField(
                        controller: _minAgeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Minimum Age (Minutes)',
                          helperText: 'Usenet only: delay search matches',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: Insets.md),
                      TextFormField(
                        controller: _retentionController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Retention (Days)',
                          helperText:
                              'Usenet only: max retention age (0 = unlimited)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: Insets.md),
                      TextFormField(
                        controller: _maxSizeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Maximum Size',
                          helperText: '0 = unlimited',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: Insets.md),
                      TextFormField(
                        controller: _rssIntervalController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'RSS Sync Interval (Minutes)',
                          helperText: 'Default: 15 minutes',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: Insets.lg),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const ExpressiveProgressIndicator()
                              : const Text('Save Options'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
