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
          return ListView.separated(
            padding: Insets.page,
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: Insets.sm),
            itemBuilder: (BuildContext context, int index) =>
                _MovieCard(instance: instance, movie: list[index]),
          );
        },
      ),
    );
  }
}

class _MovieCard extends StatelessWidget {
  const _MovieCard({required this.instance, required this.movie});

  final Instance instance;
  final BazarrMovie movie;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final bool allDone = movie.missingSubtitles.isEmpty;
    final String status = allDone
        ? (movie.subtitles.isEmpty
            ? 'No subtitles needed'
            : '${movie.subtitles.length} subtitles')
        : '${movie.missingSubtitles.length} missing subtitles';
    final String title =
        movie.year != null ? '${movie.title} (${movie.year})' : movie.title;

    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (_) => BazarrMovieDetailScreen(
              instance: instance,
              radarrId: movie.radarrId,
              title: title,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.movie_outlined, color: cs.primary),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: Insets.xs),
                    _Pill(
                      icon: allDone
                          ? Icons.check_circle_outline
                          : Icons.subtitles_off_outlined,
                      label: status,
                      color: allDone ? cs.tertiary : cs.secondary,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Insets.sm),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small tonal metadata pill: a colored icon and label on a faint tint.
class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.color});

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
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
