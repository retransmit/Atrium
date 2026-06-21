part of '../sonarr_home.dart';

class _IndexerSettingsPanel extends ConsumerWidget {
  const _IndexerSettingsPanel({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final AsyncValue<List<SonarrIndexer>> indexers = ref.watch(sonarrIndexersProvider(instance));

    return _OneUISettingsCard(
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Indexers', style: theme.textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Indexer',
              onPressed: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SonarrSettingsFormScreen(
                      instance: instance,
                      category: 'indexer',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        children: [
          AsyncValueView<List<SonarrIndexer>>(
            value: indexers,
            data: (list) {
              if (list.isEmpty) return const Text('No indexers configured.');
              return Column(
                children: list.map((indexer) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Switch(
                      value: indexer.enableRss,
                      onChanged: (val) async {
                        final api = await ref.read(sonarrApiProvider(instance).future);
                        final newRaw = Map<String, dynamic>.of(indexer.raw)..['enableRss'] = val;
                        await api.updateIndexerRaw(newRaw);
                        ref.invalidate(sonarrIndexersProvider(instance));
                      },
                    ),
                    title: Text(indexer.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    subtitle: Text('Protocol: ${indexer.protocol}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.science_outlined),
                          tooltip: 'Test Indexer',
                          onPressed: () async {
                            final api = await ref.read(sonarrApiProvider(instance).future);
                            try {
                              await api.testIndexerRaw(indexer.raw);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Indexer test successful!')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Indexer test failed')),
                                );
                              }
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit Indexer',
                          onPressed: () {
                            Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute<void>(
                                builder: (_) => SonarrSettingsFormScreen(
                                  instance: instance,
                                  category: 'indexer',
                                  itemRaw: indexer.raw,
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                          tooltip: 'Delete Indexer',
                          onPressed: () async {
                            final api = await ref.read(sonarrApiProvider(instance).future);
                            await api.deleteIndexer(indexer.id);
                            ref.invalidate(sonarrIndexersProvider(instance));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Indexer deleted')),
                              );
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

class _DownloadClientSettingsPanel extends ConsumerWidget {
  const _DownloadClientSettingsPanel({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final AsyncValue<List<SonarrDownloadClient>> clients = ref.watch(sonarrDownloadClientsProvider(instance));

    return _OneUISettingsCard(
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Download Clients', style: theme.textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Download Client',
              onPressed: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SonarrSettingsFormScreen(
                      instance: instance,
                      category: 'downloadclient',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        children: [
          AsyncValueView<List<SonarrDownloadClient>>(
            value: clients,
            data: (list) {
              if (list.isEmpty) return const Text('No download clients configured.');
              return Column(
                children: list.map((client) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Switch(
                      value: client.enable,
                      onChanged: (val) async {
                        final api = await ref.read(sonarrApiProvider(instance).future);
                        final newRaw = Map<String, dynamic>.of(client.raw)..['enable'] = val;
                        await api.updateDownloadClientRaw(newRaw);
                        ref.invalidate(sonarrDownloadClientsProvider(instance));
                      },
                    ),
                    title: Text(client.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    subtitle: Text('Protocol: ${client.protocol}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.science_outlined),
                          tooltip: 'Test Download Client',
                          onPressed: () async {
                            final api = await ref.read(sonarrApiProvider(instance).future);
                            try {
                              await api.testDownloadClientRaw(client.raw);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Download client test successful!')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Download client test failed')),
                                );
                              }
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit Download Client',
                          onPressed: () {
                            Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute<void>(
                                builder: (_) => SonarrSettingsFormScreen(
                                  instance: instance,
                                  category: 'downloadclient',
                                  itemRaw: client.raw,
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                          tooltip: 'Delete Download Client',
                          onPressed: () async {
                            final api = await ref.read(sonarrApiProvider(instance).future);
                            await api.deleteDownloadClient(client.id);
                            ref.invalidate(sonarrDownloadClientsProvider(instance));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Download client deleted')),
                              );
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

class _NotificationSettingsPanel extends ConsumerWidget {
  const _NotificationSettingsPanel({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final AsyncValue<List<SonarrNotification>> notifications = ref.watch(sonarrNotificationsProvider(instance));

    return _OneUISettingsCard(
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Notifications', style: theme.textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Notification',
              onPressed: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SonarrSettingsFormScreen(
                      instance: instance,
                      category: 'notification',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        children: [
          AsyncValueView<List<SonarrNotification>>(
            value: notifications,
            data: (list) {
              if (list.isEmpty) return const Text('No notifications configured.');
              return Column(
                children: list.map((notification) {
                  final List<String> activeTriggers = [
                    if (notification.onGrab) 'Grab',
                    if (notification.onDownload) 'Download',
                    if (notification.onUpgrade) 'Upgrade',
                  ];

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Switch(
                      value: notification.enable,
                      onChanged: (val) async {
                        final api = await ref.read(sonarrApiProvider(instance).future);
                        final newRaw = Map<String, dynamic>.of(notification.raw)..['enable'] = val;
                        await api.updateNotificationRaw(newRaw);
                        ref.invalidate(sonarrNotificationsProvider(instance));
                      },
                    ),
                    title: Text(notification.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    subtitle: Text('Triggers: ${activeTriggers.isEmpty ? "None" : activeTriggers.join(", ")}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.science_outlined),
                          tooltip: 'Test Notification',
                          onPressed: () async {
                            final api = await ref.read(sonarrApiProvider(instance).future);
                            try {
                              await api.testNotificationRaw(notification.raw);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Notification test successful!')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Notification test failed')),
                                );
                              }
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit Notification',
                          onPressed: () {
                            Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute<void>(
                                builder: (_) => SonarrSettingsFormScreen(
                                  instance: instance,
                                  category: 'notification',
                                  itemRaw: notification.raw,
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                          tooltip: 'Delete Notification',
                          onPressed: () async {
                            final api = await ref.read(sonarrApiProvider(instance).future);
                            await api.deleteNotification(notification.id);
                            ref.invalidate(sonarrNotificationsProvider(instance));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Notification deleted')),
                              );
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

class _ImportListSettingsPanel extends ConsumerWidget {
  const _ImportListSettingsPanel({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final AsyncValue<List<SonarrImportList>> lists = ref.watch(sonarrImportListsProvider(instance));

    return _OneUISettingsCard(
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Import Lists', style: theme.textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Import List',
              onPressed: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SonarrSettingsFormScreen(
                      instance: instance,
                      category: 'importlist',
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        children: [
          AsyncValueView<List<SonarrImportList>>(
            value: lists,
            data: (list) {
              if (list.isEmpty) return const Text('No import lists configured.');
              return Column(
                children: list.map((importList) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Switch(
                      value: importList.enable,
                      onChanged: (val) async {
                        final api = await ref.read(sonarrApiProvider(instance).future);
                        final newRaw = Map<String, dynamic>.of(importList.raw)..['enable'] = val;
                        await api.updateImportListRaw(newRaw);
                        ref.invalidate(sonarrImportListsProvider(instance));
                      },
                    ),
                    title: Text(importList.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.science_outlined),
                          tooltip: 'Test Import List',
                          onPressed: () async {
                            final api = await ref.read(sonarrApiProvider(instance).future);
                            try {
                              await api.testImportListRaw(importList.raw);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Import list test successful!')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Import list test failed')),
                                );
                              }
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edit Import List',
                          onPressed: () {
                            Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute<void>(
                                builder: (_) => SonarrSettingsFormScreen(
                                  instance: instance,
                                  category: 'importlist',
                                  itemRaw: importList.raw,
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                          tooltip: 'Delete Import List',
                          onPressed: () async {
                            final api = await ref.read(sonarrApiProvider(instance).future);
                            await api.deleteImportList(importList.id);
                            ref.invalidate(sonarrImportListsProvider(instance));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Import list deleted')),
                              );
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

class _TagSettingsPanel extends ConsumerWidget {
  const _TagSettingsPanel({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final AsyncValue<List<SonarrTag>> tags = ref.watch(sonarrTagsProvider(instance));

    return _OneUISettingsCard(
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Tags', style: theme.textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Tag',
              onPressed: () => _showAddTagDialog(context, ref),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        children: [
          AsyncValueView<List<SonarrTag>>(
            value: tags,
            data: (tagList) {
              if (tagList.isEmpty) return const Text('No tags created yet.');
              return Wrap(
                spacing: Insets.sm,
                runSpacing: Insets.sm,
                children: tagList.map((tag) {
                  return Chip(
                    label: Text(tag.label),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () async {
                      final api = await ref.read(sonarrApiProvider(instance).future);
                      await api.deleteTag(tag.id);
                      ref.invalidate(sonarrTagsProvider(instance));
                    },
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAddTagDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Tag'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Tag Label'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final label = controller.text.trim();
                if (label.isNotEmpty) {
                  final api = await ref.read(sonarrApiProvider(instance).future);
                  await api.createTag(label);
                  ref.invalidate(sonarrTagsProvider(instance));
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
