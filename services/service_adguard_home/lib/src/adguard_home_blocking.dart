import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'adguard_home_errors.dart';
import 'adguard_home_providers.dart';
import 'adguard_home_rules.dart';

/// Blocks or unblocks [domain] on [instance] and says what that did to the
/// custom rules.
///
/// A list of domains re-reads itself every half minute and can reorder under
/// a finger, and a block reaches everything that uses the server, so the
/// message offers to take the change back. Taking it back is the opposite
/// tap, which undoes an added rule by removing it and a removed one by
/// adding it again. It is not offered when the rule was already there:
/// nothing changed, and the opposite tap would remove a rule this one never
/// added.
Future<void> adguardHomeToggleBlocking(
  BuildContext context,
  WidgetRef ref,
  Instance instance,
  String domain, {
  required bool block,
}) {
  // Both are taken before anything is awaited: the screen that asked may be
  // gone by the time the server answers, and these outlive it.
  return _toggle(
    ScaffoldMessenger.of(context),
    ref.read(adguardHomeActionsProvider(instance)),
    domain,
    block: block,
    undoable: true,
  );
}

Future<void> _toggle(
  ScaffoldMessengerState messenger,
  AdguardHomeActions actions,
  String domain, {
  required bool block,
  required bool undoable,
}) async {
  void say(String message, {VoidCallback? onUndo}) {
    if (!messenger.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        onUndo == null
            ? SnackBar(content: Text(message))
            : SnackBar(
                content: Text(message),
                action: SnackBarAction(label: 'Undo', onPressed: onUndo),
                // A message with an action would otherwise stay until it is
                // dismissed. This one leaves by itself, after long enough
                // to read the rule and reach for Undo.
                persist: false,
                duration: const Duration(seconds: 8),
              ),
      );
  }

  try {
    final AdguardHomeRuleEdit edit =
        await actions.toggleBlocking(domain, block: block);
    say(
      switch (edit.change) {
        AdguardHomeRuleChange.added => 'Added ${edit.rule} to the custom rules',
        AdguardHomeRuleChange.removed =>
          'Removed ${edit.rule} from the custom rules',
        AdguardHomeRuleChange.alreadyThere =>
          '${edit.rule} is already in the custom rules',
      },
      onUndo: undoable && edit.change != AdguardHomeRuleChange.alreadyThere
          ? () => _toggle(
                messenger,
                actions,
                domain,
                block: !block,
                undoable: false,
              )
          : null,
    );
  } on Object catch (error) {
    say(describeAdguardHomeError(error));
  }
}
