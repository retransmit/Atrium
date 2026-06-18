import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bazarr_providers.dart';
import 'bazarr_series_detail_screen.dart';
import 'models/bazarr_models.dart';

/// The Series tab: all Sonarr-backed series with their subtitle status. Tapping
/// a row opens the per-episode subtitle view.
class BazarrSeriesTab extends ConsumerWidget {
  const BazarrSeriesTab({required this.instance, super.key});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<BazarrSeries>> series =
        ref.watch(bazarrSeriesProvider(instance));
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(bazarrSeriesProvider(instance)),
      child: AsyncValueView<List<BazarrSeries>>(
        value: series,
        onRetry: () => ref.invalidate(bazarrSeriesProvider(instance)),
        data: (List<BazarrSeries> list) {
          if (list.isEmpty) {
            return const EmptyView(
              icon: Icons.live_tv_outlined,
              title: 'No series',
              message: 'Bazarr has no series from Sonarr yet.',
            );
          }
          return ListView.builder(
            padding: Insets.pageH,
            itemCount: list.length,
            itemBuilder: (BuildContext context, int index) {
              final BazarrSeries s = list[index];
              final bool allDone = s.episodeMissingCount == 0;
              return ListTile(
                leading: const Icon(Icons.live_tv_outlined),
                title: Text(
                  s.year != null ? '${s.title} (${s.year})' : s.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  allDone
                      ? '${s.episodeFileCount} episodes · all subtitled'
                      : '${s.episodeMissingCount} missing subtitles',
                  style: allDone
                      ? TextStyle(color: Colors.green.shade700)
                      : null,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BazarrSeriesDetailScreen(
                      instance: instance,
                      series: s,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
