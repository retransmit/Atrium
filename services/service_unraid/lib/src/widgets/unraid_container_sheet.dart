import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/unraid_models.dart';
import '../unraid_client.dart';
import '../unraid_providers.dart';
import 'unraid_common.dart';

/// Everything about one container, and everything that can be done to it.
///
/// The row it opens from carries the one action people reach for most. This
/// carries the rest, which would not fit a list and do not belong one stray
/// tap away.
Future<void> showUnraidContainerSheet(
  BuildContext context, {
  required Instance instance,
  required UnraidContainer container,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (BuildContext context, ScrollController controller) =>
          _ContainerSheet(
        instance: instance,
        container: container,
        controller: controller,
      ),
    ),
  );
}

class _ContainerSheet extends ConsumerStatefulWidget {
  const _ContainerSheet({
    required this.instance,
    required this.container,
    required this.controller,
  });

  final Instance instance;
  final UnraidContainer container;
  final ScrollController controller;

  @override
  ConsumerState<_ContainerSheet> createState() => _ContainerSheetState();
}

class _ContainerSheetState extends ConsumerState<_ContainerSheet> {
  bool _busy = false;

  /// Runs one lifecycle action and refreshes the list behind the sheet.
  ///
  /// The reason a refusal gives is shown as it comes: an API key without the
  /// Docker permission is an ordinary way to have this set up, and "Action
  /// failed" would leave nothing to act on.
  Future<void> _run(
    Future<UnraidContainer> Function(UnraidClient client) action,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final UnraidClient client =
          await ref.read(unraidClientProvider(widget.instance).future);
      await action(client);
      if (!mounted) return;
      ref.invalidate(unraidContainersProvider(widget.instance));
    } on Object catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(e is NetworkException ? e.message : 'Action failed.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(String url) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final bool opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Could not open $url')));
      }
    } on Object {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open that link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    // Read the container back out of the list so the sheet follows what the
    // server says after an action, rather than the snapshot it opened with.
    final List<UnraidContainer> all =
        ref.watch(unraidContainersProvider(widget.instance)).value ??
            <UnraidContainer>[];
    final UnraidContainer c = all.firstWhere(
      (UnraidContainer e) => e.id == widget.container.id,
      orElse: () => widget.container,
    );

    final (IconData icon, Color color) = c.isUnhealthy
        ? (Icons.warning_amber_rounded, cs.error)
        : c.isPaused
            ? (Icons.pause_rounded, cs.tertiary)
            : c.isRunning
                ? (Icons.play_arrow_rounded, unraidOkGreen(cs))
                : (Icons.stop_rounded, cs.outline);

    final List<_Row> facts = <_Row>[
      if (c.status != null) _Row(Icons.schedule_rounded, 'Status', c.status!),
      if (c.createdAt != null)
        _Row(
          Icons.event_outlined,
          'Created',
          unraidAgo(c.createdAt!.toLocal()),
        ),
      for (final String m in c.portMappings)
        _Row(Icons.lan_outlined, 'Port', m),
      if (c.sizeRootFsBytes != null && c.sizeRootFsBytes! > 0)
        _Row(Icons.sd_storage_outlined, 'Size', c.sizeLabel),
      _Row(
        Icons.bolt_rounded,
        'Autostart',
        c.autoStart ? 'Starts with the array' : 'Off',
      ),
      if (c.command != null) _Row(Icons.terminal_rounded, 'Command', c.command!),
    ];

    final List<(IconData, String, String)> links =
        <(IconData, String, String)>[
      if ((c.webUiUrl ?? '').isNotEmpty)
        (Icons.open_in_new_rounded, 'Web interface', c.webUiUrl!),
      if ((c.projectUrl ?? '').isNotEmpty)
        (Icons.public_rounded, 'Project page', c.projectUrl!),
      if ((c.supportUrl ?? '').isNotEmpty)
        (Icons.forum_outlined, 'Support thread', c.supportUrl!),
      if ((c.registryUrl ?? '').isNotEmpty)
        (Icons.inventory_2_outlined, 'Registry', c.registryUrl!),
    ];

    return ListView(
      controller: widget.controller,
      padding: const EdgeInsets.fromLTRB(
        Insets.lg,
        0,
        Insets.lg,
        Insets.xl,
      ),
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    c.displayName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (c.imageName != null)
                    Text(
                      c.imageTag == null
                          ? c.imageName!
                          : '${c.imageName!}:${c.imageTag!}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.lg),
        _Actions(container: c, busy: _busy, run: _run),
        if (c.isOrphaned) ...<Widget>[
          const SizedBox(height: Insets.md),
          Text(
            'No Unraid template matches this container, which is normal for '
            'anything created outside the web UI. It is why there is no icon '
            'or web link for it.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: Insets.lg),
        for (final _Row r in facts) _FactLine(row: r),
        if (links.isNotEmpty) ...<Widget>[
          const SizedBox(height: Insets.md),
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.6)),
          for (final (IconData i, String label, String url) in links)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(i, size: 20, color: cs.onSurfaceVariant),
              title: Text(label, style: theme.textTheme.bodyMedium),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurfaceVariant,
              ),
              onTap: () => _open(url),
            ),
        ],
      ],
    );
  }
}

/// The lifecycle buttons, offering only what the current state allows.
class _Actions extends StatelessWidget {
  const _Actions({
    required this.container,
    required this.busy,
    required this.run,
  });

  final UnraidContainer container;
  final bool busy;
  final Future<void> Function(Future<UnraidContainer> Function(UnraidClient))
      run;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: Insets.md),
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // Pausing a stopped container does nothing, and resuming a running one is
    // meaningless, so each state offers only what it can actually do.
    final List<Widget> buttons = <Widget>[
      if (container.isRunning) ...<Widget>[
        FilledButton.tonalIcon(
          onPressed: () => run((UnraidClient c) => c.stopContainer(container.id)),
          icon: const Icon(Icons.stop_rounded),
          label: const Text('Stop'),
        ),
        OutlinedButton.icon(
          onPressed: () =>
              run((UnraidClient c) => c.pauseContainer(container.id)),
          icon: const Icon(Icons.pause_rounded),
          label: const Text('Pause'),
        ),
      ] else if (container.isPaused) ...<Widget>[
        FilledButton.icon(
          onPressed: () =>
              run((UnraidClient c) => c.unpauseContainer(container.id)),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Resume'),
        ),
        OutlinedButton.icon(
          onPressed: () => run((UnraidClient c) => c.stopContainer(container.id)),
          icon: const Icon(Icons.stop_rounded),
          label: const Text('Stop'),
        ),
      ] else
        FilledButton.icon(
          onPressed: () =>
              run((UnraidClient c) => c.startContainer(container.id)),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Start'),
        ),
    ];

    return Row(
      children: <Widget>[
        for (int i = 0; i < buttons.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: Insets.sm),
          Expanded(child: buttons[i]),
        ],
        if (buttons.length == 1) const Spacer(),
      ],
    );
  }
}

class _Row {
  const _Row(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;
}

class _FactLine extends StatelessWidget {
  const _FactLine({required this.row});

  final _Row row;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(row.icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: Insets.sm),
          SizedBox(
            width: 82,
            child: Text(
              row.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              row.value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
