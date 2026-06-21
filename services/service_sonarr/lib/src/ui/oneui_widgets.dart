part of '../sonarr_home.dart';

// ──────────────────────────────────────────────────────
// One UI Design System Widgets — One UI 8.5 Redesign
// ──────────────────────────────────────────────────────

/// Samsung One UI-style collapsing app bar used by every Sonarr tab.
/// Matches One UI 8.5 "Ambient Design" specs.
class _OneUIAppBar extends StatelessWidget {
  const _OneUIAppBar({
    required this.title,
    this.showLeading = true,
    this.expandedHeight = 220, // Comfortable expanded spacing pushing content into thumb zone
  });

  final String title;
  final bool showLeading;
  final double expandedHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final double safeTop = MediaQuery.of(context).padding.top;
    const double collapsedHeight = 56;

    return SliverAppBar(
      expandedHeight: expandedHeight,
      collapsedHeight: collapsedHeight,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: LayoutBuilder(
        builder: (ctx, c) {
          final double expandedH = expandedHeight + safeTop;
          final double range = expandedH - collapsedHeight - safeTop;
          final double t = range <= 0
              ? 0
              : ((expandedH - c.maxHeight) / range).clamp(0.0, 1.0);

          // t = 0 (expanded), t = 1 (collapsed/scrolling off)

          final double opacity = (1.0 - t * 1.5).clamp(0.0, 1.0);

          return Stack(
            fit: StackFit.expand,
            children: [
              // Large centered title (fades out during scroll-down)
              if (opacity > 0.0)
                Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: safeTop + 20, left: 24, right: 24),
                    child: Text(
                      title,
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 32,
                        color: colors.onSurface.withValues(alpha: opacity),
                        height: 1.1,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

              // Leading/Back Button (fades out or floats on top-left)
              if (showLeading && opacity > 0.0)
                Positioned(
                  top: safeTop + 8,
                  left: 16,
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: colors.onSurface.withValues(alpha: opacity),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      context.pop();
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Bold date/section-label header ("Today", "Yesterday", "Configuration", etc.).
/// Subdued styling, left-aligned at 24dp for layout breathing room.
class _OneUISectionHeader extends StatelessWidget {
  const _OneUISectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        left: 24,   // aligned with card content start
        right: 16,
        top: 24,    // layout breathing room
        bottom: 8,
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.15,
        ),
      ),
    );
  }
}

/// Groups related list items inside one rounded card with 0.5dp dividers.
/// Tonal fill and subtle shadow with highly rounded 24dp corners.
class _OneUIGroupCard extends StatelessWidget {
  const _OneUIGroupCard({
    required this.children,
    this.margin = const EdgeInsets.symmetric(horizontal: 16), // Customizable outer margins
  });
  
  final List<Widget> children;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (children.isEmpty) return const SizedBox.shrink();

    final separated = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      separated.add(children[i]);
      if (i < children.length - 1) {
        separated.add(Divider(
          height: 1,
          thickness: 0.5,
          indent: 56,      // past leading icon
          endIndent: 16,
          color: colors.outlineVariant.withValues(alpha: 0.3),
        ),);
      }
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24), // Highly rounded matching One UI 8.5 Phone app cards
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: separated,
        ),
      ),
    );
  }
}

/// Card container for settings sections.
class _OneUISettingsCard extends StatelessWidget {
  const _OneUISettingsCard({
    required this.child,
  });
  
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16), // Constant outer margins to resolve unused parameter
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

/// Segmented control with a smooth sliding surface indicator and overshoot bounce.
class _OneUISegmentedBar extends StatelessWidget {
  const _OneUISegmentedBar({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(3),
      child: LayoutBuilder(
        builder: (BuildContext ctx, BoxConstraints constraints) {
          final double w = constraints.maxWidth / items.length;
          return Stack(
            children: <Widget>[
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutBack, // spring animation with slight overshoot
                left: selectedIndex * w,
                top: 0,
                bottom: 0,
                width: w,
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(17),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: List<Widget>.generate(items.length, (int i) {
                  final bool active = i == selectedIndex;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onSelected(i);
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: active ? colors.onPrimary : colors.onSurfaceVariant,
                            fontSize: 13,
                          ),
                          child: Text(items[i]),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}
