import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';

import '../adguard_home_errors.dart';
import '../adguard_home_providers.dart';
import 'adguard_home_failure_dialog.dart';
import 'adguard_home_refused_view.dart';

/// The frame of a settings form: Save in the app bar, a bar while it
/// writes, nothing to touch meanwhile, and a question before leaving with
/// changes unsaved.
class AdguardHomeSettingsForm extends StatelessWidget {
  const AdguardHomeSettingsForm({
    required this.title,
    required this.busy,
    required this.changed,
    required this.onSave,
    required this.body,
    super.key,
  });

  final String title;
  final bool busy;
  final bool changed;
  final VoidCallback onSave;
  final Widget body;

  Future<void> _leave(BuildContext context) async {
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
    if (discard == true && context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
        canPop: !busy && !changed,
        onPopInvokedWithResult: (bool didPop, Object? _) {
          if (didPop || busy) return;
          _leave(context);
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: <Widget>[
              FilledButton(
                onPressed: busy || !changed ? null : onSave,
                child: const Text('Save'),
              ),
              const SizedBox(width: Insets.md),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(4),
              child: busy
                  ? const LinearProgressIndicatorM3E(
                      size: LinearProgressM3ESize.s,
                      shape: ProgressM3EShape.flat,
                    )
                  : const SizedBox(height: 4),
            ),
          ),
          body: AbsorbPointer(absorbing: busy, child: body),
        ),
      );
}

/// What a settings screen shows before its read is in: the refused
/// sign-in with Try again, the failure with Retry, or progress. Null once
/// there is something to show.
Widget? adguardHomeSettingsWaiting<T>(
  BuildContext context,
  WidgetRef ref,
  Instance instance,
  AsyncValue<T> value, {
  required VoidCallback onRetry,
}) {
  final Object? error = value.error;
  if (error is AdguardHomeSignInRefused) {
    return AdguardHomeRefusedView(
      onRetry: ref.read(adguardHomeActionsProvider(instance)).retrySignIn,
      onEdit: () => context.pushNamed(
        AtriumRoutes.editInstanceName,
        pathParameters: <String, String>{'instanceId': instance.id},
      ),
      hasCredentials: adguardHomeHasCredentials(instance),
      refusals: ref.read(adguardHomeSessionProvider(instance)).refusals,
    );
  }
  if (value.hasValue) return null;
  if (error != null) {
    return SingleChildScrollView(
      child: ErrorView(
        message: describeAdguardHomeError(error),
        onRetry: onRetry,
      ),
    );
  }
  return const Center(child: ExpressiveProgressIndicator());
}

/// Writes a settings form with [save], then closes the form's own route
/// and says [done]. A failure is said in a dialog that, for a refused
/// sign-in, offers Try again and runs [retry] (the save once more).
/// Returns whether it was written.
Future<bool> adguardHomeSaveSettings(
  BuildContext context,
  WidgetRef ref,
  Instance instance, {
  required Future<void> Function() save,
  required String done,
  required void Function(bool busy) setBusy,
  required Future<void> Function() retry,
}) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final ModalRoute<Object?>? form = ModalRoute.of(context);
  setBusy(true);
  try {
    await save();
  } on Object catch (error) {
    if (!context.mounted) return false;
    setBusy(false);
    final bool again = await showAdguardHomeFailure(
      context,
      title: 'Not saved',
      error: error,
    );
    if (again && context.mounted) {
      ref.read(adguardHomeActionsProvider(instance)).retrySignIn();
      await retry();
    }
    return false;
  }
  if (!context.mounted) return true;
  setBusy(false);
  if (form != null && form.isActive) {
    Navigator.of(context)
      ..popUntil((Route<Object?> route) => route == form)
      ..pop();
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(done)));
  return true;
}
