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
    return EasyRefresh(
      header: const MaterialHeader(),
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

/// A tonal, rounded section card. Sections supply their own bottom gap so an
/// absent (shrunk) section leaves no double space.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: Container(
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
      ),
    );
  }
}

/// Small tonal status pill: tinted background, leading icon, label.
class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

/// Small color-coded leading badge (denser 32x32 square).
class _LeadingBadge extends StatelessWidget {
  const _LeadingBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 17, color: color),
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
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
        ref.watch(bazarrSystemStatusProvider(instance)).value;
    if (s == null) {
      return const SizedBox.shrink();
    }
    return _SectionCard(
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
    final ColorScheme cs = theme.colorScheme;
    final List<BazarrHealthItem> issues =
        ref.watch(bazarrSystemHealthProvider(instance)).value ??
            const <BazarrHealthItem>[];
    return _SectionCard(
      title: 'Health',
      child: issues.isEmpty
          ? Align(
              alignment: Alignment.centerLeft,
              child: _StatusPill(
                icon: Icons.check_circle,
                label: 'All healthy',
                color: cs.tertiary,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (int i = 0; i < issues.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(height: Insets.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _LeadingBadge(
                        icon: Icons.warning_amber,
                        color: cs.error,
                      ),
                      const SizedBox(width: Insets.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              issues[i].issue,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            if (issues[i].object.isNotEmpty)
                              Text(
                                issues[i].object,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
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
    final ColorScheme cs = theme.colorScheme;
    final List<BazarrProviderStatus> providers =
        ref.watch(bazarrProviderStatusesProvider(instance)).value ??
            const <BazarrProviderStatus>[];
    return _SectionCard(
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
                  ?.copyWith(color: cs.onSurfaceVariant),
            )
          : Column(
              children: <Widget>[
                for (int i = 0; i < providers.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(height: Insets.sm),
                  _ProviderRow(provider: providers[i]),
                ],
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

class _ProviderRow extends StatelessWidget {
  const _ProviderRow({required this.provider});

  final BazarrProviderStatus provider;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final bool good = provider.status.toLowerCase() == 'good';
    final Color accent = good ? cs.tertiary : cs.error;
    final bool hasRetry = provider.retry != '-' && provider.retry.isNotEmpty;
    return Row(
      children: <Widget>[
        _LeadingBadge(
          icon: good ? Icons.check_circle : Icons.error_outline,
          color: accent,
        ),
        const SizedBox(width: Insets.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                provider.name,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (hasRetry)
                Text(
                  'retry ${provider.retry}',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
            ],
          ),
        ),
        const SizedBox(width: Insets.sm),
        _StatusPill(
          icon: good ? Icons.check : Icons.warning_amber,
          label: provider.status,
          color: accent,
        ),
      ],
    );
  }
}

class _TasksSection extends ConsumerWidget {
  const _TasksSection({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final List<BazarrSystemTask> tasks =
        ref.watch(bazarrSystemTasksProvider(instance)).value ??
            const <BazarrSystemTask>[];
    if (tasks.isEmpty) {
      return const SizedBox.shrink();
    }
    return _SectionCard(
      title: 'Tasks',
      child: Column(
        children: <Widget>[
          for (int i = 0; i < tasks.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: Insets.sm),
            Row(
              children: <Widget>[
                _LeadingBadge(
                  icon: Icons.schedule,
                  color: cs.secondary,
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        tasks[i].name,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Builder(
                        builder: (BuildContext context) {
                          final String detail = <String>[
                            if (tasks[i].interval.isNotEmpty) tasks[i].interval,
                            if (tasks[i].nextRunIn.isNotEmpty)
                              'next ${tasks[i].nextRunIn}',
                          ].join(' · ');
                          if (detail.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            detail,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Run now',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () => _run(context, ref, tasks[i]),
                ),
              ],
            ),
          ],
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
    final ColorScheme cs = theme.colorScheme;
    final List<BazarrBackup> backups =
        ref.watch(bazarrBackupsProvider(instance)).value ??
            const <BazarrBackup>[];
    return _SectionCard(
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
                  ?.copyWith(color: cs.onSurfaceVariant),
            )
          : Column(
              children: <Widget>[
                for (int i = 0; i < backups.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(height: Insets.sm),
                  Row(
                    children: <Widget>[
                      _LeadingBadge(
                        icon: Icons.archive_outlined,
                        color: cs.secondary,
                      ),
                      const SizedBox(width: Insets.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              backups[i].filename,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Builder(
                              builder: (BuildContext context) {
                                final String detail = <String>[
                                  if (backups[i].type.isNotEmpty)
                                    backups[i].type,
                                  if (backups[i].date.isNotEmpty)
                                    backups[i].date,
                                ].join(' · ');
                                if (detail.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return Text(
                                  detail,
                                  style: theme.textTheme.labelSmall
                                      ?.copyWith(color: cs.onSurfaceVariant),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(context, ref, backups[i]),
                      ),
                    ],
                  ),
                ],
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
    final ColorScheme cs = theme.colorScheme;
    final List<BazarrLogEntry> logs =
        ref.watch(bazarrLogsProvider(instance)).value ??
            const <BazarrLogEntry>[];
    final List<BazarrLogEntry> shown =
        logs.length > _max ? logs.sublist(0, _max) : logs;
    return _SectionCard(
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
                  ?.copyWith(color: cs.onSurfaceVariant),
            )
          : Column(
              children: <Widget>[
                for (int i = 0; i < shown.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(height: Insets.sm),
                  Builder(
                    builder: (BuildContext context) {
                      final (Color color, IconData icon) =
                          _logLook(cs, shown[i].type);
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _StatusPill(
                            icon: icon,
                            label: shown[i].type,
                            color: color,
                          ),
                          const SizedBox(width: Insets.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  shown[i].message,
                                  style: theme.textTheme.bodySmall,
                                ),
                                Text(
                                  shown[i].timestamp,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
    );
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

/// Log-level look: error red, warning amber, everything else muted.
(Color, IconData) _logLook(ColorScheme cs, String type) {
  switch (type.toUpperCase()) {
    case 'ERROR':
      return (cs.error, Icons.error_outline);
    case 'WARNING':
      return (Colors.orange.shade700, Icons.warning_amber);
    default:
      return (cs.onSurfaceVariant, Icons.info_outline);
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
