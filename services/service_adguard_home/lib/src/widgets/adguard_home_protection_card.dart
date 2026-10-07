import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../adguard_home_providers.dart';
import '../models/adguard_home_status.dart';
import 'adguard_home_countdown.dart';

/// Whether protection is on, a switch for it, and the pauses.
class AdguardHomeProtectionCard extends StatelessWidget {
  const AdguardHomeProtectionCard({
    required this.status,
    required this.busy,
    required this.onSet,
    required this.onPauseEnded,
    this.now = DateTime.now,
    super.key,
  });

  final AdguardHomeStatus status;

  /// While a change is on its way to the server the controls are off, so a
  /// second tap cannot race the first.
  final bool busy;
  final void Function({required bool enabled, Duration? pause}) onSet;
  final VoidCallback onPauseEnded;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AdguardHomeProtection state = status.protection;
    final Color color = switch (state) {
      AdguardHomeProtection.on => cs.primary,
      AdguardHomeProtection.paused => cs.tertiary,
      AdguardHomeProtection.off => cs.error,
    };
    final IconData icon = switch (state) {
      AdguardHomeProtection.on => Icons.gpp_good_outlined,
      AdguardHomeProtection.paused => Icons.gpp_maybe_outlined,
      AdguardHomeProtection.off => Icons.gpp_bad_outlined,
    };
    final String title = switch (state) {
      AdguardHomeProtection.on => 'Protection is on',
      AdguardHomeProtection.paused => 'Protection is paused',
      AdguardHomeProtection.off => 'Protection is off',
    };
    final TextStyle? quiet =
        theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant);
    final DateTime? pausedUntil = status.pausedUntil;

    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 24, color: color),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (pausedUntil != null)
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            Text('Back on in ', style: quiet),
                            AdguardHomeCountdown(
                              until: pausedUntil,
                              onDone: onPauseEnded,
                              now: now,
                              style: quiet?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          state == AdguardHomeProtection.on
                              ? 'Filtering as it is set up.'
                              : 'Off until it is turned back on.',
                          style: quiet,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Switch(
                  value: status.protectionEnabled,
                  onChanged: busy ? null : (bool on) => onSet(enabled: on),
                ),
              ],
            ),
            const SizedBox(height: Insets.md),
            Text('Pause for', style: theme.textTheme.labelMedium),
            const SizedBox(height: Insets.xs),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.xs,
              children: <Widget>[
                for (final AdguardHomePause pause in adguardHomePauses)
                  ActionChip(
                    label: Text(pause.label),
                    onPressed: busy
                        ? null
                        : () => onSet(enabled: false, pause: pause.length),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
