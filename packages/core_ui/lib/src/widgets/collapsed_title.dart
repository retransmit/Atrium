import 'package:flutter/material.dart';

class CollapsedTitle extends StatefulWidget {
  final ScrollController controller;
  final String title;

  const CollapsedTitle({
    super.key,
    required this.controller,
    required this.title,
  });

  @override
  State<CollapsedTitle> createState() => _CollapsedTitleState();
}

class _CollapsedTitleState extends State<CollapsedTitle> {
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
    // Initialize opacity based on initial offset if any
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  @override
  void didUpdateWidget(covariant CollapsedTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!mounted || !widget.controller.hasClients) return;
    final offset = widget.controller.offset;
    const double expandedHeight = 250.0;
    const double toolbarHeight = kToolbarHeight;
    const double collapseThreshold = expandedHeight - toolbarHeight;

    final progress = (offset / collapseThreshold).clamp(0.0, 1.0);
    // Fade in over the last 20% of collapse
    final newOpacity = progress > 0.8 ? (progress - 0.8) / 0.2 : 0.0;
    if (newOpacity != _opacity) {
      setState(() {
        _opacity = newOpacity;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: _opacity,
      child: Text(
        widget.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }
}
