// app/lib/src/update_check/update_check_tile.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../external_links.dart';
import 'update_check_state.dart';
import 'update_checker.dart';

/// Settings tile that runs the manual update check and shows its result.
class UpdateCheckTile extends ConsumerWidget {
  const UpdateCheckTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UpdateCheckState state = ref.watch(updateCheckProvider);
    final UpdateChecker checker = ref.read(updateCheckProvider.notifier);

    final (String subtitle, Widget? trailing, bool tappable) =
        switch (state.status) {
      UpdateStatus.idle => ('Tap to check', null, true),
      UpdateStatus.checking => (
          'Checking...',
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          false,
        ),
      UpdateStatus.upToDate => ('Up to date', null, true),
      UpdateStatus.updateAvailable => (
          'Version ${state.latestVersion} is available',
          const Icon(Icons.open_in_new, size: 18),
          true,
        ),
      UpdateStatus.error => ('Could not check, tap to retry', null, true),
    };

    return ListTile(
      leading: const Icon(Icons.system_update_outlined),
      title: const Text('Check for updates'),
      subtitle: Text(subtitle),
      trailing: trailing,
      onTap: !tappable
          ? null
          : () {
              if (state.status == UpdateStatus.updateAvailable &&
                  state.releaseUrl != null) {
                openExternal(ScaffoldMessenger.of(context), state.releaseUrl!);
              } else {
                checker.check();
              }
            },
    );
  }
}
