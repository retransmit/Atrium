import 'package:flutter/material.dart';

import '../design_tokens.dart';

/// A reusable expandable box for displaying an overview or synopsis.
class OverviewBox extends StatefulWidget {
  const OverviewBox({
    required this.overview,
    this.title = 'Overview',
    super.key,
  });

  /// The text content to display.
  final String overview;

  /// The title of the box, defaults to 'Overview'.
  final String title;

  @override
  State<OverviewBox> createState() => _OverviewBoxState();
}

class _OverviewBoxState extends State<OverviewBox> {
  static const int _collapsedMaxLines = 3;

  bool _expanded = false;

  /// Whether [OverviewBox.overview] wraps past [_collapsedMaxLines] lines at
  /// the given width, using the same style, direction, and text scale the
  /// visible [Text] will render with.
  bool _exceedsCollapsedLines(
    BuildContext context,
    TextStyle? style,
    double maxWidth,
  ) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: widget.overview, style: style),
      maxLines: _collapsedMaxLines,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: maxWidth);
    final bool exceeds = painter.didExceedMaxLines;
    painter.dispose();
    return exceeds;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final TextStyle? bodyStyle = theme.textTheme.bodyMedium?.copyWith(
      color: cs.onSurfaceVariant,
      height: 1.5,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            widget.title,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: Insets.sm),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool needsToggle = _exceedsCollapsedLines(
                context,
                bodyStyle,
                constraints.maxWidth,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AnimatedCrossFade(
                    firstChild: Text(
                      widget.overview,
                      maxLines: _collapsedMaxLines,
                      overflow: TextOverflow.ellipsis,
                      style: bodyStyle,
                    ),
                    secondChild: Text(
                      widget.overview,
                      style: bodyStyle,
                    ),
                    crossFadeState: _expanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 250),
                  ),
                  if (needsToggle) ...<Widget>[
                    const SizedBox(height: Insets.xs),
                    GestureDetector(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Text(
                        _expanded ? 'Show less' : 'Show more',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
