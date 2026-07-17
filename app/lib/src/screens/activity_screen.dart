import 'package:core_models/core_models.dart';
import 'package:core_profile/core_profile.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../activity/activity_cards.dart';
import '../activity/activity_providers.dart';

/// Cross-service activity feed: a summary stat bar, active streams from every
/// media server / Tautulli instance, and in-flight downloads from every
/// download client / *arr queue. One unreachable server surfaces as a chip
/// and never blocks the rest of the feed.
class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ActivityStreamsState streamsState =
        ref.watch(activityStreamsProvider);
    final ActivityDownloadsState downloadsState =
        ref.watch(activityDownloadsProvider);
    final ActivitySummary summary = ref.watch(activitySummaryProvider);
    final List<Instance> instances = ref.watch(activeInstancesProvider);

    // Instance names are only shown when a service kind has several
    // configured instances; a single Plex doesn't need labeling.
    final Map<ServiceKind, int> kindCounts = <ServiceKind, int>{};
    for (final Instance instance in instances) {
      kindCounts[instance.kind] = (kindCounts[instance.kind] ?? 0) + 1;
    }
    String? labelFor(Instance instance) =>
        (kindCounts[instance.kind] ?? 0) > 1 ? instance.name : null;

    final bool nothing = streamsState.streams.isEmpty &&
        downloadsState.downloads.isEmpty &&
        streamsState.errors.isEmpty &&
        downloadsState.errors.isEmpty;

    final Widget body;
    if (nothing && (streamsState.anyLoading || downloadsState.anyLoading)) {
      body = const Center(child: ExpressiveProgressIndicator());
    } else if (nothing) {
      body = const EmptyView(
        icon: Icons.swap_vert_outlined,
        title: 'Nothing happening right now',
        message: 'Active streams and transfers will show up here.',
      );
    } else {
      final bool showStreams =
          streamsState.streams.isNotEmpty || streamsState.errors.isNotEmpty;
      final bool showDownloads = downloadsState.downloads.isNotEmpty ||
          downloadsState.errors.isNotEmpty;
      body = EasyRefresh(
          header: const ClassicHeader(
            dragText: 'Pull to refresh',
            armedText: 'Release ready',
            readyText: 'Refreshing...',
            processingText: 'Refreshing...',
            processedText: 'Succeeded',
            failedText: 'Failed',
            messageText: 'Last updated at %T',
          ),
        onRefresh: () async => refreshActivity(ref),
        child: ListView(
          padding: Insets.page,
          children: <Widget>[
            _SummaryBar(summary: summary),
            if (showStreams) ...<Widget>[
              _SectionHeader(
                title: 'Now Streaming',
                trailing: '${streamsState.streams.length}',
              ),
              if (streamsState.errors.isNotEmpty)
                ActivitySourceErrorChips(errors: streamsState.errors),
              for (final ActivityStream stream in streamsState.streams)
                ActivityStreamCard(
                  key: ValueKey<String>(stream.key),
                  stream: stream,
                  instanceLabel: labelFor(stream.instance),
                  onTap: () => _openStream(context, stream),
                ),
            ],
            if (showStreams && showDownloads) const SizedBox(height: Insets.sm),
            if (showDownloads) ...<Widget>[
              _SectionHeader(
                title: 'Transfers',
                trailing: <String>[
                  '${downloadsState.downloads.length}',
                  if (summary.totalDlBps > 0)
                    '↓ ${fmtSpeedBps(summary.totalDlBps)}',
                  if (summary.totalUpBps > 0)
                    '↑ ${fmtSpeedBps(summary.totalUpBps)}',
                ].join(' · '),
              ),
              if (downloadsState.errors.isNotEmpty)
                ActivitySourceErrorChips(errors: downloadsState.errors),
              for (final ActivityDownload download in downloadsState.downloads)
                ActivityDownloadCard(
                  key: ValueKey<String>(download.key),
                  download: download,
                  instanceLabel: labelFor(download.instance),
                  onTap: () => context.go(
                    AtriumRoutes.servicePath(
                      download.instance.kind.name,
                      download.instance.id,
                    ),
                  ),
                ),
            ],
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (BuildContext context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                openDrawer(context);
              },
            );
          },
        ),
        title: const Text('Activity'),
      ),
      body: body,
    );
  }

  /// Streams with a dedicated screen push it full-screen; the rest (Tautulli)
  /// jump to the source service.
  void _openStream(BuildContext context, ActivityStream stream) {
    final Widget Function(BuildContext)? builder = stream.onOpenBuilder;
    if (builder != null) {
      pushScreen<void>(context, builder(context));
    } else {
      context.go(
        AtriumRoutes.servicePath(
          stream.instance.kind.name,
          stream.instance.id,
        ),
      );
    }
  }
}

/// Three-tile stat bar: stream count, download count, and the summed
/// download rate.
class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.summary});

  final ActivitySummary summary;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: Insets.md),
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.md,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _StatTile(
              icon: Icons.sensors,
              value: '${summary.streamCount}',
              label: summary.streamCount == 1 ? 'Stream' : 'Streams',
              color: cs.primary,
            ),
          ),
          const _StatDivider(),
          Expanded(
            child: _StatTile(
              icon: Icons.swap_vert,
              value: '${summary.downloadCount}',
              label: summary.downloadCount == 1 ? 'Transfer' : 'Transfers',
              color: cs.secondary,
            ),
          ),
          const _StatDivider(),
          Expanded(
            child: _StatTile(
              icon: Icons.speed,
              value: summary.totalUpBps > 0
                  ? '↓ ${fmtSpeedBps(summary.totalDlBps)}'
                      '  ↑ ${fmtSpeedBps(summary.totalUpBps)}'
                  : fmtSpeedBps(summary.totalDlBps),
              label: 'Speed',
              color: cs.tertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 6),
        // Scale down instead of ellipsizing: the speed tile can carry both a
        // download and an upload rate at once.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 44,
        color: Theme.of(context).colorScheme.outlineVariant,
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
        ],
      ),
    );
  }
}
