import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../radarr_providers.dart';
import 'widgets/confirm_delete.dart';
import 'widgets/dynamic_schema_form.dart';

class DownloadClientsScreen extends ConsumerStatefulWidget {
  const DownloadClientsScreen({
    required this.instance,
    super.key,
  });

  final Instance instance;

  @override
  ConsumerState<DownloadClientsScreen> createState() =>
      _DownloadClientsScreenState();
}

class _DownloadClientsScreenState extends ConsumerState<DownloadClientsScreen>
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
        title: const Text('Download Clients & Mappings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Clients'),
            Tab(text: 'Path Mappings'),
            Tab(text: 'Options'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DownloadClientsTab(instance: widget.instance),
          _RemotePathMappingsTab(instance: widget.instance),
          _DownloadClientOptionsTab(instance: widget.instance),
        ],
      ),
    );
  }
}

class _DownloadClientsTab extends ConsumerWidget {
  const _DownloadClientsTab({required this.instance});

  final Instance instance;

  Future<void> _selectClientPresetAndAdd(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final schemasAsync = ref.read(radarrDownloadClientSchemaProvider(instance));
    final presets = schemasAsync.value ?? [];
    if (presets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading download client presets...')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(Insets.md),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Download Client',
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
                    final name = preset['name'] as String? ?? 'Client';
                    final implementation =
                        preset['implementationName'] as String? ?? '';

                    return ListTile(
                      title: Text(name),
                      subtitle: Text(implementation),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(context);
                        _showClientEditorDialog(
                          context,
                          ref,
                          preset,
                          isNew: true,
                        );
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

  Future<void> _showClientEditorDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> client, {
    bool isNew = false,
  }) async {
    final fields = (client['fields'] as List<dynamic>?)
            ?.map((dynamic f) => f as Map<String, dynamic>)
            .toList() ??
        [];

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title:
              Text(isNew ? 'Add ${client['name']}' : 'Edit ${client['name']}'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: DynamicSchemaForm(
                fields: fields,
                onTest: (updatedFields) async {
                  final api =
                      await ref.read(radarrApiProvider(instance).future);
                  final payload = Map<String, dynamic>.from(client);
                  payload['fields'] = updatedFields;
                  await api.testDownloadClient(payload);
                },
                onSave: (updatedFields) async {
                  try {
                    final api =
                        await ref.read(radarrApiProvider(instance).future);
                    final payload = Map<String, dynamic>.from(client);
                    payload['fields'] = updatedFields;

                    if (isNew) {
                      await api.createDownloadClient(payload);
                    } else {
                      await api.updateDownloadClient(
                        payload,
                        payload['id'] as int,
                      );
                    }

                    ref.invalidate(radarrDownloadClientsProvider(instance));
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Download client ${isNew ? 'added' : 'updated'}!',
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to save download client: $e'),
                        ),
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

  Future<void> _deleteClient(
    BuildContext context,
    WidgetRef ref,
    int id,
    String name,
  ) async {
    final confirmed = await confirmDelete(context, 'Download Client "$name"');
    if (!confirmed) return;

    try {
      final api = await ref.read(radarrApiProvider(instance).future);
      await api.deleteDownloadClient(id);
      ref.invalidate(radarrDownloadClientsProvider(instance));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download client deleted!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete download client: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final clientsAsync = ref.watch(radarrDownloadClientsProvider(instance));

    ref.watch(radarrDownloadClientSchemaProvider(instance));

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _selectClientPresetAndAdd(context, ref),
        child: const Icon(Icons.add),
      ),
      body: clientsAsync.when(
        loading: () => const Center(child: ExpressiveProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (clients) {
          if (clients.isEmpty) {
            return const Center(
              child: Text('No download clients configured. Tap + to add one.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(Insets.md),
            itemCount: clients.length,
            itemBuilder: (context, index) {
              final c = clients[index];
              final name = c['name'] as String? ?? 'Client';
              final proto = c['protocol'] as String? ?? 'Torrent';
              final id = c['id'] as int;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: theme.colorScheme.surfaceContainerLow,
                child: ListTile(
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Protocol: ${proto.toUpperCase()}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () =>
                            _showClientEditorDialog(context, ref, c),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: theme.colorScheme.error,
                        ),
                        onPressed: () => _deleteClient(context, ref, id, name),
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

class _RemotePathMappingsTab extends ConsumerWidget {
  const _RemotePathMappingsTab({required this.instance});

  final Instance instance;

  Future<void> _showMappingDialog(
    BuildContext context,
    WidgetRef ref, [
    Map<String, dynamic>? mapping,
  ]) async {
    final isEdit = mapping != null;
    final hostController =
        TextEditingController(text: mapping?['host'] as String? ?? '');
    final remoteController =
        TextEditingController(text: mapping?['remotePath'] as String? ?? '');
    final localController =
        TextEditingController(text: mapping?['localPath'] as String? ?? '');

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEdit ? 'Edit Path Mapping' : 'Add Path Mapping'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: hostController,
                decoration: const InputDecoration(
                  labelText: 'Host',
                  helperText: 'Download client host (exactly as configured)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: Insets.md),
              TextField(
                controller: remoteController,
                decoration: const InputDecoration(
                  labelText: 'Remote Path',
                  helperText: 'Path reported by download client',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: Insets.md),
              TextField(
                controller: localController,
                decoration: const InputDecoration(
                  labelText: 'Local Path',
                  helperText: 'Path accessible by Radarr local system',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
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
                  final payload = mapping != null
                      ? Map<String, dynamic>.from(mapping)
                      : <String, dynamic>{};

                  payload['host'] = hostController.text.trim();
                  payload['remotePath'] = remoteController.text.trim();
                  payload['localPath'] = localController.text.trim();

                  if (isEdit) {
                    await api.updateRemotePathMapping(
                      payload,
                      payload['id'] as int,
                    );
                  } else {
                    await api.createRemotePathMapping(payload);
                  }

                  ref.invalidate(radarrRemotePathMappingsProvider(instance));
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Path mapping saved!')),
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
  }

  Future<void> _deleteMapping(
    BuildContext context,
    WidgetRef ref,
    int id,
    String host,
  ) async {
    final confirmed = await confirmDelete(context, 'Path Mapping for "$host"');
    if (!confirmed) return;

    try {
      final api = await ref.read(radarrApiProvider(instance).future);
      await api.deleteRemotePathMapping(id);
      ref.invalidate(radarrRemotePathMappingsProvider(instance));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Path mapping deleted!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete path mapping: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mappingsAsync = ref.watch(radarrRemotePathMappingsProvider(instance));

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showMappingDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: mappingsAsync.when(
        loading: () => const Center(child: ExpressiveProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (mappings) {
          if (mappings.isEmpty) {
            return const Center(
              child: Text('No path mappings configured. Tap + to add one.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(Insets.md),
            itemCount: mappings.length,
            itemBuilder: (context, index) {
              final m = mappings[index];
              final id = m['id'] as int;
              final host = m['host'] as String? ?? 'localhost';
              final remote = m['remotePath'] as String? ?? '';
              final local = m['localPath'] as String? ?? '';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: theme.colorScheme.surfaceContainerLow,
                child: ListTile(
                  title: Text(
                    'Host: $host',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Remote: $remote\nLocal: $local'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _showMappingDialog(context, ref, m),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: theme.colorScheme.error,
                        ),
                        onPressed: () => _deleteMapping(context, ref, id, host),
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

class _DownloadClientOptionsTab extends ConsumerStatefulWidget {
  const _DownloadClientOptionsTab({required this.instance});

  final Instance instance;

  @override
  ConsumerState<_DownloadClientOptionsTab> createState() =>
      _DownloadClientOptionsTabState();
}

class _DownloadClientOptionsTabState
    extends ConsumerState<_DownloadClientOptionsTab> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool _initialized = false;
  Map<String, dynamic>? _rawConfig;

  bool _enableCompletedDownloadHandling = false;
  bool _autoRedownloadFailed = false;

  void _initialize(Map<String, dynamic> config) {
    if (_initialized) return;
    _initialized = true;
    _rawConfig = config;

    _enableCompletedDownloadHandling =
        config['enableCompletedDownloadHandling'] as bool? ?? false;
    _autoRedownloadFailed = config['autoRedownloadFailed'] as bool? ?? false;
  }

  Future<void> _save() async {
    if (_rawConfig == null) return;
    setState(() => _saving = true);

    try {
      final api = await ref.read(radarrApiProvider(widget.instance).future);
      final payload = Map<String, dynamic>.from(_rawConfig!);
      payload['enableCompletedDownloadHandling'] =
          _enableCompletedDownloadHandling;
      payload['autoRedownloadFailed'] = _autoRedownloadFailed;

      await api.updateDownloadClientConfig(payload);
      ref.invalidate(radarrDownloadClientConfigProvider(widget.instance));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download client config saved!')),
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
    final configAsync =
        ref.watch(radarrDownloadClientConfigProvider(widget.instance));

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
                        'Completed Download Handling',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: Insets.md),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enable Completed Download Handling'),
                        subtitle: const Text(
                          'Automatically import finished downloads from clients',
                        ),
                        value: _enableCompletedDownloadHandling,
                        onChanged: (val) => setState(
                          () => _enableCompletedDownloadHandling = val,
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Redownload Failed'),
                        subtitle: const Text(
                          'Search for a release alternative if download reports failure',
                        ),
                        value: _autoRedownloadFailed,
                        onChanged: (val) =>
                            setState(() => _autoRedownloadFailed = val),
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
