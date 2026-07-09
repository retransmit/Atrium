import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import 'models/seerr_discover.dart';

/// The shared media card used on the Seerr detail screen and as the Requests-
/// tab tiles: a tall poster on the left, then title, metadata pills, a
/// prominent status/action, and rating. Styled to match the Sonarr module card.
class SeerrMediaCard extends StatelessWidget {
  const SeerrMediaCard({
    required this.item,
    this.requestedBy,
    this.action,
    this.trailing,
    super.key,
  });

  final SeerrDiscoverResult item;

  /// Optional "Requested by X" subtitle (used on the Requests tab).
  final String? requestedBy;

  /// The prominent status/action slot (the request button, or a status row).
  final Widget? action;

  /// Optional top-right widget (e.g. the request actions menu).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? runtimeLabel = item.isMovie
        ? (item.runtime != null && item.runtime! > 0
            ? _fmtRuntime(item.runtime!)
            : null)
        : (item.numberOfEpisodes != null && item.numberOfEpisodes! > 0
            ? '${item.numberOfEpisodes} eps'
            : null);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 180),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(
                      width: 120,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: item.posterPath != null
                            ? Image.network(
                                'https://image.tmdb.org/t/p/w342${item.posterPath}',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _posterFallback(theme),
                              )
                            : _posterFallback(theme),
                      ),
                    ),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Padding(
                            // keep the title clear of the trailing menu
                            padding: EdgeInsets.only(
                              right: trailing != null ? 28 : 0,
                            ),
                            child: Text(
                              item.displayTitle,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                height: 1.1,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (requestedBy != null &&
                              requestedBy!.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 4),
                            Text(
                              'Requested by $requestedBy',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                          const SizedBox(height: Insets.sm),
                          Wrap(
                            spacing: Insets.sm,
                            runSpacing: Insets.xs,
                            children: <Widget>[
                              if (item.year != null)
                                SeerrInfoPill(label: item.year!),
                              SeerrInfoPill(
                                  label: item.isMovie ? 'Movie' : 'TV'),
                              if (item.status != null &&
                                  item.status!.isNotEmpty)
                                SeerrInfoPill(label: item.status!),
                              if (runtimeLabel != null)
                                SeerrInfoPill(label: runtimeLabel),
                            ],
                          ),
                          if (action != null) ...<Widget>[
                            const SizedBox(height: Insets.md),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: action,
                            ),
                          ],
                          const Spacer(),
                          if (item.voteAverage != null &&
                              item.voteAverage! > 0) ...<Widget>[
                            const SizedBox(height: Insets.sm),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  item.voteAverage!.toStringAsFixed(1),
                                  style: theme.textTheme.titleMedium,
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
          ),
          if (trailing != null) Positioned(top: 0, right: 0, child: trailing!),
        ],
      ),
    );
  }

  Widget _posterFallback(ThemeData theme) => ColoredBox(
        color: theme.colorScheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.image_not_supported)),
      );

  String _fmtRuntime(int minutes) {
    final int h = minutes ~/ 60;
    final int m = minutes % 60;
    if (h > 0) {
      return m == 0 ? '${h}h' : '${h}h ${m}m';
    }
    return '${m}m';
  }
}

/// A small rounded metadata pill (year, type, status, runtime, genre).
class SeerrInfoPill extends StatelessWidget {
  const SeerrInfoPill({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: theme.textTheme.labelMedium),
    );
  }
}

/// The Requests-tab card: a darkened backdrop banner fills the card, with the
/// year / title / requester / status overlaid on the left and the poster on
/// the right. Modeled on the Jellyseerr "Recent Requests" cards.
class SeerrRequestCard extends StatelessWidget {
  const SeerrRequestCard({
    required this.item,
    this.requestedBy,
    this.mediaStatus,
    this.requestStatus,
    this.trailing,
    super.key,
  });

  final SeerrDiscoverResult item;

  /// "Requested by X" name, shown next to an avatar.
  final String? requestedBy;

  /// Seerr media (download) status: 2 pending, 3 processing, 4 partial,
  /// 5 available.
  final int? mediaStatus;

  /// Request approval status: 1 pending, 2 approved, 3 declined, 4 failed,
  /// 5 completed.
  final int? requestStatus;

  /// Optional top-right widget (the request actions menu).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? backdrop = item.backdropPath;
    final List<Widget> pills = _statusPills();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: <Widget>[
          if (backdrop != null)
            Positioned.fill(
              child: Image.network(
                'https://image.tmdb.org/t/p/w780$backdrop',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          // Darken left-to-right so the overlaid text stays legible.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  stops: <double>[0.0, 0.6, 1.0],
                  colors: <Color>[
                    Color(0xE6000000), // black 90%
                    Color(0x99000000), // black 60%
                    Color(0x59000000), // black 35%
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Insets.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 150),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          if (item.year != null)
                            Text(
                              item.year!,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Padding(
                            padding: EdgeInsets.only(
                              right: trailing != null ? 28 : 0,
                            ),
                            child: Text(
                              item.displayTitle,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                height: 1.1,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (requestedBy != null &&
                              requestedBy!.isNotEmpty) ...<Widget>[
                            const SizedBox(height: Insets.sm),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const CircleAvatar(
                                  radius: 11,
                                  backgroundColor: Colors.white24,
                                  child: Icon(
                                    Icons.person,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    requestedBy!,
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(color: Colors.white),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (pills.isNotEmpty) ...<Widget>[
                            const SizedBox(height: Insets.sm),
                            Wrap(spacing: 6, runSpacing: 4, children: pills),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: Insets.md),
                    SizedBox(
                      width: 108,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: item.posterPath != null
                            ? Image.network(
                                'https://image.tmdb.org/t/p/w342${item.posterPath}',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _posterFallback(theme),
                              )
                            : _posterFallback(theme),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (trailing != null) Positioned(top: 0, right: 0, child: trailing!),
        ],
      ),
    );
  }

  Widget _posterFallback(ThemeData theme) => ColoredBox(
        color: theme.colorScheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.image_not_supported)),
      );

  List<Widget> _statusPills() {
    final List<Widget> pills = <Widget>[];
    final (Color, IconData, String)? avail = switch (mediaStatus) {
      5 => (const Color(0xFF22C55E), Icons.check_circle, 'Available'),
      4 => (
          const Color(0xFF14B8A6),
          Icons.check_circle_outline,
          'Partially Available',
        ),
      3 => (const Color(0xFF3B82F6), Icons.downloading, 'Processing'),
      2 => (const Color(0xFFF59E0B), Icons.hourglass_top, 'Pending'),
      _ => null,
    };
    if (avail != null) {
      pills.add(_pill(avail.$3, avail.$1, avail.$2));
    }
    // Approval state, only when it adds information beyond availability.
    final (Color, IconData, String)? appr = switch (requestStatus) {
      1 => (const Color(0xFFF97316), Icons.pending, 'Pending Approval'),
      3 => (const Color(0xFFEF4444), Icons.cancel, 'Declined'),
      4 => (const Color(0xFFEF4444), Icons.error_outline, 'Failed'),
      2 => pills.isEmpty
          ? (const Color(0xFF22C55E), Icons.check_circle, 'Approved')
          : null,
      _ => null,
    };
    if (appr != null) {
      pills.add(_pill(appr.$3, appr.$1, appr.$2));
    }
    return pills;
  }

  Widget _pill(String label, Color color, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      );
}
