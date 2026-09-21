import 'package:core_models/core_models.dart';
import 'package:core_profile/core_profile.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Manage profiles: switch the active profile, create, rename, or delete one.
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
        onPressed: () => _create(context, ref),
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
                      secondary: PopupMenuButton<_ProfileAction>(
                        tooltip: 'Profile actions',
                        onSelected: (_ProfileAction action) =>
                            switch (action) {
                          _ProfileAction.rename => _rename(context, ref, p),
                          _ProfileAction.delete => ref
                              .read(profileListProvider.notifier)
                              .deleteProfile(p.id),
                        },
                        itemBuilder: (BuildContext _) =>
                            <PopupMenuEntry<_ProfileAction>>[
                          const PopupMenuItem<_ProfileAction>(
                            value: _ProfileAction.rename,
                            child: Text('Rename'),
                          ),
                          // The last profile stays: the app needs one to
                          // hold its instances.
                          PopupMenuItem<_ProfileAction>(
                            value: _ProfileAction.delete,
                            enabled: list.length > 1,
                            child: const Text('Delete'),
                          ),
                        ],
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

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext _) => const _ProfileNameDialog(
        title: 'New profile',
        confirm: 'Create',
      ),
    );
    final String trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return;
    final Profile created =
        await ref.read(profileListProvider.notifier).createProfile(trimmed);
    await ref.read(activeProfileIdProvider.notifier).select(created.id);
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    Profile profile,
  ) async {
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext _) => _ProfileNameDialog(
        title: 'Rename profile',
        confirm: 'Rename',
        initial: profile.name,
      ),
    );
    final String trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty || trimmed == profile.name) return;
    await ref
        .read(profileListProvider.notifier)
        .updateProfile(profile.copyWith(name: trimmed));
  }
}

enum _ProfileAction { rename, delete }

/// One name field, used to create a profile and to rename one. Owns its
/// controller so it outlives the dialog's exit animation.
class _ProfileNameDialog extends StatefulWidget {
  const _ProfileNameDialog({
    required this.title,
    required this.confirm,
    this.initial = '',
  });

  final String title;
  final String confirm;
  final String initial;

  @override
  State<_ProfileNameDialog> createState() => _ProfileNameDialogState();
}

class _ProfileNameDialogState extends State<_ProfileNameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
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
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(widget.confirm),
        ),
      ],
    );
  }
}
