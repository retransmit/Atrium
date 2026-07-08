import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'emby_client.dart';
import 'emby_providers.dart';

class EmbySettingsScreen extends ConsumerWidget {
  const EmbySettingsScreen({required this.instance, super.key});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<({double progress, String state})?> scanState = 
        ref.watch(embyLibraryScanProvider(instance));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emby Settings'),
      ),
      body: ListView(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text('Scan media library'),
            subtitle: scanState.when(
              data: (({double progress, String state})? data) {
                if (data == null || data.state == 'Idle') {
                  return const Text('Ready');
                }
                return Text('${data.state} - ${data.progress.toStringAsFixed(1)}%');
              },
              loading: () => const Text('Checking status...'),
              error: (Object err, StackTrace stack) => const Text('Error checking status'),
            ),
            trailing: scanState.maybeWhen(
              data: (({double progress, String state})? data) {
                if (data != null && data.state == 'Running') {
                  return ExpressiveProgressIndicator(
                    value: data.progress > 0 ? data.progress / 100.0 : null,
                  );
                }
                return IconButton(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () async {
                    try {
                      final EmbyClient client = await ref.read(embyClientProvider(instance).future);
                      await client.startLibraryScan();
                      if (!context.mounted) return;
                      ref.invalidate(embyLibraryScanProvider(instance));
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to start scan: $e')),
                        );
                      }
                    }
                  },
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
          ),
          const Divider(),
        ],
      ),
    );
  }
}
