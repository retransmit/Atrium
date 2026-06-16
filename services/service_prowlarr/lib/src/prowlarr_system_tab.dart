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
          _TasksSection(instance: instance),
          _BackupsSection(instance: instance),
          _StatusSection(instance: instance),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: Insets.lg, bottom: Insets.sm),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          if (action != null) action!,
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
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<ProwlarrHealth>> health =
        ref.watch(prowlarrHealthProvider(instance));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _SectionHeader('Health'),
        health.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(Insets.md),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (Object e, _) => _MessageCard(
            icon: Icons.error_outline,
            color: theme.colorScheme.error,
            text: _msg(e),
          ),
          data: (List<ProwlarrHealth> list) {
            if (list.isEmpty) {
              return const _MessageCard(
                icon: Icons.check_circle,
                color: Color(0xFF22C55E),
                text: 'All healthy',
              );
            }
            return Column(
              children: <Widget>[
                for (final ProwlarrHealth h in list)
                  _MessageCard(
                    icon: _healthIcon(h.type),
                    color: _healthColor(theme, h.type),
                    text: h.message,
                    subtext: h.source,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  IconData _healthIcon(String type) => switch (type.toLowerCase()) {
        'error' => Icons.error_outline,
        'warning' => Icons.warning_amber,
        _ => Icons.info_outline,
      };

  Color _healthColor(ThemeData theme, String type) =>
      switch (type.toLowerCase()) {
        'error' => theme.colorScheme.error,
        'warning' => const Color(0xFFF59E0B),
        _ => theme.colorScheme.primary,
      };
}

class _TasksSection extends ConsumerWidget {
  const _TasksSection({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ProwlarrSystemTask>> tasks =
        ref.watch(prowlarrTasksProvider(instance));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _SectionHeader('Tasks'),
        tasks.when(
          loading: () => const SizedBox.shrink(),
          error: (Object e, _) => _MessageCard(
            icon: Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
            text: _msg(e),
          ),
          data: (List<ProwlarrSystemTask> list) => Column(
            children: <Widget>[
              for (final ProwlarrSystemTask t in list)
                _TaskTile(instance: instance, task: t),
            ],
          ),
        ),
      ],
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
    final ProwlarrSystemTask t = widget.task;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(t.name),
      subtitle: Text(
        <String>[
          'every ${_interval(t.interval)}',
          if (t.lastExecution != null) 'last ${_relativeTime(t.lastExecution)}',
        ].join(' • '),
      ),
      trailing: _running
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              tooltip: 'Run now',
              icon: const Icon(Icons.play_arrow),
              onPressed: _run,
            ),
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
    final AsyncValue<List<ProwlarrBackup>> backups =
        ref.watch(prowlarrBackupsProvider(instance));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SectionHeader(
          'Backups',
          action: TextButton.icon(
            onPressed: () => _create(context, ref),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create'),
          ),
        ),
        backups.when(
          loading: () => const SizedBox.shrink(),
          error: (Object e, _) => _MessageCard(
            icon: Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
            text: _msg(e),
          ),
          data: (List<ProwlarrBackup> list) {
            if (list.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: Insets.sm),
                child: Text('No backups yet.'),
              );
            }
            return Column(
              children: <Widget>[
                for (final ProwlarrBackup b in list)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.archive_outlined),
                    title: Text(b.name),
                    subtitle: Text(
                      <String>[
                        if (b.type != null && b.type!.isNotEmpty) b.type!,
                        if (b.time != null) _relativeTime(b.time),
                      ].join(' • '),
                    ),
                    trailing: IconButton(
                      tooltip: 'Delete',
                      icon: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: () => _delete(context, ref, b),
                    ),
                  ),
              ],
            );
          },
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
    final AsyncValue<ProwlarrSystemStatus> status =
        ref.watch(prowlarrSystemStatusProvider(instance));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _SectionHeader('Status'),
        status.when(
          loading: () => const SizedBox.shrink(),
          error: (Object e, _) => _MessageCard(
            icon: Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
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
        const SizedBox(height: Insets.lg),
      ],
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.color,
    required this.text,
    this.subtext,
  });

  final IconData icon;
  final Color color;
  final String text;
  final String? subtext;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: Insets.sm),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(text),
        subtitle: (subtext != null && subtext!.isNotEmpty)
            ? Text(
                subtext!,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline),
              )
            : null,
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
                  ?.copyWith(color: theme.colorScheme.outline),
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
