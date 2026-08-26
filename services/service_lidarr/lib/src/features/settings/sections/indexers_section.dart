import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/lidarr_formatters.dart';
import '../../../generated/generated.dart';
import '../../../lidarr_api.dart';
import '../../../lidarr_providers.dart';
import '../widgets/dynamic_schema_form.dart';
import '../widgets/schema_preset_picker.dart';

/// Indexers configuration section.
class IndexersSection extends ConsumerWidget {
  const IndexersSection({required this.instance, super.key});

  final Instance instance;

  Future<void> _selectIndexerPresetAndAdd(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final AsyncValue<List<IndexerResource>> schemasAsync =
        ref.read(lidarrIndexerSchemaProvider(instance));
    final List<IndexerResource> presets = schemasAsync.value ?? [];
    if (presets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading indexer presets...')),
      );
      return;
    }

    final IndexerResource? selectedPreset =
        await showSchemaPresetPicker<IndexerResource>(
      context: context,
      title: 'Add Indexer',
      presets: presets,
      titleBuilder: (preset) {
        final String impl = preset.implementationName?.trim() ?? '';
        final String name = preset.name?.trim() ?? '';
        if (impl.isNotEmpty) return impl;
        if (name.isNotEmpty && name != 'Indexer') return name;
        return preset.implementation ?? 'Indexer';
      },
      subtitleBuilder: (preset) {
        final String impl = preset.implementationName?.trim() ?? '';
        final String name = preset.name?.trim() ?? '';
        if (impl.isNotEmpty &&
            name.isNotEmpty &&
            name != 'Indexer' &&
            name != impl) {
          return name;
        }
        return '';
      },
      icon: Icons.rss_feed,
    );

    if (selectedPreset != null && context.mounted) {
      await _showIndexerEditorDialog(
        context,
        ref,
        selectedPreset,
        isNew: true,
      );
    }
  }

  Future<void> _showIndexerEditorDialog(
    BuildContext context,
    WidgetRef ref,
    IndexerResource indexer, {
    bool isNew = false,
  }) async {
    final List<Map<String, dynamic>> fields =
        (indexer.fields ?? []).map((Field f) => f.toJson()).toList();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(
            isNew
                ? 'Add ${indexer.implementationName ?? indexer.name ?? 'Indexer'}'
                : 'Edit ${indexer.name ?? indexer.implementationName ?? 'Indexer'}',
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: DynamicSchemaForm(
                fields: fields,
                onTest: (List<Map<String, dynamic>> updatedFields) async {
                  final LidarrApi api =
                      await ref.read(lidarrApiProvider(instance).future);
                  final IndexerResource payload = indexer.copyWith(
                    id: indexer.id ?? 0,
                    fields: updatedFields.map(Field.fromJson).toList(),
                  );
                  final ApiResponse<void> resp =
                      await api.indexer.postIndexerTest(body: payload);
                  if (!resp.isSuccess) {
                    throw Exception(
                      resp.error?.message ?? 'Connection test failed',
                    );
                  }
                },
                onSave: (List<Map<String, dynamic>> updatedFields) async {
                  final ScaffoldMessengerState messenger =
                      ScaffoldMessenger.of(context);
                  try {
                    final LidarrApi api =
                        await ref.read(lidarrApiProvider(instance).future);
                    final IndexerResource payload = indexer.copyWith(
                      id: indexer.id ?? 0,
                      fields: updatedFields.map(Field.fromJson).toList(),
                    );

                    if (isNew) {
                      await api.indexer.postIndexer(body: payload);
                    } else if (indexer.id != null) {
                      await api.indexer.putIndexerById(
                        id: indexer.id!,
                        body: payload,
                      );
                    }

                    ref.invalidate(lidarrIndexersProvider(instance));
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            isNew
                                ? 'Indexer added successfully!'
                                : 'Indexer updated successfully!',
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Error saving indexer: $e')),
                      );
                    }
                  }
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteIndexer(
    BuildContext context,
    WidgetRef ref,
    IndexerResource indexer,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('Delete ${indexer.name ?? 'Indexer'}?'),
        content: Text('Are you sure you want to delete "${indexer.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || indexer.id == null) return;

    try {
      final LidarrApi api = await ref.read(lidarrApiProvider(instance).future);
      await api.indexer.deleteIndexerById(id: indexer.id!);
      ref.invalidate(lidarrIndexersProvider(instance));
      messenger.showSnackBar(
        const SnackBar(content: Text('Indexer deleted.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error deleting indexer: $e')),
      );
    }
  }

  Future<void> _showIndexerOptionsDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final AsyncValue<IndexerConfigResource> configAsync =
        ref.read(lidarrIndexerConfigProvider(instance));
    final IndexerConfigResource? config = configAsync.value;

    final TextEditingController minAgeController = TextEditingController(
      text: (config?.minimumAge ?? 0).toString(),
    );
    final TextEditingController maxSizeController = TextEditingController(
      text: (config?.maximumSize ?? 0).toString(),
    );
    final TextEditingController retentionController = TextEditingController(
      text: (config?.retention ?? 0).toString(),
    );
    final TextEditingController rssIntervalController = TextEditingController(
      text: (config?.rssSyncInterval ?? 25).toString(),
    );

    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Indexer Options'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: minAgeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Minimum Age (Minutes)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: Insets.md),
              TextField(
                controller: retentionController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Retention (Days)',
                  helperText: '0 for unlimited',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: Insets.md),
              TextField(
                controller: maxSizeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Maximum Size (MB)',
                  helperText: '0 for unlimited',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: Insets.md),
              TextField(
                controller: rssIntervalController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'RSS Sync Interval (Minutes)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final ScaffoldMessengerState messenger =
                  ScaffoldMessenger.of(context);
              try {
                final LidarrApi api =
                    await ref.read(lidarrApiProvider(instance).future);
                final IndexerConfigResource updated =
                    (config ?? const IndexerConfigResource()).copyWith(
                  minimumAge: int.tryParse(minAgeController.text) ?? 0,
                  retention: int.tryParse(retentionController.text) ?? 0,
                  maximumSize: int.tryParse(maxSizeController.text) ?? 0,
                  rssSyncInterval:
                      int.tryParse(rssIntervalController.text) ?? 25,
                );

                if (config?.id != null) {
                  await api.indexerConfig.putConfigIndexerById(
                    id: config!.id!.toString(),
                    body: updated,
                  );
                }

                ref.invalidate(lidarrIndexerConfigProvider(instance));
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Indexer options saved!')),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AsyncValue<List<IndexerResource>> asyncIndexers =
        ref.watch(lidarrIndexersProvider(instance));
    // Warm up schemas and config
    ref.watch(lidarrIndexerSchemaProvider(instance));
    ref.watch(lidarrIndexerConfigProvider(instance));

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'indexer_add_fab',
        onPressed: () => _selectIndexerPresetAndAdd(context, ref),
        tooltip: 'Add Indexer',
        child: const Icon(Icons.add),
      ),
      body: EasyRefresh(
        onRefresh: () async {
          ref.invalidate(lidarrIndexersProvider(instance));
          ref.invalidate(lidarrIndexerConfigProvider(instance));
        },
        child: AsyncValueView<List<IndexerResource>>(
          value: asyncIndexers,
          data: (List<IndexerResource> indexers) {
            return ListView(
              padding: const EdgeInsets.all(Insets.md),
              children: <Widget>[
                // Options Card Banner
                Card(
                  elevation: 0,
                  color: cs.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: cs.secondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.tune,
                        color: cs.onSecondaryContainer,
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Indexer Options & Restrictions',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Minimum seeders, maximum size, and delay',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () => _showIndexerOptionsDialog(context, ref),
                  ),
                ),
                const SizedBox(height: Insets.md),
                if (indexers.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: EmptyView(
                        icon: Icons.rss_feed_outlined,
                        title: 'No Indexers',
                        message: 'No indexers configured in Lidarr.',
                        action: FilledButton.icon(
                          onPressed: () =>
                              _selectIndexerPresetAndAdd(context, ref),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Indexer'),
                        ),
                      ),
                    ),
                  )
                else
                  ...indexers.map((IndexerResource indexer) {
                    final String protocolStr = LidarrFormatters.formatWireEnum(
                      indexer.protocol?.value,
                    );

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
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
                              Icons.rss_feed,
                              color: cs.onPrimaryContainer,
                              size: 22,
                            ),
                          ),
                          title: Text(
                            indexer.name ?? 'Indexer',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: <Widget>[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cs.primaryContainer,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    protocolStr,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: cs.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                                if (indexer.enableRss == true)
                                  Text(
                                    '• RSS',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                if (indexer.enableAutomaticSearch == true)
                                  Text(
                                    '• Auto Search',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                if (indexer.enableInteractiveSearch == true)
                                  Text(
                                    '• Interactive Search',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            tooltip: 'Delete Indexer',
                            onPressed: () =>
                                _deleteIndexer(context, ref, indexer),
                          ),
                          onTap: () => _showIndexerEditorDialog(
                            context,
                            ref,
                            indexer,
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}
