import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// What every AdGuard Home screen shows once the server has refused the
/// sign-in: why, what the server does about wrong tries, and a way to try
/// again that the user has to ask for.
class AdguardHomeRefusedView extends StatelessWidget {
  const AdguardHomeRefusedView({
    required this.onRetry,
    this.onEdit,
    super.key,
  });

  /// Sends one more request.
  final VoidCallback onRetry;

  /// Opens the instance's settings, where the password can be corrected.
  final VoidCallback? onEdit;

  /// The two numbers are AdGuard Home's defaults (`auth_attempts` and
  /// `block_auth_min` in its config), hence "by default".
  static const String explanation =
      'The username or password was not accepted. By default AdGuard Home '
      'blocks an address for 15 minutes after five wrong tries, and while '
      'it does, it refuses the right password too.';

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
              'AdGuard Home refused the sign-in',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Insets.sm),
            Text(
              explanation,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
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
