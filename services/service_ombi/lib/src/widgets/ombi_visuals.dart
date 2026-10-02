import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../models/ombi_models.dart';

/// The icon that stands in for a kind of media where its artwork is missing.
IconData ombiKindIcon(OmbiMediaKind kind) => switch (kind) {
      OmbiMediaKind.movie => Icons.movie_outlined,
      OmbiMediaKind.tv => Icons.live_tv_outlined,
      OmbiMediaKind.music => Icons.album_outlined,
    };

/// A small rounded label: a status, a tag, a genre.
class OmbiPill extends StatelessWidget {
  const OmbiPill({
    required this.label,
    required this.foreground,
    required this.background,
    this.icon,
    super.key,
  });

  final String label;
  final Color foreground;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A title's artwork, with the kind's icon where there is none or it will
/// not load. Films and shows get a two-by-three poster box; an album cover
/// is square, and a poster box would cut its sides off.
class OmbiPoster extends StatelessWidget {
  const OmbiPoster({
    required this.url,
    required this.kind,
    required this.width,
    this.radius = 12,
    super.key,
  });

  final String? url;
  final OmbiMediaKind kind;
  final double width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Widget fallback = ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Center(
        child: Icon(ombiKindIcon(kind), color: cs.onSurfaceVariant),
      ),
    );
    final String? url = this.url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: kind == OmbiMediaKind.music
            ? width
            : width / Sizes.posterAspect,
        child: url == null
            ? fallback
            : AtriumNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                // Decoded for a dense screen, not at the source's full size.
                memCacheWidth: (width * 3).round(),
                errorWidget: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}

/// TheMovieDB's score out of ten. Drawn white on a scrim, since it sits
/// over artwork of any colour.
class OmbiRatingPill extends StatelessWidget {
  const OmbiRatingPill({required this.rating, super.key});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.star_rounded, size: 13, color: Colors.amber),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
