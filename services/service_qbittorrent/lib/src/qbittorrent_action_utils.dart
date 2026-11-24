import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/qbit_torrent.dart';
import 'qbittorrent_client.dart';
import 'qbittorrent_providers.dart';

class QbittorrentActionUtils {
  static Future<void> run(
    WidgetRef ref,
    Instance instance,
    Future<void> Function(QbittorrentClient) action,
  ) async {
    final QbittorrentClient client =
        await ref.read(qbittorrentClientProvider(instance).future);
    await action(client);
    ref.invalidate(qbitRawTorrentsProvider(instance));
    ref.invalidate(qbitSelectionProvider(instance));
  }

  static Future<void> confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Instance instance,
    Set<String> selectedHashes,
  ) async {
    bool deleteFiles = false;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) => AlertDialog(
          title: const Text('Delete select Torrents?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Are you sure to delete the selected ${selectedHashes.length} torrents?',
              ),
              const SizedBox(height: Insets.md),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Delete files'),
                value: deleteFiles,
                onChanged: (bool? v) =>
                    setState(() => deleteFiles = v ?? false),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('CONFIRM'),
            ),
          ],
        ),
      ),
    );
    if (ok ?? false) {
      final QbittorrentClient client =
          await ref.read(qbittorrentClientProvider(instance).future);
      await client.delete(selectedHashes.toList(), deleteFiles: deleteFiles);
      ref.invalidate(qbitSelectionProvider(instance));
      ref.invalidate(qbitRawTorrentsProvider(instance));
    }
  }

  /// Picks a category for [selectedHashes] and sets it.
  ///
  /// The current category is ticked when every selected torrent shares one,
  /// None included. A refused change is reported, and on success the
  /// torrents' properties are refreshed too: with Automatic Torrent
  /// Management a new category also moves the save path.
  static Future<void> editCategory(
    BuildContext context,
    WidgetRef ref,
    Instance instance,
    Set<String> selectedHashes,
  ) async {
    final Set<String> held = <String>{
      for (final QbitTorrent t in ref
              .read(qbitRawTorrentsProvider(instance))
              .value ??
          const <QbitTorrent>[])
        if (selectedHashes.contains(t.hash)) t.category,
    };
    final String? current = held.length == 1 ? held.single : null;
    final List<String> cats =
        await ref.read(qbitCategoriesProvider(instance).future);
    if (!context.mounted) return;

    Widget option(BuildContext context, String value, String label) =>
        SimpleDialogOption(
          onPressed: () => Navigator.of(context).pop(value),
          child: Row(
            children: <Widget>[
              Expanded(child: Text(label)),
              if (value == current)
                Icon(
                  Icons.check,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
            ],
          ),
        );

    final String? chosen = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => SimpleDialog(
        title: const Text('Set category'),
        children: <Widget>[
          option(context, '', 'None'),
          for (final String c in cats) option(context, c, c),
        ],
      ),
    );
    if (chosen == null) return;
    try {
      await run(
        ref,
        instance,
        (QbittorrentClient c) => c.setCategory(selectedHashes.toList(), chosen),
      );
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not set category')),
        );
      }
      return;
    }
    for (final String hash in selectedHashes) {
      ref.invalidate(qbitPropertiesProvider((instance, hash)));
    }
  }

  static Future<void> editTags(
    BuildContext context,
    WidgetRef ref,
    Instance instance,
    Set<String> selectedHashes,
  ) async {
    final TextEditingController ctrl = TextEditingController();
    final String? chosen = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Set tags'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'tag1, tag2'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (chosen != null && chosen.isNotEmpty) {
      await run(
        ref,
        instance,
        (QbittorrentClient c) => c.addTags(selectedHashes.toList(), chosen),
      );
    }
  }

  static Future<void> editSavePath(
    BuildContext context,
    WidgetRef ref,
    Instance instance,
    Set<String> selectedHashes,
  ) async {
    final TextEditingController ctrl = TextEditingController();
    final String? chosen = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Set save path'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: '/downloads/new_path'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (chosen != null && chosen.isNotEmpty) {
      await run(
        ref,
        instance,
        (QbittorrentClient c) => c.setLocation(selectedHashes.toList(), chosen),
      );
    }
  }

  static Future<void> rename(
    BuildContext context,
    WidgetRef ref,
    Instance instance,
    Set<String> selectedHashes,
  ) async {
    final TextEditingController ctrl = TextEditingController();
    final String? chosen = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'New name'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (chosen != null && chosen.isNotEmpty) {
      await run(
        ref,
        instance,
        (QbittorrentClient c) => c.rename(selectedHashes.first, chosen),
      );
    }
  }
}
