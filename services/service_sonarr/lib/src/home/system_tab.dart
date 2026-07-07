import 'dart:async';

import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../sonarr_api.dart';
import '../sonarr_providers.dart';

class SystemTab extends ConsumerStatefulWidget {
  const SystemTab({required this.instance, super.key});

  final Instance instance;

  @override
  ConsumerState<SystemTab> createState() => _SystemTabState();
}

class _SystemTabState extends ConsumerState<SystemTab> {
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: NestedScrollView(
          headerSliverBuilder:
              (BuildContext innerContext, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverAppBar(
                floating: true,
                snap: true,
                pinned: true,
                scrolledUnderElevation: 0.0,
                surfaceTintColor: Colors.transparent,
                backgroundColor: theme.colorScheme.surface,
                leadingWidth: 56,
                leading: IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
                title: const Text('System'),
                actions: <Widget>[
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (String value) {
                      if (value == 'restart') {
                        _confirmRestart();
                      } else if (value == 'shutdown') {
                        _confirmShutdown();
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'restart',
                        child: ListTile(
                          leading: Icon(Icons.restart_alt),
                          title: Text('Restart'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'shutdown',
                        child: ListTile(
                          leading: Icon(Icons.power_settings_new),
                          title: Text('Shutdown'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: Insets.xs),
                ],
                bottom: TabBar(
                  dividerColor: Colors.transparent,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorColor: theme.colorScheme.primary,
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelStyle: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelStyle: theme.textTheme.titleSmall,
                  tabs: const <Widget>[
                    Tab(text: 'Status'),
                    Tab(text: 'Tasks'),
                    Tab(text: 'Updates'),
                    Tab(text: 'Logs'),
                    Tab(text: 'Backups'),
                  ],
                ),
              ),
            ];
          },
          body: TabBarView(
            children: <Widget>[
              _StatusTab(instance: widget.instance),
              _TasksTab(instance: widget.instance),
              _UpdatesTab(instance: widget.instance),
              _LogsTab(instance: widget.instance),
              _BackupsTab(instance: widget.instance),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRestart() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Restart Sonarr?'),
        content: const Text(
          'This will restart the Sonarr service. It will be temporarily unavailable.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restart'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        final SonarrApi api =
            await ref.read(sonarrApiProvider(widget.instance).future);
        await api.restartSonarr();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Restart signal sent!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to restart: $e')),
          );
        }
      }
    }
  }

  Future<void> _confirmShutdown() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Shutdown Sonarr?'),
        content: const Text(
          'This will shut down the Sonarr service. You will need to restart it manually.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Shutdown'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        final SonarrApi api =
            await ref.read(sonarrApiProvider(widget.instance).future);
        await api.shutdownSonarr();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Shutdown signal sent!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to shutdown: $e')),
          );
        }
      }
    }
  }
}

// ==========================================
// 1. STATUS TAB (Health + About + Disk Space)
// ==========================================
class _StatusTab extends ConsumerWidget {
  const _StatusTab({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final statusAsync = ref.watch(sonarrSystemStatusProvider(instance));
    final healthAsync = ref.watch(sonarrHealthProvider(instance));
    final diskAsync = ref.watch(sonarrDiskSpaceProvider(instance));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(sonarrSystemStatusProvider(instance));
        ref.invalidate(sonarrHealthProvider(instance));
        ref.invalidate(sonarrDiskSpaceProvider(instance));
        await Future.wait(<Future<void>>[
          ref.read(sonarrSystemStatusProvider(instance).future),
          ref.read(sonarrHealthProvider(instance).future),
          ref.read(sonarrDiskSpaceProvider(instance).future),
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.all(Insets.md),
        children: <Widget>[
          // ── Health Checks ──
          healthAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (Object err, _) => _sectionError('Health', err),
            data: (List<Map<String, dynamic>> items) {
              if (items.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _sectionHeader(theme, 'Health'),
                  ...items.map(
                    (Map<String, dynamic> h) => _HealthCard(health: h),
                  ),
                  const SizedBox(height: Insets.md),
                ],
              );
            },
          ),

          // ── About / Status ──
          statusAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (Object err, _) => _sectionError('Status', err),
            data: (Map<String, dynamic> s) {
              final String version =
                  s['version'] as String? ?? 'Unknown';
              final String branch =
                  s['branch'] as String? ?? 'Unknown';
              final String osName =
                  s['osName'] as String? ?? 'Unknown';
              final String osVersion =
                  s['osVersion'] as String? ?? '';
              final String runtimeName =
                  s['runtimeName'] as String? ?? '';
              final String runtimeVersion =
                  s['runtimeVersion'] as String? ?? '';
              final bool isDocker = s['isDocker'] as bool? ?? false;
              final String packageAuthor =
                  s['packageAuthor'] as String? ?? '';
              final String dbType =
                  s['databaseType'] as String? ?? '';
              final String dbVersion =
                  s['databaseVersion'] as String? ?? '';
              final String startTimeStr =
                  s['startTime'] as String? ?? '';
              final String appData =
                  s['appData'] as String? ?? '';
              final String startupPath =
                  s['startupPath'] as String? ?? '';

              String uptimeText = '';
              if (startTimeStr.isNotEmpty) {
                final DateTime startTime =
                    DateTime.tryParse(startTimeStr) ?? DateTime.now();
                final Duration uptime =
                    DateTime.now().toUtc().difference(startTime);
                if (uptime.inDays > 0) {
                  uptimeText =
                      '${uptime.inDays}d ${uptime.inHours % 24}h ${uptime.inMinutes % 60}m';
                } else if (uptime.inHours > 0) {
                  uptimeText =
                      '${uptime.inHours}h ${uptime.inMinutes % 60}m';
                } else {
                  uptimeText = '${uptime.inMinutes}m';
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _sectionHeader(theme, 'About'),
                  Wrap(
                    spacing: Insets.sm,
                    runSpacing: Insets.sm,
                    children: <Widget>[
                      _InfoChip(
                        icon: Icons.info_outline,
                        label: 'Version',
                        value: version,
                      ),
                      _InfoChip(
                        icon: Icons.account_tree_outlined,
                        label: 'Branch',
                        value: branch,
                      ),
                      if (isDocker)
                        const _InfoChip(
                          icon: Icons.inventory_2_outlined,
                          label: 'Docker',
                          value: 'Yes',
                        ),
                      _InfoChip(
                        icon: Icons.computer_outlined,
                        label: 'OS',
                        value: '$osName $osVersion'.trim(),
                      ),
                      if (runtimeName.isNotEmpty)
                        _InfoChip(
                          icon: Icons.memory_outlined,
                          label: 'Runtime',
                          value: '$runtimeName $runtimeVersion'.trim(),
                        ),
                      if (dbType.isNotEmpty)
                        _InfoChip(
                          icon: Icons.storage_outlined,
                          label: 'Database',
                          value: '$dbType $dbVersion'.trim(),
                        ),
                      if (uptimeText.isNotEmpty)
                        _InfoChip(
                          icon: Icons.timer_outlined,
                          label: 'Uptime',
                          value: uptimeText,
                        ),
                      if (packageAuthor.isNotEmpty)
                        _InfoChip(
                          icon: Icons.person_outline,
                          label: 'Package',
                          value: packageAuthor.replaceAll(
                            RegExp(r'\[|\]\(.*?\)'),
                            '',
                          ),
                        ),
                      if (appData.isNotEmpty)
                        _InfoChip(
                          icon: Icons.folder_outlined,
                          label: 'App Data',
                          value: appData,
                        ),
                      if (startupPath.isNotEmpty)
                        _InfoChip(
                          icon: Icons.launch_outlined,
                          label: 'Startup',
                          value: startupPath,
                        ),
                    ],
                  ),
                  const SizedBox(height: Insets.lg),
                ],
              );
            },
          ),

          // ── Disk Space ──
          diskAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (Object err, _) => _sectionError('Disk Space', err),
            data: (List<Map<String, dynamic>> disks) {
              if (disks.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _sectionHeader(theme, 'Disk Space'),
                  ...disks.map(
                    (Map<String, dynamic> d) =>
                        _DiskSpaceCard(disk: d),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: Insets.xs, bottom: Insets.sm),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _sectionError(String section, Object err) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: Text('$section error: $err'),
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({required this.health});

  final Map<String, dynamic> health;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String type = health['type'] as String? ?? 'warning';
    final String message = health['message'] as String? ?? '';
    final String source = health['source'] as String? ?? '';
    final String? wikiUrl = health['wikiUrl'] as String?;

    final bool isError = type == 'error';
    final Color bgColor = isError
        ? theme.colorScheme.errorContainer
        : Colors.amber.withAlpha(30);
    final Color fgColor = isError
        ? theme.colorScheme.onErrorContainer
        : Colors.amber.shade800;
    final IconData icon =
        isError ? Icons.error_outline : Icons.warning_amber_rounded;

    return Card(
      margin: const EdgeInsets.only(bottom: Insets.sm),
      elevation: 0,
      color: bgColor,
      shape: const RoundedRectangleBorder(borderRadius: Radii.card),
      child: ListTile(
        leading: Icon(icon, color: fgColor),
        title: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(color: fgColor),
        ),
        subtitle: Text(
          source,
          style: theme.textTheme.bodySmall?.copyWith(
            color: fgColor.withAlpha(180),
          ),
        ),
        trailing: wikiUrl != null
            ? IconButton(
                icon: Icon(Icons.open_in_new, color: fgColor, size: 18),
                onPressed: () =>
                    launchUrl(Uri.parse(wikiUrl)),
                tooltip: 'Open wiki',
              )
            : null,
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: Radii.card,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.md,
          vertical: Insets.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: Insets.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DiskSpaceCard extends StatelessWidget {
  const _DiskSpaceCard({required this.disk});

  final Map<String, dynamic> disk;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String path = disk['path'] as String? ?? '/';
    final int freeSpace = disk['freeSpace'] as int? ?? 0;
    final int totalSpace = disk['totalSpace'] as int? ?? 1;
    final int usedSpace = totalSpace - freeSpace;
    final double usedPercent =
        totalSpace > 0 ? usedSpace / totalSpace : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: Insets.sm),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: Radii.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.storage,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(
                    path,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${(usedPercent * 100).toStringAsFixed(1)}%',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: usedPercent > 0.9
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: usedPercent,
                minHeight: 8,
                backgroundColor:
                    theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  usedPercent > 0.9
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: Insets.xs),
            Text(
              '${_formatBytes(freeSpace)} free of ${_formatBytes(totalSpace)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1099511627776) {
      return '${(bytes / 1099511627776).toStringAsFixed(1)} TB';
    } else if (bytes >= 1073741824) {
      return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
    } else if (bytes >= 1048576) {
      return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }
}

// ==========================================
// 2. TASKS TAB
// ==========================================
class _TasksTab extends ConsumerWidget {
  const _TasksTab({required this.instance});

  final Instance instance;

  Future<void> _runTask(
    BuildContext context,
    WidgetRef ref,
    String taskName,
  ) async {
    try {
      final SonarrApi api =
          await ref.read(sonarrApiProvider(instance).future);
      await api.runCommand(<String, dynamic>{'name': taskName});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$taskName started!')),
        );
      }
      // Refresh tasks list after a short delay
      await Future<void>.delayed(const Duration(seconds: 2));
      ref.invalidate(sonarrTasksProvider(instance));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to run task: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final tasksAsync = ref.watch(sonarrTasksProvider(instance));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(sonarrTasksProvider(instance));
        await ref.read(sonarrTasksProvider(instance).future);
      },
      child: tasksAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (Object err, _) =>
            Center(child: Text('Error: $err')),
        data: (List<Map<String, dynamic>> tasks) {
          if (tasks.isEmpty) {
            return const Center(child: Text('No scheduled tasks.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(Insets.md),
            itemCount: tasks.length,
            itemBuilder: (BuildContext context, int index) {
              final Map<String, dynamic> task = tasks[index];
              final String name =
                  task['name'] as String? ?? 'Task';
              final String taskName =
                  task['taskName'] as String? ?? '';
              final int interval =
                  task['interval'] as int? ?? 0;
              final String lastExecStr =
                  task['lastExecution'] as String? ?? '';
              final String nextExecStr =
                  task['nextExecution'] as String? ?? '';
              final String lastDuration =
                  task['lastDuration'] as String? ?? '';

              final String intervalText = _formatInterval(interval);
              final String lastExecText =
                  _formatRelativeTime(lastExecStr);
              final String nextExecText =
                  _formatRelativeTime(nextExecStr);

              return Card(
                margin: const EdgeInsets.only(bottom: Insets.sm),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                  ),
                  borderRadius: Radii.card,
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Insets.md,
                    vertical: Insets.xs,
                  ),
                  title: Text(
                    name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SizedBox(height: 4),
                      Text(
                        'Every $intervalText • Last: $lastExecText • Duration: ${_formatDuration(lastDuration)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        'Next: $nextExecText',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.play_arrow_outlined),
                    tooltip: 'Run now',
                    onPressed: () =>
                        _runTask(context, ref, taskName),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatInterval(int minutes) {
    if (minutes >= 1440) {
      final int days = minutes ~/ 1440;
      return days == 1 ? '1 day' : '$days days';
    } else if (minutes >= 60) {
      final int hours = minutes ~/ 60;
      return hours == 1 ? '1 hour' : '$hours hours';
    }
    return '$minutes min';
  }

  String _formatRelativeTime(String isoStr) {
    if (isoStr.isEmpty) return 'N/A';
    final DateTime? dt = DateTime.tryParse(isoStr);
    if (dt == null) return isoStr;
    final Duration diff = DateTime.now().toUtc().difference(dt);
    if (diff.isNegative) {
      // Future time
      final Duration absDiff = diff.abs();
      if (absDiff.inDays > 0) {
        return 'in ${absDiff.inDays}d ${absDiff.inHours % 24}h';
      } else if (absDiff.inHours > 0) {
        return 'in ${absDiff.inHours}h ${absDiff.inMinutes % 60}m';
      }
      return 'in ${absDiff.inMinutes}m';
    }
    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    }
    return '${diff.inMinutes}m ago';
  }

  String _formatDuration(String duration) {
    // Duration comes as "HH:MM:SS.fffffff"
    if (duration.isEmpty) return 'N/A';
    final List<String> parts = duration.split(':');
    if (parts.length < 3) return duration;
    final int hours = int.tryParse(parts[0]) ?? 0;
    final int minutes = int.tryParse(parts[1]) ?? 0;
    final double seconds = double.tryParse(parts[2]) ?? 0;
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m ${seconds.toStringAsFixed(0)}s';
    return '${seconds.toStringAsFixed(1)}s';
  }
}

// ==========================================
// 3. UPDATES TAB
// ==========================================
class _UpdatesTab extends ConsumerWidget {
  const _UpdatesTab({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updatesAsync = ref.watch(sonarrUpdatesProvider(instance));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(sonarrUpdatesProvider(instance));
        await ref.read(sonarrUpdatesProvider(instance).future);
      },
      child: updatesAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (Object err, _) =>
            Center(child: Text('Error: $err')),
        data: (List<Map<String, dynamic>> updates) {
          if (updates.isEmpty) {
            return const Center(
              child: Text('No updates available.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(Insets.md),
            itemCount: updates.length,
            itemBuilder: (BuildContext context, int index) {
              final Map<String, dynamic> update = updates[index];
              return _UpdateCard(update: update);
            },
          );
        },
      ),
    );
  }
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({required this.update});

  final Map<String, dynamic> update;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String version = update['version'] as String? ?? '';
    final String branch = update['branch'] as String? ?? '';
    final bool installed = update['installed'] as bool? ?? false;
    final bool latest = update['latest'] as bool? ?? false;
    final String releaseDateStr =
        update['releaseDate'] as String? ?? '';
    final Map<String, dynamic>? changes =
        update['changes'] as Map<String, dynamic>?;

    final List<String> newItems =
        (changes?['new'] as List<dynamic>?)
                ?.map((dynamic e) => e as String)
                .toList() ??
            <String>[];
    final List<String> fixedItems =
        (changes?['fixed'] as List<dynamic>?)
                ?.map((dynamic e) => e as String)
                .toList() ??
            <String>[];

    String releaseDateText = '';
    if (releaseDateStr.isNotEmpty) {
      final DateTime? dt = DateTime.tryParse(releaseDateStr);
      if (dt != null) {
        releaseDateText =
            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: Insets.md),
      elevation: 0,
      color: installed
          ? theme.colorScheme.primaryContainer.withAlpha(50)
          : null,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: installed
              ? theme.colorScheme.primary.withAlpha(100)
              : theme.colorScheme.outlineVariant,
          width: installed ? 1.5 : 1,
        ),
        borderRadius: Radii.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  'v$version',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: Insets.sm),
                if (installed)
                  Chip(
                    label: const Text('Installed'),
                    backgroundColor: theme.colorScheme.primaryContainer,
                    labelStyle: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    side: BorderSide.none,
                  ),
                if (latest && !installed)
                  Chip(
                    label: const Text('Latest'),
                    backgroundColor:
                        Colors.green.withAlpha(30),
                    labelStyle:
                        theme.textTheme.labelSmall?.copyWith(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    side: BorderSide.none,
                  ),
                const Spacer(),
                Text(
                  releaseDateText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            Text(
              'Branch: $branch',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (newItems.isNotEmpty || fixedItems.isNotEmpty) ...<Widget>[
              const Divider(height: Insets.lg),
              if (newItems.isNotEmpty) ...<Widget>[
                Text(
                  'New',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                ...newItems.map(
                  (String item) => Padding(
                    padding: const EdgeInsets.only(
                      left: Insets.sm,
                      bottom: 2,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '• ',
                          style: TextStyle(
                            color: Colors.green.shade700,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            item,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Insets.sm),
              ],
              if (fixedItems.isNotEmpty) ...<Widget>[
                Text(
                  'Fixed',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                ...fixedItems.map(
                  (String item) => Padding(
                    padding: const EdgeInsets.only(
                      left: Insets.sm,
                      bottom: 2,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '• ',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            item,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 4. LOGS TAB
// ==========================================
class _LogsTab extends ConsumerStatefulWidget {
  const _LogsTab({required this.instance});

  final Instance instance;

  @override
  ConsumerState<_LogsTab> createState() => _LogsTabState();
}

class _LogsTabState extends ConsumerState<_LogsTab> {
  int _currentPage = 1;
  static const int _pageSize = 50;
  String? _levelFilter;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final logsAsync = ref.watch(
      sonarrLogsProvider((
        widget.instance,
        page: _currentPage,
        pageSize: _pageSize,
        level: _levelFilter,
      ),),
    );

    return Column(
      children: <Widget>[
        // Level filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.md,
            vertical: Insets.sm,
          ),
          child: Row(
            children: <Widget>[
              _FilterChip(
                label: 'All',
                selected: _levelFilter == null,
                onSelected: () => setState(() {
                  _levelFilter = null;
                  _currentPage = 1;
                }),
              ),
              const SizedBox(width: Insets.xs),
              _FilterChip(
                label: 'Info',
                selected: _levelFilter == 'info',
                onSelected: () => setState(() {
                  _levelFilter = 'info';
                  _currentPage = 1;
                }),
              ),
              const SizedBox(width: Insets.xs),
              _FilterChip(
                label: 'Warn',
                selected: _levelFilter == 'warn',
                onSelected: () => setState(() {
                  _levelFilter = 'warn';
                  _currentPage = 1;
                }),
              ),
              const SizedBox(width: Insets.xs),
              _FilterChip(
                label: 'Error',
                selected: _levelFilter == 'error',
                onSelected: () => setState(() {
                  _levelFilter = 'error';
                  _currentPage = 1;
                }),
              ),
            ],
          ),
        ),

        Expanded(
          child: logsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (Object err, _) =>
                Center(child: Text('Error: $err')),
            data: (Map<String, dynamic> data) {
              final List<dynamic> records =
                  data['records'] as List<dynamic>? ?? <dynamic>[];
              final int totalRecords =
                  data['totalRecords'] as int? ?? 0;
              final int totalPages =
                  (totalRecords / _pageSize).ceil().clamp(1, 9999);

              if (records.isEmpty) {
                return const Center(child: Text('No log entries.'));
              }

              return Column(
                children: <Widget>[
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(sonarrLogsProvider((
                          widget.instance,
                          page: _currentPage,
                          pageSize: _pageSize,
                          level: _levelFilter,
                        ),),);
                      },
                      child: ListView.builder(
                        padding:
                            const EdgeInsets.symmetric(horizontal: Insets.md),
                        itemCount: records.length,
                        itemBuilder:
                            (BuildContext context, int index) {
                          final Map<String, dynamic> log =
                              records[index] as Map<String, dynamic>;
                          return _LogEntryTile(log: log);
                        },
                      ),
                    ),
                  ),

                  // Pagination controls
                  Padding(
                    padding: const EdgeInsets.all(Insets.sm),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: _currentPage > 1
                              ? () =>
                                  setState(() => _currentPage--)
                              : null,
                        ),
                        Text(
                          'Page $_currentPage of $totalPages',
                          style: theme.textTheme.bodyMedium,
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: _currentPage < totalPages
                              ? () =>
                                  setState(() => _currentPage++)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
    );
  }
}

class _LogEntryTile extends StatelessWidget {
  const _LogEntryTile({required this.log});

  final Map<String, dynamic> log;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String level = log['level'] as String? ?? 'info';
    final String logger = log['logger'] as String? ?? '';
    final String message = log['message'] as String? ?? '';
    final String? exception = log['exception'] as String?;
    final String timeStr = log['time'] as String? ?? '';

    Color levelColor;
    switch (level.toLowerCase()) {
      case 'error':
      case 'fatal':
        levelColor = theme.colorScheme.error;
      case 'warn':
        levelColor = Colors.amber.shade700;
      case 'debug':
      case 'trace':
        levelColor = theme.colorScheme.onSurfaceVariant;
      default:
        levelColor = theme.colorScheme.primary;
    }

    String timeText = '';
    if (timeStr.isNotEmpty) {
      final DateTime? dt = DateTime.tryParse(timeStr);
      if (dt != null) {
        final DateTime local = dt.toLocal();
        timeText =
            '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}:${local.second.toString().padLeft(2, '0')}';
      }
    }

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 55,
                child: Text(
                  timeText,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontFamily: 'monospace',
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: levelColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  level.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: levelColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      logger,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      message,
                      style: theme.textTheme.bodySmall,
                    ),
                    if (exception != null && exception.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          exception,
                          style:
                              theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          color: theme.colorScheme.outlineVariant.withAlpha(80),
        ),
      ],
    );
  }
}

// ==========================================
// 5. BACKUPS TAB
// ==========================================
class _BackupsTab extends ConsumerWidget {
  const _BackupsTab({required this.instance});

  final Instance instance;

  Future<void> _deleteBackup(
    BuildContext context,
    WidgetRef ref,
    int id,
    String name,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Delete Backup?'),
        content: Text('Delete "$name"? This cannot be undone.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final SonarrApi api =
            await ref.read(sonarrApiProvider(instance).future);
        await api.deleteBackup(id);
        ref.invalidate(sonarrBackupsProvider(instance));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Backup deleted!')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete backup: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final backupsAsync = ref.watch(sonarrBackupsProvider(instance));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(sonarrBackupsProvider(instance));
        await ref.read(sonarrBackupsProvider(instance).future);
      },
      child: backupsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (Object err, _) =>
            Center(child: Text('Error: $err')),
        data: (List<Map<String, dynamic>> backups) {
          if (backups.isEmpty) {
            return const Center(child: Text('No backups found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(Insets.md),
            itemCount: backups.length,
            itemBuilder: (BuildContext context, int index) {
              final Map<String, dynamic> backup = backups[index];
              final String name =
                  backup['name'] as String? ?? 'Backup';
              final String type =
                  backup['type'] as String? ?? 'unknown';
              final int size = backup['size'] as int? ?? 0;
              final int id = backup['id'] as int? ?? 0;
              final String timeStr =
                  backup['time'] as String? ?? '';

              String dateText = '';
              if (timeStr.isNotEmpty) {
                final DateTime? dt = DateTime.tryParse(timeStr);
                if (dt != null) {
                  final DateTime local = dt.toLocal();
                  dateText =
                      '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
                }
              }

              IconData typeIcon;
              switch (type) {
                case 'scheduled':
                  typeIcon = Icons.schedule;
                case 'manual':
                  typeIcon = Icons.touch_app_outlined;
                case 'update':
                  typeIcon = Icons.system_update_outlined;
                default:
                  typeIcon = Icons.backup_outlined;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: Insets.sm),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                  ),
                  borderRadius: Radii.card,
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      typeIcon,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  title: Text(
                    name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${type[0].toUpperCase()}${type.substring(1)} • ${_formatBytes(size)} • $dateText',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: theme.colorScheme.error,
                    ),
                    onPressed: () =>
                        _deleteBackup(context, ref, id, name),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1073741824) {
      return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
    } else if (bytes >= 1048576) {
      return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }
}
