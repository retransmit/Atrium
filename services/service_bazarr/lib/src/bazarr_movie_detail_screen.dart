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
            onPressed: () =>
                Navigator.of(context, rootNavigator: true).push(
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
          final ThemeData theme = Theme.of(context);
          return ListView(
            padding: Insets.page,
            children: <Widget>[
              Text('Subtitles', style: theme.textTheme.titleSmall),
              const SizedBox(height: Insets.sm),
              if (movie.subtitles.isEmpty)
                Text(
                  'None downloaded',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                )
              else
                BazarrSubtitleChips(
                  present: movie.subtitles,
                  onDeletePresent: (BazarrSubtitle s) =>
                      _confirmDelete(context, ref, s),
                ),
              const SizedBox(height: Insets.lg),
              Text('Missing', style: theme.textTheme.titleSmall),
              const SizedBox(height: Insets.sm),
              if (movie.missingSubtitles.isEmpty)
                Text(
                  'Nothing missing',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                )
              else
                BazarrSubtitleChips(missing: movie.missingSubtitles),
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

String _err(Object e) {
  if (e is NetworkException && e.message.isNotEmpty) {
    return e.message;
  }
  return 'request failed';
}
