import 'package:flutter/material.dart';

import '../adguard_home_errors.dart';

/// Says in a dialog that something was not done, under [title], and why.
///
/// After a refused sign-in nothing is sent until the user asks, and a form
/// with unsaved work in it hides the Try again behind it. So for that
/// reason the dialog offers Try again itself; the answer is true when it
/// was taken.
Future<bool> showAdguardHomeFailure(
  BuildContext context, {
  required String title,
  required Object error,
}) async {
  final bool refused = error is AdguardHomeSignInRefused;
  final bool? again = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(title),
      content: Text(describeAdguardHomeError(error)),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(refused ? 'Cancel' : 'OK'),
        ),
        if (refused)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Try again'),
          ),
      ],
    ),
  );
  return again ?? false;
}

/// A snackbar that says why something was not done. For a refused sign-in
/// it offers Try again, which lets one more request out and runs [again]:
/// without it the next tap would only get the same refusal back, without
/// a word to the server.
SnackBar adguardHomeFailureSnackBar(
  Object error, {
  required VoidCallback retrySignIn,
  required VoidCallback again,
}) =>
    SnackBar(
      content: Text(describeAdguardHomeError(error)),
      action: error is AdguardHomeSignInRefused
          ? SnackBarAction(
              label: 'Try again',
              onPressed: () {
                retrySignIn();
                again();
              },
            )
          : null,
    );
