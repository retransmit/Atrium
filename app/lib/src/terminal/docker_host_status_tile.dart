import 'package:clock/clock.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../health_providers.dart';
import 'ssh_host_status.dart';
import 'terminal_hub.dart';

/// Says why a Docker host's dot is the colour it is, for its long-press
/// sheet. Docker trouble is deliberately not part of it; see the note.
class DockerHostStatusTile extends ConsumerWidget {
  const DockerHostStatusTile({required this.host, super.key});

  final Instance host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Health health =
        ref.watch(instanceHealthProvider(host.id)).value ?? Health.unknown;
    final SshLoginRecord? lastLogin = ref.watch(
      sshLoginRecordsProvider
          .select((Map<String, SshLoginRecord> m) => m[host.id]),
    );
    final HostSession session = ref.watch(terminalHubProvider).session(host.id);

    return ListenableBuilder(
      listenable: session,
      builder: (BuildContext context, Widget? _) {
        final bool connected = session.status == SshStatus.connected;
        final Health shown = connected ? Health.ok : health;
        final bool refused = lastLogin != null && !lastLogin.ok;
        final (IconData icon, Color color) = switch (shown) {
          Health.ok => (Icons.check_circle_outline, cs.primary),
          Health.warning => (Icons.warning_amber_rounded, cs.tertiary),
          Health.error => (Icons.error_outline, cs.error),
          Health.unknown => (Icons.help_outline, cs.outline),
        };
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.lg,
            0,
            Insets.lg,
            Insets.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: color),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      describeDockerHost(
                        health: shown,
                        session: session.status,
                        endpoint: session.endpoint,
                        lastLogin: lastLogin,
                        now: clock.now(),
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (refused &&
                        !connected &&
                        lastLogin.message != null) ...<Widget>[
                      const SizedBox(height: Insets.xxs),
                      Text(
                        lastLogin.message!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.tertiary),
                      ),
                    ],
                    const SizedBox(height: Insets.xxs),
                    Text(
                      'This covers the SSH connection only. Docker problems '
                      '(not installed, needs sudo) show on each service\'s '
                      'container shell instead.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
