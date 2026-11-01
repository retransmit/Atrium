import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../adguard_home_format.dart';
import '../adguard_home_providers.dart';
import '../models/adguard_home_settings.dart';
import '../widgets/adguard_home_failure_dialog.dart';
import '../widgets/adguard_home_settings_form.dart';

/// The DNS cache: on or off, how big, how long answers are kept, and
/// whether expired ones are still used. Saved with Save; Clear cache acts
/// at once, after a question.
class AdguardHomeDnsCacheScreen extends ConsumerStatefulWidget {
  const AdguardHomeDnsCacheScreen({required this.instance, super.key});

  final Instance instance;

  @override
  ConsumerState<AdguardHomeDnsCacheScreen> createState() =>
      _AdguardHomeDnsCacheScreenState();
}

class _AdguardHomeDnsCacheScreenState
    extends ConsumerState<AdguardHomeDnsCacheScreen> {
  final TextEditingController _size = TextEditingController();
  final TextEditingController _ttlMin = TextEditingController();
  final TextEditingController _ttlMax = TextEditingController();

  Map<String, dynamic>? _before;
  bool _enabled = false;
  bool _optimistic = false;
  bool _checked = false;
  bool _busy = false;

  /// The fields typed in since the form opened: their problems show at
  /// once, the others' only after Save.
  final Set<String> _touched = <String>{};

  Instance get _instance => widget.instance;

  void _edited(String key) => setState(() => _touched.add(key));

  @override
  void dispose() {
    _size.dispose();
    _ttlMin.dispose();
    _ttlMax.dispose();
    super.dispose();
  }

  void _fill(AdguardHomeDnsConfig dns) {
    _size.text = '${dns.cacheSize}';
    _ttlMin.text = '${dns.cacheTtlMin}';
    _ttlMax.text = '${dns.cacheTtlMax}';
    _enabled = dns.cacheEnabled;
    _optimistic = dns.cacheOptimistic;
    _before = _json();
  }

  Map<String, String> get _problems {
    final Map<String, String> problems = <String, String>{};
    void check(String key, String? problem) {
      if (problem != null) problems[key] = problem;
    }

    check('size', adguardHomeWholeNumberProblem(_size.text));
    check('min', adguardHomeWholeNumberProblem(_ttlMin.text));
    check('max', adguardHomeWholeNumberProblem(_ttlMax.text));
    final int? min = int.tryParse(_ttlMin.text.trim());
    final int? max = int.tryParse(_ttlMax.text.trim());
    // 0 is no override, so it bounds nothing.
    if (min != null && max != null && min > 0 && max > 0 && min > max) {
      problems['min'] = 'Has to be at most the maximum.';
    }
    return problems;
  }

  Map<String, dynamic> _json() => <String, dynamic>{
        'cache_enabled': _enabled,
        'cache_size': int.tryParse(_size.text.trim()),
        'cache_ttl_min': int.tryParse(_ttlMin.text.trim()),
        'cache_ttl_max': int.tryParse(_ttlMax.text.trim()),
        'cache_optimistic': _optimistic,
      };

  bool get _changed {
    final Map<String, dynamic>? before = _before;
    if (before == null) return false;
    return adguardHomeChangedSettings(before, _json()).isNotEmpty;
  }

  Future<void> _save() async {
    final Map<String, dynamic>? before = _before;
    if (_busy || before == null) return;
    if (_problems.isNotEmpty) {
      setState(() => _checked = true);
      return;
    }
    final Map<String, dynamic> after = _json();
    await adguardHomeSaveSettings(
      context,
      ref,
      _instance,
      save: () => ref
          .read(adguardHomeActionsProvider(_instance))
          .saveDnsSettings(before: before, after: after),
      done: 'Cache settings saved',
      setBusy: (bool busy) => setState(() => _busy = busy),
      retry: _save,
    );
  }

  Future<void> _clear() async {
    final bool? clear = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Clear the DNS cache?'),
        content: const Text(
          'Every name is asked of the upstream servers again the next time.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (clear != true) return;
    await _clearAsked();
  }

  /// Clears the cache, asked already: Try again comes back here.
  Future<void> _clearAsked() async {
    if (!mounted) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AdguardHomeActions actions =
        ref.read(adguardHomeActionsProvider(_instance));
    setState(() => _busy = true);
    SnackBar said = const SnackBar(content: Text('DNS cache cleared'));
    try {
      await actions.clearDnsCache();
    } on Object catch (error) {
      said = adguardHomeFailureSnackBar(
        error,
        retrySignIn: actions.retrySignIn,
        again: () => unawaited(_clearAsked()),
      );
    }
    if (mounted) setState(() => _busy = false);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(said);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AdguardHomeDnsConfig> read =
        ref.watch(adguardHomeDnsConfigProvider(_instance));
    final AdguardHomeDnsConfig? value = read.value;
    // Filled once. A later read must not replace what is being typed.
    if (_before == null && value != null) _fill(value);
    return AdguardHomeSettingsForm(
      title: 'DNS cache',
      busy: _busy,
      changed: _changed,
      onSave: _save,
      body: _before == null
          ? adguardHomeSettingsWaiting<AdguardHomeDnsConfig>(
                context,
                ref,
                _instance,
                read,
                onRetry: () =>
                    ref.invalidate(adguardHomeDnsConfigProvider(_instance)),
              ) ??
              const SizedBox.shrink()
          : _form(context),
    );
  }

  Widget _form(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Map<String, String> problems = _problems;
    String? shown(String key) =>
        _checked || _touched.contains(key) ? problems[key] : null;
    final int? size = int.tryParse(_size.text.trim());
    return ListView(
      padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.xl),
      children: <Widget>[
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Cache'),
          subtitle: const Text('Keep answers to answer again from'),
          value: _enabled,
          onChanged: (bool on) => setState(() => _enabled = on),
        ),
        const SizedBox(height: Insets.sm),
        _number(
          'size',
          _size,
          'Cache size in bytes',
          size == null ? null : adguardHomeBytesLabel(size),
          shown('size'),
        ),
        _number(
          'min',
          _ttlMin,
          'Minimum TTL in seconds',
          'Shorter times from the upstream are made this long. 0 leaves '
              'them.',
          shown('min'),
        ),
        _number(
          'max',
          _ttlMax,
          'Maximum TTL in seconds',
          'No answer is kept longer. 0 leaves the time as it came.',
          shown('max'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Optimistic caching'),
          subtitle: const Text(
            'Answer from the cache even after an answer expired, and fetch '
            'it again meanwhile',
          ),
          value: _optimistic,
          onChanged: (bool on) => setState(() => _optimistic = on),
        ),
        const SizedBox(height: Insets.lg),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            onPressed: _clear,
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('Clear cache'),
          ),
        ),
      ],
    );
  }

  Widget _number(
    String key,
    TextEditingController controller,
    String label,
    String? helper,
    String? error,
  ) =>
      Padding(
        padding: const EdgeInsets.only(bottom: Insets.md),
        child: TextField(
          key: Key('adguard-cache-$key'),
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          onChanged: (_) => _edited(key),
          decoration: InputDecoration(
            labelText: label,
            helperText: helper,
            helperMaxLines: 3,
            border: const OutlineInputBorder(),
            errorText: error,
          ),
        ),
      );
}
