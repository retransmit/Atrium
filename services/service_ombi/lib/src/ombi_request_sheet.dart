import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/ombi_models.dart';
import 'ombi_failure.dart';
import 'ombi_providers.dart';
import 'ombi_strings.dart';
import 'services/ombi_client.dart';
import 'widgets/ombi_visuals.dart';

/// Opens the title sheet for [hit] on the root navigator.
Future<void> showOmbiRequestSheet({
  required BuildContext context,
  required Instance instance,
  required OmbiSearchHit hit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    // The sheet draws its own handle so the backdrop can run to its top
    // edge, and the clip is what rounds the artwork's corners.
    clipBehavior: Clip.antiAlias,
    builder: (BuildContext _) => OmbiRequestSheet(instance: instance, hit: hit),
  );
}

/// What a title is, where it stands in Ombi, and a way to request it if it
/// can be.
///
/// It opens with what the list already knew about the title and fills in
/// the rest when Ombi's title page arrives, so there is something to read
/// straight away and something left to read if that page never comes.
class OmbiRequestSheet extends ConsumerStatefulWidget {
  const OmbiRequestSheet({
    required this.instance,
    required this.hit,
    super.key,
  });

  final Instance instance;
  final OmbiSearchHit hit;

  @override
  ConsumerState<OmbiRequestSheet> createState() => _OmbiRequestSheetState();
}

class _OmbiRequestSheetState extends ConsumerState<OmbiRequestSheet> {
  bool _busy = false;

  OmbiTitleKey get _key => (
        instance: widget.instance,
        kind: widget.hit.kind,
        tmdbId: widget.hit.tmdbId,
      );

  Future<void> _request(Future<void> Function(OmbiClient client) action) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await runOmbiAction(ref, widget.instance, action);
      ref.invalidate(ombiTitleStateProvider(_key));
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Requested ${widget.hit.title}')),
      );
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(describeOmbiFailure(error))),
      );
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final OmbiSearchHit hit = widget.hit;
    final AsyncValue<OmbiTitleState> lookup =
        ref.watch(ombiTitleStateProvider(_key));
    final OmbiTitleState? page = lookup.value;

    final String? overview = page?.overview ?? hit.overview;
    final double? rating = page?.rating ?? hit.rating;
    final List<String> genres = page?.genres ?? const <String>[];
    // The colour the sheet itself is drawn in, which the backdrop fades to.
    final Color sheetColor = theme.bottomSheetTheme.modalBackgroundColor ??
        theme.bottomSheetTheme.backgroundColor ??
        cs.surfaceContainerLow;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      child: SingleChildScrollView(
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _Header(
                hit: hit,
                posterUrl: hit.posterUrl ?? page?.posterUrl,
                backdropUrl: page?.backdropUrl ?? hit.backdropUrl,
                // A title page still on its way may bring a backdrop, so
                // its place is kept and the sheet does not jump when it
                // lands.
                keepBackdropPlace: lookup.isLoading,
                tagline: page?.tagline,
                facts: ombiTitleFacts(
                  kind: hit.kind,
                  year: page?.year ?? hit.year,
                  runtimeMinutes: page?.runtimeMinutes,
                  network: page?.network,
                  releaseStatus: page?.releaseStatus,
                ),
                sheetColor: sheetColor,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.lg,
                  Insets.md,
                  Insets.lg,
                  Insets.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (rating != null || genres.isNotEmpty) ...<Widget>[
                      Wrap(
                        spacing: Insets.xs,
                        runSpacing: Insets.xs,
                        children: <Widget>[
                          if (rating != null)
                            OmbiPill(
                              label: rating.toStringAsFixed(1),
                              icon: Icons.star_rounded,
                              foreground: cs.onSecondaryContainer,
                              background: cs.secondaryContainer,
                            ),
                          for (final String genre in genres)
                            OmbiPill(
                              label: genre,
                              foreground: cs.onSurfaceVariant,
                              background: cs.surfaceContainerHighest,
                            ),
                        ],
                      ),
                      const SizedBox(height: Insets.md),
                    ],
                    if (overview != null) ...<Widget>[
                      OverviewBox(overview: overview),
                      const SizedBox(height: Insets.lg),
                    ],
                    lookup.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (Object error, StackTrace _) => Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              describeOmbiFailure(
                                error,
                                lookup: OmbiLookup.title,
                              ),
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: cs.error),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                ref.invalidate(ombiTitleStateProvider(_key)),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                      data: (OmbiTitleState state) => _standing(theme, state),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Where the title stands, or the way to request it. Worded the way
  /// Ombi's own title page words it.
  Widget _standing(ThemeData theme, OmbiTitleState state) {
    final ColorScheme cs = theme.colorScheme;
    if (state.available) {
      return _Standing(
        icon: Icons.check_circle_outline_rounded,
        label: 'Available',
        foreground: cs.onTertiaryContainer,
        background: cs.tertiaryContainer,
      );
    }
    if (state.denied) {
      return _Standing(
        icon: Icons.block_rounded,
        label: 'Denied',
        detail: state.deniedReason,
        foreground: cs.onErrorContainer,
        background: cs.errorContainer,
      );
    }
    if (state.requested) {
      return _Standing(
        icon: Icons.schedule_rounded,
        label: 'Requested',
        foreground: cs.onPrimaryContainer,
        background: cs.primaryContainer,
      );
    }

    final OmbiSearchHit hit = widget.hit;
    VoidCallback? tv(OmbiTvSeasons seasons) => _busy
        ? null
        : () => _request(
              (OmbiClient c) => c.requestService.requestTv(hit.tmdbId, seasons),
            );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (state.partlyAvailable) ...<Widget>[
          _Standing(
            icon: Icons.incomplete_circle_rounded,
            label: 'Partially Available',
            foreground: cs.onSecondaryContainer,
            background: cs.secondaryContainer,
          ),
          const SizedBox(height: Insets.md),
        ],
        if (hit.kind == OmbiMediaKind.movie)
          FilledButton.icon(
            onPressed: _busy
                ? null
                : () => _request(
                      (OmbiClient c) =>
                          c.requestService.requestMovie(hit.tmdbId),
                    ),
            icon: const Icon(Icons.add),
            label: const Text('Request'),
          )
        else ...<Widget>[
          FilledButton(
            onPressed: tv(OmbiTvSeasons.all),
            child: const Text('All seasons'),
          ),
          const SizedBox(height: Insets.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.tonal(
                  onPressed: tv(OmbiTvSeasons.first),
                  child: const Text('First season'),
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: tv(OmbiTvSeasons.latest),
                  child: const Text('Latest season'),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: Insets.sm),
        Text(
          "Requests made here are made as Ombi's admin, so Ombi approves "
          'them and sends them on straight away.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// The top of the sheet: the backdrop fading into the sheet, the poster
/// standing over its foot, and the title with the facts about it.
class _Header extends StatelessWidget {
  const _Header({
    required this.hit,
    required this.posterUrl,
    required this.backdropUrl,
    required this.keepBackdropPlace,
    required this.tagline,
    required this.facts,
    required this.sheetColor,
  });

  final OmbiSearchHit hit;
  final String? posterUrl;
  final String? backdropUrl;
  final bool keepBackdropPlace;
  final String? tagline;
  final List<String> facts;
  final Color sheetColor;

  static const double _posterWidth = 92;
  static const double _posterFrame = 2;
  static const double _posterHeight =
      _posterWidth / Sizes.posterAspect + _posterFrame * 2;

  /// How far the poster rises over the backdrop.
  static const double _overlap = 52;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final String? backdrop = backdropUrl;
    final bool hasBackdrop = backdrop != null || keepBackdropPlace;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (hasBackdrop)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                ColoredBox(color: cs.surfaceContainerHigh),
                if (backdrop != null)
                  AtriumNetworkImage(
                    imageUrl: backdrop,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                // The artwork fades out into the sheet, so the title under
                // it sits on the sheet's own colour whatever the picture.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const <double>[0.45, 1],
                      colors: <Color>[
                        sheetColor.withValues(alpha: 0),
                        sheetColor,
                      ],
                    ),
                  ),
                ),
                // A shade across the top, so the handle shows on artwork of
                // any colour, a white one included.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: <double>[0, 0.3],
                      colors: <Color>[Color(0x73000000), Color(0x00000000)],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: Insets.sm),
                    child: _Handle(color: Colors.white.withValues(alpha: 0.8)),
                  ),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Insets.md),
            child: Center(
              child: _Handle(color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // The poster rises over the foot of the backdrop, and the
              // row is only as tall as the part of it left below.
              SizedBox(
                width: _posterWidth + _posterFrame * 2,
                height: hasBackdrop ? _posterHeight - _overlap : _posterHeight,
                child: OverflowBox(
                  alignment: Alignment.bottomCenter,
                  minHeight: _posterHeight,
                  maxHeight: _posterHeight,
                  child: Container(
                    padding: const EdgeInsets.all(_posterFrame),
                    decoration: BoxDecoration(
                      color: sheetColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: OmbiPoster(
                      url: posterUrl,
                      kind: hit.kind,
                      width: _posterWidth,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      hit.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (tagline != null) ...<Widget>[
                      const SizedBox(height: Insets.xxs),
                      Text(
                        tagline!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: Insets.xs),
                    Text(
                      facts.join(' · '),
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The small bar that says a sheet can be dragged.
class _Handle extends StatelessWidget {
  const _Handle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 32,
        height: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      );
}

/// Where a title stands, as a tinted band across the sheet, with the reason
/// under it when Ombi gave one.
class _Standing extends StatelessWidget {
  const _Standing({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
    this.detail,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: foreground),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
                if (detail != null)
                  Text(
                    detail!,
                    style: text.bodySmall?.copyWith(color: foreground),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
