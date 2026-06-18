import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bazarr_movie_detail_screen.dart';
import 'bazarr_providers.dart';
import 'models/bazarr_models.dart';

/// The Movies tab: all Radarr-backed movies with their subtitle status. Tapping
/// a row opens the movie subtitle view.
class BazarrMoviesTab extends ConsumerWidget {
  const BazarrMoviesTab({required this.instance, super.key});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<BazarrMovie>> movies =
        ref.watch(bazarrMoviesProvider(instance));
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(bazarrMoviesProvider(instance)),
      child: AsyncValueView<List<BazarrMovie>>(
        value: movies,
        onRetry: () => ref.invalidate(bazarrMoviesProvider(instance)),
        data: (List<BazarrMovie> list) {
          if (list.isEmpty) {
            return const EmptyView(
              icon: Icons.movie_outlined,
              title: 'No movies',
              message: 'Bazarr has no movies from Radarr yet.',
            );
          }
          return ListView.builder(
            padding: Insets.pageH,
            itemCount: list.length,
            itemBuilder: (BuildContext context, int index) {
              final BazarrMovie m = list[index];
              final bool allDone = m.missingSubtitles.isEmpty;
              final String status = allDone
                  ? (m.subtitles.isEmpty
                      ? 'No subtitles needed'
                      : '${m.subtitles.length} subtitles')
                  : '${m.missingSubtitles.length} missing subtitles';
              return ListTile(
                leading: const Icon(Icons.movie_outlined),
                title: Text(
                  m.year != null ? '${m.title} (${m.year})' : m.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  status,
                  style: allDone ? TextStyle(color: Colors.green.shade700) : null,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BazarrMovieDetailScreen(
                      instance: instance,
                      radarrId: m.radarrId,
                      title: m.year != null ? '${m.title} (${m.year})' : m.title,
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
