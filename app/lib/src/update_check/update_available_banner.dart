// app/lib/src/update_check/update_available_banner.dart
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../external_links.dart';
import 'update_checker.dart';

/// A tappable banner shown on the Change log screen when the last known latest
/// release is newer than the running app. Reads state only; never fetches.
class UpdateAvailableBanner extends ConsumerWidget {
  const UpdateAvailableBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateCheckProvider);
    if (!state.hasNewer) return const SizedBox.shrink();
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: Material(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => openExternal(
            ScaffoldMessenger.of(context),
            state.releaseUrl ?? AtriumLinks.releases,
          ),
          child: Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: Row(
              children: <Widget>[
                Icon(Icons.system_update, color: cs.onPrimaryContainer),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(
                    'Version ${state.latestVersion} is available',
                    style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text('View release',
                    style: TextStyle(color: cs.onPrimaryContainer)),
                const SizedBox(width: 4),
                Icon(Icons.open_in_new, size: 16, color: cs.onPrimaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
