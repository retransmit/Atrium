import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'prowlarr_api.dart';
import 'prowlarr_providers.dart';
import 'package:m3_expressive/m3_expressive.dart';

/// Settings ▸ Tags: Prowlarr's `/tag` list (just id + label). Add, rename, and
/// delete. Reuses the generic provider list/CRUD helpers (tags have no schema
/// or test route, so no form picker is involved).
class ProwlarrTagsScreen extends ConsumerWidget {
  const ProwlarrTagsScreen({required this.instance, super.key});

  final Instance instance;

  ProwlarrProviderArgs get _args => (instance: instance, endpoint: 'tag');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Map<String, dynamic>>> tags =
        ref.watch(prowlarrProvidersProvider(_args));
    return Scaffold(
      appBar: AppBar(title: const Text('Tags')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'prowlarr-add-tag',
        onPressed: () => _editLabel(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: M3RefreshIndicator(
        onRefresh: () async => ref.invalidate(prowlarrProvidersProvider(_args)),
        child: AsyncValueView<List<Map<String, dynamic>>>(
          value: tags,
          onRetry: () => ref.invalidate(prowlarrProvidersProvider(_args)),
          data: (List<Map<String, dynamic>> items) {
            if (items.isEmpty) {
              return const EmptyView(
                icon: Icons.label_outline,
                title: 'No tags',
                message: 'Tap Add to create a tag.',
              );
            }
            final List<Map<String, dynamic>> sorted = <Map<String, dynamic>>[
              ...items
            ]..sort(
                (Map<String, dynamic> a, Map<String, dynamic> b) =>
                    ((a['label'] ?? '') as String).toLowerCase().compareTo(
                        ((b['label'] ?? '') as String).toLowerCase()),
              );
            return ListView.builder(
              padding: Insets.pageH,
              itemCount: sorted.length,
              itemBuilder: (BuildContext context, int i) {
                final Map<String, dynamic> tag = sorted[i];
                return ListTile(
                  leading: const Icon(Icons.label_outline),
                  title: Text((tag['label'] as String?) ?? ''),
                  trailing: IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(context, ref, tag),
                  ),
                  onTap: () => _editLabel(context, ref, tag),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _editLabel(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic>? existing,
  ) async {
    final TextEditingController controller =
        TextEditingController(text: (existing?['label'] as String?) ?? '');
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String? label = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(existing == null ? 'New tag' : 'Rename tag'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Label',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (String v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (label == null || label.isEmpty) {
      return;
    }
    try {
      final ProwlarrApi api =
          await ref.read(prowlarrApiProvider(instance).future);
      if (existing == null) {
        await api.createProvider('tag', <String, dynamic>{'label': label});
      } else {
        await api.updateProvider('tag', <String, dynamic>{
          ...existing,
          'label': label,
        });
      }
      ref.invalidate(prowlarrProvidersProvider(_args));
      messenger.showSnackBar(
        SnackBar(content: Text(existing == null ? 'Tag added' : 'Tag renamed')),
      );
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed: ${_err(e)}')),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> tag,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Delete tag?'),
        content: Text('Remove "${tag['label']}" from Prowlarr?'),
        actions: <Widget>[
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
    if (confirm != true) {
      return;
    }
    try {
      final ProwlarrApi api =
          await ref.read(prowlarrApiProvider(instance).future);
      await api.deleteProvider('tag', (tag['id'] as num).toInt());
      ref.invalidate(prowlarrProvidersProvider(_args));
      messenger.showSnackBar(const SnackBar(content: Text('Tag deleted')));
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Delete failed: ${_err(e)}')),
      );
    }
  }
}

String _err(Object e) {
  if (e is NetworkException && e.message.isNotEmpty) {
    return e.message;
  }
  return 'request failed';
}
