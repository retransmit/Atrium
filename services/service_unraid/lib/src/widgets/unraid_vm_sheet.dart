import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/unraid_models.dart';
import '../unraid_client.dart';
import '../unraid_providers.dart';
import 'unraid_common.dart';

/// Everything that can be done to one virtual machine.
///
/// Deliberately short. The API answers with exactly four fields per machine,
/// id, name, state and uuid, and offers no VNC port, no memory or vCPU count
/// and no disk size, so there is no specification to lay out here. What it
/// does offer is seven lifecycle mutations, and those are the point of this
/// sheet.
Future<void> showUnraidVmSheet(
  BuildContext context, {
  required Instance instance,
  required UnraidVm vm,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.42,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (BuildContext context, ScrollController controller) => _VmSheet(
        instance: instance,
        vm: vm,
        controller: controller,
      ),
    ),
  );
}

class _VmSheet extends ConsumerStatefulWidget {
  const _VmSheet({
    required this.instance,
    required this.vm,
    required this.controller,
  });

  final Instance instance;
  final UnraidVm vm;
  final ScrollController controller;

  @override
  ConsumerState<_VmSheet> createState() => _VmSheetState();
}

class _VmSheetState extends ConsumerState<_VmSheet> {
  bool _busy = false;

  /// Runs one lifecycle action and refreshes the list behind the sheet.
  ///
  /// These mutations answer with a bare boolean rather than the machine in its
  /// new state, so unlike the container ones there is nothing to show straight
  /// back. libvirt has also not finished the transition by the time the call
  /// returns, so refetching immediately reads the old state and looks like the
  /// action did nothing. The spinner is therefore held over a short settle
  /// before the refetch.
  Future<void> _run(Future<bool> Function(UnraidClient client) action) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final UnraidClient client =
          await ref.read(unraidClientProvider(widget.instance).future);
      await action(client);
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      ref.invalidate(unraidVmsProvider(widget.instance));
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

  /// Guards the two actions that do not ask the guest first.
  Future<bool> _confirm(String title, String message, String verb) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(verb),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    // Read the machine back out of the polled list so the sheet follows the
    // state along rather than freezing on whatever it was opened with.
    final List<UnraidVm> all =
        ref.watch(unraidVmsProvider(widget.instance)).value?.vms ??
            const <UnraidVm>[];
    final UnraidVm vm = all.firstWhere(
      (UnraidVm e) => e.id == widget.vm.id,
      orElse: () => widget.vm,
    );

    final (IconData icon, Color color) = vm.hasCrashed
        ? (Icons.error_outline, cs.error)
        : vm.isPaused
            ? (Icons.pause_rounded, cs.tertiary)
            : vm.isRunning
                ? (Icons.play_arrow_rounded, unraidOkGreen(cs))
                : (Icons.stop_rounded, cs.outline);

    return ListView(
      controller: widget.controller,
      padding: const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.xl),
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
                    vm.displayName,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    vm.stateLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: vm.hasCrashed ? cs.error : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.lg),
        _VmActions(vm: vm, busy: _busy, run: _run, confirm: _confirm),
        if ((vm.uuid ?? '').isNotEmpty) ...<Widget>[
          const SizedBox(height: Insets.lg),
          Text(
            'UUID',
            style:
                theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: Insets.xxs),
          SelectableText(
            vm.uuid!,
            style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurface),
          ),
        ],
      ],
    );
  }
}

/// The lifecycle buttons, offering only what the current state allows.
class _VmActions extends StatelessWidget {
  const _VmActions({
    required this.vm,
    required this.busy,
    required this.run,
    required this.confirm,
  });

  final UnraidVm vm;
  final bool busy;
  final Future<void> Function(Future<bool> Function(UnraidClient)) run;
  final Future<bool> Function(String title, String message, String verb)
      confirm;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

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

    // A machine on its way down is between states: starting it is refused and
    // stopping it again does nothing, so it is left alone until it lands.
    if (vm.isBusy) {
      return Text(
        'This machine is shutting down. Its actions come back once it has '
        'stopped.',
        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      );
    }

    final List<Widget> primary = <Widget>[
      if (vm.isRunning) ...<Widget>[
        FilledButton.tonalIcon(
          onPressed: () => run((UnraidClient c) => c.stopVm(vm.id)),
          icon: const Icon(Icons.stop_rounded),
          label: const Text('Shut down'),
        ),
        OutlinedButton.icon(
          onPressed: () => run((UnraidClient c) => c.pauseVm(vm.id)),
          icon: const Icon(Icons.pause_rounded),
          label: const Text('Pause'),
        ),
      ] else if (vm.isPaused) ...<Widget>[
        FilledButton.icon(
          onPressed: () => run((UnraidClient c) => c.resumeVm(vm.id)),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Resume'),
        ),
        OutlinedButton.icon(
          onPressed: () => run((UnraidClient c) => c.stopVm(vm.id)),
          icon: const Icon(Icons.stop_rounded),
          label: const Text('Shut down'),
        ),
      ] else
        FilledButton.icon(
          onPressed: () => run((UnraidClient c) => c.startVm(vm.id)),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Start'),
        ),
    ];

    // Rebooting asks the guest; the other two do not. Keeping all three off the
    // main row means the destructive pair is never sitting next to the button
    // someone came here to press.
    final List<Widget> secondary = <Widget>[
      if (vm.isRunning)
        TextButton.icon(
          onPressed: () => run((UnraidClient c) => c.rebootVm(vm.id)),
          icon: const Icon(Icons.restart_alt_rounded, size: 18),
          label: const Text('Reboot'),
        ),
      if (vm.isRunning || vm.isPaused || vm.hasCrashed)
        TextButton.icon(
          onPressed: () async {
            final bool ok = await confirm(
              'Force stop ${vm.displayName}?',
              'The machine is cut off immediately. Anything it has not '
                  'written to disk is lost, the same as pulling the power.',
              'Force stop',
            );
            if (ok) await run((UnraidClient c) => c.forceStopVm(vm.id));
          },
          icon: Icon(
            Icons.power_settings_new_rounded,
            size: 18,
            color: cs.error,
          ),
          label: Text('Force stop', style: TextStyle(color: cs.error)),
        ),
      if (vm.isRunning)
        TextButton.icon(
          onPressed: () async {
            final bool ok = await confirm(
              'Reset ${vm.displayName}?',
              'The machine restarts without being asked to shut down first. '
                  'Anything it has not written to disk is lost.',
              'Reset',
            );
            if (ok) await run((UnraidClient c) => c.resetVm(vm.id));
          },
          icon: Icon(Icons.bolt_rounded, size: 18, color: cs.error),
          label: Text('Reset', style: TextStyle(color: cs.error)),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            for (int i = 0; i < primary.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: Insets.sm),
              Expanded(child: primary[i]),
            ],
            if (primary.length == 1) const Spacer(),
          ],
        ),
        if (secondary.isNotEmpty) ...<Widget>[
          const SizedBox(height: Insets.xs),
          Wrap(spacing: Insets.xs, children: secondary),
        ],
      ],
    );
  }
}
