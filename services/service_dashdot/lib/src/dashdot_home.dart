import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';

import 'dashdot_history_providers.dart';
import 'dashdot_providers.dart';

class DashdotHome extends ConsumerWidget {
  const DashdotHome({required this.instance, super.key});
  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoAsync = ref.watch(dashdotInfoProvider(instance));

    return infoAsync.when(
      data: (info) {
        if (info == null) {
          return const Center(child: Text('Failed to load Dashdot info.'));
        }

        final cpu = info.cpu;
        final ram = info.ram;
        final storageList = info.storage ?? [];
        final network = info.network;

        final rawStorageLoad = ref
            .watch(dashdotStorageLoadProvider(instance))
            .value;
        List<dynamic> rawStorageList = [];
        if (rawStorageLoad != null && rawStorageLoad is List) {
          rawStorageList = rawStorageLoad;
        }

        const refreshHeader = ClassicHeader(
          dragText: 'Pull to refresh',
          armedText: 'Release ready',
          readyText: 'Refreshing...',
          processingText: 'Refreshing...',
          processedText: 'Succeeded',
          noMoreText: 'No more',
          failedText: 'Failed',
          messageText: 'Last updated at %T',
        );

        Future<void> onRefresh() async {
          ref.invalidate(dashdotInfoProvider(instance));
          ref.invalidate(dashdotConfigProvider(instance));
        }

        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              TabBar(
                tabs: const [
                  Tab(text: 'Live Metrics'),
                  Tab(text: 'System Information'),
                ],
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant,
                indicatorColor: Theme.of(context).colorScheme.primary,
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    EasyRefresh(
                      header: refreshHeader,
                      onRefresh: onRefresh,
                      child: ListView(
                        padding: const EdgeInsets.all(Insets.md),
                        children: [
                          DashdotRingMetricsCard(instance: instance),
                          DashdotGpusRow(instance: instance),
                          const SizedBox(height: Insets.md),
                          DashdotOsCard(instance: instance),
                          const SizedBox(height: Insets.md),
                          DashdotStatsRow(instance: instance),
                        ],
                      ),
                    ),
                    EasyRefresh(
                      header: refreshHeader,
                      onRefresh: onRefresh,
                      child: ListView(
                        padding: const EdgeInsets.all(Insets.md),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: Insets.sm),
                            child: Text(
                              'CPU INFORMATION',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                          _InfoBox(
                            title: 'CPU',
                            subtitle: cpu?.cpuBrand ?? 'Unknown',
                            details:
                                '${cpu?.cores ?? '?'} Cores / ${cpu?.threads ?? '?'} Threads\n${cpu?.freq ?? '?'} GHz',
                            icon: Icons.memory,
                          ),
                          const SizedBox(height: Insets.lg),

                          Padding(
                            padding: const EdgeInsets.only(bottom: Insets.sm),
                            child: Text(
                              'RAM INFORMATION',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                          _InfoBox(
                            title: 'RAM',
                            subtitle: ram != null && ram.totalCapacity != null
                                ? '${ram.totalCapacity} GB'
                                : 'Unknown',
                            details: (ram?.sticks?.isNotEmpty ?? false)
                                ? '${ram!.sticks!.first.type ?? ''} @ ${ram.sticks!.first.frequency ?? '?'} MHz'
                                : '',
                            icon: Icons.developer_board,
                          ),
                          const SizedBox(height: Insets.lg),

                          Padding(
                            padding: const EdgeInsets.only(bottom: Insets.sm),
                            child: Text(
                              'NETWORK INFORMATION',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                          Builder(
                            builder: (context) {
                              String speedStr = '? Mbps';
                              if (network?.interfaceSpeed != null) {
                                if (network!.interfaceSpeed is num) {
                                  final speed = (network.interfaceSpeed as num)
                                      .toDouble();
                                  if (speed >= 1000) {
                                    final gbps = speed / 1000;
                                    speedStr =
                                        '${gbps == gbps.truncate() ? gbps.toInt() : gbps.toStringAsFixed(1)} Gbps';
                                  } else {
                                    speedStr =
                                        '${speed == speed.truncate() ? speed.toInt() : speed.toStringAsFixed(0)} Mbps';
                                  }
                                } else {
                                  speedStr = '${network.interfaceSpeed} Mbps';
                                }
                              }
                              return _InfoBox(
                                title: 'Network',
                                subtitle: network?.type ?? 'Unknown',
                                details: 'Speed: $speedStr',
                                icon: Icons.network_check,
                              );
                            },
                          ),
                          const SizedBox(height: Insets.lg),

                          Padding(
                            padding: const EdgeInsets.only(bottom: Insets.sm),
                            child: Text(
                              'STORAGE INFORMATION',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ),
                          if (storageList.isNotEmpty) ...[
                            ...storageList.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final disk = entry.value;

                              double usedGB = 0.0;
                              if (idx < rawStorageList.length) {
                                final used = rawStorageList[idx];
                                if (used is num) usedGB = used.toDouble();
                              }

                              final capacityGB =
                                  (disk.capacity as num?)?.toDouble() ?? 0.0;
                              final usedPct = capacityGB > 0
                                  ? (usedGB / capacityGB * 100)
                                  : 0.0;

                              final displayType = disk.type == 'HD'
                                  ? 'HDD'
                                  : (disk.type ?? 'Disk');
                              final brand = disk.storageBrand;
                              final subtitle =
                                  (brand != null && brand.isNotEmpty)
                                  ? '$brand ($displayType)'
                                  : displayType;

                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: Insets.md,
                                ),
                                child: _InfoBox(
                                  title: 'Storage ${idx + 1}',
                                  subtitle: subtitle,
                                  details:
                                      'Total: $capacityGB GB${usedGB < 0 ? "" : "\nUsed: ${usedGB.toStringAsFixed(1)} GB (${usedPct.toStringAsFixed(1)}%)"}',
                                  icon: Icons.storage,
                                ),
                              );
                            }),
                          ] else
                            const _InfoBox(
                              title: 'Storage',
                              subtitle: 'Unknown',
                              details: '',
                              icon: Icons.storage,
                            ),
                          const SizedBox(height: Insets.sm),

                          if ((info.gpu != null && info.gpu!.isNotEmpty) ||
                              ref
                                  .watch(dashdotGpuHistoryProvider(instance))
                                  .layout
                                  .isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: Insets.sm,
                                top: Insets.sm,
                              ),
                              child: Text(
                                'GPU INFORMATION',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ),
                          if (info.gpu != null && info.gpu!.isNotEmpty) ...[
                            ...info.gpu!.map(
                              (g) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: Insets.md,
                                ),
                                child: _InfoBox(
                                  title: 'GPU',
                                  subtitle: (g['name'] as String?) ?? 'GPU',
                                  details: '${g['memory']} MB',
                                  icon: Icons.monitor,
                                ),
                              ),
                            ),
                          ] else if (ref
                              .watch(dashdotGpuHistoryProvider(instance))
                              .layout
                              .isNotEmpty) ...[
                            ...ref
                                .watch(dashdotGpuHistoryProvider(instance))
                                .layout
                                .map(
                                  (g) => Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: Insets.md,
                                    ),
                                    child: _InfoBox(
                                      title: 'GPU',
                                      subtitle: (g['name'] as String?) ?? 'GPU',
                                      details:
                                          'Load: ${g['load']}%  Mem: ${g['memory']}MB',
                                      icon: Icons.monitor,
                                    ),
                                  ),
                                ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicatorM3E()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}

class DashdotRingMetricsCard extends StatelessWidget {
  const DashdotRingMetricsCard({required this.instance, super.key});
  final Instance instance;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Insets.md),
        side: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Live Metrics',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.lg),
            DashdotRingMetrics(instance: instance),
          ],
        ),
      ),
    );
  }
}

class DashdotRingMetrics extends ConsumerWidget {
  const DashdotRingMetrics({required this.instance, super.key});
  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cpuHistory = ref.watch(dashdotCpuHistoryProvider(instance)).overall;
    final ramHistory = ref.watch(dashdotRamHistoryProvider(instance));
    final storageHistory = ref.watch(dashdotStorageHistoryProvider(instance));

    final currentCpu = cpuHistory.values.isNotEmpty
        ? cpuHistory.values.last
        : 0.0;

    final info = ref.watch(dashdotInfoProvider(instance)).value;

    final num totalRamGb = (info?.ram?.totalCapacity as num?) ?? 0;
    final currentRamLoad = ramHistory.values.isNotEmpty
        ? ramHistory.values.last
        : 0.0;
    final double ramPct = totalRamGb > 0
        ? (currentRamLoad / totalRamGb * 100)
        : 0.0;

    double totalDiskGb = 0;
    for (final disk in info?.storage ?? []) {
      totalDiskGb += (disk.capacity as num?)?.toDouble() ?? 0;
    }
    final currentDiskLoad = storageHistory.values.isNotEmpty
        ? storageHistory.values.last
        : 0.0;
    final double diskPct = totalDiskGb > 0
        ? (currentDiskLoad / totalDiskGb * 100)
        : 0.0;

    final cpuColor = Theme.of(context).colorScheme.primary;
    final ramColor = Theme.of(context).colorScheme.tertiary;
    final diskColor = Theme.of(context).colorScheme.secondary;

    return Row(
      children: [
        Expanded(
          child: Center(
            child: SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _buildRing(140, currentCpu / 100, cpuColor),
                  _buildRing(105, ramPct / 100, ramColor),
                  _buildRing(70, diskPct / 100, diskColor),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: Insets.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LegendItem(
              color: cpuColor,
              label: 'CPU',
              value: '${currentCpu.toStringAsFixed(0)}%',
            ),
            const SizedBox(height: Insets.md),
            _LegendItem(
              color: ramColor,
              label: 'RAM',
              value: '${ramPct.toStringAsFixed(0)}%',
            ),
            const SizedBox(height: Insets.md),
            _LegendItem(
              color: diskColor,
              label: 'Disk',
              value: '${diskPct.toStringAsFixed(0)}%',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRing(double size, double value, Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: value.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double animValue, Widget? child) {
        return SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicatorM3E(
            shape: ProgressM3EShape.flat,
            value: animValue,
            trackColor: color.withValues(alpha: 0.15),
            activeColor: color,
            strokeWidth: 12,
            gap: 0,
          ),
        );
      },
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class DashdotOsCard extends ConsumerWidget {
  const DashdotOsCard({required this.instance, super.key});
  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(dashdotInfoProvider(instance)).value;
    final os = info?.os;
    final cpu = info?.cpu;

    final distro = os?.distro ?? 'Unknown OS';
    final release = os?.release ?? '';
    final title = release.isNotEmpty ? '$distro $release' : distro;

    final cpuBrand = cpu?.cpuBrand ?? 'Unknown';
    final cores = cpu?.cores != null ? '${cpu!.cores} core' : '';
    final archRaw = os?.arch;
    final arch = archRaw == null
        ? ''
        : (archRaw.startsWith('x') ? archRaw : 'x$archRaw');

    final List<String> subs = [
      if (cpuBrand.isNotEmpty) cpuBrand.split(' ')[0],
      if (cores.isNotEmpty) cores,
      if (arch.isNotEmpty) arch,
    ];

    final uptimeSecs = (os?.uptime ?? 0).toInt();
    final int days = uptimeSecs ~/ 86400;
    final int hours = (uptimeSecs % 86400) ~/ 3600;
    final int mins = (uptimeSecs % 3600) ~/ 60;
    final String uptimeStr = days > 0
        ? '${days}d ${hours}h'
        : '${hours}h ${mins}m';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Insets.md),
        side: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.computer,
                size: 28,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subs.join(' • '),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  uptimeStr,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'uptime',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class DashdotGpusRow extends ConsumerWidget {
  const DashdotGpusRow({required this.instance, super.key});
  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(dashdotInfoProvider(instance)).value;
    final gpuState = ref.watch(dashdotGpuHistoryProvider(instance));
    if (gpuState.layout.isEmpty) return const SizedBox.shrink();

    final gpuColor = Theme.of(context).colorScheme.error;

    return Padding(
      padding: const EdgeInsets.only(top: Insets.md),
      child: Column(
        children: gpuState.layout.asMap().entries.map((entry) {
          final idx = entry.key;
          final gpu = entry.value;
          final load = (gpu['load'] as num?)?.toDouble() ?? 0.0;
          final mem = (gpu['memory'] as num?)?.toDouble() ?? 0.0;

          String? infoName;
          double totalMem = 0.0;
          if (info?.gpu != null && idx < info!.gpu!.length) {
            final gInfo = info.gpu![idx];
            infoName = (gInfo['name'] ?? gInfo['model']) as String?;
            totalMem = (gInfo['memory'] as num?)?.toDouble() ?? 0.0;
          }

          final String name =
              infoName ??
              (gpu['name'] as String?) ??
              (gpuState.layout.length > 1 ? 'GPU $idx' : 'GPU');
          final double? memProgress = mem == 0
              ? 0.0
              : (totalMem > 0 ? (mem / totalMem).clamp(0.0, 1.0) : null);

          return Card(
            elevation: 0,
            margin: EdgeInsets.only(
              bottom: idx < gpuState.layout.length - 1 ? Insets.md : 0,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Insets.md),
              side: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: gpuColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.memory, size: 32, color: gpuColor),
                  ),
                  const SizedBox(width: Insets.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: Insets.md),
                        Row(
                          children: [
                            SizedBox(
                              width: 40,
                              child: Text(
                                'Load',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ),
                            const SizedBox(width: Insets.sm),
                            Expanded(
                              child: TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0, end: load / 100),
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeOutCubic,
                                builder: (context, val, _) =>
                                    LinearProgressIndicatorM3E(
                                      value: val,
                                      shape: ProgressM3EShape.flat,
                                      activeColor: gpuColor,
                                      trackColor: gpuColor.withValues(
                                        alpha: 0.15,
                                      ),
                                    ),
                              ),
                            ),
                            const SizedBox(width: Insets.md),
                            SizedBox(
                              width: 45,
                              child: Text(
                                '${load.toStringAsFixed(0)}%',
                                textAlign: TextAlign.end,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Insets.sm),
                        Row(
                          children: [
                            SizedBox(
                              width: 40,
                              child: Text(
                                'Mem',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ),
                            const SizedBox(width: Insets.sm),
                            Expanded(
                              child: memProgress == null
                                  ? LinearProgressIndicatorM3E(
                                      shape: ProgressM3EShape.flat,
                                      activeColor: Theme.of(
                                        context,
                                      ).colorScheme.tertiary,
                                      trackColor: Theme.of(context)
                                          .colorScheme
                                          .tertiary
                                          .withValues(alpha: 0.15),
                                    )
                                  : TweenAnimationBuilder<double>(
                                      tween: Tween<double>(
                                        begin: 0,
                                        end: memProgress,
                                      ),
                                      duration: const Duration(
                                        milliseconds: 600,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      builder: (context, val, _) =>
                                          LinearProgressIndicatorM3E(
                                            value: val,
                                            shape: ProgressM3EShape.flat,
                                            activeColor: Theme.of(
                                              context,
                                            ).colorScheme.tertiary,
                                            trackColor: Theme.of(context)
                                                .colorScheme
                                                .tertiary
                                                .withValues(alpha: 0.15),
                                          ),
                                    ),
                            ),
                            const SizedBox(width: Insets.md),
                            SizedBox(
                              width: 55,
                              child: Text(
                                '${mem.toStringAsFixed(0)} MB',
                                textAlign: TextAlign.end,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class DashdotStatsRow extends ConsumerWidget {
  const DashdotStatsRow({required this.instance, super.key});
  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final netHistory = ref.watch(dashdotNetworkHistoryProvider(instance));
    final cpuHistoryState = ref.watch(dashdotCpuHistoryProvider(instance));

    final currentDownBytes = netHistory.down.isNotEmpty
        ? netHistory.down.last
        : 0.0;
    final currentUpBytes = netHistory.up.isNotEmpty ? netHistory.up.last : 0.0;

    String formatBytes(double bytes) {
      if (bytes >= 1048576)
        return '${(bytes / 1048576).toStringAsFixed(1)} MB/s';
      if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB/s';
      return '${bytes.toStringAsFixed(0)} B/s';
    }

    final downStr = formatBytes(currentDownBytes).split(' ');
    final upStr = formatBytes(currentUpBytes).split(' ');

    double cpuTemp = 0.0;
    if (cpuHistoryState.cores.isNotEmpty &&
        cpuHistoryState.cores.first.temps.isNotEmpty) {
      cpuTemp = cpuHistoryState.cores.first.temps.last;
    }

    return Row(
      children: [
        Expanded(
          child: _StatBox(
            label: 'DOWN',
            value: downStr[0],
            unit: downStr[1],
            valueColor: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: Insets.sm),
        Expanded(
          child: _StatBox(
            label: 'UP',
            value: upStr[0],
            unit: upStr[1],
            valueColor: Theme.of(context).colorScheme.tertiary,
          ),
        ),
        const SizedBox(width: Insets.sm),
        Expanded(
          child: _StatBox(
            label: 'TEMP',
            value: '${cpuTemp.toStringAsFixed(0)}°',
            unit: 'CPU',
            valueColor: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.unit,
    required this.valueColor,
  });

  final String label;
  final String value;
  final String unit;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Insets.md),
        side: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: Insets.md,
          horizontal: Insets.sm,
        ),
        child: Column(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: valueColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              unit,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.title,
    required this.subtitle,
    required this.details,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String details;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Insets.md),
        side: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(width: Insets.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      details,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
