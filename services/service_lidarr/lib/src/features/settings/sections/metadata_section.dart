import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../generated/generated.dart';
import '../../../lidarr_api.dart';
import '../../../lidarr_providers.dart';
import '../widgets/dynamic_schema_form.dart';
import '../widgets/schema_preset_picker.dart';

/// Metadata Consumers configuration section.
class MetadataConsumersSection extends ConsumerWidget {
  const MetadataConsumersSection({required this.instance, super.key});

  final Instance instance;

  Future<void> _showAddMetadataConsumerDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final List<MetadataResource> schemas =
        ref.read(lidarrMetadataConsumerSchemaProvider(instance)).value ??
            <MetadataResource>[];
    if (schemas.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No metadata consumer presets available.'),
        ),
      );
      return;
    }

    final MetadataResource? selected =
        await showSchemaPresetPicker<MetadataResource>(
      context: context,
      title: 'Add Metadata Consumer',
      presets: schemas,
      titleBuilder: (schema) {
        final String impl = schema.implementationName?.trim() ?? '';
        final String name = schema.name?.trim() ?? '';
        if (impl.isNotEmpty) return impl;
        if (name.isNotEmpty && name != 'Consumer' && name != 'Metadata') {
          return name;
        }
        return schema.implementation ?? 'Metadata Consumer';
      },
      subtitleBuilder: (schema) {
        final String impl = schema.implementationName?.trim() ?? '';
        final String name = schema.name?.trim() ?? '';
        if (impl.isNotEmpty && name.isNotEmpty && name != impl) {
          return name;
        }
        return '';
      },
      icon: Icons.perm_media_outlined,
    );

    if (selected != null && context.mounted) {
      await _showEditMetadataConsumerDialog(
        context,
        ref,
        selected,
        isNew: true,
      );
    }
  }

  Future<void> _showEditMetadataConsumerDialog(
    BuildContext context,
    WidgetRef ref,
    MetadataResource consumer, {
    bool isNew = false,
  }) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String initialName = isNew
        ? ((consumer.implementationName?.isNotEmpty == true)
            ? consumer.implementationName!
            : (consumer.name != 'Consumer' && consumer.name != 'Metadata'
                ? (consumer.name ?? '')
                : ''))
        : (consumer.name ?? '');

    final TextEditingController nameController =
        TextEditingController(text: initialName);
    bool enable = consumer.enable ?? true;
    final List<Map<String, dynamic>> fields =
        (consumer.fields ?? <Field>[]).map((Field f) => f.toJson()).toList();

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dCtx) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setDialogState) {
            return AlertDialog(
              title: Text(
                isNew
                    ? 'Add Metadata Consumer'
                    : 'Edit ${consumer.name ?? 'Metadata Consumer'}',
              ),
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
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: Insets.sm),
                      SwitchListTile(
                        title: const Text('Enable Consumer'),
                        value: enable,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (bool val) =>
                            setDialogState(() => enable = val),
                      ),
                      const SizedBox(height: Insets.md),
                      DynamicSchemaForm(
                        fields: fields,
                        onTest:
                            (List<Map<String, dynamic>> updatedFields) async {
                          final LidarrApi api = await ref
                              .read(lidarrApiProvider(instance).future);
                          final MetadataResource payload = consumer.copyWith(
                            id: consumer.id ?? 0,
                            name: nameController.text.trim().isNotEmpty
                                ? nameController.text.trim()
                                : consumer.name,
                            enable: enable,
                            fields: updatedFields.map(Field.fromJson).toList(),
                          );
                          final ApiResponse<void> resp = await api.metadata
                              .postMetadataTest(body: payload);
                          if (!resp.isSuccess) {
                            throw Exception(
                              resp.error?.message ?? 'Test failed',
                            );
                          }
                        },
                        onSave:
                            (List<Map<String, dynamic>> updatedFields) async {
                          try {
                            final LidarrApi api = await ref.read(
                              lidarrApiProvider(instance).future,
                            );
                            final MetadataResource payload = consumer.copyWith(
                              id: consumer.id ?? 0,
                              name: nameController.text.trim().isNotEmpty
                                  ? nameController.text.trim()
                                  : consumer.name,
                              enable: enable,
                              fields:
                                  updatedFields.map(Field.fromJson).toList(),
                            );

                            if (isNew) {
                              final ApiResponse<MetadataResource> resp =
                                  await api.metadata
                                      .postMetadata(body: payload);
                              if (!resp.isSuccess) {
                                throw Exception(
                                  resp.error?.message ??
                                      'Failed to create metadata consumer',
                                );
                              }
                            } else {
                              final ApiResponse<MetadataResource> resp =
                                  await api.metadata.putMetadataById(
                                id: consumer.id!,
                                body: payload,
                              );
                              if (!resp.isSuccess) {
                                throw Exception(
                                  resp.error?.message ??
                                      'Failed to update metadata consumer',
                                );
                              }
                            }

                            ref.invalidate(
                              lidarrMetadataConsumersProvider(instance),
                            );
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Metadata consumer ${isNew ? 'added' : 'updated'}!',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              messenger.showSnackBar(
                                SnackBar(content: Text('Error: $e')),
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

  Future<void> _deleteMetadataConsumer(
    BuildContext context,
    WidgetRef ref,
    MetadataResource consumer,
  ) async {
    final int? id = consumer.id;
    if (id == null) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('Delete ${consumer.name ?? 'Consumer'}?'),
        content: Text('Are you sure you want to delete "${consumer.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final LidarrApi api = await ref.read(lidarrApiProvider(instance).future);
      final ApiResponse<void> resp =
          await api.metadata.deleteMetadataById(id: id);
      if (!resp.isSuccess) {
        throw Exception(
          resp.error?.message ?? 'Failed to delete metadata consumer',
        );
      }

      ref.invalidate(lidarrMetadataConsumersProvider(instance));
      messenger.showSnackBar(
        const SnackBar(content: Text('Metadata consumer deleted.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to delete metadata consumer: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final AsyncValue<List<MetadataResource>> asyncConsumers =
        ref.watch(lidarrMetadataConsumersProvider(instance));

    ref.watch(lidarrMetadataConsumerSchemaProvider(instance));

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_metadata_consumer_fab',
        onPressed: () => _showAddMetadataConsumerDialog(context, ref),
        tooltip: 'Add Metadata Consumer',
        child: const Icon(Icons.add),
      ),
      body: EasyRefresh(
        onRefresh: () async {
          ref.invalidate(lidarrMetadataConsumersProvider(instance));
        },
        child: AsyncValueView<List<MetadataResource>>(
          value: asyncConsumers,
          data: (List<MetadataResource> consumers) {
            if (consumers.isEmpty) {
              return Center(
                child: EmptyView(
                  icon: Icons.perm_media_outlined,
                  title: 'No Metadata Consumers',
                  message:
                      'Add metadata consumers (Kodi, Roon, WMP) to write metadata and cover images alongside audio tracks.',
                  action: FilledButton.icon(
                    onPressed: () =>
                        _showAddMetadataConsumerDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Metadata Consumer'),
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                Insets.md,
                Insets.md,
                Insets.md,
                80,
              ),
              itemCount: consumers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (BuildContext context, int index) {
                final MetadataResource item = consumers[index];
                final bool isEnabled = item.enable == true;

                return Card(
                  elevation: 0,
                  color: cs.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isEnabled
                            ? Icons.perm_media
                            : Icons.perm_media_outlined,
                        color: cs.onPrimaryContainer,
                        size: 22,
                      ),
                    ),
                    title: Text(
                      item.name ?? 'Metadata Consumer',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.implementationName ?? 'Consumer',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color:
                                  isEnabled ? cs.primary : cs.onSurfaceVariant,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isEnabled ? 'Active' : 'Disabled',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: isEnabled
                                          ? cs.primary
                                          : cs.onSurfaceVariant,
                                      fontWeight: isEnabled
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      tooltip: 'Delete Consumer',
                      onPressed: () =>
                          _deleteMetadataConsumer(context, ref, item),
                    ),
                    onTap: () =>
                        _showEditMetadataConsumerDialog(context, ref, item),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
