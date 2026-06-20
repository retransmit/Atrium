part of '../sonarr_home.dart';

class _BlocklistScreen extends StatelessWidget {
  const _BlocklistScreen({required this.instance});
  final Instance instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocklist'),
      ),
      body: _BlocklistTab(instance: instance),
    );
  }
}

class _MoreTab extends ConsumerStatefulWidget {
  const _MoreTab({required this.instance});

  final Instance instance;

  @override
  ConsumerState<_MoreTab> createState() => _MoreTabState();
}

class _MoreTabState extends ConsumerState<_MoreTab> {
  late final ScrollController _scrollController;
  bool _showScrollUp = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      final show = _scrollController.offset > 200;
      if (show != _showScrollUp) {
        setState(() {
          _showScrollUp = show;
        });
      }
    }
  }

  void _scrollToTop() {
    HapticFeedback.lightImpact();
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    final AsyncValue<List<SonarrHealth>> health = ref.watch(sonarrHealthProvider(widget.instance));
    final AsyncValue<SonarrSystemStatus> status = ref.watch(sonarrSystemStatusProvider(widget.instance));
    final AsyncValue<List<SonarrDiskSpace>> diskSpace = ref.watch(sonarrDiskSpaceProvider(widget.instance));
    final AsyncValue<List<SonarrSystemTask>> tasks = ref.watch(sonarrSystemTasksProvider(widget.instance));
    final AsyncValue<List<SonarrBackup>> backups = ref.watch(sonarrBackupsProvider(widget.instance));

    return Scaffold(
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(sonarrHealthProvider(widget.instance));
              ref.invalidate(sonarrSystemStatusProvider(widget.instance));
              ref.invalidate(sonarrDiskSpaceProvider(widget.instance));
              ref.invalidate(sonarrSystemTasksProvider(widget.instance));
              ref.invalidate(sonarrBackupsProvider(widget.instance));
              ref.invalidate(sonarrIndexersProvider(widget.instance));
              ref.invalidate(sonarrDownloadClientsProvider(widget.instance));
              ref.invalidate(sonarrNotificationsProvider(widget.instance));
              ref.invalidate(sonarrImportListsProvider(widget.instance));
              ref.invalidate(sonarrTagsProvider(widget.instance));
              ref.invalidate(sonarrHostConfigProvider(widget.instance));
              ref.invalidate(sonarrNamingConfigProvider(widget.instance));
              ref.invalidate(sonarrMediaManagementConfigProvider(widget.instance));
              ref.invalidate(sonarrUiConfigProvider(widget.instance));
              ref.invalidate(sonarrMetadataProvidersProvider(widget.instance));
              ref.invalidate(sonarrDelayProfilesProvider(widget.instance));
              ref.invalidate(sonarrCustomFormatsProvider(widget.instance));
              ref.invalidate(sonarrQualityDefinitionsProvider(widget.instance));
              ref.invalidate(sonarrReleaseProfilesProvider(widget.instance));
              ref.invalidate(sonarrImportListExclusionsProvider(widget.instance));
              ref.invalidate(sonarrAutoTaggingRulesProvider(widget.instance));
              ref.invalidate(sonarrQualityProfilesRawProvider(widget.instance));
              ref.invalidate(sonarrQualityProfilesProvider(widget.instance));
            },
            child: CustomScrollView(
              controller: _scrollController,
              slivers: <Widget>[
                const _OneUIAppBar(
                  title: 'More',
                  showLeading: false,
                  expandedHeight: 280, // Expanded height matching One UI 8.5 Specs
                ),
                SliverPadding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 100), // padding bottom for bottom nav
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _HealthWarningsSection(health: health),
                        _OneUIGroupCard(
                          margin: EdgeInsets.zero,
                          children: <Widget>[
                            ...status.maybeWhen(
                              data: (stat) => <Widget>[
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                  leading: const Icon(Icons.info_outline),
                                  title: const Text('Version'),
                                  trailing: Text(
                                    stat.version,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                  leading: const Icon(Icons.dns_outlined),
                                  title: const Text('OS'),
                                  trailing: Text(
                                    stat.osName,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                  leading: const Icon(Icons.computer),
                                  title: const Text('Environment'),
                                  trailing: Text(
                                    stat.isDocker ? 'Docker' : 'Bare Metal',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                              orElse: () => <Widget>[],
                            ),
                            ...diskSpace.maybeWhen(
                              data: (disks) => disks.map((disk) {
                                final double progress = disk.totalSpace <= 0
                                    ? 0
                                    : ((disk.totalSpace - disk.freeSpace) / disk.totalSpace)
                                        .clamp(0, 1)
                                        .toDouble();
                                final String freeStr = _formatBytes(disk.freeSpace);
                                final String totalStr = _formatBytes(disk.totalSpace);

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                  leading: const Icon(Icons.pie_chart_outline),
                                  title: Text(
                                    disk.path,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: progress,
                                          minHeight: 8, // Chunkier progress bar
                                          backgroundColor: colors.surfaceContainerHighest,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            progress > 0.9 ? colors.error : colors.primary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Free: $freeStr / Total: $totalStr',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                              color: colors.outline,
                                            ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              orElse: () => <Widget>[],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24), // 24dp gap between sections
                        _OneUIGroupCard(
                          margin: EdgeInsets.zero,
                          children: <Widget>[
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                              splashColor: colors.primary.withValues(alpha: 0.1),
                              leading: CircleAvatar(
                                backgroundColor: colors.primaryContainer,
                                child: Icon(Icons.edit_outlined, color: colors.onPrimaryContainer),
                              ),
                              title: const Text('Edit Connection Settings'),
                              subtitle: const Text('Configure connection URLs and API keys'),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                context.goNamed(
                                  'edit-instance',
                                  pathParameters: <String, String>{'instanceId': widget.instance.id},
                                );
                              },
                            ),
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                              splashColor: colors.error.withValues(alpha: 0.1),
                              leading: CircleAvatar(
                                backgroundColor: colors.errorContainer,
                                child: Icon(Icons.block, color: colors.onErrorContainer),
                              ),
                              title: const Text('Blocklist'),
                              subtitle: const Text('Manage blocked releases and history'),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                pushScreen<void>(context, _BlocklistScreen(instance: widget.instance));
                              },
                            ),
                            ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: colors.secondaryContainer,
                                child: Icon(Icons.task_alt, color: colors.onSecondaryContainer),
                              ),
                              title: const Text('Scheduled Tasks'),
                              subtitle: const Text('View and run system maintenance tasks'),
                              iconColor: colors.primary,
                              collapsedIconColor: colors.onSurfaceVariant,
                              tilePadding: const EdgeInsets.symmetric(horizontal: 20),
                              childrenPadding: const EdgeInsets.all(16),
                              shape: const Border(), // remove default borders
                              children: <Widget>[
                                _TasksSection(tasks: tasks, instance: widget.instance),
                              ],
                            ),
                            ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: colors.tertiaryContainer,
                                child: Icon(Icons.backup_outlined, color: colors.onTertiaryContainer),
                              ),
                              title: const Text('Backups'),
                              subtitle: const Text('Manage system configuration backups'),
                              iconColor: colors.primary,
                              collapsedIconColor: colors.onSurfaceVariant,
                              tilePadding: const EdgeInsets.symmetric(horizontal: 20),
                              childrenPadding: const EdgeInsets.all(16),
                              shape: const Border(), // remove default borders
                              children: <Widget>[
                                _BackupsSection(backups: backups, instance: widget.instance),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24), // 24dp gap before headers
                        const _OneUISectionHeader('Configuration Settings'),
                        const SizedBox(height: 8),
                        _IndexerSettingsPanel(instance: widget.instance),
                        const SizedBox(height: 24),
                        _DownloadClientSettingsPanel(instance: widget.instance),
                        const SizedBox(height: 24),
                        _NotificationSettingsPanel(instance: widget.instance),
                        const SizedBox(height: 24),
                        _ImportListSettingsPanel(instance: widget.instance),
                        const SizedBox(height: 24),
                        _TagSettingsPanel(instance: widget.instance),
                        const SizedBox(height: 24),
                        _HostSettingsPanel(instance: widget.instance),
                        const SizedBox(height: 24),
                        _NamingSettingsPanel(instance: widget.instance),
                        const SizedBox(height: 24),
                        _MediaManagementSettingsPanel(instance: widget.instance),
                        const SizedBox(height: 24),
                        _UiSettingsPanel(instance: widget.instance),
                        const SizedBox(height: 24),
                        _MetadataSettingsPanel(instance: widget.instance),
                        const SizedBox(height: 24),
                        _DelayProfileSettingsPanel(instance: widget.instance),
                        const SizedBox(height: 24),
                        _CustomFormatSettingsPanel(instance: widget.instance),
                        const SizedBox(height: 24),
                        _QualityDefinitionSettingsPanel(instance: widget.instance),
                        const SizedBox(height: 24),
                        _QualityProfileSettingsPanel(instance: widget.instance),
                        const SizedBox(height: 24),
                        _ReleaseProfileSettingsPanel(instance: widget.instance),
                        const SizedBox(height: 24),
                        _ImportListExclusionSettingsPanel(instance: widget.instance),
                        const SizedBox(height: 24),
                        _AutoTaggingSettingsPanel(instance: widget.instance),
                        const SizedBox(height: 48), // comfortable breathing space at the end
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Floating scroll-up button
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            bottom: _showScrollUp ? 96 : 40,
            right: 24,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _showScrollUp ? 1.0 : 0.0,
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: FloatingActionButton.small(
                  heroTag: 'scroll_up_more',
                  onPressed: _scrollToTop,
                  backgroundColor: colors.secondaryContainer,
                  foregroundColor: colors.onSecondaryContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.keyboard_arrow_up_rounded, size: 24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlocklistTab extends ConsumerStatefulWidget {
  const _BlocklistTab({required this.instance});

  final Instance instance;

  @override
  ConsumerState<_BlocklistTab> createState() => _BlocklistTabState();
}

class _BlocklistTabState extends ConsumerState<_BlocklistTab> {
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<SonarrBlocklistPage> blocklist =
        ref.watch(sonarrBlocklistProvider((widget.instance, _page)));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(sonarrBlocklistProvider((widget.instance, _page)));
        await ref.read(sonarrBlocklistProvider((widget.instance, _page)).future);
      },
      child: AsyncValueView<SonarrBlocklistPage>(
        value: blocklist,
        onRetry: () => ref.invalidate(sonarrBlocklistProvider((widget.instance, _page))),
        data: (SonarrBlocklistPage dataPage) {
          if (dataPage.records.isEmpty) {
            return const EmptyView(
              icon: Icons.block,
              title: 'Blocklist is empty',
              message: 'No releases have been blocklisted.',
            );
          }

          final int totalPages = (dataPage.totalRecords / dataPage.pageSize).ceil().clamp(1, double.infinity).toInt();

          return Column(
            children: <Widget>[
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: dataPage.records.length,
                  itemBuilder: (BuildContext context, int index) {
                    final SonarrBlocklistRecord record = dataPage.records[index];
                    final String formattedDate = record.date != null
                        ? DateFormat.yMMMd().add_jm().format(record.date!.toLocal())
                        : 'Unknown Date';

                    return Card(
                      margin: const EdgeInsets.only(bottom: Insets.sm),
                      child: ListTile(
                        splashColor: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                        title: Text(
                          record.sourceTitle ?? 'Unknown Release',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: Insets.xs),
                            Text(
                              'Indexer: ${record.indexer ?? 'Unknown'} • Protocol: ${record.protocol ?? 'Unknown'}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              'Blocked: $formattedDate',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (record.message != null && record.message!.isNotEmpty) ...[
                              const SizedBox(height: Insets.xs),
                              Text(
                                'Reason: ${record.message}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.error,
                                    ),
                              ),
                            ],
                          ],
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                          onPressed: () async {
                            final apiObj = await ref.read(sonarrApiProvider(widget.instance).future);
                            await apiObj.deleteBlocklist(record.id);
                            ref.invalidate(sonarrBlocklistProvider((widget.instance, _page)));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Release removed from blocklist')),
                              );
                            }
                          },
                        ),
                        onTap: record.seriesId > 0
                            ? () => Navigator.of(context, rootNavigator: true).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => SeriesDetailScreen(
                                      instance: widget.instance,
                                      seriesId: record.seriesId,
                                    ),
                                  ),
                                )
                            : null,
                      ),
                    );
                  },
                ),
              ),
              if (totalPages > 1)
                _PaginationBar(
                  currentPage: _page,
                  totalPages: totalPages,
                  onPageChanged: (p) => setState(() => _page = p),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TasksSection extends StatelessWidget {
  const _TasksSection({required this.tasks, required this.instance});

  final AsyncValue<List<SonarrSystemTask>> tasks;
  final Instance instance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AsyncValueView<List<SonarrSystemTask>>(
          value: tasks,
          data: (taskList) {
            if (taskList.isEmpty) {
              return const Text('No system tasks available');
            }
            return Column(
              children: taskList.map((task) {
                final String intervalStr = '${task.interval} min';
                final String lastRun = task.lastExecution != null
                    ? DateFormat.yMMMd().add_jm().format(task.lastExecution!.toLocal())
                    : 'Never';

                return Consumer(
                  builder: (context, ref, _) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule),
                      title: Text(task.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        'Interval: $intervalStr\nLast Run: $lastRun',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.play_arrow),
                        tooltip: 'Run task now',
                        onPressed: () async {
                          final apiObj = await ref.read(sonarrApiProvider(instance).future);
                          await apiObj.runSystemTask(task.taskName);
                          ref.invalidate(sonarrSystemTasksProvider(instance));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Task "${task.name}" triggered')),
                            );
                          }
                        },
                      ),
                    );
                  },
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: Insets.sm, horizontal: Insets.lg),
      color: theme.colorScheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
            ),
            Text(
              'Page $currentPage of $totalPages',
              style: theme.textTheme.bodyMedium,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: currentPage < totalPages ? () => onPageChanged(currentPage + 1) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthWarningsSection extends StatelessWidget {
  const _HealthWarningsSection({required this.health});

  final AsyncValue<List<SonarrHealth>> health;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AsyncValueView<List<SonarrHealth>>(
      value: health,
      data: (healthItems) {
        if (healthItems.isEmpty) return const SizedBox.shrink();
        return Card(
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
          margin: const EdgeInsets.only(bottom: 24), // 24dp gap
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
                    const SizedBox(width: Insets.sm),
                    Text(
                      'System Health Warnings',
                      style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const Divider(),
                ...healthItems.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: Insets.xs),
                    child: Text(
                      '• ${item.message}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BackupsSection extends StatelessWidget {
  const _BackupsSection({required this.backups, required this.instance});

  final AsyncValue<List<SonarrBackup>> backups;
  final Instance instance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('System Backups', style: theme.textTheme.titleMedium),
            Consumer(
              builder: (context, ref, _) {
                return TextButton.icon(
                  icon: const Icon(Icons.backup),
                  label: const Text('Backup Now'),
                  onPressed: () async {
                    final apiObj = await ref.read(sonarrApiProvider(instance).future);
                    await apiObj.runSystemTask('Backup');
                    ref.invalidate(sonarrBackupsProvider(instance));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Backup task triggered')),
                      );
                    }
                  },
                );
              },
            ),
          ],
        ),
        const Divider(height: Insets.lg),
        AsyncValueView<List<SonarrBackup>>(
          value: backups,
          data: (backupList) {
            if (backupList.isEmpty) {
              return const Text('No backups found');
            }
            return Column(
              children: backupList.map((backup) {
                final String sizeStr = '${(backup.size / 1024 / 1024).toStringAsFixed(1)} MB';
                final String timeStr = DateFormat.yMMMd().add_jm().format(backup.time.toLocal());

                return Consumer(
                  builder: (context, ref, _) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.backup),
                      title: Text(backup.name, style: theme.textTheme.bodyMedium),
                      subtitle: Text('Size: $sizeStr • Date: $timeStr'),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                        onPressed: () async {
                          final apiObj = await ref.read(sonarrApiProvider(instance).future);
                          await apiObj.deleteBackup(backup.id);
                          ref.invalidate(sonarrBackupsProvider(instance));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Backup deleted')),
                            );
                          }
                        },
                      ),
                    );
                  },
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
