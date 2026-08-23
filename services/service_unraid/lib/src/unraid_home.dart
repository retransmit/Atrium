import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/unraid_models.dart';
import 'unraid_providers.dart';

/// Unraid: array health and Docker containers.
///
/// Read-only. Unraid's public GraphQL API exposes plenty to read, but its
/// documented Docker mutations only organise the web UI's folders, so there is
/// nothing here that can start or stop a container. Better to show that
/// honestly than to offer a button that cannot work.
class UnraidHome extends ConsumerWidget {
  const UnraidHome({required this.instance, this.drawer, super.key});

  final Instance instance;
  final Widget? drawer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<UnraidArray> arrayAsync =
        ref.watch(unraidArrayProvider(instance));
    final AsyncValue<List<UnraidContainer>> containersAsync =
        ref.watch(unraidContainersProvider(instance));

    return Scaffold(
      drawer: drawer,
      appBar: AppBar(
        leading: drawer == null
            ? null
            : Builder(
                builder: (BuildContext context) => IconButton(
                  icon: const Icon(Icons.menu),
                  tooltip: 'Open menu',
                  onPressed: Scaffold.of(context).openDrawer,
                ),
              ),
        title: Text(instance.name),
      ),
      body: EasyRefresh(
        header: const ClassicHeader(
          dragText: 'Pull to refresh',
          armedText: 'Release ready',
          readyText: 'Refreshing...',
          processingText: 'Refreshing...',
          processedText: 'Updated',
          failedText: 'Failed',
          messageText: 'Last updated at %T',
        ),
        onRefresh: () async {
          ref.invalidate(unraidArrayProvider(instance));
          ref.invalidate(unraidContainersProvider(instance));
        },
        child: ListView(
          padding: Insets.page,
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[
            AsyncValueView<UnraidArray>(
              value: arrayAsync,
              onRetry: () => ref.invalidate(unraidArrayProvider(instance)),
              loading: const _CardPlaceholder(height: 210),
              data: (UnraidArray array) => _ArraySection(array: array),
            ),
            const SizedBox(height: Insets.xl),
            AsyncValueView<List<UnraidContainer>>(
              value: containersAsync,
              onRetry: () => ref.invalidate(unraidContainersProvider(instance)),
              loading: const _CardPlaceholder(height: 160),
              data: (List<UnraidContainer> containers) =>
                  _DockerSection(containers: containers),
            ),
            const SizedBox(height: Insets.xl),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Array
// ---------------------------------------------------------------------------

class _ArraySection extends StatelessWidget {
  const _ArraySection({required this.array});

  final UnraidArray array;

  @override
  Widget build(BuildContext context) {
    final List<UnraidDisk> parity = array.parityDisks;
    final List<UnraidDisk> data = array.dataDisks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ArrayHero(array: array),
        if (array.disks.isNotEmpty) ...<Widget>[
          const SizedBox(height: Insets.lg),
          if (parity.isNotEmpty) ...<Widget>[
            _SectionHeader(
              title: 'Parity',
              trailing: parity.length == 1 ? '1 disk' : '${parity.length} disks',
            ),
            const SizedBox(height: Insets.sm),
            _DiskGroup(disks: parity),
            const SizedBox(height: Insets.lg),
          ],
          if (data.isNotEmpty) ...<Widget>[
            _SectionHeader(
              title: 'Data',
              trailing: data.length == 1 ? '1 disk' : '${data.length} disks',
            ),
            const SizedBox(height: Insets.sm),
            _DiskGroup(disks: data),
          ],
        ],
      ],
    );
  }
}

class _ArrayHero extends StatelessWidget {
  const _ArrayHero({required this.array});

  final UnraidArray array;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    final bool started = array.isStarted;
    final List<UnraidDisk> faults = array.unhealthyDisks;
    // The icon reports whether the array is up, not whether every disk is
    // well: a fault already has the banner below and the health stat beside
    // it, and colouring all three red buries which one is the actual news.
    final Color accent = started ? _okGreen(cs) : cs.onSurfaceVariant;

    final UnraidDisk? warmest = array.warmestDisk;
    final int parityCount = array.parityDisks.length;

    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(Insets.md),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: Icon(
                  started ? Icons.dns_rounded : Icons.pause_circle_outline,
                  size: 28,
                  color: accent,
                ),
              ),
              const SizedBox(width: Insets.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Array ${array.stateLabel}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: Insets.xxs),
                    Text(
                      parityCount == 0
                          ? 'No parity protection'
                          : parityCount == 1
                              ? 'Single parity'
                              : '$parityCount parity disks',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (faults.isNotEmpty) ...<Widget>[
            const SizedBox(height: Insets.lg),
            _FaultBanner(faults: faults),
          ],
          const SizedBox(height: Insets.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: _StatBox(
                  label: 'DISKS',
                  value: '${array.disks.length}',
                  unit: parityCount > 0
                      ? '${array.dataDisks.length} data'
                      : 'total',
                  valueColor: cs.onSurface,
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: _StatBox(
                  label: 'WARMEST',
                  value: warmest?.temp == null ? '--' : '${warmest!.temp}',
                  unit: warmest == null ? 'all idle' : warmest.name,
                  valueColor: warmest == null
                      ? cs.onSurfaceVariant
                      : _heatColor(warmest.heat, cs),
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: _StatBox(
                  label: 'HEALTH',
                  value: faults.isEmpty ? 'OK' : '${faults.length}',
                  unit: faults.isEmpty ? 'all disks' : 'need attention',
                  valueColor: faults.isEmpty ? _okGreen(cs) : cs.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Names the disks that are actually in trouble.
///
/// A bare count sends you to a browser to find out which disk; the names cost
/// no more space and answer the only question the warning raises.
class _FaultBanner extends StatelessWidget {
  const _FaultBanner({required this.faults});

  final List<UnraidDisk> faults;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final String detail = faults
        .map((UnraidDisk d) => '${d.name} ${d.statusLabel.toLowerCase()}')
        .join(', ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.warning_amber_rounded, size: 20, color: cs.error),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Text(
              detail,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiskGroup extends StatelessWidget {
  const _DiskGroup({required this.disks});

  final List<UnraidDisk> disks;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < disks.length; i++) ...<Widget>[
            if (i > 0)
              Divider(height: 1, indent: Insets.lg, color: cs.outlineVariant),
            _DiskRow(disk: disks[i]),
          ],
        ],
      ),
    );
  }
}

class _DiskRow extends StatelessWidget {
  const _DiskRow({required this.disk});

  final UnraidDisk disk;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final bool healthy = disk.isHealthy;
    final String? size = disk.size;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.md,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            disk.isParity ? Icons.shield_outlined : Icons.storage_rounded,
            size: 20,
            color: healthy ? cs.onSurfaceVariant : cs.error,
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  disk.name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!healthy) ...<Widget>[
                  const SizedBox(height: Insets.xxs),
                  Text(
                    disk.statusLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (size != null && size.isNotEmpty) ...<Widget>[
            Text(
              size,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: Insets.md),
          ],
          _TempPill(disk: disk),
        ],
      ),
    );
  }
}

/// The temperature, banded by [DiskHeat] so a hot disk reads as hot without
/// anyone having to know what a normal number looks like.
class _TempPill extends StatelessWidget {
  const _TempPill({required this.disk});

  final UnraidDisk disk;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final int? temp = disk.temp;

    // A spun-down disk reports nothing, which is not a fault and should not
    // look like one.
    if (temp == null) {
      return Text(
        'idle',
        style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
      );
    }

    final Color color = _heatColor(disk.heat, cs);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.sm,
        vertical: Insets.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: Radii.chip,
      ),
      child: Text(
        '$temp deg',
        style: theme.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The one green used for a healthy state, kept off the colour scheme so it
/// reads the same as the green end of the temperature scale.
Color _okGreen(ColorScheme cs) => cs.brightness == Brightness.dark
    ? const Color(0xFF66BB6A)
    : const Color(0xFF2E7D32);

/// Cool blue through to hot red, deliberately not taken from the colour
/// scheme: the dark theme's error colour is a pale pink that reads cooler than
/// the orange one band below it, which would put the scale in the wrong order.
/// Each band is given a light and a dark variant so it stays legible either
/// way.
Color _heatColor(DiskHeat heat, ColorScheme cs) {
  final bool dark = cs.brightness == Brightness.dark;
  return switch (heat) {
    DiskHeat.hot => dark ? const Color(0xFFFF5252) : const Color(0xFFC62828),
    DiskHeat.warm => dark ? const Color(0xFFFFA726) : const Color(0xFFE65100),
    DiskHeat.normal => dark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32),
    DiskHeat.cool => dark ? const Color(0xFF4FC3F7) : const Color(0xFF0277BD),
    DiskHeat.unknown => cs.outline,
  };
}

// ---------------------------------------------------------------------------
// Docker
// ---------------------------------------------------------------------------

enum _DockerFilter { all, running, stopped, issues }

class _DockerSection extends StatefulWidget {
  const _DockerSection({required this.containers});

  final List<UnraidContainer> containers;

  @override
  State<_DockerSection> createState() => _DockerSectionState();
}

class _DockerSectionState extends State<_DockerSection> {
  _DockerFilter _filter = _DockerFilter.all;

  List<UnraidContainer> _apply(_DockerFilter filter) {
    return switch (filter) {
      _DockerFilter.all => widget.containers,
      _DockerFilter.running =>
        widget.containers.where((UnraidContainer c) => c.isRunning).toList(),
      _DockerFilter.stopped =>
        widget.containers.where((UnraidContainer c) => !c.isRunning).toList(),
      _DockerFilter.issues =>
        widget.containers.where((UnraidContainer c) => c.isUnhealthy).toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final List<UnraidContainer> all = widget.containers;

    if (all.isEmpty) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _SectionHeader(title: 'Docker'),
          SizedBox(height: Insets.sm),
          EmptyView(
            title: 'No containers',
            message: 'This server is not running any Docker containers.',
          ),
        ],
      );
    }

    final int running = _apply(_DockerFilter.running).length;
    final int issues = _apply(_DockerFilter.issues).length;
    // A filter that would show nothing is worse than no filter: keep the chip
    // out of the row rather than offering an empty result.
    final List<_DockerFilter> available = <_DockerFilter>[
      _DockerFilter.all,
      if (running > 0) _DockerFilter.running,
      if (running < all.length) _DockerFilter.stopped,
      if (issues > 0) _DockerFilter.issues,
    ];
    final List<UnraidContainer> shown = _apply(_filter);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionHeader(
          title: 'Docker',
          trailing: '$running of ${all.length} running',
        ),
        if (available.length > 1) ...<Widget>[
          const SizedBox(height: Insets.md),
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.sm,
            children: <Widget>[
              for (final _DockerFilter f in available)
                FilterChip(
                  label: Text(_filterLabel(f, all.length, running, issues)),
                  selected: _filter == f,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => setState(() => _filter = f),
                ),
            ],
          ),
        ],
        const SizedBox(height: Insets.md),
        _ContainerGroup(containers: shown),
      ],
    );
  }

  String _filterLabel(_DockerFilter f, int total, int running, int issues) =>
      switch (f) {
        _DockerFilter.all => 'All $total',
        _DockerFilter.running => 'Running $running',
        _DockerFilter.stopped => 'Stopped ${total - running}',
        _DockerFilter.issues => 'Issues $issues',
      };
}

class _ContainerGroup extends StatelessWidget {
  const _ContainerGroup({required this.containers});

  final List<UnraidContainer> containers;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    // Anything failing a healthcheck first, then what is up, then by name, so
    // the thing that needs a person is never buried.
    final List<UnraidContainer> sorted = <UnraidContainer>[...containers]
      ..sort((UnraidContainer a, UnraidContainer b) {
        if (a.isUnhealthy != b.isUnhealthy) return a.isUnhealthy ? -1 : 1;
        if (a.isRunning != b.isRunning) return a.isRunning ? -1 : 1;
        return a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            );
      });

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < sorted.length; i++) ...<Widget>[
            if (i > 0)
              Divider(height: 1, indent: Insets.lg, color: cs.outlineVariant),
            _ContainerRow(container: sorted[i]),
          ],
        ],
      ),
    );
  }
}

class _ContainerRow extends StatelessWidget {
  const _ContainerRow({required this.container});

  final UnraidContainer container;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    // A failing healthcheck still reports RUNNING, so state alone would show
    // it as fine. It gets its own icon rather than only its own colour, which
    // a red-green colour blind eye would miss.
    final (IconData icon, Color color) = container.isUnhealthy
        ? (Icons.warning_amber_rounded, cs.error)
        : container.isRunning
            ? (Icons.play_arrow_rounded, _okGreen(cs))
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
                  container.displayName,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: Insets.xxs),
                Text(
                  container.status ??
                      (container.isRunning ? 'Running' : 'Stopped'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: container.isUnhealthy ? cs.error : cs.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (container.autoStart) ...<Widget>[
            const SizedBox(width: Insets.sm),
            Tooltip(
              message: 'Starts with the array',
              child: Icon(Icons.bolt, size: 18, color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final String? sub = trailing;

    return Row(
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        if (sub != null)
          Text(
            sub,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
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
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: Insets.md,
        horizontal: Insets.sm,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: Insets.xs),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
          ),
          const SizedBox(height: Insets.xxs),
          Text(
            unit,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _CardPlaceholder extends StatelessWidget {
  const _CardPlaceholder({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: const Center(child: ExpressiveProgressIndicator()),
    );
  }
}
