import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/radarr_movie.dart';
import 'radarr_api.dart';
import 'radarr_providers.dart';
import 'radarr_release_search_screen.dart';

/// Detail view for one Radarr movie: a backdrop hero header, a frosted info
/// card (poster, status, rating), actions (monitor toggle, search), and the
/// overview.
class MovieDetailScreen extends ConsumerWidget {
  const MovieDetailScreen({
    required this.instance,
    required this.movieId,
    super.key,
  });

  final Instance instance;
  final int movieId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<RadarrMovie> movie =
        ref.watch(radarrMovieByIdProvider((instance, movieId)));

    return Scaffold(
      body: movie.when(
        data: (RadarrMovie m) => _Body(instance: instance, movie: m),
        loading: () => const _DetailShell(
          child: Center(child: ExpressiveProgressIndicator()),
        ),
        error: (Object e, _) => _DetailShell(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(Insets.lg),
              child: Text('Could not load movie.\n$e', textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    );
  }
}

/// Scaffold shell with a plain app bar, used for the loading/error states so a
/// back button is always available.
class _DetailShell extends StatelessWidget {
  const _DetailShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: <Widget>[
        const SliverAppBar(pinned: true, title: Text('Movie')),
        SliverFillRemaining(hasScrollBody: false, child: child),
      ],
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.instance, required this.movie});

  final Instance instance;
  final RadarrMovie movie;

  void _refresh(WidgetRef ref) {
    ref.invalidate(radarrMovieByIdProvider((instance, movie.id)));
    ref.invalidate(radarrMoviesProvider(instance));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final RadarrApi? api = ref.watch(radarrApiProvider(instance)).value;

    final RadarrImage? poster = movie.images
        .firstWhereOrNull((RadarrImage i) => i.coverType == 'poster');
    final String? imageUrl = poster == null ? null : api?.posterUrl(poster);

    final RadarrImage? fanart = movie.images
        .firstWhereOrNull((RadarrImage i) => i.coverType == 'fanart');
    final String? fanartUrl = fanart == null ? null : api?.posterUrl(fanart);

    return RefreshIndicator(
      onRefresh: () async => _refresh(ref),
      child: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            stretch: true,
            backgroundColor: cs.surface,
            surfaceTintColor: cs.surfaceTint,
            actions: <Widget>[
              _MovieMenu(instance: instance, movie: movie),
            ],
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: false,
              titlePadding: const EdgeInsetsDirectional.only(
                start: 56,
                bottom: 16,
                end: 16,
              ),
              title: Text(
                movie.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
              ),
              background: _Backdrop(fanartUrl: fanartUrl),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              Insets.lg,
              Insets.md,
              Insets.lg,
              Insets.lg,
            ),
            sliver: SliverList.list(
              children: <Widget>[
                _Header(movie: movie, imageUrl: imageUrl),
                const SizedBox(height: Insets.md),
                _ActionsRow(
                  instance: instance,
                  movie: movie,
                  onChanged: _refresh,
                ),
                if (movie.overview != null &&
                    movie.overview!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: Insets.md),
                  _OverviewCard(text: movie.overview!),
                ],
                const SizedBox(height: Insets.xl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.movie, required this.imageUrl});

  final RadarrMovie movie;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.65)
                : theme.colorScheme.surfaceContainerLowest
                    .withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(Insets.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Hero(
                tag: 'movie-poster-${movie.id}',
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 110,
                      height: 165,
                      child: imageUrl == null
                          ? Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.movie_outlined,
                                color: theme.colorScheme.outline,
                                size: 32,
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: imageUrl!,
                              fit: BoxFit.cover,
                              memCacheWidth: 500,
                              placeholder: (BuildContext context, String url) =>
                                  Container(
                                color: theme.colorScheme.surfaceContainerHighest,
                                child: const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: ExpressiveProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: theme.colorScheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.movie_outlined,
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Insets.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: Insets.xs,
                      runSpacing: 4,
                      children: <Widget>[
                        if (movie.year != null) _InfoChip(label: '${movie.year}'),
                        if (movie.runtime != null && movie.runtime! > 0)
                          _InfoChip(label: '${movie.runtime} min'),
                        if (movie.studio != null && movie.studio!.isNotEmpty)
                          _InfoChip(label: movie.studio!),
                      ],
                    ),
                    const SizedBox(height: Insets.sm),
                    _StatusPill(movie: movie),
                    if (movie.ratings?.tmdb != null &&
                        movie.ratings!.tmdb!.value > 0) ...<Widget>[
                      const SizedBox(height: Insets.md),
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.star,
                            size: 14,
                            color: theme.colorScheme.tertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            movie.ratings!.tmdb!.value.toStringAsFixed(1),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.movie});

  final RadarrMovie movie;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool downloaded = movie.hasFile;
    final String label = downloaded
        ? 'Downloaded${movie.sizeOnDisk > 0 ? ' • ${_fmtSize(movie.sizeOnDisk)}' : ''}'
        : 'Missing';
    final Color tint =
        downloaded ? theme.colorScheme.primary : theme.colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tint.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            downloaded ? Icons.download_done : Icons.error_outline,
            size: 14,
            color: tint,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: tint, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.fanartUrl});

  final String? fanartUrl;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (fanartUrl != null)
          CachedNetworkImage(
            imageUrl: fanartUrl!,
            fit: BoxFit.cover,
            memCacheWidth: 1080,
            errorWidget: (_, __, ___) =>
                ColoredBox(color: cs.surfaceContainerHigh),
          )
        else
          ColoredBox(color: cs.surfaceContainerHigh),
        // Scrim so the title stays legible and the image melts into the surface.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                cs.surface.withValues(alpha: 0.0),
                cs.surface.withValues(alpha: 0.55),
                cs.surface,
              ],
              stops: const <double>[0.35, 0.75, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
      ),
    );
  }
}

class _ActionsRow extends ConsumerWidget {
  const _ActionsRow({
    required this.instance,
    required this.movie,
    required this.onChanged,
  });

  final Instance instance;
  final RadarrMovie movie;
  final void Function(WidgetRef) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: movie.monitored
              ? FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        theme.colorScheme.primaryContainer.withValues(alpha: 0.8),
                    foregroundColor: theme.colorScheme.onPrimaryContainer,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.bookmark, size: 20),
                  label: const Text(
                    'Monitored',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _toggleMonitored(ref),
                )
              : OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: theme.colorScheme.outline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.bookmark_border, size: 20),
                  label: const Text('Unmonitored'),
                  onPressed: () => _toggleMonitored(ref),
                ),
        ),
        const SizedBox(width: Insets.md),
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.search, size: 20),
            label: const Text(
              'Search',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () async {
              final RadarrApi api =
                  await ref.read(radarrApiProvider(instance).future);
              await api.searchMovie(movie.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Search started')),
                );
              }
            },
          ),
        ),
        const SizedBox(width: Insets.sm),
        IconButton.filledTonal(
          icon: const Icon(Icons.manage_search),
          tooltip: 'Manual search',
          onPressed: () {
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(
                builder: (_) => RadarrReleaseSearchScreen(
                  instance: instance,
                  movie: movie,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _toggleMonitored(WidgetRef ref) async {
    final RadarrApi api = await ref.read(radarrApiProvider(instance).future);
    final Map<String, dynamic> raw = await api.getMovieRaw(movie.id);
    raw['monitored'] = !movie.monitored;
    await api.updateMovieRaw(raw);
    onChanged(ref);
  }
}

class _MovieMenu extends ConsumerWidget {
  const _MovieMenu({required this.instance, required this.movie});

  final Instance instance;
  final RadarrMovie movie;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      onSelected: (String v) async {
        if (v == 'delete') {
          await _confirmDelete(context, ref);
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('Delete movie'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    bool deleteFiles = false;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) => AlertDialog(
          title: const Text('Delete movie?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(movie.title),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Also delete file on disk'),
                value: deleteFiles,
                onChanged: (bool? v) =>
                    setState(() => deleteFiles = v ?? false),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
    if (ok ?? false) {
      final RadarrApi api = await ref.read(radarrApiProvider(instance).future);
      await api.deleteMovie(movie.id, deleteFiles: deleteFiles);
      ref.invalidate(radarrMoviesProvider(instance));
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }
}

String _fmtSize(int bytes) {
  if (bytes <= 0) {
    return '0 B';
  }
  const List<String> units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
  double value = bytes.toDouble();
  int unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final String text = value >= 100 || unit == 0
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$text ${units[unit]}';
}
