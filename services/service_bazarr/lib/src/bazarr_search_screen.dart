import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bazarr_api.dart';
import 'bazarr_providers.dart';
import 'models/bazarr_models.dart';

/// Manual subtitle search for one episode or movie: lists provider results and
/// downloads the chosen one. The search hits live providers, so it can take a
/// few seconds.
class BazarrSubtitleSearchScreen extends ConsumerWidget {
  const BazarrSubtitleSearchScreen({
    required this.instance,
    required this.isMovie,
    required this.id,
    required this.seriesId,
    required this.title,
    super.key,
  });

  final Instance instance;
  final bool isMovie;

  /// Sonarr episode id, or Radarr movie id.
  final int id;

  /// Sonarr series id (episodes only; 0 for movies).
  final int seriesId;

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final BazarrSearchArgs args = (instance: instance, id: id);
    final AsyncValue<List<BazarrSubtitleSearchResult>> results = ref.watch(
      isMovie
          ? bazarrMovieSearchProvider(args)
          : bazarrEpisodeSearchProvider(args),
    );
    void invalidate() => ref.invalidate(
          isMovie
              ? bazarrMovieSearchProvider(args)
              : bazarrEpisodeSearchProvider(args),
        );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search subtitles'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(
              left: Insets.lg,
              right: Insets.lg,
              bottom: Insets.sm,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
      body: AsyncValueView<List<BazarrSubtitleSearchResult>>(
        value: results,
        onRetry: invalidate,
        data: (List<BazarrSubtitleSearchResult> list) {
          if (list.isEmpty) {
            return const EmptyView(
              icon: Icons.search_off,
              title: 'No subtitles found',
              message: 'No provider returned a match.',
            );
          }
          return ListView.builder(
            padding: Insets.pageH,
            itemCount: list.length,
            itemBuilder: (BuildContext context, int i) => _ResultCard(
              instance: instance,
              isMovie: isMovie,
              id: id,
              seriesId: seriesId,
              result: list[i],
            ),
          );
        },
      ),
    );
  }
}

class _ResultCard extends ConsumerStatefulWidget {
  const _ResultCard({
    required this.instance,
    required this.isMovie,
    required this.id,
    required this.seriesId,
    required this.result,
  });

  final Instance instance;
  final bool isMovie;
  final int id;
  final int seriesId;
  final BazarrSubtitleSearchResult result;

  @override
  ConsumerState<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends ConsumerState<_ResultCard> {
  bool _downloading = false;

  Future<void> _download() async {
    setState(() => _downloading = true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState nav = Navigator.of(context);
    try {
      final BazarrApi api =
          await ref.read(bazarrApiProvider(widget.instance).future);
      if (widget.isMovie) {
        await api.downloadMovieSubtitle(
          radarrId: widget.id,
          result: widget.result,
        );
        ref.invalidate(bazarrMoviesProvider(widget.instance));
      } else {
        await api.downloadEpisodeSubtitle(
          seriesId: widget.seriesId,
          episodeId: widget.id,
          result: widget.result,
        );
        ref.invalidate(
          bazarrEpisodesProvider(
            (instance: widget.instance, seriesId: widget.seriesId),
          ),
        );
      }
      ref.invalidate(bazarrWantedProvider(widget.instance));
      ref.invalidate(bazarrBadgesProvider(widget.instance));
      messenger.showSnackBar(
        const SnackBar(content: Text('Subtitle downloaded')),
      );
      nav.pop();
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Download failed: ${_err(e)}')),
      );
      if (mounted) {
        setState(() => _downloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final BazarrSubtitleSearchResult r = widget.result;
    final bool hi = r.hearingImpaired == 'True';
    final bool forced = r.forced == 'True';
    return Card(
      margin: const EdgeInsets.only(bottom: Insets.sm),
      child: ListTile(
        isThreeLine: true,
        title: Text(
          '${r.language.toUpperCase()} • ${r.provider}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (r.releaseInfo.isNotEmpty)
              Text(
                r.releaseInfo.join(' / '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 2),
            Wrap(
              spacing: Insets.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text('Score ${r.score}', style: theme.textTheme.labelSmall),
                if (hi) Text('HI', style: theme.textTheme.labelSmall),
                if (forced) Text('Forced', style: theme.textTheme.labelSmall),
                if (r.uploader != null && r.uploader!.isNotEmpty)
                  Text(
                    r.uploader!,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
              ],
            ),
          ],
        ),
        trailing: _downloading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: ExpressiveProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                tooltip: 'Download',
                icon: const Icon(Icons.download_outlined),
                onPressed: _download,
              ),
      ),
    );
  }
}

String _err(Object e) {
  if (e is NetworkException && e.message.isNotEmpty) {
    return e.message;
  }
  return 'request failed';
}
