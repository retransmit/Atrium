import 'package:flutter/material.dart';

/// Returns a human-friendly descriptor for a 1-5 rating.
String navidromeRatingLabel(int rating) {
  switch (rating) {
    case 1:
      return '1 Star • Poor';
    case 2:
      return '2 Stars • Fair';
    case 3:
      return '3 Stars • Good';
    case 4:
      return '4 Stars • Great';
    case 5:
      return '5 Stars • Masterpiece';
    default:
      return 'Not Rated';
  }
}

/// An interactive or read-only 5-star rating bar with generous touch targets.
class NavidromeRatingBar extends StatelessWidget {
  const NavidromeRatingBar({
    required this.rating,
    this.onRatingChanged,
    this.starSize = 36,
    this.hitTargetSize = 48,
    this.spacing = 4,
    this.activeColor = const Color(0xFFFFB300), // Amber
    this.inactiveColor,
    super.key,
  });

  /// Current rating (0 to 5).
  final int rating;

  /// Callback when user selects a rating. If null, the bar is read-only.
  final ValueChanged<int>? onRatingChanged;

  /// Diameter of each star icon.
  final double starSize;

  /// Minimum width & height for each star's touch target (defaults to 48 for mobile accessibility).
  final double hitTargetSize;

  /// Extra horizontal spacing between stars.
  final double spacing;

  /// Color for filled stars.
  final Color activeColor;

  /// Color for unfilled stars.
  final Color? inactiveColor;

  bool get isInteractive => onRatingChanged != null;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color defaultInactive = cs.onSurfaceVariant.withValues(alpha: 0.35);

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(5, (int index) {
        final int starValue = index + 1;
        final bool isFilled = starValue <= rating;
        final Color color =
            isFilled ? activeColor : (inactiveColor ?? defaultInactive);
        final IconData icon =
            isFilled ? Icons.star_rounded : Icons.star_outline_rounded;

        final Widget starIcon = Icon(icon, size: starSize, color: color);

        if (!isInteractive) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing / 2),
            child: SizedBox(
              width: starSize,
              height: starSize,
              child: starIcon,
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing / 2),
          child: SizedBox(
            width: hitTargetSize,
            height: hitTargetSize,
            child: Material(
              color: Colors.transparent,
              child: InkResponse(
                onTap: () {
                  // Tapping active star clears rating to 0
                  final int newRating = starValue == rating ? 0 : starValue;
                  onRatingChanged!(newRating);
                },
                radius: hitTargetSize / 2,
                splashColor: activeColor.withValues(alpha: 0.25),
                highlightColor: activeColor.withValues(alpha: 0.1),
                child: Center(child: starIcon),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Opens a spacious, thumb-friendly modal sheet for rating an album or track.
Future<void> showNavidromeRatingModal({
  required BuildContext context,
  required String title,
  String? subtitle,
  required int initialRating,
  required Future<void> Function(int newRating) onRatingChanged,
}) async {
  final ThemeData theme = Theme.of(context);
  final ColorScheme cs = theme.colorScheme;
  int currentRating = initialRating;

  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (BuildContext sheetContext) {
      return StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setModalState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Handle
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title & Subtitle
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Rating descriptor badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: currentRating > 0
                          ? Colors.amber.withValues(alpha: 0.15)
                          : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      navidromeRatingLabel(currentRating),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: currentRating > 0
                            ? (Colors.amber[800] ?? Colors.amber)
                            : cs.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Large, thumb-friendly stars (42px star in 52px hit target)
                  NavidromeRatingBar(
                    rating: currentRating,
                    starSize: 42,
                    hitTargetSize: 52,
                    onRatingChanged: (int newRating) async {
                      setModalState(() {
                        currentRating = newRating;
                      });
                      try {
                        await onRatingChanged(newRating);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to set rating: $e'),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Action buttons
                  if (currentRating > 0)
                    TextButton.icon(
                      onPressed: () async {
                        setModalState(() {
                          currentRating = 0;
                        });
                        try {
                          await onRatingChanged(0);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to clear rating: $e'),
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      label: const Text('Remove Rating'),
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
