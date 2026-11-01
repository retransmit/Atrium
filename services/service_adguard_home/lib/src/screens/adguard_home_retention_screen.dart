import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../adguard_home_filter_rules.dart';
import '../adguard_home_format.dart';
import '../adguard_home_log_actions.dart';
import '../adguard_home_providers.dart';
import '../models/adguard_home_settings.dart';
import '../widgets/adguard_home_failure_dialog.dart';
import '../widgets/adguard_home_fields.dart';
import '../widgets/adguard_home_settings_form.dart';

/// Which of the two the screen sets.
enum AdguardHomeRetentionKind {
  queryLog,
  statistics;

  String get title => switch (this) {
        queryLog => 'Query log',
        statistics => 'Statistics',
      };
}

/// Whether the query log or the statistics are kept, for how long, and
/// which queries they leave out. Saved as a whole with Save.
class AdguardHomeRetentionScreen extends ConsumerStatefulWidget {
  const AdguardHomeRetentionScreen({
    required this.instance,
    required this.kind,
    super.key,
  });

  final Instance instance;
  final AdguardHomeRetentionKind kind;

  @override
  ConsumerState<AdguardHomeRetentionScreen> createState() =>
      _AdguardHomeRetentionScreenState();
}

class _AdguardHomeRetentionScreenState
    extends ConsumerState<AdguardHomeRetentionScreen> {
  final TextEditingController _hours = TextEditingController();
  final TextEditingController _ignored = TextEditingController();

  /// As read when the form was filled. Null until then.
  AdguardHomeRetention? _before;
  late AdguardHomeRetention _draft;

  /// Whether Custom is picked, with its hours in [_hours].
  bool _custom = false;

  /// The hours the form opened with. Left as they are, the retention stays
  /// as the server has it, which need not be a whole number of hours.
  String _hoursAsRead = '';
  bool _checked = false;
  bool _busy = false;

  Instance get _instance => widget.instance;
  bool get _log => widget.kind == AdguardHomeRetentionKind.queryLog;

  FutureProvider<AdguardHomeRetention> get _provider => _log
      ? adguardHomeQueryLogRetentionProvider(_instance)
      : adguardHomeStatsRetentionProvider(_instance);

  List<Duration> get _choices =>
      _log ? adguardHomeQueryLogRetentions : adguardHomeStatsRetentions;

  @override
  void dispose() {
    _hours.dispose();
    _ignored.dispose();
    super.dispose();
  }

  void _fill(AdguardHomeRetention read) {
    _before = read;
    _draft = read;
    _custom = !_choices.contains(read.interval);
    _hours.text = _custom ? '${read.interval.inHours}' : '';
    _hoursAsRead = _hours.text;
    _ignored.text = adguardHomeRulesToText(read.ignored);
  }

  /// The form as it would be saved; null while Custom holds no number.
  AdguardHomeRetention? get _after {
    Duration interval = _draft.interval;
    if (_custom && _hours.text.trim() == _hoursAsRead) {
      interval = _before!.interval;
    } else if (_custom) {
      final int? hours = int.tryParse(_hours.text.trim());
      if (adguardHomeRetentionProblem(hours) != null) return null;
      interval = Duration(hours: hours!);
    }
    return _draft.copyWith(
      interval: interval,
      ignored: adguardHomeRulesFromText(_ignored.text)
          .map((String rule) => rule.trim())
          .toList(),
    );
  }

  bool get _changed {
    final AdguardHomeRetention? before = _before;
    if (before == null) return false;
    final AdguardHomeRetention? after = _after;
    if (after == null) return true;
    return adguardHomeChangedSettings(before.toJson(), after.toJson())
        .isNotEmpty;
  }

  Future<void> _save() async {
    final AdguardHomeRetention? before = _before;
    final AdguardHomeRetention? after = _after;
    if (_busy || before == null) return;
    if (after == null) {
      setState(() => _checked = true);
      return;
    }
    // Less time to keep things is lost data, so it is asked about first.
    if (after.interval < before.interval) {
      final bool? shorter = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: Text(
            _log ? 'Keep the log for less time?' : 'Keep statistics for '
                'less time?',
          ),
          content: Text(
            'What is older than ${adguardHomeRetentionLabel(after.interval)} '
            'is deleted.',
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
      if (shorter != true || !mounted) return;
    }
    await _write(before, after);
  }

  Future<void> _write(
    AdguardHomeRetention before,
    AdguardHomeRetention after,
  ) {
    final AdguardHomeActions actions =
        ref.read(adguardHomeActionsProvider(_instance));
    return adguardHomeSaveSettings(
      context,
      ref,
      _instance,
      save: () => _log
          ? actions.saveQueryLogRetention(before: before, after: after)
          : actions.saveStatsRetention(before: before, after: after),
      done: _log ? 'Query log settings saved' : 'Statistics settings saved',
      setBusy: (bool busy) => setState(() => _busy = busy),
      // Asked once already: Try again goes straight to the write.
      retry: () => _write(before, after),
    );
  }

  String get _ignoredHelp => _log
      ? 'Queries matching these rules are not written to the query log'
      : 'Queries matching these rules are not counted in the statistics';

  Future<void> _reset() async {
    final bool? reset = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Reset statistics?'),
        content: const Text(
          'Every count and chart starts again from nothing. This cannot be '
          'undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (reset != true) return;
    await _resetAsked();
  }

  /// Resets the statistics, asked already: Try again comes back here.
  Future<void> _resetAsked() async {
    if (!mounted) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AdguardHomeActions actions =
        ref.read(adguardHomeActionsProvider(_instance));
    setState(() => _busy = true);
    SnackBar said = const SnackBar(content: Text('Statistics reset'));
    try {
      await actions.resetStats();
    } on Object catch (error) {
      said = adguardHomeFailureSnackBar(
        error,
        retrySignIn: actions.retrySignIn,
        again: () => unawaited(_resetAsked()),
      );
    }
    if (mounted) setState(() => _busy = false);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(said);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AdguardHomeRetention> read = ref.watch(_provider);
    final AdguardHomeRetention? value = read.value;
    // Filled once. A later read must not replace what is being changed.
    if (_before == null && value != null) _fill(value);
    return AdguardHomeSettingsForm(
      title: widget.kind.title,
      busy: _busy,
      changed: _changed,
      onSave: _save,
      body: _before == null
          ? adguardHomeSettingsWaiting<AdguardHomeRetention>(
                context,
                ref,
                _instance,
                read,
                onRetry: () => ref.invalidate(_provider),
              ) ??
              const SizedBox.shrink()
          : _form(context),
    );
  }

  Widget _form(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int? hours = int.tryParse(_hours.text.trim());
    return ListView(
      padding: const EdgeInsets.only(bottom: Insets.xl),
      children: <Widget>[
        SwitchListTile(
          title: Text(_log ? 'Keep a query log' : 'Keep statistics'),
          value: _draft.enabled,
          onChanged: (bool on) =>
              setState(() => _draft = _draft.copyWith(enabled: on)),
        ),
        if (_log)
          SwitchListTile(
            title: const Text('Anonymize client IP'),
            subtitle: const Text(
              "Don't save the client's full IP address to logs or statistics",
            ),
            value: _draft.anonymizeClientIp ?? false,
            onChanged: (bool on) => setState(
              () => _draft = _draft.copyWith(anonymizeClientIp: on),
            ),
          ),
        _Inset(child: AdguardHomeHeading(_log ? 'Keep queries for' : 'Keep for')),
        // Hours, and -1 for Custom.
        RadioGroup<int>(
          groupValue: _custom ? -1 : _draft.interval.inHours,
          onChanged: (int? picked) => setState(() {
            if (picked == null) return;
            if (picked < 0) {
              _custom = true;
              if (_hours.text.isEmpty) {
                _hours.text = '${_draft.interval.inHours}';
              }
            } else {
              _custom = false;
              _draft = _draft.copyWith(interval: Duration(hours: picked));
            }
          }),
          child: Column(
            children: <Widget>[
              for (final Duration choice in _choices)
                RadioListTile<int>(
                  title: Text(adguardHomeRetentionLabel(choice)),
                  value: choice.inHours,
                ),
              const RadioListTile<int>(
                title: Text('Custom'),
                value: -1,
              ),
            ],
          ),
        ),
        if (_custom)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.xl * 2,
              0,
              Insets.lg,
              Insets.sm,
            ),
            child: TextField(
              key: const Key('adguard-retention-hours'),
              controller: _hours,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Hours',
                helperText: 'From 1 to $adguardHomeRetentionMaxHours',
                border: const OutlineInputBorder(),
                errorText:
                    _checked || _hours.text.isNotEmpty
                        ? adguardHomeRetentionProblem(hours)
                        : null,
              ),
            ),
          ),
        const _Inset(child: AdguardHomeHeading('Ignored domains')),
        // A server from before the switch always leaves these out.
        if (_draft.hasIgnoredSwitch)
          SwitchListTile(
            title: const Text('Leave out these domains'),
            subtitle: Text(_ignoredHelp),
            value: _draft.ignoredEnabled,
            onChanged: (bool on) =>
                setState(() => _draft = _draft.copyWith(ignoredEnabled: on)),
          )
        else
          ListTile(subtitle: Text(_ignoredHelp)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
          child: TextField(
            key: const Key('adguard-retention-ignored'),
            controller: _ignored,
            onChanged: (_) => setState(() {}),
            minLines: 3,
            maxLines: 10,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.multiline,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontFamily: 'monospace'),
            decoration: const InputDecoration(
              helperText: 'One rule per line, such as example.org or '
                  '*.example.com',
              helperMaxLines: 2,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(height: Insets.xl),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              onPressed: _log
                  ? () => unawaited(
                        adguardHomeClearQueryLog(context, ref, _instance),
                      )
                  : _reset,
              icon: const Icon(Icons.delete_sweep_outlined),
              label: Text(_log ? 'Clear query log' : 'Reset statistics'),
            ),
          ),
        ),
      ],
    );
  }
}

class _Inset extends StatelessWidget {
  const _Inset({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
        child: child,
      );
}
