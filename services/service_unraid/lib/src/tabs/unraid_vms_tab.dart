import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/unraid_models.dart';
import '../unraid_providers.dart';
import '../widgets/unraid_common.dart';

/// The server's virtual machines.
///
/// Read only for now. The API has start, stop, pause, resume, reboot and
/// force stop, and they are the obvious next step, but nothing available to
/// test against runs a VM: this module was built against a virtual machine
/// itself, which cannot nest another. Shipping buttons nobody has watched
/// work is worse than shipping the list first.
class UnraidVmsTab extends ConsumerWidget {
  const UnraidVmsTab({required this.instance, super.key});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<UnraidVmList> vms = ref.watch(unraidVmsProvider(instance));

    return UnraidTabScaffold(
      onRefresh: () => ref.invalidate(unraidVmsProvider(instance)),
      children: <Widget>[
        AsyncValueView<UnraidVmList>(
          value: vms,
          onRetry: () => ref.invalidate(unraidVmsProvider(instance)),
          loading: const UnraidCardPlaceholder(height: 160),
          data: (UnraidVmList value) => _VmBody(list: value),
        ),
      ],
    );
  }
}

class _VmBody extends StatelessWidget {
  const _VmBody({required this.list});

  final UnraidVmList list;

  @override
  Widget build(BuildContext context) {
    // Unraid ships with virtualisation off, so this is the ordinary case for
    // most servers rather than something to report as broken.
    if (!list.enabled) {
      return const EmptyView(
        icon: Icons.desktop_access_disabled_outlined,
        title: 'Virtual machines are off',
        message: 'This server has no VM manager running. Turn it on under '
            'Settings, VM Manager, to see virtual machines here.',
      );
    }
    if (list.vms.isEmpty) {
      return const EmptyView(
        icon: Icons.desktop_windows_outlined,
        title: 'No virtual machines',
        message: 'The VM manager is on, but no machines are defined yet.',
      );
    }

    final ColorScheme cs = Theme.of(context).colorScheme;
    final int running = list.vms.where((UnraidVm v) => v.isRunning).length;
    final List<UnraidVm> sorted = <UnraidVm>[...list.vms]
      ..sort((UnraidVm a, UnraidVm b) {
        if (a.hasCrashed != b.hasCrashed) return a.hasCrashed ? -1 : 1;
        if (a.isRunning != b.isRunning) return a.isRunning ? -1 : 1;
        return a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            );
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        UnraidSectionHeader(
          title: 'Virtual machines',
          trailing: '$running of ${list.vms.length} running',
        ),
        const SizedBox(height: Insets.sm),
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
          child: Column(
            children: <Widget>[
              for (int i = 0; i < sorted.length; i++) ...<Widget>[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: Insets.lg,
                    color: cs.outlineVariant,
                  ),
                _VmRow(vm: sorted[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _VmRow extends StatelessWidget {
  const _VmRow({required this.vm});

  final UnraidVm vm;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    // A crashed machine reads as stopped from its state alone, so it gets its
    // own glyph rather than only a colour.
    final (IconData icon, Color color) = vm.hasCrashed
        ? (Icons.error_outline, cs.error)
        : vm.isPaused
            ? (Icons.pause_rounded, cs.tertiary)
            : vm.isRunning
                ? (Icons.play_arrow_rounded, unraidOkGreen(cs))
                : (Icons.stop_rounded, cs.outline);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.md,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  vm.displayName,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: Insets.xxs),
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
    );
  }
}
