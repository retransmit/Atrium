import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../adguard_home_errors.dart';
import '../adguard_home_filter_rules.dart';
import '../adguard_home_providers.dart';
import '../models/adguard_home_settings.dart';
import '../widgets/adguard_home_fields.dart';
import '../widgets/adguard_home_settings_form.dart';

/// The upstream part of the DNS settings, as the form holds it.
class AdguardHomeUpstreamDraft {
  const AdguardHomeUpstreamDraft({
    required this.upstreams,
    required this.mode,
    required this.fallback,
    required this.bootstrap,
    required this.privateUpstreams,
    required this.usePrivatePtrResolvers,
    required this.resolveClients,
    required this.timeout,
    this.upstreamsFile = '',
  });

  factory AdguardHomeUpstreamDraft.of(AdguardHomeDnsConfig dns) =>
      AdguardHomeUpstreamDraft(
        upstreams: dns.upstreams,
        mode: dns.upstreamMode,
        fallback: dns.fallback,
        bootstrap: dns.bootstrap,
        privateUpstreams: dns.privateUpstreams,
        usePrivatePtrResolvers: dns.usePrivatePtrResolvers,
        resolveClients: dns.resolveClients,
        timeout: dns.upstreamTimeout,
        upstreamsFile: dns.upstreamsFile,
      );

  final List<String> upstreams;
  final AdguardHomeUpstreamMode mode;
  final List<String> fallback;
  final List<String> bootstrap;
  final List<String> privateUpstreams;
  final bool usePrivatePtrResolvers;
  final bool resolveClients;

  /// Seconds.
  final int timeout;

  /// Where the server reads its upstreams from instead, if it does. Then
  /// [upstreams] is not sent: it is not the list in force.
  final String upstreamsFile;

  /// The settings as `dns_config` takes them.
  Map<String, dynamic> toJson() => <String, dynamic>{
        if (upstreamsFile.isEmpty) 'upstream_dns': upstreams,
        'upstream_mode': mode.wire,
        'fallback_dns': fallback,
        'bootstrap_dns': bootstrap,
        'local_ptr_upstreams': privateUpstreams,
        'use_private_ptr_resolvers': usePrivatePtrResolvers,
        'resolve_clients': resolveClients,
        'upstream_timeout': timeout,
      };
}

/// The servers AdGuard Home asks, how it picks among them, and what it
/// falls back to. Saved with Save; Test upstreams tries what is typed.
class AdguardHomeDnsUpstreamsScreen extends ConsumerStatefulWidget {
  const AdguardHomeDnsUpstreamsScreen({required this.instance, super.key});

  final Instance instance;

  @override
  ConsumerState<AdguardHomeDnsUpstreamsScreen> createState() =>
      _AdguardHomeDnsUpstreamsScreenState();
}

class _AdguardHomeDnsUpstreamsScreenState
    extends ConsumerState<AdguardHomeDnsUpstreamsScreen> {
  final TextEditingController _upstreams = TextEditingController();
  final TextEditingController _fallback = TextEditingController();
  final TextEditingController _bootstrap = TextEditingController();
  final TextEditingController _private = TextEditingController();
  final TextEditingController _timeout = TextEditingController();

  AdguardHomeDnsConfig? _read;
  AdguardHomeUpstreamDraft? _before;
  AdguardHomeUpstreamMode _mode = AdguardHomeUpstreamMode.loadBalance;
  bool _usePrivate = false;
  bool _resolveClients = false;
  bool _checked = false;
  bool _busy = false;
  bool _testing = false;

  Instance get _instance => widget.instance;

  @override
  void dispose() {
    _upstreams.dispose();
    _fallback.dispose();
    _bootstrap.dispose();
    _private.dispose();
    _timeout.dispose();
    super.dispose();
  }

  void _fill(AdguardHomeDnsConfig dns) {
    final AdguardHomeUpstreamDraft draft = AdguardHomeUpstreamDraft.of(dns);
    _read = dns;
    _before = draft;
    _upstreams.text = adguardHomeRulesToText(draft.upstreams);
    _fallback.text = adguardHomeRulesToText(draft.fallback);
    _bootstrap.text = adguardHomeRulesToText(draft.bootstrap);
    _private.text = adguardHomeRulesToText(draft.privateUpstreams);
    // An older server may have none to say; then the box starts empty and
    // the form is not edited until something is typed there.
    _timeout.text = draft.timeout > 0 ? '${draft.timeout}' : '';
    _mode = draft.mode;
    _usePrivate = draft.usePrivatePtrResolvers;
    _resolveClients = draft.resolveClients;
  }

  static List<String> _lines(TextEditingController text) => <String>[
        for (final String line in adguardHomeRulesFromText(text.text))
          line.trim(),
      ];

  /// The timeout as typed, as the server has it when left empty there
  /// was none, or null when it will not do.
  int? get _timeoutSeconds {
    final String text = _timeout.text.trim();
    final AdguardHomeUpstreamDraft? before = _before;
    if (text.isEmpty && before != null && before.timeout < 1) {
      return before.timeout;
    }
    if (adguardHomeWholeNumberProblem(text, min: 1) != null) return null;
    return int.parse(text);
  }

  AdguardHomeUpstreamDraft? get _after {
    final int? timeout = _timeoutSeconds;
    final AdguardHomeUpstreamDraft? before = _before;
    if (timeout == null || before == null) return null;
    return AdguardHomeUpstreamDraft(
      upstreams: _lines(_upstreams),
      mode: _mode,
      fallback: _lines(_fallback),
      bootstrap: _lines(_bootstrap),
      privateUpstreams: _lines(_private),
      usePrivatePtrResolvers: _usePrivate,
      resolveClients: _resolveClients,
      timeout: timeout,
      upstreamsFile: before.upstreamsFile,
    );
  }

  bool get _changed {
    final AdguardHomeUpstreamDraft? before = _before;
    if (before == null) return false;
    final AdguardHomeUpstreamDraft? after = _after;
    if (after == null) return true;
    return adguardHomeChangedSettings(before.toJson(), after.toJson())
        .isNotEmpty;
  }

  Future<void> _save() async {
    final AdguardHomeUpstreamDraft? before = _before;
    final AdguardHomeUpstreamDraft? after = _after;
    if (_busy || before == null) return;
    if (after == null) {
      setState(() => _checked = true);
      return;
    }
    await adguardHomeSaveSettings(
      context,
      ref,
      _instance,
      save: () => ref
          .read(adguardHomeActionsProvider(_instance))
          .saveDnsSettings(before: before.toJson(), after: after.toJson()),
      done: 'Upstream settings saved',
      setBusy: (bool busy) => setState(() => _busy = busy),
      retry: _save,
    );
  }

  Future<void> _test() async {
    if (_testing) return;
    final AdguardHomeUpstreamDraft? before = _before;
    setState(() => _testing = true);
    // The server reads a file of upstreams only for itself: what dns_info
    // lists then is not what is in force, and is not tested as if it were.
    final String file = before?.upstreamsFile ?? '';
    List<AdguardHomeUpstreamResult>? results;
    Object? failure;
    try {
      results = await ref
          .read(adguardHomeActionsProvider(_instance))
          .testUpstreams(
            upstreams: file.isEmpty ? _lines(_upstreams) : const <String>[],
            bootstrap: _lines(_bootstrap),
            fallback: _lines(_fallback),
            privateUpstreams: _lines(_private),
          );
    } on Object catch (error) {
      failure = error;
    }
    if (!mounted) return;
    setState(() => _testing = false);
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext sheet) => _UpstreamResults(
        results: results,
        failure: failure,
        upstreamsFile: file,
        // After a refused sign-in nothing is sent until asked; this asks,
        // and tests again.
        onTryAgain: failure is AdguardHomeSignInRefused
            ? () {
                Navigator.of(sheet).pop();
                ref.read(adguardHomeActionsProvider(_instance)).retrySignIn();
                unawaited(_test());
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AdguardHomeDnsConfig> read =
        ref.watch(adguardHomeDnsConfigProvider(_instance));
    final AdguardHomeDnsConfig? value = read.value;
    // Filled once. A later read must not replace what is being typed.
    if (_before == null && value != null) _fill(value);
    return AdguardHomeSettingsForm(
      title: 'Upstreams',
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
    final AdguardHomeDnsConfig dns = _read!;
    final List<String> defaults = dns.defaultPrivateUpstreams;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.xl),
      children: <Widget>[
        const AdguardHomeHeading('Upstream DNS servers'),
        const SizedBox(height: Insets.sm),
        if (dns.upstreamsFile.isNotEmpty)
          Text(
            'Configured in ${dns.upstreamsFile} on the server, so they are '
            'not changed here.',
            style: theme.textTheme.bodyMedium,
          )
        else
          _box(
            key: 'adguard-upstreams',
            controller: _upstreams,
              helper: 'One server per line. [/example.org/] before a server '
                'sends only that domain to it.',
          ),
        const SizedBox(height: Insets.md),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            onPressed: _testing ? null : _test,
            icon: _testing
                ? const SizedBox.square(
                    dimension: 18,
                    child: ExpressiveProgressIndicator(),
                  )
                : const Icon(Icons.network_check),
            label: const Text('Test upstreams'),
          ),
        ),
        const AdguardHomeHeading('Mode'),
        RadioGroup<AdguardHomeUpstreamMode>(
          groupValue: _mode,
          onChanged: (AdguardHomeUpstreamMode? mode) {
            if (mode != null) setState(() => _mode = mode);
          },
          child: Column(
            children: <Widget>[
              for (final AdguardHomeUpstreamMode mode
                  in AdguardHomeUpstreamMode.values)
                RadioListTile<AdguardHomeUpstreamMode>(
                  contentPadding: EdgeInsets.zero,
                  title: Text(mode.label),
                  subtitle: Text(_modeHelp(mode)),
                  value: mode,
                ),
            ],
          ),
        ),
        const AdguardHomeHeading('Fallback DNS servers'),
        const SizedBox(height: Insets.sm),
        _box(
          key: 'adguard-fallback',
          controller: _fallback,
          helper: 'Asked when the upstream servers do not answer. One per '
              'line.',
        ),
        const AdguardHomeHeading('Bootstrap DNS servers'),
        const SizedBox(height: Insets.sm),
        _box(
          key: 'adguard-bootstrap',
          controller: _bootstrap,
          helper: 'IP addresses that find the encrypted upstreams by name. '
              'One per line.',
        ),
        const AdguardHomeHeading('Private reverse DNS servers'),
        const SizedBox(height: Insets.sm),
        _box(
          key: 'adguard-private',
          controller: _private,
          helper: defaults.isEmpty
              ? 'For names of local addresses. The server found no default '
                  'to use.'
              : 'For names of local addresses. Empty, the server uses '
                  '${defaults.join(', ')}.',
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Use private reverse DNS resolvers'),
          subtitle: const Text(
            'Off, lookups of local addresses are answered with NXDOMAIN',
          ),
          value: _usePrivate,
          onChanged: (bool on) => setState(() => _usePrivate = on),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("Look up clients' names"),
          subtitle: const Text(
            'Find the hostname of each client from its IP address',
          ),
          value: _resolveClients,
          onChanged: (bool on) => setState(() => _resolveClients = on),
        ),
        const AdguardHomeHeading('Upstream timeout'),
        const SizedBox(height: Insets.sm),
        TextField(
          key: const Key('adguard-upstream-timeout'),
          controller: _timeout,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Seconds',
            border: const OutlineInputBorder(),
            errorText: (_checked || _timeout.text.isNotEmpty) &&
                    _timeoutSeconds == null
                ? (int.tryParse(_timeout.text.trim()) ?? 0) < 1
                    ? 'At least 1 second.'
                    : 'At most $adguardHomeMaxUint32 seconds.'
                : null,
          ),
        ),
      ],
    );
  }

  static String _modeHelp(AdguardHomeUpstreamMode mode) => switch (mode) {
        AdguardHomeUpstreamMode.loadBalance =>
          'One server at a time, the fastest and most reliable most often',
        AdguardHomeUpstreamMode.parallel =>
          'All servers at once, the first answer wins',
        AdguardHomeUpstreamMode.fastestAddress =>
          'All servers, then the address that connects fastest. Slow when '
              'a server does not answer',
      };

  Widget _box({
    required String key,
    required TextEditingController controller,
    required String helper,
  }) =>
      TextField(
        key: Key(key),
        controller: controller,
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
          // No example in the box: an empty box would look set to it.
          helperText: helper,
          helperMaxLines: 4,
          border: const OutlineInputBorder(),
        ),
      );
}

/// What each server said when tested.
class _UpstreamResults extends StatelessWidget {
  const _UpstreamResults({
    required this.results,
    required this.failure,
    this.upstreamsFile = '',
    this.onTryAgain,
  });

  final List<AdguardHomeUpstreamResult>? results;
  final Object? failure;

  /// Where the server keeps its upstreams, when it does: those are not
  /// tested from here.
  final String upstreamsFile;

  /// Offered when the test was refused for the sign-in.
  final VoidCallback? onTryAgain;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final List<AdguardHomeUpstreamResult> all =
        results ?? const <AdguardHomeUpstreamResult>[];
    final int failed =
        all.where((AdguardHomeUpstreamResult r) => !r.ok).length;
    final String title = failure != null
        ? 'Not tested'
        : all.isEmpty
            ? 'Nothing to test'
            : failed == 0
                ? 'Every server answered'
                : failed == 1
                    ? '1 server did not answer'
                    : '$failed servers did not answer';
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.xl),
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: Insets.sm),
        if (upstreamsFile.isNotEmpty)
          Text(
            'The upstreams in $upstreamsFile are read by the server alone '
            'and cannot be tested from here.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        if (failure != null)
          Text(
            describeAdguardHomeError(failure!),
            style: theme.textTheme.bodyMedium?.copyWith(color: cs.error),
          ),
        if (onTryAgain != null)
          Padding(
            padding: const EdgeInsets.only(top: Insets.md),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.tonalIcon(
                onPressed: onTryAgain,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ),
          ),
        for (final AdguardHomeUpstreamResult result in all)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              result.ok ? Icons.check_circle_outline : Icons.error_outline,
              color: result.ok ? cs.primary : cs.error,
            ),
            title: Text(
              result.server,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontFamily: 'monospace'),
            ),
            subtitle: result.ok ? null : Text(result.message),
          ),
      ],
    );
  }
}
