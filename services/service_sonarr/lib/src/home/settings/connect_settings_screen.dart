import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sonarr_providers.dart';
import 'widgets/confirm_delete.dart';
import 'widgets/dynamic_schema_form.dart';

class ConnectSettingsScreen extends ConsumerWidget {
  const ConnectSettingsScreen({
    required this.instance,
    super.key,
  });

  final Instance instance;

  Future<void> _selectNotificationPresetAndAdd(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final schemasAsync = ref.read(sonarrNotificationSchemaProvider(instance));
    final presets = schemasAsync.value ?? [];
    if (presets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading notification presets...')),
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
                'Add Notification Integration',
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
                    final name = preset['name'] as String? ?? 'Notification';
                    final implementation =
                        preset['implementationName'] as String? ?? '';

                    return ListTile(
                      title: Text(name),
                      subtitle: Text(implementation),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(context);
                        _showNotificationEditorDialog(
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

  Future<void> _showNotificationEditorDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> notification, {
    bool isNew = false,
  }) async {
    final fields = (notification['fields'] as List<dynamic>?)
            ?.map((dynamic f) => f as Map<String, dynamic>)
            .toList() ??
        [];

    final nameController =
        TextEditingController(text: notification['name'] as String? ?? '');
    bool onGrab = notification['onGrab'] as bool? ?? true;
    bool onDownload = notification['onDownload'] as bool? ?? true;
    bool onUpgrade = notification['onUpgrade'] as bool? ?? true;
    bool onRename = notification['onRename'] as bool? ?? false;
    bool onSeriesAdd = notification['onSeriesAdd'] as bool? ?? false;
    bool onSeriesDelete = notification['onSeriesDelete'] as bool? ?? false;
    bool onEpisodeFileDelete =
        notification['onEpisodeFileDelete'] as bool? ?? false;
    bool onHealthIssue = notification['onHealthIssue'] as bool? ?? false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                isNew
                    ? 'Add ${notification['name']}'
                    : 'Edit ${notification['name']}',
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: Insets.md),
                      // Trigger Events Card
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                          borderRadius: Radii.card,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(Insets.sm),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Trigger Events',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('On Grab'),
                                value: onGrab,
                                onChanged: (val) =>
                                    setDialogState(() => onGrab = val ?? false),
                              ),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('On Download'),
                                value: onDownload,
                                onChanged: (val) => setDialogState(
                                    () => onDownload = val ?? false,),
                              ),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('On Upgrade'),
                                value: onUpgrade,
                                onChanged: (val) => setDialogState(
                                    () => onUpgrade = val ?? false,),
                              ),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('On Rename'),
                                value: onRename,
                                onChanged: (val) => setDialogState(
                                    () => onRename = val ?? false,),
                              ),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('On Series Add'),
                                value: onSeriesAdd,
                                onChanged: (val) => setDialogState(
                                  () => onSeriesAdd = val ?? false,
                                ),
                              ),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('On Series Delete'),
                                value: onSeriesDelete,
                                onChanged: (val) => setDialogState(
                                  () => onSeriesDelete = val ?? false,
                                ),
                              ),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('On Episode File Delete'),
                                value: onEpisodeFileDelete,
                                onChanged: (val) => setDialogState(
                                  () => onEpisodeFileDelete = val ?? false,
                                ),
                              ),
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('On Health Issue'),
                                value: onHealthIssue,
                                onChanged: (val) => setDialogState(
                                  () => onHealthIssue = val ?? false,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: Insets.md),
                      // Custom field editor
                      DynamicSchemaForm(
                        fields: fields,
                        onTest: (updatedFields) async {
                          final api = await ref
                              .read(sonarrApiProvider(instance).future);
                          final payload =
                              Map<String, dynamic>.from(notification);
                          payload['name'] = nameController.text.trim();
                          payload['onGrab'] = onGrab;
                          payload['onDownload'] = onDownload;
                          payload['onUpgrade'] = onUpgrade;
                          payload['onRename'] = onRename;
                          payload['onSeriesAdd'] = onSeriesAdd;
                          payload['onSeriesDelete'] = onSeriesDelete;
                          payload['onEpisodeFileDelete'] = onEpisodeFileDelete;
                          payload['onHealthIssue'] = onHealthIssue;
                          payload['fields'] = updatedFields;
                          await api.testNotification(payload);
                        },
                        onSave: (updatedFields) async {
                          try {
                            final api = await ref
                                .read(sonarrApiProvider(instance).future);
                            final payload =
                                Map<String, dynamic>.from(notification);
                            payload['name'] = nameController.text.trim();
                            payload['onGrab'] = onGrab;
                            payload['onDownload'] = onDownload;
                            payload['onUpgrade'] = onUpgrade;
                            payload['onRename'] = onRename;
                            payload['onSeriesAdd'] = onSeriesAdd;
                            payload['onSeriesDelete'] = onSeriesDelete;
                            payload['onEpisodeFileDelete'] =
                                onEpisodeFileDelete;
                            payload['onHealthIssue'] = onHealthIssue;
                            payload['fields'] = updatedFields;

                            if (isNew) {
                              await api.createNotification(payload);
                            } else {
                              await api.updateNotification(payload);
                            }

                            ref.invalidate(
                                sonarrNotificationsProvider(instance),);
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Notification ${isNew ? 'added' : 'updated'}!',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Failed to save notification: $e',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteNotification(
    BuildContext context,
    WidgetRef ref,
    int id,
  ) async {
    if (!await confirmDelete(context, 'this notification')) return;
    try {
      final api = await ref.read(sonarrApiProvider(instance).future);
      await api.deleteNotification(id);
      ref.invalidate(sonarrNotificationsProvider(instance));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification deleted!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete notification: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notificationsAsync = ref.watch(sonarrNotificationsProvider(instance));
    // Warm up templates
    ref.watch(sonarrNotificationSchemaProvider(instance));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect (Notifications)'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _selectNotificationPresetAndAdd(context, ref),
        child: const Icon(Icons.add),
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: ExpressiveProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(
              child: Text('No notification connections configured.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(Insets.md),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final id = notification['id'] as int;
              final name = (notification['name'] as String?) ?? 'Connect';
              final implementation =
                  (notification['implementationName'] as String?) ?? '';

              final List<String> activeEvents = [];
              if (notification['onGrab'] as bool? ?? false) {
                activeEvents.add('Grab');
              }
              if (notification['onDownload'] as bool? ?? false) {
                activeEvents.add('Download');
              }
              if (notification['onUpgrade'] as bool? ?? false) {
                activeEvents.add('Upgrade');
              }
              if (notification['onRename'] as bool? ?? false) {
                activeEvents.add('Rename');
              }
              if (notification['onSeriesAdd'] as bool? ?? false) {
                activeEvents.add('Series Add');
              }
              if (notification['onHealthIssue'] as bool? ?? false) {
                activeEvents.add('Health');
              }

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
                    '$implementation\nEvents: ${activeEvents.isEmpty ? 'None' : activeEvents.join(', ')}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _showNotificationEditorDialog(
                          context,
                          ref,
                          notification,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteNotification(context, ref, id),
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
