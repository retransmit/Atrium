import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bazarr_api.dart';
import 'bazarr_providers.dart';
import 'models/bazarr_models.dart';

/// Settings > Languages: toggle which subtitle languages Bazarr searches for.
/// Edits are held locally and written in one POST on Save (a full replace of
/// the enabled set).
class BazarrLanguagesScreen extends ConsumerStatefulWidget {
  const BazarrLanguagesScreen({required this.instance, super.key});

  final Instance instance;

  @override
  ConsumerState<BazarrLanguagesScreen> createState() =>
      _BazarrLanguagesScreenState();
}

class _BazarrLanguagesScreenState extends ConsumerState<BazarrLanguagesScreen> {
  final TextEditingController _query = TextEditingController();
  final Set<String> _enabled = <String>{};
  bool _seeded = false;
  bool _saving = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final BazarrApi api =
          await ref.read(bazarrApiProvider(widget.instance).future);
      await api.setEnabledLanguages(_enabled.toList());
      ref.invalidate(bazarrLanguagesProvider(widget.instance));
      ref.invalidate(bazarrWantedProvider(widget.instance));
      ref.invalidate(bazarrBadgesProvider(widget.instance));
      messenger.showSnackBar(
        const SnackBar(content: Text('Languages saved')),
      );
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Save failed: ${_err(e)}')),
      );
    } finally {
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
        title: Text('Languages (${_enabled.length})'),
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
              onPressed: _seeded ? _save : null,
            ),
        ],
      ),
      body: AsyncValueView<List<BazarrLanguage>>(
        value: languages,
        onRetry: () => ref.invalidate(bazarrLanguagesProvider(widget.instance)),
        data: (List<BazarrLanguage> list) {
          if (!_seeded) {
            _enabled
              ..clear()
              ..addAll(
                list.where((BazarrLanguage l) => l.enabled).map(
                      (BazarrLanguage l) => l.code,
                    ),
              );
            _seeded = true;
          }
          final String q = _query.text.trim().toLowerCase();
          final List<BazarrLanguage> filtered = q.isEmpty
              ? list
              : list
                  .where(
                    (BazarrLanguage l) =>
                        l.name.toLowerCase().contains(q) ||
                        l.code2.toLowerCase().contains(q) ||
                        l.code3.toLowerCase().contains(q),
                  )
                  .toList();
          return Column(
            children: <Widget>[
              Padding(
                padding: Insets.page,
                child: TextField(
                  controller: _query,
                  decoration: const InputDecoration(
                    hintText: 'Search languages...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (BuildContext context, int i) {
                    final BazarrLanguage l = filtered[i];
                    return SwitchListTile(
                      title: Text(l.name),
                      subtitle: Text(l.code2.toUpperCase()),
                      value: _enabled.contains(l.code),
                      onChanged: (bool v) => setState(() {
                        if (v) {
                          _enabled.add(l.code);
                        } else {
                          _enabled.remove(l.code);
                        }
                      }),
                    );
                  },
                ),
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
