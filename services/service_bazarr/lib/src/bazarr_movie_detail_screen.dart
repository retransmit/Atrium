import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bazarr_api.dart';
import 'bazarr_providers.dart';
import 'bazarr_search_screen.dart';
import 'bazarr_subtitle_chips.dart';
import 'models/bazarr_models.dart';

/// Per-movie subtitle view: present and missing subtitles, a manual-search
/// action, and delete on downloaded subs. Provider-backed so it refreshes in
/// place after a download or delete.
class BazarrMovieDetailScreen extends ConsumerWidget {
  const BazarrMovieDetailScreen({
    required this.instance,
    required this.radarrId,
    required this.title,
    super.key,
  });

  final Instance instance;
  final int radarrId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<BazarrMovie>> movies =
        ref.watch(bazarrMoviesProvider(instance));
    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          IconButton(
            tooltip: 'Search subtitles',
            icon: const Icon(Icons.subtitles_outlined),
            onPressed: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(
                builder: (_) => BazarrSubtitleSearchScreen(
                  instance: instance,
                  isMovie: true,
                  id: radarrId,
                  seriesId: 0,
                  title: title,
                ),
              ),
            ),
          ),
        ],
      ),
      body: AsyncValueView<List<BazarrMovie>>(
        value: movies,
        onRetry: () => ref.invalidate(bazarrMoviesProvider(instance)),
        data: (List<BazarrMovie> list) {
          BazarrMovie? movie;
          for (final BazarrMovie m in list) {
            if (m.radarrId == radarrId) {
              movie = m;
              break;
            }
          }
          if (movie == null) {
            return const EmptyView(
              icon: Icons.movie_outlined,
              title: 'Movie not found',
              message: 'It may have been removed from Bazarr.',
            );
          }
          final BazarrMovie m = movie;
          return ListView(
            padding: Insets.page,
            children: <Widget>[
              _HeaderCard(movie: m),
              const SizedBox(height: Insets.md),
              _SectionCard(
                title: 'Subtitles',
                child: m.subtitles.isEmpty
                    ? const _MutedLine('None downloaded')
                    : BazarrSubtitleChips(
                        present: m.subtitles,
                        onDeletePresent: (BazarrSubtitle s) =>
                            _confirmDelete(context, ref, s),
                      ),
              ),
              const SizedBox(height: Insets.md),
              _SectionCard(
                title: 'Missing',
                child: m.missingSubtitles.isEmpty
                    ? const _MutedLine('Nothing missing')
                    : BazarrSubtitleChips(missing: m.missingSubtitles),
              ),
              const SizedBox(height: Insets.xl),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    BazarrSubtitle s,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    if (!(s.path?.isNotEmpty ?? false)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'This subtitle is embedded in the video and cannot be removed here.',
          ),
        ),
      );
      return;
    }
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Delete subtitle?'),
        content: Text(
          'Remove the ${s.name.isNotEmpty ? s.name : s.code2.toUpperCase()} '
          'subtitle for this movie?',
        ),
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
      await api.deleteMovieSubtitle(radarrId: radarrId, subtitle: s);
      ref.invalidate(bazarrMoviesProvider(instance));
      ref.invalidate(bazarrWantedProvider(instance));
      ref.invalidate(bazarrBadgesProvider(instance));
      messenger.showSnackBar(const SnackBar(content: Text('Subtitle deleted')));
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Delete failed: ${_err(e)}')),
      );
    }
  }
}

/// Tonal hero header: a poster-stand-in tile, the title, and metadata pills.
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.movie});

  final BazarrMovie movie;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final int present = movie.subtitles.length;
    final int missing = movie.missingSubtitles.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.movie_outlined, color: cs.primary, size: 28),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  movie.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: Insets.sm),
                Wrap(
                  spacing: Insets.xs,
                  runSpacing: Insets.xs,
                  children: <Widget>[
                    if (movie.year != null)
                      _MetaPill(
                        icon: Icons.calendar_today,
                        label: '${movie.year}',
                        color: cs.secondary,
                      ),
                    _MetaPill(
                      icon: movie.monitored
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      label: movie.monitored ? 'Monitored' : 'Unmonitored',
                      color: movie.monitored ? cs.primary : cs.outline,
                    ),
                    _MetaPill(
                      icon: Icons.subtitles_outlined,
                      label: '$present subs',
                      color: cs.tertiary,
                    ),
                    if (missing > 0)
                      _MetaPill(
                        icon: Icons.report_outlined,
                        label: '$missing missing',
                        color: cs.error,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tonal section card with a titleMedium w700 heading.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: Insets.sm),
          child,
        ],
      ),
    );
  }
}

/// Small tonal metadata pill (icon + label), tinted by [color].
class _MetaPill extends StatelessWidget {
  const _MetaPill({
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

/// A muted "nothing here" line for an empty section.
class _MutedLine extends StatelessWidget {
  const _MutedLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Text(
      text,
      style:
          theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
    );
  }
}

String _err(Object e) {
  if (e is NetworkException && e.message.isNotEmpty) {
    return e.message;
  }
  return 'request failed';
}
