import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';

import 'models/nzbget_group.dart';
import 'models/nzbget_status.dart';
import 'nzbget_add_sheet.dart';
import 'nzbget_api.dart';
import 'nzbget_providers.dart';
import 'nzbget_speed_dialog.dart';

/// '2.5 MB/s' from a bytes-per-second rate.
String nzbgetFmtRate(int bytesPerSec) {
  if (bytesPerSec >= 1024 * 1024) {
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }
  if (bytesPerSec >= 1024) {
    return '${(bytesPerSec / 1024).toStringAsFixed(0)} KB/s';
  }
  return '$bytesPerSec B/s';
}

/// Human label for a group status.
String nzbgetStatusLabel(String status) => switch (status) {
      'DOWNLOADING' => 'Downloading',
      'QUEUED' => 'Queued',
      'PAUSED' => 'Paused',
      'FETCHING' => 'Fetching',
      _ when status.startsWith('PP_') ||
              status == 'UNPACKING' ||
              status == 'MOVING' ||
              status == 'VERIFYING_SOURCES' ||
              status == 'VERIFYING_REPAIRED' ||
              status == 'REPAIRING' ||
              status == 'RENAMING' ||
              status == 'LOADING_PARS' ||
              status == 'EXECUTING_SCRIPT' =>
        'Processing',
      '' => 'Queued',
      _ => status[0] + status.substring(1).toLowerCase(),
    };

class NzbgetQueueTab extends ConsumerWidget {
  const NzbgetQueueTab({required this.instance, super.key});

  final Instance instance;

  void _refresh(WidgetRef ref) {
    ref.invalidate(nzbgetQueueProvider(instance));
    ref.invalidate(nzbgetStatusProvider(instance));
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(NzbgetApi api) action,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final NzbgetApi api =
          await ref.read(nzbgetApiProvider(instance).future);
      await action(api);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Action failed: $e')));
    } finally {
      if (context.mounted) {
        _refresh(ref);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<NzbgetGroup>> queue =
        ref.watch(nzbgetQueueProvider(instance));
    return AsyncValueView<List<NzbgetGroup>>(
      value: queue,
      onRetry: () => _refresh(ref),
      data: (List<NzbgetGroup> groups) {
        final Widget summary = _QueueSummary(
          instance: instance,
          onPauseResume: (bool paused) => _run(
            context,
            ref,
            (NzbgetApi api) => paused ? api.resumeAll() : api.pauseAll(),
          ),
          onSpeedLimit: () async {
            final int? kb = await showNzbgetSpeedDialog(context);
            if (kb != null && context.mounted) {
              await _run(context, ref, (NzbgetApi api) => api.setSpeedLimit(kb));
            }
          },
          onAdd: () => showNzbgetAddSheet(context, instance),
        );
        if (groups.isEmpty) {
          return EasyRefresh(
            header: const ClassicHeader(),
            onRefresh: () async => _refresh(ref),
            child: ListView(
              padding: Insets.page,
              children: <Widget>[
                summary,
                const SizedBox(height: Insets.xl),
                const EmptyView(
                  icon: Icons.download_done_outlined,
                  title: 'Queue is empty',
                  message: 'Nothing downloading right now.',
                ),
              ],
            ),
          );
        }
        // ReorderableListView owns the scrolling; the summary rides as the
        // header. Drag handles are explicit so taps open the action sheet.
        return ReorderableListView.builder(
          padding: Insets.page,
          buildDefaultDragHandles: false,
          header: Padding(
            padding: const EdgeInsets.only(bottom: Insets.md),
            child: summary,
          ),
          itemCount: groups.length,
          onReorder: (int oldIndex, int newIndex) {
            if (newIndex > oldIndex) {
              newIndex -= 1;
            }
            final int offset = newIndex - oldIndex;
            if (offset == 0) {
              return;
            }
            final NzbgetGroup moved = groups[oldIndex];
            _run(
              context,
              ref,
              (NzbgetApi api) => api.moveOffset(moved.nzbId, offset),
            );
          },
          itemBuilder: (BuildContext context, int index) {
            final NzbgetGroup group = groups[index];
            return Padding(
              key: ValueKey<int>(group.nzbId),
              padding: const EdgeInsets.only(bottom: Insets.sm),
              child: _GroupCard(
                group: group,
                dragIndex: index,
                onTap: () => _showGroupSheet(context, ref, group),
              ),
            );
          },
        );
      },
    );
  }

  void _showGroupSheet(BuildContext context, WidgetRef ref, NzbgetGroup group) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              title: Text(
                group.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              subtitle: Text(nzbgetStatusLabel(group.status)),
            ),
            ListTile(
              leading: Icon(group.isPaused ? Icons.play_arrow : Icons.pause),
              title: Text(group.isPaused ? 'Resume' : 'Pause'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _run(
                  context,
                  ref,
                  (NzbgetApi api) => group.isPaused
                      ? api.resumeItems(<int>[group.nzbId])
                      : api.pauseItems(<int>[group.nzbId]),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.low_priority),
              title: const Text('Priority'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showPriorityPicker(context, ref, group);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('Category'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showCategoryPicker(context, ref, group);
              },
            ),
            ListTile(
              leading: const Icon(Icons.vertical_align_top),
              title: const Text('Move to top'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _run(
                  context,
                  ref,
                  (NzbgetApi api) => api.moveTop(<int>[group.nzbId]),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.vertical_align_bottom),
              title: const Text('Move to bottom'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _run(
                  context,
                  ref,
                  (NzbgetApi api) => api.moveBottom(<int>[group.nzbId]),
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(sheetContext).colorScheme.error,
              ),
              title: const Text('Delete'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final bool? confirmed = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext dialogContext) => AlertDialog(
                    title: const Text('Delete download?'),
                    content: Text(group.name),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if ((confirmed ?? false) && context.mounted) {
                  await _run(
                    context,
                    ref,
                    (NzbgetApi api) => api.deleteItems(<int>[group.nzbId]),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPriorityPicker(
    BuildContext context,
    WidgetRef ref,
    NzbgetGroup group,
  ) {
    const List<(String, int)> priorities = <(String, int)>[
      ('Very low', -100),
      ('Low', -50),
      ('Normal', 0),
      ('High', 50),
      ('Very high', 100),
      ('Force', 900),
    ];
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final (String label, int value) in priorities)
              ListTile(
                title: Text(label),
                trailing:
                    group.priority == value ? const Icon(Icons.check) : null,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _run(
                    context,
                    ref,
                    (NzbgetApi api) =>
                        api.setPriority(<int>[group.nzbId], value),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showCategoryPicker(
    BuildContext context,
    WidgetRef ref,
    NzbgetGroup group,
  ) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Consumer(
          builder: (BuildContext context, WidgetRef sheetRef, Widget? _) {
            final AsyncValue<List<String>> categories =
                sheetRef.watch(nzbgetCategoriesProvider(instance));
            return categories.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(Insets.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (Object e, StackTrace _) => Padding(
                padding: const EdgeInsets.all(Insets.xl),
                child: Text('Could not load categories: $e'),
              ),
              data: (List<String> names) => Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (names.isEmpty)
                    const ListTile(title: Text('No categories configured')),
                  for (final String name in names)
                    ListTile(
                      title: Text(name),
                      trailing: group.category == name
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _run(
                          context,
                          ref,
                          (NzbgetApi api) =>
                              api.setCategory(<int>[group.nzbId], name),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _QueueSummary extends ConsumerWidget {
  const _QueueSummary({
    required this.instance,
    required this.onPauseResume,
    required this.onSpeedLimit,
    required this.onAdd,
  });

  final Instance instance;
  final void Function(bool paused) onPauseResume;
  final VoidCallback onSpeedLimit;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final NzbgetStatus status =
        ref.watch(nzbgetStatusProvider(instance)).value ??
            const NzbgetStatus();
    final bool paused = status.downloadPaused;
    final Color accent = paused ? cs.outline : cs.primary;

    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              paused ? Icons.pause_rounded : Icons.download_rounded,
              color: accent,
            ),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  nzbgetFmtRate(status.downloadRate),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
                InkWell(
                  onTap: onSpeedLimit,
                  child: Text(
                    'Limit: ${speedLimitLabel(status.downloadLimit ~/ 1024)}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Add NZB',
            onPressed: onAdd,
            icon: const Icon(Icons.add),
          ),
          const SizedBox(width: Insets.xs),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              backgroundColor: cs.secondaryContainer,
              foregroundColor: cs.onSecondaryContainer,
            ),
            icon: Icon(paused ? Icons.play_arrow : Icons.pause),
            label: Text(paused ? 'Resume' : 'Pause'),
            onPressed: () => onPauseResume(paused),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.dragIndex,
    required this.onTap,
  });

  final NzbgetGroup group;
  final int dragIndex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final String size = group.fileSizeMb >= 1024
        ? '${(group.fileSizeMb / 1024).toStringAsFixed(1)} GB'
        : '${group.fileSizeMb} MB';
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${nzbgetStatusLabel(group.status)} - $size'
                      '${group.category.isEmpty ? '' : ' - ${group.category}'}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: Insets.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicatorM3E(
                        size: LinearProgressM3ESize.s,
                        shape: ProgressM3EShape.flat,
                        value: group.progress,
                        activeColor:
                            group.isPaused ? cs.outline : cs.primary,
                        trackColor: cs.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Insets.sm),
              ReorderableDragStartListener(
                index: dragIndex,
                child: Icon(Icons.drag_handle, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
