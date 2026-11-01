import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';

import '../adguard_home_errors.dart';
import '../adguard_home_providers.dart';
import '../models/adguard_home_filters.dart';
import '../widgets/adguard_home_failure_dialog.dart';
import '../widgets/adguard_home_pullable.dart';
import '../widgets/adguard_home_refused_view.dart';

/// The DNS rewrites: the switch for all of them, then each with its own
/// switch, and a form to add, change or delete one.
class AdguardHomeRewritesScreen extends ConsumerStatefulWidget {
  const AdguardHomeRewritesScreen({required this.instance, super.key});

  final Instance instance;

  @override
  ConsumerState<AdguardHomeRewritesScreen> createState() =>
      _AdguardHomeRewritesScreenState();
}

class _AdguardHomeRewritesScreenState
    extends ConsumerState<AdguardHomeRewritesScreen> {
  /// The rows, by place in the list, whose switch is being written. The
  /// server allows two rewrites that are the same, so a place is the only
  /// thing that tells them apart.
  final Set<int> _toggling = <int>{};
  bool _switchingAll = false;

  Instance get _instance => widget.instance;

  AdguardHomeActions get _actions =>
      ref.read(adguardHomeActionsProvider(_instance));

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggle(int index, AdguardHomeRewrite rewrite, bool on) async {
    if (_toggling.contains(index)) return;
    setState(() => _toggling.add(index));
    try {
      await _actions.setRewriteEnabled(rewrite, enabled: on);
    } on Object catch (error) {
      _say(describeAdguardHomeError(error));
    } finally {
      if (mounted) setState(() => _toggling.remove(index));
    }
  }

  Future<void> _switchAll(bool on) async {
    if (_switchingAll) return;
    setState(() => _switchingAll = true);
    try {
      await _actions.setRewritesEnabled(enabled: on);
    } on Object catch (error) {
      _say(describeAdguardHomeError(error));
    } finally {
      if (mounted) setState(() => _switchingAll = false);
    }
  }

  void _open([AdguardHomeRewrite? rewrite]) => pushScreen<void>(
        context,
        AdguardHomeRewriteScreen(instance: _instance, rewrite: rewrite),
      );

  Future<void> _refresh() async {
    ref
      ..invalidate(adguardHomeRewritesProvider(_instance))
      ..invalidate(adguardHomeRewritesEnabledProvider(_instance));
    try {
      await ref.read(adguardHomeRewritesProvider(_instance).future);
    } on Object {
      // The screen shows the failure itself.
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<AdguardHomeRewrite>> rewrites =
        ref.watch(adguardHomeRewritesProvider(_instance));
    final bool? enabled =
        ref.watch(adguardHomeRewritesEnabledProvider(_instance)).value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('DNS rewrites'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add rewrite',
            onPressed: _open,
          ),
        ],
      ),
      body: _body(rewrites, enabled),
    );
  }

  Widget _body(AsyncValue<List<AdguardHomeRewrite>> rewrites, bool? enabled) {
    if (rewrites.error is AdguardHomeSignInRefused) {
      return AdguardHomeRefusedView(
        onRetry: _actions.retrySignIn,
        onEdit: () => context.pushNamed(
          AtriumRoutes.editInstanceName,
          pathParameters: <String, String>{'instanceId': _instance.id},
        ),
        hasCredentials: adguardHomeHasCredentials(_instance),
        refusals: ref.read(adguardHomeSessionProvider(_instance)).refusals,
      );
    }
    return rewrites.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: ExpressiveProgressIndicator()),
      error: (Object error, StackTrace _) => AdguardHomePullable(
        onRefresh: _refresh,
        child: ErrorView(
          message: describeAdguardHomeError(error),
          onRetry: () =>
              ref.invalidate(adguardHomeRewritesProvider(_instance)),
        ),
      ),
      data: (List<AdguardHomeRewrite> rewrites) {
        // Only what the server has: the switch for all of them once its
        // setting is read, which an older server does not have, and a
        // switch per rewrite where its list carries one.
        final Widget? overall = enabled == null
            ? null
            : SwitchListTile(
                title: const Text('Use rewrites'),
                subtitle: enabled
                    ? (rewrites.any((AdguardHomeRewrite r) => r.switchable)
                        ? const Text('Each rewrite still has its own switch.')
                        : null)
                    : const Text('None of these apply while this is off.'),
                value: enabled,
                onChanged: _switchingAll ? null : _switchAll,
              );
        if (rewrites.isEmpty) {
          return AdguardHomePullable(
            onRefresh: _refresh,
            child: Column(
              children: <Widget>[
                if (overall != null) overall,
                EmptyView(
                  icon: Icons.alt_route,
                  title: 'No rewrites',
                  message: 'A rewrite answers a domain with an address or '
                      'another domain of your choosing.',
                  action: FilledButton.tonalIcon(
                    onPressed: _open,
                    icon: const Icon(Icons.add),
                    label: const Text('Add rewrite'),
                  ),
                ),
              ],
            ),
          );
        }
        return EasyRefresh(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.only(bottom: Insets.xl),
            children: <Widget>[
              if (overall != null) ...<Widget>[
                overall,
                const Divider(height: 1),
              ],
              for (int i = 0; i < rewrites.length; i++)
                Opacity(
                  opacity: enabled == false ? 0.6 : 1,
                  child: AdguardHomeRewriteRow(
                    rewrite: rewrites[i],
                    busy: _toggling.contains(i),
                    onTap: () => _open(rewrites[i]),
                    onToggle: rewrites[i].switchable
                        ? (bool on) => _toggle(i, rewrites[i], on)
                        : null,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// One rewrite: its domain, what it is answered with, and its switch where
/// [onToggle] gives it one.
class AdguardHomeRewriteRow extends StatelessWidget {
  const AdguardHomeRewriteRow({
    required this.rewrite,
    required this.onTap,
    required this.onToggle,
    this.busy = false,
    super.key,
  });

  final AdguardHomeRewrite rewrite;
  final VoidCallback onTap;
  /// Null for a rewrite the server has no switch for.
  final ValueChanged<bool>? onToggle;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Insets.lg,
          Insets.md,
          Insets.sm,
          Insets.md,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    rewrite.domain,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: Insets.xxs),
                  Text(
                    rewrite.answer,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            if (onToggle case final ValueChanged<bool> toggle) ...<Widget>[
              const SizedBox(width: Insets.sm),
              Switch(value: rewrite.enabled, onChanged: busy ? null : toggle),
            ],
          ],
        ),
      ),
    );
  }
}

/// A rewrite's domain and answer, to add one or change it, with Delete for
/// one that is there.
class AdguardHomeRewriteScreen extends ConsumerStatefulWidget {
  const AdguardHomeRewriteScreen({
    required this.instance,
    this.rewrite,
    super.key,
  });

  final Instance instance;

  /// The rewrite to change. Null for a new one.
  final AdguardHomeRewrite? rewrite;

  @override
  ConsumerState<AdguardHomeRewriteScreen> createState() =>
      _AdguardHomeRewriteScreenState();
}

class _AdguardHomeRewriteScreenState
    extends ConsumerState<AdguardHomeRewriteScreen> {
  late final TextEditingController _domain =
      TextEditingController(text: widget.rewrite?.domain ?? '');
  late final TextEditingController _answer =
      TextEditingController(text: widget.rewrite?.answer ?? '');

  bool _busy = false;
  bool _checked = false;

  bool get _changed =>
      _domain.text.trim() != (widget.rewrite?.domain ?? '') ||
      _answer.text.trim() != (widget.rewrite?.answer ?? '');

  @override
  void dispose() {
    _domain.dispose();
    _answer.dispose();
    super.dispose();
  }

  /// After a refused sign-in, lets one more request out.
  void _retrySignIn() =>
      ref.read(adguardHomeActionsProvider(widget.instance)).retrySignIn();

  void _close(ModalRoute<Object?>? form, String message) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    if (form != null && form.isActive) {
      Navigator.of(context)
        ..popUntil((Route<Object?> route) => route == form)
        ..pop();
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (_busy) return;
    final String domain = _domain.text.trim();
    final String answer = _answer.text.trim();
    if (domain.isEmpty || answer.isEmpty) {
      setState(() => _checked = true);
      return;
    }
    final AdguardHomeRewrite? original = widget.rewrite;
    if (original != null && !_changed) {
      Navigator.of(context).pop();
      return;
    }
    final ModalRoute<Object?>? form = ModalRoute.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(adguardHomeActionsProvider(widget.instance)).saveRewrite(
            original: original,
            rewrite: AdguardHomeRewrite(
              domain: domain,
              answer: answer,
              enabled: original?.enabled ?? true,
            ),
          );
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      final bool again = await showAdguardHomeFailure(
        context,
        title: 'Not saved',
        error: error,
      );
      if (again && mounted) {
        _retrySignIn();
        await _save();
      }
      return;
    }
    if (!mounted) return;
    _close(form, original == null ? 'Rewrite added' : 'Rewrite saved');
  }

  Future<void> _delete() async {
    final AdguardHomeRewrite? rewrite = widget.rewrite;
    if (_busy || rewrite == null) return;
    // The server deletes every copy of a rewrite it holds more than once.
    final int copies = ref
            .read(adguardHomeRewritesProvider(widget.instance))
            .value
            ?.where(rewrite.sameTarget)
            .length ??
        1;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Delete the rewrite of ${rewrite.domain}?'),
        content: Text(
          copies > 1
              ? 'AdGuard Home holds it $copies times, and every copy goes. '
                  'The domain will be answered as it is again.'
              : 'The domain will be answered as it is again.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _busy) return;
    final ModalRoute<Object?>? form = ModalRoute.of(context);
    setState(() => _busy = true);
    try {
      await ref
          .read(adguardHomeActionsProvider(widget.instance))
          .deleteRewrite(rewrite);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      final bool again = await showAdguardHomeFailure(
        context,
        title: 'Not deleted',
        error: error,
      );
      if (again && mounted) {
        _retrySignIn();
        await _delete();
      }
      return;
    }
    if (!mounted) return;
    _close(form, 'Rewrite deleted');
  }

  Future<void> _leave() async {
    final bool? discard = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('What was changed here has not been saved.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bool missingDomain = _checked && _domain.text.trim().isEmpty;
    final bool missingAnswer = _checked && _answer.text.trim().isEmpty;
    return PopScope<Object?>(
      canPop: !_busy && !_changed,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (didPop || _busy) return;
        _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.rewrite == null ? 'New rewrite' : 'Edit rewrite'),
          actions: <Widget>[
            if (widget.rewrite != null)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete rewrite',
                onPressed: _busy ? null : _delete,
              ),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: const Text('Save'),
            ),
            const SizedBox(width: Insets.md),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: _busy
                ? const LinearProgressIndicatorM3E(
                    size: LinearProgressM3ESize.s,
                    shape: ProgressM3EShape.flat,
                  )
                : const SizedBox(height: 4),
          ),
        ),
        body: AbsorbPointer(
          absorbing: _busy,
          child: ListView(
            padding: Insets.page,
            children: <Widget>[
              TextField(
                key: const Key('adguard-rewrite-domain'),
                controller: _domain,
                onChanged: (String _) => setState(() {}),
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: 'Domain',
                  hintText: 'nas.home.example',
                  helperText: 'A domain, or *.example.org for every name '
                      'under it.',
                  helperMaxLines: 3,
                  errorText: missingDomain ? 'Enter a domain.' : null,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: Insets.lg),
              TextField(
                key: const Key('adguard-rewrite-answer'),
                controller: _answer,
                onChanged: (String _) => setState(() {}),
                autocorrect: false,
                enableSuggestions: false,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: 'Answer',
                  hintText: '192.168.1.10',
                  helperText: 'An IP address; a domain, to answer with its '
                      'address; or A or AAAA to keep the upstream\'s answer '
                      'of that type.',
                  helperMaxLines: 4,
                  errorText: missingAnswer ? 'Enter an answer.' : null,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
