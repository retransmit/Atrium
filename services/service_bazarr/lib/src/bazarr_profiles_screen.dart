import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bazarr_api.dart';
import 'bazarr_providers.dart';
import 'models/bazarr_models.dart';
import 'package:m3_expressive/m3_expressive.dart';

/// Settings > Language Profiles: the language sets that series/movies are
/// assigned. List, create, edit, and delete; all saved as one languages-profiles
/// JSON via the settings POST.
class BazarrProfilesScreen extends ConsumerWidget {
  const BazarrProfilesScreen({required this.instance, super.key});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<BazarrLanguageProfile>> profiles =
        ref.watch(bazarrProfilesProvider(instance));
    return Scaffold(
      appBar: AppBar(title: const Text('Language Profiles')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'bazarr-add-profile',
        onPressed: () => _openEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: M3RefreshIndicator(
        onRefresh: () async => ref.invalidate(bazarrProfilesProvider(instance)),
        child: AsyncValueView<List<BazarrLanguageProfile>>(
          value: profiles,
          onRetry: () => ref.invalidate(bazarrProfilesProvider(instance)),
          data: (List<BazarrLanguageProfile> list) {
            if (list.isEmpty) {
              return const EmptyView(
                icon: Icons.tune_outlined,
                title: 'No language profiles',
                message: 'Tap Add to create one (enable languages first).',
              );
            }
            return ListView.builder(
              padding: Insets.pageH,
              itemCount: list.length,
              itemBuilder: (BuildContext context, int i) {
                final BazarrLanguageProfile p = list[i];
                final String langs = p.items
                    .map((BazarrProfileItem it) => it.language.toUpperCase())
                    .join(', ');
                return Card(
                  margin: const EdgeInsets.only(bottom: Insets.sm),
                  child: ListTile(
                    leading: const Icon(Icons.tune_outlined),
                    title: Text(p.name),
                    subtitle: Text(langs.isEmpty ? 'No languages' : langs),
                    trailing: IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(context, ref, list, p),
                    ),
                    onTap: () => _openEditor(context, existing: p),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _openEditor(BuildContext context, {BazarrLanguageProfile? existing}) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => BazarrProfileEditScreen(
          instance: instance,
          existing: existing,
        ),
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    List<BazarrLanguageProfile> all,
    BazarrLanguageProfile p,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Delete profile?'),
        content: Text('Remove "${p.name}"?'),
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
    if (ok != true) {
      return;
    }
    try {
      final BazarrApi api = await ref.read(bazarrApiProvider(instance).future);
      await api.setProfiles(
        all
            .where((BazarrLanguageProfile x) => x.profileId != p.profileId)
            .toList(),
      );
      ref.invalidate(bazarrProfilesProvider(instance));
      messenger.showSnackBar(const SnackBar(content: Text('Profile deleted')));
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Delete failed: ${_err(e)}')),
      );
    }
  }
}

/// Create or edit one language profile: a name plus the enabled languages it
/// includes.
class BazarrProfileEditScreen extends ConsumerStatefulWidget {
  const BazarrProfileEditScreen({
    required this.instance,
    this.existing,
    super.key,
  });

  final Instance instance;
  final BazarrLanguageProfile? existing;

  @override
  ConsumerState<BazarrProfileEditScreen> createState() =>
      _BazarrProfileEditScreenState();
}

class _BazarrProfileEditScreenState
    extends ConsumerState<BazarrProfileEditScreen> {
  late final TextEditingController _name;
  final Set<String> _langs = <String>{};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    for (final BazarrProfileItem it
        in widget.existing?.items ?? const <BazarrProfileItem>[]) {
      _langs.add(it.language);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a profile name')),
      );
      return;
    }
    if (_langs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one language')),
      );
      return;
    }
    setState(() => _saving = true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState nav = Navigator.of(context);
    try {
      final List<BazarrLanguageProfile> current =
          ref.read(bazarrProfilesProvider(widget.instance)).value ??
              const <BazarrLanguageProfile>[];
      int maxId = 0;
      for (final BazarrLanguageProfile p in current) {
        if (p.profileId > maxId) {
          maxId = p.profileId;
        }
      }
      final int id = widget.existing?.profileId ?? (maxId + 1);
      final List<String> langs = _langs.toList();
      final BazarrLanguageProfile profile = BazarrLanguageProfile(
        profileId: id,
        name: name,
        items: <BazarrProfileItem>[
          for (int i = 0; i < langs.length; i++)
            BazarrProfileItem(id: i + 1, language: langs[i]),
        ],
        cutoff: widget.existing?.cutoff,
        mustContain: widget.existing?.mustContain ?? const <String>[],
        mustNotContain: widget.existing?.mustNotContain ?? const <String>[],
        originalFormat: widget.existing?.originalFormat ?? 0,
        tag: widget.existing?.tag,
      );
      final List<BazarrLanguageProfile> next = <BazarrLanguageProfile>[
        ...current.where((BazarrLanguageProfile p) => p.profileId != id),
        profile,
      ];
      final BazarrApi api =
          await ref.read(bazarrApiProvider(widget.instance).future);
      await api.setProfiles(next);
      ref.invalidate(bazarrProfilesProvider(widget.instance));
      messenger.showSnackBar(const SnackBar(content: Text('Profile saved')));
      nav.pop();
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Save failed: ${_err(e)}')),
      );
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<BazarrLanguage>> languages =
        ref.watch(bazarrLanguagesProvider(widget.instance));
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New profile' : 'Edit profile'),
        actions: <Widget>[
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: Insets.md),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: ExpressiveProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'Save',
              icon: const Icon(Icons.save_outlined),
              onPressed: _save,
            ),
        ],
      ),
      body: AsyncValueView<List<BazarrLanguage>>(
        value: languages,
        onRetry: () => ref.invalidate(bazarrLanguagesProvider(widget.instance)),
        data: (List<BazarrLanguage> all) {
          final List<BazarrLanguage> enabled =
              all.where((BazarrLanguage l) => l.enabled).toList();
          return ListView(
            padding: Insets.page,
            children: <Widget>[
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Profile name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: Insets.md),
              Text(
                'Languages',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (enabled.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Insets.md),
                  child: Text(
                    'No languages enabled. Enable some in Settings > Languages '
                    'first.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                )
              else
                for (final BazarrLanguage l in enabled)
                  CheckboxListTile(
                    title: Text(l.name),
                    subtitle: Text(l.code2.toUpperCase()),
                    value: _langs.contains(l.code),
                    onChanged: (bool? v) => setState(() {
                      if (v ?? false) {
                        _langs.add(l.code);
                      } else {
                        _langs.remove(l.code);
                      }
                    }),
                  ),
            ],
          );
        },
      ),
    );
  }
}

String _err(Object e) {
  if (e is NetworkException && e.message.isNotEmpty) {
    return e.message;
  }
  return 'request failed';
}
