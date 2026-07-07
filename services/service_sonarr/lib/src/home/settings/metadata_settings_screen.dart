import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sonarr_providers.dart';
import 'widgets/dynamic_schema_form.dart';

class MetadataSettingsScreen extends ConsumerWidget {
  const MetadataSettingsScreen({
    required this.instance,
    super.key,
  });

  final Instance instance;

  Future<void> _showMetadataEditorDialog(
      BuildContext context, WidgetRef ref, Map<String, dynamic> metadata,) async {
    final fields = (metadata['fields'] as List<dynamic>?)
            ?.map((dynamic f) => f as Map<String, dynamic>)
            .toList() ??
        [];

    final enableController = ValueNotifier<bool>(metadata['enable'] as bool? ?? false);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return ValueListenableBuilder<bool>(
          valueListenable: enableController,
          builder: (context, enable, _) {
            return AlertDialog(
              title: Text('Edit ${metadata['name']}'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enable metadata creation'),
                        value: enable,
                        onChanged: (val) => enableController.value = val,
                      ),
                      const Divider(),
                      const SizedBox(height: Insets.sm),
                      DynamicSchemaForm(
                        fields: fields,
                        onSave: (updatedFields) async {
                          try {
                            final api = await ref
                                .read(sonarrApiProvider(instance).future);
                            final payload = Map<String, dynamic>.from(metadata);
                            payload['enable'] = enableController.value;
                            payload['fields'] = updatedFields;

                            await api.updateMetadataConfig(payload);

                            ref.invalidate(sonarrMetadataConfigsProvider(instance));
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Metadata consumer updated!'),),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Failed to save metadata consumer: $e',),),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final metadataListAsync = ref.watch(sonarrMetadataConfigsProvider(instance));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Metadata Consumers'),
      ),
      body: metadataListAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (configs) {
          if (configs.isEmpty) {
            return const Center(child: Text('No metadata consumers configured.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(Insets.md),
            itemCount: configs.length,
            itemBuilder: (context, index) {
              final metadata = configs[index];
              final name = (metadata['name'] as String?) ?? 'Metadata';
              final isEnabled = metadata['enable'] as bool? ?? false;
              final implementation =
                  (metadata['implementationName'] as String?) ?? '';

              return Card(
                margin: const EdgeInsets.only(bottom: Insets.md),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                  borderRadius: Radii.card,
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isEnabled
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.settings_applications_outlined,
                      color: isEnabled
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  title: Text(
                    name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text('$implementation • Status: ${isEnabled ? 'Enabled' : 'Disabled'}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: isEnabled,
                        onChanged: (val) async {
                          try {
                            final api = await ref
                                .read(sonarrApiProvider(instance).future);
                            final payload = Map<String, dynamic>.from(metadata);
                            payload['enable'] = val;
                            await api.updateMetadataConfig(payload);
                            ref.invalidate(sonarrMetadataConfigsProvider(instance));
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Failed to update metadata status: $e',),),
                              );
                            }
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () =>
                            _showMetadataEditorDialog(context, ref, metadata),
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
