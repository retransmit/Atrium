import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sonarr_providers.dart';
import 'widgets/confirm_delete.dart';

class TagsSettingsScreen extends ConsumerWidget {
  const TagsSettingsScreen({
    required this.instance,
    super.key,
  });

  final Instance instance;

  Future<void> _showAddTagDialog(BuildContext context, WidgetRef ref) async {
    final labelController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Tag'),
          content: TextField(
            controller: labelController,
            decoration: const InputDecoration(
              labelText: 'Tag Label',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final label = labelController.text.trim();
                if (label.isEmpty) return;

                try {
                  final api = await ref.read(sonarrApiProvider(instance).future);
                  await api.createTag(label);
                  ref.invalidate(sonarrTagsProvider(instance));
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tag added!')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to add tag: $e')),
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

  Future<void> _deleteTag(BuildContext context, WidgetRef ref, int id) async {
    if (!await confirmDelete(context, 'this tag')) return;
    try {
      final api = await ref.read(sonarrApiProvider(instance).future);
      await api.deleteTag(id);
      ref.invalidate(sonarrTagsProvider(instance));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tag deleted!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete tag: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tagsAsync = ref.watch(sonarrTagsProvider(instance));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tags'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTagDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: tagsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (tags) {
          if (tags.isEmpty) {
            return const Center(child: Text('No tags configured.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(Insets.md),
            itemCount: tags.length,
            itemBuilder: (context, index) {
              final tag = tags[index];
              final id = tag['id'] as int;
              final label = (tag['label'] as String?) ?? '';

              return Card(
                margin: const EdgeInsets.only(bottom: Insets.sm),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                  borderRadius: Radii.card,
                ),
                child: ListTile(
                  leading: Icon(
                    Icons.label_outline,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteTag(context, ref, id),
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
