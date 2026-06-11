import 'package:core_models/core_models.dart';
import 'package:core_profile/core_profile.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Manage profiles: switch the active profile, create, or delete one.
///
/// A profile bundles a set of instances. Most users keep one; power users
/// split "Home" vs "Friend's place" etc.
class ProfilesScreen extends ConsumerWidget {
  const ProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Profile>> profiles = ref.watch(profileListProvider);
    final String? activeId = ref.watch(activeProfileIdProvider) ??
        ref.watch(activeProfileProvider)?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Profiles')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New profile'),
      ),
      body: AsyncValueView<List<Profile>>(
        value: profiles,
        onRetry: () => ref.invalidate(profileListProvider),
        data: (List<Profile> list) {
          if (list.isEmpty) {
            return const EmptyView(
              icon: Icons.switch_account_outlined,
              title: 'No profiles',
              message: 'Create a profile to start adding services.',
            );
          }
          return RadioGroup<String>(
            groupValue: activeId,
            onChanged: (String? id) =>
                ref.read(activeProfileIdProvider.notifier).select(id),
            child: ListView(
              padding: Insets.page,
              children: <Widget>[
                for (final Profile p in list)
                  Card(
                    child: RadioListTile<String>(
                      value: p.id,
                      title: Text(p.name),
                      subtitle: Text(
                        '${p.instances.length} '
                        'service${p.instances.length == 1 ? '' : 's'}',
                      ),
                      secondary: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: list.length == 1
                            ? null
                            : () => ref
                                .read(profileListProvider.notifier)
                                .deleteProfile(p.id),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _createDialog(BuildContext context, WidgetRef ref) async {
    final TextEditingController controller = TextEditingController();
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('New profile'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Profile name'),
          onSubmitted: (String v) => Navigator.of(context).pop(v),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      final Profile created = await ref
          .read(profileListProvider.notifier)
          .createProfile(name.trim());
      await ref.read(activeProfileIdProvider.notifier).select(created.id);
    }
  }
}
