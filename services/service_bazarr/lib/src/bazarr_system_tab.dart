import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bazarr_api.dart';
import 'bazarr_providers.dart';
import 'models/bazarr_models.dart';

/// The System tab: status, health, subtitle-provider status (with reset),
/// scheduled tasks (run now), backups (create / delete), and recent logs
/// (clear). All mutating actions are user-initiated.
class BazarrSystemTab extends ConsumerWidget {
  const BazarrSystemTab({required this.instance, super.key});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(bazarrSystemStatusProvider(instance));
        ref.invalidate(bazarrSystemHealthProvider(instance));
        ref.invalidate(bazarrProviderStatusesProvider(instance));
        ref.invalidate(bazarrSystemTasksProvider(instance));
        ref.invalidate(bazarrBackupsProvider(instance));
        ref.invalidate(bazarrLogsProvider(instance));
      },
      child: ListView(
        padding: Insets.page,
        children: <Widget>[
          _HealthSection(instance: instance),
          _StatusSection(instance: instance),
          _ProvidersSection(instance: instance),
          _TasksSection(instance: instance),
          _BackupsSection(instance: instance),
          _LogsSection(instance: instance),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(title, style: theme.textTheme.titleMedium),
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

Widget _kv(BuildContext context, String k, String v) {
  final ThemeData theme = Theme.of(context);
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 120,
          child: Text(
            k,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ),
        Expanded(child: Text(v, style: theme.textTheme.bodyMedium)),
      ],
    ),
  );
}

class _StatusSection extends ConsumerWidget {
  const _StatusSection({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BazarrSystemStatus? s =
        ref.watch(bazarrSystemStatusProvider(instance)).valueOrNull;
    if (s == null) {
      return const SizedBox.shrink();
    }
    return _Section(
      title: 'Status',
      child: Column(
        children: <Widget>[
          _kv(context, 'Bazarr', s.bazarrVersion),
          if (s.packageVersion.isNotEmpty)
            _kv(context, 'Package', s.packageVersion),
          if (s.sonarrVersion.isNotEmpty)
            _kv(context, 'Sonarr', s.sonarrVersion),
          if (s.radarrVersion.isNotEmpty)
            _kv(context, 'Radarr', s.radarrVersion),
          if (s.operatingSystem.isNotEmpty)
            _kv(context, 'OS', s.operatingSystem),
          if (s.pythonVersion.isNotEmpty)
            _kv(context, 'Python', s.pythonVersion),
          if (s.databaseEngine.isNotEmpty)
            _kv(context, 'Database', s.databaseEngine),
          if (s.cpuCores != null) _kv(context, 'CPU cores', '${s.cpuCores}'),
          if (s.timezone.isNotEmpty) _kv(context, 'Timezone', s.timezone),
          if (_uptime(s.startTime).isNotEmpty)
            _kv(context, 'Uptime', _uptime(s.startTime)),
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
    final List<BazarrHealthItem> issues =
        ref.watch(bazarrSystemHealthProvider(instance)).valueOrNull ??
            const <BazarrHealthItem>[];
    return _Section(
      title: 'Health',
      child: issues.isEmpty
          ? Row(
              children: <Widget>[
                Icon(Icons.check_circle, color: Colors.green.shade600, size: 18),
                const SizedBox(width: Insets.sm),
                Text('All healthy', style: theme.textTheme.bodyMedium),
              ],
            )
          : Column(
              children: <Widget>[
                for (final BazarrHealthItem h in issues)
                  Card(
                    margin: const EdgeInsets.only(bottom: Insets.sm),
                    child: ListTile(
                      leading: Icon(
                        Icons.warning_amber,
                        color: theme.colorScheme.error,
                      ),
                      title: Text(h.issue),
                      subtitle: h.object.isNotEmpty ? Text(h.object) : null,
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ProvidersSection extends ConsumerWidget {
  const _ProvidersSection({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final List<BazarrProviderStatus> providers =
        ref.watch(bazarrProviderStatusesProvider(instance)).valueOrNull ??
            const <BazarrProviderStatus>[];
    return _Section(
      title: 'Providers',
      action: TextButton.icon(
        onPressed: () => _reset(context, ref),
        icon: const Icon(Icons.restart_alt, size: 18),
        label: const Text('Reset'),
      ),
      child: providers.isEmpty
          ? Text(
              'No providers enabled',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            )
          : Column(
              children: <Widget>[
                for (final BazarrProviderStatus p in providers)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(
                      p.status.toLowerCase() == 'good'
                          ? Icons.check_circle
                          : Icons.error_outline,
                      color: p.status.toLowerCase() == 'good'
                          ? Colors.green.shade600
                          : theme.colorScheme.error,
                    ),
                    title: Text(p.name),
                    subtitle: Text(
                      p.retry != '-' && p.retry.isNotEmpty
                          ? '${p.status} · retry ${p.retry}'
                          : p.status,
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final BazarrApi api = await ref.read(bazarrApiProvider(instance).future);
      await api.resetProviders();
      ref.invalidate(bazarrProviderStatusesProvider(instance));
      messenger.showSnackBar(
        const SnackBar(content: Text('Throttled providers reset')),
      );
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Reset failed: ${_err(e)}')),
      );
    }
  }
}

class _TasksSection extends ConsumerWidget {
  const _TasksSection({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<BazarrSystemTask> tasks =
        ref.watch(bazarrSystemTasksProvider(instance)).valueOrNull ??
            const <BazarrSystemTask>[];
    if (tasks.isEmpty) {
      return const SizedBox.shrink();
    }
    return _Section(
      title: 'Tasks',
      child: Column(
        children: <Widget>[
          for (final BazarrSystemTask t in tasks)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(t.name),
              subtitle: Text(
                <String>[
                  if (t.interval.isNotEmpty) t.interval,
                  if (t.nextRunIn.isNotEmpty) 'next ${t.nextRunIn}',
                ].join(' · '),
              ),
              trailing: IconButton(
                tooltip: 'Run now',
                icon: const Icon(Icons.play_arrow),
                onPressed: () => _run(context, ref, t),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    BazarrSystemTask t,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final BazarrApi api = await ref.read(bazarrApiProvider(instance).future);
      await api.runTask(t.jobId);
      ref.invalidate(bazarrSystemTasksProvider(instance));
      messenger.showSnackBar(SnackBar(content: Text('${t.name} started')));
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Run failed: ${_err(e)}')),
      );
    }
  }
}

class _BackupsSection extends ConsumerWidget {
  const _BackupsSection({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final List<BazarrBackup> backups =
        ref.watch(bazarrBackupsProvider(instance)).valueOrNull ??
            const <BazarrBackup>[];
    return _Section(
      title: 'Backups',
      action: TextButton.icon(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Create'),
      ),
      child: backups.isEmpty
          ? Text(
              'No backups',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            )
          : Column(
              children: <Widget>[
                for (final BazarrBackup b in backups)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.archive_outlined),
                    title: Text(b.filename),
                    subtitle: Text(
                      <String>[
                        if (b.type.isNotEmpty) b.type,
                        if (b.date.isNotEmpty) b.date,
                      ].join(' · '),
                    ),
                    trailing: IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(context, ref, b),
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final BazarrApi api = await ref.read(bazarrApiProvider(instance).future);
      await api.createBackup();
      ref.invalidate(bazarrBackupsProvider(instance));
      messenger.showSnackBar(
        const SnackBar(content: Text('Backup started')),
      );
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Backup failed: ${_err(e)}')),
      );
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    BazarrBackup b,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Delete backup?'),
        content: Text('Delete "${b.filename}"?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    try {
      final BazarrApi api = await ref.read(bazarrApiProvider(instance).future);
      await api.deleteBackup(b.filename);
      ref.invalidate(bazarrBackupsProvider(instance));
      messenger.showSnackBar(const SnackBar(content: Text('Backup deleted')));
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Delete failed: ${_err(e)}')),
      );
    }
  }
}

class _LogsSection extends ConsumerWidget {
  const _LogsSection({required this.instance});

  final Instance instance;

  static const int _max = 25;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final List<BazarrLogEntry> logs =
        ref.watch(bazarrLogsProvider(instance)).valueOrNull ??
            const <BazarrLogEntry>[];
    final List<BazarrLogEntry> shown =
        logs.length > _max ? logs.sublist(0, _max) : logs;
    return _Section(
      title: 'Logs',
      action: logs.isEmpty
          ? null
          : TextButton.icon(
              onPressed: () => _clear(context, ref),
              icon: const Icon(Icons.delete_sweep_outlined, size: 18),
              label: const Text('Clear'),
            ),
      child: logs.isEmpty
          ? Text(
              'No logs',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            )
          : Column(
              children: <Widget>[
                for (final BazarrLogEntry l in shown)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            l.type,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: _logColor(theme, l.type),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: Insets.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(l.message, style: theme.textTheme.bodySmall),
                              Text(
                                l.timestamp,
                                style: theme.textTheme.labelSmall
                                    ?.copyWith(color: theme.colorScheme.outline),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Color _logColor(ThemeData theme, String type) {
    switch (type.toUpperCase()) {
      case 'ERROR':
        return theme.colorScheme.error;
      case 'WARNING':
        return Colors.orange.shade700;
      default:
        return theme.colorScheme.outline;
    }
  }

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Clear logs?'),
        content: const Text('Delete all Bazarr log entries?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    try {
      final BazarrApi api = await ref.read(bazarrApiProvider(instance).future);
      await api.clearLogs();
      ref.invalidate(bazarrLogsProvider(instance));
      messenger.showSnackBar(const SnackBar(content: Text('Logs cleared')));
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Clear failed: ${_err(e)}')),
      );
    }
  }
}

String _uptime(double? startTime) {
  if (startTime == null || startTime <= 0) {
    return '';
  }
  final DateTime start =
      DateTime.fromMillisecondsSinceEpoch((startTime * 1000).round());
  final Duration d = DateTime.now().difference(start);
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

String _err(Object e) {
  if (e is NetworkException && e.message.isNotEmpty) {
    return e.message;
  }
  return 'request failed';
}
