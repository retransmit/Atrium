import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// What every AdGuard Home screen shows once the server has refused the
/// sign-in: why, what the server does about wrong tries, and a way to try
/// again that the user has to ask for.
class AdguardHomeRefusedView extends StatelessWidget {
  const AdguardHomeRefusedView({
    required this.onRetry,
    this.onEdit,
    this.hasCredentials = true,
    this.refusals = 0,
    super.key,
  });

  /// Sends one more request.
  final VoidCallback onRetry;

  /// Opens the instance's settings, where the password can be corrected.
  final VoidCallback? onEdit;

  /// Whether the instance has a username or password at all. Without them
  /// the server refused nothing it counts: it only wants a sign-in, and the
  /// talk of a lockout would mislead.
  final bool hasCredentials;

  /// How many tries in a row the server has refused, from the session. Said
  /// from the second on: a try that is refused again would otherwise look
  /// like no try at all, and the fifth is the one that gets the address
  /// blocked.
  final int refusals;

  /// The two numbers are AdGuard Home's defaults (`auth_attempts` and
  /// `block_auth_min` in its config), hence "by default".
  static const String explanation =
      'The username or password was not accepted. By default AdGuard Home '
      'blocks an address for 15 minutes after five wrong tries, and while '
      'it does, it refuses the right password too.';

  /// What is said instead of [explanation] when nothing was entered.
  static const String noCredentials =
      'This AdGuard Home has a user, and this instance has no username or '
      'password. Add them under Edit instance.';

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: Insets.page,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.lock_outline, size: 48, color: cs.error),
            const SizedBox(height: Insets.lg),
            Text(
              hasCredentials
                  ? 'AdGuard Home refused the sign-in'
                  : 'AdGuard Home asks for a sign-in',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Insets.sm),
            Text(
              hasCredentials ? explanation : noCredentials,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (hasCredentials && refusals > 1) ...<Widget>[
              const SizedBox(height: Insets.sm),
              Text(
                'Refused $refusals times in a row from this app.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.error,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: Insets.lg),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
            if (onEdit != null)
              TextButton(
                onPressed: onEdit,
                child: const Text('Edit instance'),
              ),
          ],
        ),
      ),
    );
  }
}
