import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../adguard_home_filter_rules.dart';
import '../adguard_home_providers.dart';
import '../models/adguard_home_access.dart';
import '../models/adguard_home_settings.dart';
import '../widgets/adguard_home_fields.dart';
import '../widgets/adguard_home_settings_form.dart';

/// Who may use the server, and which names it drops outright. A wrong
/// entry can cut devices off from DNS, this phone among them, so Save asks
/// first.
class AdguardHomeAccessScreen extends ConsumerStatefulWidget {
  const AdguardHomeAccessScreen({required this.instance, super.key});

  final Instance instance;

  @override
  ConsumerState<AdguardHomeAccessScreen> createState() =>
      _AdguardHomeAccessScreenState();
}

class _AdguardHomeAccessScreenState
    extends ConsumerState<AdguardHomeAccessScreen> {
  final TextEditingController _allowed = TextEditingController();
  final TextEditingController _disallowed = TextEditingController();
  final TextEditingController _domains = TextEditingController();

  AdguardHomeAccessList? _before;
  bool _busy = false;

  Instance get _instance => widget.instance;

  @override
  void dispose() {
    _allowed.dispose();
    _disallowed.dispose();
    _domains.dispose();
    super.dispose();
  }

  void _fill(AdguardHomeAccessList list) {
    _before = list;
    _allowed.text = adguardHomeRulesToText(list.allowedClients);
    _disallowed.text = adguardHomeRulesToText(list.disallowedClients);
    _domains.text = adguardHomeRulesToText(list.blockedHosts);
  }

  static List<String> _lines(TextEditingController text) => <String>[
        for (final String line in adguardHomeRulesFromText(text.text))
          line.trim(),
      ];

  AdguardHomeAccessList get _after => AdguardHomeAccessList(
        allowedClients: _lines(_allowed),
        disallowedClients: _lines(_disallowed),
        blockedHosts: _lines(_domains),
      );

  bool get _changed {
    final AdguardHomeAccessList? before = _before;
    if (before == null) return false;
    return adguardHomeChangedSettings(before.toJson(), _after.toJson())
        .isNotEmpty;
  }

  Future<void> _save() async {
    final AdguardHomeAccessList? before = _before;
    if (_busy || before == null) return;
    final AdguardHomeAccessList after = _after;
    final bool allowlist = after.allowedClients.isNotEmpty;
    final bool? sure = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Save the access settings?'),
        content: Text(
          allowlist
              ? 'Only the allowed clients will get answers. A device not on '
                  'the list, this phone included, is cut off from DNS.'
              : 'A wrong entry can cut devices off from DNS, this phone '
                  'included.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    await _write(before, after);
  }

  Future<void> _write(
    AdguardHomeAccessList before,
    AdguardHomeAccessList after,
  ) =>
      adguardHomeSaveSettings(
        context,
        ref,
        _instance,
        save: () => ref
            .read(adguardHomeActionsProvider(_instance))
            .saveAccessList(before: before, after: after),
        done: 'Access settings saved',
        setBusy: (bool busy) => setState(() => _busy = busy),
        // Asked once already: Try again goes straight to the write.
        retry: () => _write(before, after),
      );

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AdguardHomeAccessList> read =
        ref.watch(adguardHomeAccessListProvider(_instance));
    final AdguardHomeAccessList? value = read.value;
    // Filled once. A later read must not replace what is being typed.
    if (_before == null && value != null) _fill(value);
    return AdguardHomeSettingsForm(
      title: 'Access',
      busy: _busy,
      changed: _changed,
      onSave: _save,
      body: _before == null
          ? adguardHomeSettingsWaiting<AdguardHomeAccessList>(
                context,
                ref,
                _instance,
                read,
                onRetry: () =>
                    ref.invalidate(adguardHomeAccessListProvider(_instance)),
              ) ??
              const SizedBox.shrink()
          : _form(context),
    );
  }

  Widget _form(BuildContext context) {
    final bool allowlist = _lines(_allowed).isNotEmpty;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.xl),
      children: <Widget>[
        const AdguardHomeHeading('Allowed clients'),
        const SizedBox(height: Insets.sm),
        _box(
          'allowed',
          _allowed,
          'IP addresses, ranges or ClientIDs, one per line. With any here, '
              'only these get answers.',
        ),
        const AdguardHomeHeading('Disallowed clients'),
        const SizedBox(height: Insets.sm),
        _box(
          'disallowed',
          _disallowed,
          allowlist
              ? 'Not in force while there are allowed clients.'
              : 'IP addresses, ranges or ClientIDs, one per line. These get '
                  'no answers.',
          enabled: !allowlist,
        ),
        const AdguardHomeHeading('Disallowed domains'),
        const SizedBox(height: Insets.sm),
        _box(
          'domains',
          _domains,
          'Queries for these are dropped and not logged. A name, '
              '*.example.org or ||example.org^, one per line. Not the same '
              'as a blocklist.',
        ),
      ],
    );
  }

  Widget _box(
    String key,
    TextEditingController controller,
    String helper, {
    bool enabled = true,
  }) =>
      TextField(
        key: Key('adguard-access-$key'),
        controller: controller,
        enabled: enabled,
        onChanged: (_) => setState(() {}),
        minLines: 3,
        maxLines: 12,
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: TextInputType.multiline,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(fontFamily: 'monospace'),
        decoration: InputDecoration(
          helperText: helper,
          helperMaxLines: 4,
          border: const OutlineInputBorder(),
        ),
      );
}
