import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';

import '../adguard_home_errors.dart';
import '../adguard_home_filter_rules.dart';
import '../adguard_home_providers.dart';
import '../models/adguard_home_filtering.dart';
import '../widgets/adguard_home_failure_dialog.dart';
import '../widgets/adguard_home_refused_view.dart';

/// The custom filtering rules in one editor, saved as a whole.
class AdguardHomeCustomRulesScreen extends ConsumerStatefulWidget {
  const AdguardHomeCustomRulesScreen({required this.instance, super.key});

  final Instance instance;

  @override
  ConsumerState<AdguardHomeCustomRulesScreen> createState() =>
      _AdguardHomeCustomRulesScreenState();
}

class _AdguardHomeCustomRulesScreenState
    extends ConsumerState<AdguardHomeCustomRulesScreen> {
  final TextEditingController _text = TextEditingController();

  /// The rules as the server had them when the editor was filled, or last
  /// saved. Null until the first read is in. A save that finds the server's
  /// rules no longer these asks before it replaces them.
  List<String>? _before;
  bool _busy = false;

  /// Whether a rule too long for the box goes on over more lines. Off, each
  /// rule stays on its one line and the box scrolls sideways, so a line is
  /// always a rule.
  bool _wrap = true;

  Instance get _instance => widget.instance;

  bool get _changed {
    final List<String>? held = _before;
    if (held == null) return false;
    // Both sides as the editor would write them: the server can hold blank
    // entries, which the editor drops, and a blank line is no change.
    final List<String> before =
        adguardHomeRulesFromText(adguardHomeRulesToText(held));
    final List<String> now = adguardHomeRulesFromText(_text.text);
    if (now.length != before.length) return true;
    for (int i = 0; i < now.length; i++) {
      if (now[i] != before[i]) return true;
    }
    return false;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _load(List<String> rules) {
    _before = rules;
    _text.text = adguardHomeRulesToText(rules);
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save({bool overwrite = false}) async {
    final List<String>? before = _before;
    if (_busy || before == null) return;
    final List<String> after = adguardHomeRulesFromText(_text.text);
    setState(() => _busy = true);
    try {
      await ref.read(adguardHomeActionsProvider(_instance)).saveRules(
            before: before,
            after: after,
            overwrite: overwrite,
          );
    } on AdguardHomeRulesChanged catch (changed) {
      if (!mounted) return;
      setState(() => _busy = false);
      await _resolve(changed);
      return;
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      final bool again = await showAdguardHomeFailure(
        context,
        title: 'Not saved',
        error: error,
      );
      if (again && mounted) {
        ref.read(adguardHomeActionsProvider(_instance)).retrySignIn();
        await _save(overwrite: overwrite);
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _before = after;
    });
    _say('Custom rules saved');
  }

  /// Asks what to do about rules changed on the server meanwhile.
  Future<void> _resolve(AdguardHomeRulesChanged changed) async {
    final bool? overwrite = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Rules changed elsewhere'),
        content: const Text(
          '${AdguardHomeRulesChanged.message} Saving yours replaces those '
          'changes. Loading theirs replaces what you typed here.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Load theirs'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Overwrite'),
          ),
        ],
      ),
    );
    if (!mounted || overwrite == null) return;
    if (overwrite) {
      await _save(overwrite: true);
    } else {
      setState(() => _load(changed.rules));
    }
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
    final AsyncValue<AdguardHomeFiltering> filtering =
        ref.watch(adguardHomeFilteringProvider(_instance));
    final AdguardHomeFiltering? read = filtering.value;
    // Filled once. Later reads, every five minutes, must not replace what
    // is being typed.
    if (_before == null && read != null) _load(read.userRules);
    final bool changed = _changed;
    return PopScope<Object?>(
      canPop: !_busy && !changed,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (didPop || _busy) return;
        _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Custom rules'),
          actions: <Widget>[
            IconButton(
              isSelected: _wrap,
              icon: const Icon(Icons.wrap_text),
              tooltip: _wrap ? 'Stop wrapping lines' : 'Wrap lines',
              onPressed: () => setState(() => _wrap = !_wrap),
            ),
            FilledButton(
              onPressed: _busy || !changed ? null : _save,
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
        body: _body(filtering),
      ),
    );
  }

  Widget _body(AsyncValue<AdguardHomeFiltering> filtering) {
    if (_before == null) {
      final Object? error = filtering.error;
      if (error is AdguardHomeSignInRefused) {
        return AdguardHomeRefusedView(
          onRetry: ref.read(adguardHomeActionsProvider(_instance)).retrySignIn,
          onEdit: () => context.pushNamed(
            AtriumRoutes.editInstanceName,
            pathParameters: <String, String>{'instanceId': _instance.id},
          ),
          hasCredentials: adguardHomeHasCredentials(_instance),
          refusals: ref.read(adguardHomeSessionProvider(_instance)).refusals,
        );
      }
      if (error != null) {
        return SingleChildScrollView(
          child: ErrorView(
            message: describeAdguardHomeError(error),
            onRetry: () =>
                ref.invalidate(adguardHomeFilteringProvider(_instance)),
          ),
        );
      }
      return const Center(child: ExpressiveProgressIndicator());
    }
    final ThemeData theme = Theme.of(context);
    final int count = adguardHomeRuleCount(_text.text);
    return AbsorbPointer(
      absorbing: _busy,
      child: Padding(
        padding: Insets.page,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              count == 1 ? '1 rule' : '$count rules',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: Insets.xs),
            Text(
              'One rule per line. A line that starts with ! or # is a comment.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: Insets.md),
            Expanded(child: _editor(theme)),
          ],
        ),
      ),
    );
  }

  Widget _editor(ThemeData theme) {
    final TextStyle? style =
        theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace');
    final Widget field = TextField(
      key: const Key('adguard-rules'),
      controller: _text,
      onChanged: (String _) => setState(() {}),
      expands: true,
      maxLines: null,
      textAlignVertical: TextAlignVertical.top,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.multiline,
      style: style,
      decoration: const InputDecoration(
        hintText: '||example.org^',
        border: OutlineInputBorder(),
      ),
    );
    if (_wrap) return field;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        // The font is of one width, so the longest line in characters is
        // the widest. A few to spare for the box's own padding and the
        // cursor, so a line that fits is never wrapped after all.
        int longest = 0;
        for (final String line in _text.text.split('\n')) {
          if (line.length > longest) longest = line.length;
        }
        final TextPainter glyph = TextPainter(
          text: TextSpan(text: 'M', style: style),
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final double width = glyph.width * (longest + 6);
        glyph.dispose();
        return Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width > box.maxWidth ? width : box.maxWidth,
              height: box.maxHeight,
              child: field,
            ),
          ),
        );
      },
    );
  }
}
