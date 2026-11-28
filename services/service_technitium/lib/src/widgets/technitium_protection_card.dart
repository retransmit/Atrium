import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../models/technitium_status.dart';
import '../technitium_providers.dart';
import 'technitium_countdown.dart';

/// Card showing current blocking status, countdown, and timed pause options.
class TechnitiumProtectionCard extends StatelessWidget {
  const TechnitiumProtectionCard({
    required this.status,
    required this.busy,
    required this.onSet,
    required this.onPauseEnded,
    this.now = DateTime.now,
    super.key,
  });

  final TechnitiumStatus status;
  final bool busy;
  final void Function({required bool enabled, Duration? pause}) onSet;
  final VoidCallback onPauseEnded;
  final DateTime Function() now;

  Future<void> _showPauseMenu(BuildContext context) async {
    final RenderBox button = context.findRenderObject()! as RenderBox;
    final RenderBox overlay = Navigator.of(context, rootNavigator: true)
        .overlay!
        .context
        .findRenderObject()! as RenderBox;

    final Duration? choice = await showMenu<Duration>(
      context: context,
      useRootNavigator: true,
      position: RelativeRect.fromRect(
        Rect.fromPoints(
          button.localToGlobal(
            button.size.bottomLeft(Offset.zero),
            ancestor: overlay,
          ),
          button.localToGlobal(
            button.size.bottomRight(Offset.zero),
            ancestor: overlay,
          ),
        ),
        Offset.zero & overlay.size,
      ),
      items: <PopupMenuEntry<Duration>>[
        for (final TechnitiumPause pause in technitiumPauses)
          PopupMenuItem<Duration>(
            value: pause.duration,
            child: Text(pause.label),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<Duration>(
          value: Duration.zero,
          child: Text('Until turned back on'),
        ),
      ],
    );

    if (choice == null) return;
    if (choice == Duration.zero) {
      onSet(enabled: false);
    } else {
      onSet(enabled: false, pause: choice);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final TechnitiumProtection state = status.protection;

    final Color color = switch (state) {
      TechnitiumProtection.on => cs.primary,
      TechnitiumProtection.paused => cs.tertiary,
      TechnitiumProtection.off => cs.error,
    };

    final IconData icon = switch (state) {
      TechnitiumProtection.on => Icons.shield_rounded,
      TechnitiumProtection.paused => Icons.pause_circle_outline_rounded,
      TechnitiumProtection.off => Icons.shield_outlined,
    };

    final String title = switch (state) {
      TechnitiumProtection.on => 'Protection is on',
      TechnitiumProtection.paused => 'Protection is paused',
      TechnitiumProtection.off => 'Protection is off',
    };

    final DateTime? pausedUntil = status.pausedUntil;

    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (pausedUntil != null &&
                          state == TechnitiumProtection.paused)
                        Row(
                          children: <Widget>[
                            Text(
                              'Resumes in ',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            TechnitiumCountdown(
                              until: pausedUntil,
                              onDone: onPauseEnded,
                              now: now,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          state == TechnitiumProtection.on
                              ? 'Blocking ads & trackers'
                              : 'DNS blocking disabled',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                if (state == TechnitiumProtection.on)
                  Builder(
                    builder: (BuildContext ctx) => FilledButton.tonalIcon(
                      onPressed: busy ? null : () => _showPauseMenu(ctx),
                      icon: const Icon(Icons.pause_rounded, size: 18),
                      label: const Text('Pause'),
                    ),
                  )
                else
                  FilledButton.icon(
                    onPressed: busy ? null : () => onSet(enabled: true),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Resume'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
