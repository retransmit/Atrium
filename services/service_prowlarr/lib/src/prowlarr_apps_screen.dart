import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'prowlarr_api.dart';
import 'prowlarr_app_form_screen.dart';
import 'prowlarr_apps_tab.dart';
import 'prowlarr_providers.dart';

/// Settings ▸ Apps: the applications Prowlarr syncs its indexers to. Wraps
/// [ProwlarrAppsTab] with an Add FAB and a Sync FAB (push indexers to all apps).
/// Pushed from the Prowlarr Settings menu.
class ProwlarrAppsScreen extends ConsumerWidget {
  const ProwlarrAppsScreen({required this.instance, super.key});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Applications')),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          FloatingActionButton.small(
            heroTag: 'prowlarr-sync',
            tooltip: 'Sync app indexers',
            onPressed: () => _syncApps(context, ref),
            child: const Icon(Icons.sync),
          ),
          const SizedBox(height: Insets.sm),
          FloatingActionButton.extended(
            heroTag: 'prowlarr-add-app',
            onPressed: () => _openForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Add application'),
          ),
        ],
      ),
      body: ProwlarrAppsTab(
        instance: instance,
        onEdit: (int id) => _openForm(context, id),
      ),
    );
  }

  void _openForm(BuildContext context, [int? appId]) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => ProwlarrAppFormScreen(instance: instance, appId: appId),
      ),
    );
  }

  /// Pushes Prowlarr's indexers to every configured app (Prowlarr's "Sync App
  /// Indexers"). User-initiated; we just report the result.
  Future<void> _syncApps(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final ProwlarrApi api =
          await ref.read(prowlarrApiProvider(instance).future);
      await api.runCommand('ApplicationIndexerSync');
      messenger.showSnackBar(
        const SnackBar(content: Text('App indexer sync started')),
      );
    } on Object catch (e) {
      final String msg = (e is NetworkException && e.message.isNotEmpty)
          ? e.message
          : 'request failed';
      messenger.showSnackBar(SnackBar(content: Text('Sync failed: $msg')));
    }
  }
}
