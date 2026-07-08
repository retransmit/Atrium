import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/prowlarr_system.dart';
import 'prowlarr_api.dart';
import 'prowlarr_providers.dart';

/// System tab: health, scheduled tasks (run now), backups (create / delete),
/// and a status summary.
class ProwlarrSystemTab extends ConsumerWidget {
  const ProwlarrSystemTab({required this.instance, super.key});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        ref
          ..invalidate(prowlarrHealthProvider(instance))
          ..invalidate(prowlarrTasksProvider(instance))
          ..invalidate(prowlarrBackupsProvider(instance))
          ..invalidate(prowlarrSystemStatusProvider(instance));
      },
      child: ListView(
        padding: Insets.page,
        children: <Widget>[
          _HealthSection(instance: instance),
          const SizedBox(height: Insets.md),
          _TasksSection(instance: instance),
          const SizedBox(height: Insets.md),
          _BackupsSection(instance: instance),
          const SizedBox(height: Insets.md),
          _StatusSection(instance: instance),
          const SizedBox(height: Insets.xl),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: Insets.sm),
          child,
        ],
      ),
    );
  }
}

class _HealthSection extends ConsumerWidget {
  const _HealthSection({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final AsyncValue<List<ProwlarrHealth>> health =
        ref.watch(prowlarrHealthProvider(instance));
    return _SectionCard(
      title: 'Health',
      child: health.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: Insets.md),
          child: Center(child: ExpressiveProgressIndicator()),
        ),
        error: (Object e, _) => _StatusRow(
          icon: Icons.error_outline,
          color: cs.error,
          text: _msg(e),
        ),
        data: (List<ProwlarrHealth> list) {
          if (list.isEmpty) {
            return _StatusRow(
              icon: Icons.check_circle,
              color: cs.tertiary,
              text: 'All healthy',
              pill: 'OK',
            );
          }
          return Column(
            children: <Widget>[
              for (int i = 0; i < list.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(height: Insets.sm),
                _StatusRow(
                  icon: _healthIcon(list[i].type),
                  color: _healthColor(cs, list[i].type),
                  text: list[i].message,
                  subtext: list[i].source,
                  pill: _healthPill(list[i].type),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  IconData _healthIcon(String type) => switch (type.toLowerCase()) {
        'error' => Icons.error_outline,
        'warning' => Icons.warning_amber,
        _ => Icons.info_outline,
      };

  Color _healthColor(ColorScheme cs, String type) =>
      switch (type.toLowerCase()) {
        'error' => cs.error,
        'warning' => cs.error,
        _ => cs.primary,
      };

  String? _healthPill(String type) => switch (type.toLowerCase()) {
        'error' => 'Error',
        'warning' => 'Warning',
        'notice' => 'Notice',
        _ => null,
      };
}

class _TasksSection extends ConsumerWidget {
  const _TasksSection({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ProwlarrSystemTask>> tasks =
        ref.watch(prowlarrTasksProvider(instance));
    return _SectionCard(
      title: 'Tasks',
      child: tasks.when(
        loading: () => const SizedBox.shrink(),
        error: (Object e, _) => _StatusRow(
          icon: Icons.error_outline,
          color: Theme.of(context).colorScheme.error,
          text: _msg(e),
        ),
        data: (List<ProwlarrSystemTask> list) => Column(
          children: <Widget>[
            for (int i = 0; i < list.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: Insets.sm),
              _TaskTile(instance: instance, task: list[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _TaskTile extends ConsumerStatefulWidget {
  const _TaskTile({required this.instance, required this.task});

  final Instance instance;
  final ProwlarrSystemTask task;

  @override
  ConsumerState<_TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends ConsumerState<_TaskTile> {
  bool _running = false;

  Future<void> _run() async {
    setState(() => _running = true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final ProwlarrApi api =
          await ref.read(prowlarrApiProvider(widget.instance).future);
      await api.runCommand(widget.task.taskName);
      messenger.showSnackBar(
        SnackBar(content: Text('Started ${widget.task.name}')),
      );
      ref.invalidate(prowlarrTasksProvider(widget.instance));
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: ${_msg(e)}')));
    } finally {
      if (mounted) {
        setState(() => _running = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final ProwlarrSystemTask t = widget.task;
    return Row(
      children: <Widget>[
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.schedule, size: 20, color: cs.primary),
        ),
        const SizedBox(width: Insets.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                t.name,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                <String>[
                  'every ${_interval(t.interval)}',
                  if (t.lastExecution != null)
                    'last ${_relativeTime(t.lastExecution)}',
                ].join(' • '),
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        _running
            ? const SizedBox(
                width: 20,
                height: 20,
                child: ExpressiveProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                tooltip: 'Run now',
                icon: const Icon(Icons.play_arrow),
                onPressed: _run,
              ),
      ],
    );
  }

  String _interval(int minutes) {
    if (minutes <= 0) {
      return 'manual';
    }
    if (minutes < 60) {
      return '${minutes}m';
    }
    if (minutes % 60 == 0) {
      return '${minutes ~/ 60}h';
    }
    return '${(minutes / 60).toStringAsFixed(1)}h';
  }
}

class _BackupsSection extends ConsumerWidget {
  const _BackupsSection({required this.instance});

  final Instance instance;

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final ProwlarrApi api =
          await ref.read(prowlarrApiProvider(instance).future);
      await api.runCommand('Backup');
      messenger.showSnackBar(
        const SnackBar(content: Text('Backup started; pull to refresh')),
      );
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: ${_msg(e)}')));
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ProwlarrBackup backup,
  ) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete backup?'),
        content: Text(backup.name),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) {
      return;
    }
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final ProwlarrApi api =
          await ref.read(prowlarrApiProvider(instance).future);
      await api.deleteBackup(backup.id);
      ref.invalidate(prowlarrBackupsProvider(instance));
      messenger.showSnackBar(const SnackBar(content: Text('Backup deleted')));
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: ${_msg(e)}')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AsyncValue<List<ProwlarrBackup>> backups =
        ref.watch(prowlarrBackupsProvider(instance));
    return _SectionCard(
      title: 'Backups',
      action: TextButton.icon(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Create'),
      ),
      child: backups.when(
        loading: () => const SizedBox.shrink(),
        error: (Object e, _) => _StatusRow(
          icon: Icons.error_outline,
          color: cs.error,
          text: _msg(e),
        ),
        data: (List<ProwlarrBackup> list) {
          if (list.isEmpty) {
            return Text(
              'No backups yet.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            );
          }
          return Column(
            children: <Widget>[
              for (int i = 0; i < list.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(height: Insets.sm),
                _BackupRow(
                  backup: list[i],
                  onDelete: () => _delete(context, ref, list[i]),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _BackupRow extends StatelessWidget {
  const _BackupRow({required this.backup, required this.onDelete});

  final ProwlarrBackup backup;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Row(
      children: <Widget>[
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.secondary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.archive_outlined, size: 20, color: cs.secondary),
        ),
        const SizedBox(width: Insets.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                backup.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                <String>[
                  if (backup.type != null && backup.type!.isNotEmpty)
                    backup.type!,
                  if (backup.time != null) _relativeTime(backup.time),
                ].join(' • '),
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Delete',
          icon: Icon(Icons.delete_outline, color: cs.error),
          onPressed: onDelete,
        ),
      ],
    );
  }
}

class _StatusSection extends ConsumerWidget {
  const _StatusSection({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final AsyncValue<ProwlarrSystemStatus> status =
        ref.watch(prowlarrSystemStatusProvider(instance));
    return _SectionCard(
      title: 'Status',
      child: status.when(
        loading: () => const SizedBox.shrink(),
        error: (Object e, _) => _StatusRow(
          icon: Icons.error_outline,
          color: cs.error,
          text: _msg(e),
        ),
        data: (ProwlarrSystemStatus s) {
          final String author = _authorText(s.packageAuthor);
          final String pkg = <String>[
            if (s.packageVersion != null && s.packageVersion!.isNotEmpty)
              s.packageVersion!,
            if (author.isNotEmpty) 'by $author',
          ].join(' ');
          final List<(String, String?)> rows = <(String, String?)>[
            ('Version', s.version),
            ('Package', pkg),
            ('.NET', s.runtimeVersion),
            ('Docker', s.isDocker ? 'Yes' : 'No'),
            (
              'Database',
              <String?>[s.databaseType, s.databaseVersion]
                  .where((String? v) => v != null && v.isNotEmpty)
                  .join(' '),
            ),
            ('DB migration', s.migrationVersion?.toString()),
            (
              'OS',
              <String?>[s.osName, s.osVersion]
                  .where((String? v) => v != null && v.isNotEmpty)
                  .join(' '),
            ),
            ('AppData', s.appData),
            ('Startup', s.startupPath),
            ('Mode', s.mode),
            ('Uptime', _uptime(s.startTime)),
          ];
          return Column(
            children: <Widget>[
              for (final (String label, String? value) in rows)
                if (value != null && value.isNotEmpty)
                  _KeyValueRow(label: label, value: value),
            ],
          );
        },
      ),
    );
  }
}

/// A tonal row used across the system sections: a color-coded leading badge,
/// a primary line, an optional sub line and an optional status pill.
class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.color,
    required this.text,
    this.subtext,
    this.pill,
  });

  final IconData icon;
  final Color color;
  final String text;
  final String? subtext;
  final String? pill;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: Insets.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(text, style: theme.textTheme.bodyMedium),
              if (subtext != null && subtext!.isNotEmpty) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  subtext!,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
        if (pill != null) ...<Widget>[
          const SizedBox(width: Insets.sm),
          _StatPill(label: pill!, color: color),
        ],
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

String _msg(Object e) {
  if (e is NetworkException && e.message.isNotEmpty) {
    return e.message;
  }
  return 'request failed';
}

/// Package author can be a markdown link like `[linuxserver.io](https://...)`;
/// show just the display text.
String _authorText(String? author) {
  if (author == null || author.isEmpty) {
    return '';
  }
  final RegExpMatch? m = RegExp(r'\[([^\]]+)\]').firstMatch(author);
  return m != null ? m.group(1)! : author;
}

String _uptime(DateTime? start) {
  if (start == null) {
    return '';
  }
  final Duration d = DateTime.now().difference(start.toLocal());
  if (d.isNegative) {
    return '';
  }
  final int days = d.inDays;
  final int hours = d.inHours % 24;
  final int mins = d.inMinutes % 60;
  if (days > 0) {
    return '${days}d ${hours}h';
  }
  if (hours > 0) {
    return '${hours}h ${mins}m';
  }
  return '${mins}m';
}

String _relativeTime(DateTime? date) {
  if (date == null) {
    return '';
  }
  final DateTime local = date.toLocal();
  final Duration diff = DateTime.now().difference(local);
  if (diff.isNegative) {
    final Duration ahead = local.difference(DateTime.now());
    if (ahead.inMinutes < 60) {
      return 'in ${ahead.inMinutes}m';
    }
    if (ahead.inHours < 24) {
      return 'in ${ahead.inHours}h';
    }
    return 'in ${ahead.inDays}d';
  }
  if (diff.inSeconds < 60) {
    return 'just now';
  }
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes}m ago';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours}h ago';
  }
  return '${diff.inDays}d ago';
}
