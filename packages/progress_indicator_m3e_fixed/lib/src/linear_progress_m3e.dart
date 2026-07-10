import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:m3e_design/m3e_design.dart';

import '_tokens.dart';
import 'enums.dart';

/// Linear indicator that renders two **separate lanes** (active above, track below)
/// with a fixed vertical gap. Lanes never overlap.
class LinearProgressIndicatorM3E extends StatefulWidget {
  const LinearProgressIndicatorM3E({
    super.key,
    this.value, // null => indeterminate
    this.size = LinearProgressM3ESize.m,
    this.shape = ProgressM3EShape.wavy,
    this.activeColor,
    this.trackColor,
    this.phase = 0.0, // radians for wavy animation (external override)
    this.inset = 4.0, // horizontal left inset
  });

  final double? value;
  final LinearProgressM3ESize size;
  final ProgressM3EShape shape;
  final Color? activeColor;
  final Color? trackColor;
  final double phase;
  final double inset;

  @override
  State<LinearProgressIndicatorM3E> createState() =>
      _LinearProgressIndicatorM3EState();
}

class _LinearProgressIndicatorM3EState extends State<LinearProgressIndicatorM3E>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool get _shouldAnimate {
    final v = widget.value;
    return widget.shape == ProgressM3EShape.wavy &&
        (v == null || (v >= 1.0)) &&
        widget.phase == 0.0;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..addListener(() {
        if (mounted && _shouldAnimate) setState(() {});
      });
    if (_shouldAnimate) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant LinearProgressIndicatorM3E oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_shouldAnimate) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      if (_controller.isAnimating) _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m3e =
        theme.extension<M3ETheme>() ?? M3ETheme.defaults(theme.colorScheme);

    // Farben aus m3e_design beziehen (überschreibbar per Props)
    final active = widget.activeColor ?? m3e.colors.primary;
    final track = widget.trackColor ?? m3e.colors.surfaceContainerHighest;

    final spec = specForLinear(size: widget.size, shape: widget.shape);

    // Total height equals the taller of the two strokes sharing the same baseline.
    // For wavy, add vertical amplitude; for flat, it's just the trackHeight.
    final activeHeight = spec.isWavy
        ? (spec.trackHeight + 2 * spec.waveAmplitude)
        : spec.trackHeight;
    final totalHeight = activeHeight;

    final double phaseValue = widget.phase != 0.0
        ? widget.phase
        : (_shouldAnimate ? _controller.value * 2 * math.pi : 0.0);

    return RepaintBoundary(
      child: SizedBox(
        height: totalHeight,
        width: double.infinity,
        child: CustomPaint(
          painter: _LinearPainter(
            value: widget.value,
            spec: spec,
            active: widget.activeColor ?? active,
            track: widget.trackColor ?? track,
            phase: phaseValue,
            inset: widget.inset,
          ),
        ),
      ),
    );
  }
}

class _LinearPainter extends CustomPainter {
  _LinearPainter({
    required this.value,
    required this.spec,
    required this.active,
    required this.track,
    required this.phase,
    required this.inset,
  });

  final double? value;
  final LinearSpec spec;
  final Color active;
  final Color track;
  final double phase;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final left = inset;
    final right = size.width - spec.trailingMargin;
    final width = math.max(0.0, right - left);

    // both strokes share the same baseline (centerline)
    final cy = size.height / 2;
    final trackCy = cy;
    final activeCy = cy;

    // --- Draw track lane (flat pill) ---
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = spec.trackHeight
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // compute progress fraction early for both lanes
    final double p = (value ?? 0).clamp(0.0, 1.0);

    // Wave-only mode: in wavy shape, when indeterminate or full (100%),
    // hide the track and end-dot; show only the wave which is animated via phase.
    final bool waveOnly = spec.isWavy && (value == null || p >= 1.0);

    // Track occupies the remaining segment to the right of the active,
    // leaving a fixed inter-stroke gap. For indeterminate, fill full width.
    final double activeEndX = value == null ? right : (left + width * p);
    final double trackStartX =
        value == null ? left : math.min(right, activeEndX + spec.gap + spec.trackHeight);

    if (!waveOnly) {
      canvas.drawLine(Offset(trackStartX, trackCy), Offset(right, trackCy),
          base..color = track,);
    }

    // --- Active lane ---
    if (spec.isWavy) {
      // wavy centerline
      final start = left;
      final end = value == null ? right : (left + width * p);
      final path = Path();
      const step = 1.5;
      final k = 2 * math.pi / spec.wavePeriod;

      double x = start;
      double y =
          activeCy + spec.waveAmplitude * math.sin(phase + (x - start) * k);
      path.moveTo(x, y);
      for (x = start + step; x <= end; x += step) {
        y = activeCy + spec.waveAmplitude * math.sin(phase + (x - start) * k);
        path.lineTo(x, y);
      }
      // precise end point
      y = activeCy + spec.waveAmplitude * math.sin(phase + (end - start) * k);
      path.lineTo(end, y);

      canvas.drawPath(
          path,
          base
            ..color = active
            ..strokeWidth = spec.trackHeight,);

      // end dot: accent at far right end of the track (shared baseline)
      if (!waveOnly) {
        final dotCenterX = math.max(left, right - spec.dotOffset);
        canvas.drawCircle(Offset(dotCenterX, trackCy), spec.dotDiameter / 2,
            Paint()..color = active,);
      }
    } else {
      // flat active pill + end dot
      final start = left;
      final end = value == null ? right : (left + width * p);
      canvas.drawLine(
          Offset(start, activeCy),
          Offset(end, activeCy),
          base
            ..color = active
            ..strokeWidth = spec.trackHeight,);
      final dotCenterX = math.max(left, right - spec.dotOffset);
      canvas.drawCircle(Offset(dotCenterX, trackCy), spec.dotDiameter / 2,
          Paint()..color = active,);
    }
  }

  @override
  bool shouldRepaint(covariant _LinearPainter old) =>
      value != old.value ||
      spec != old.spec ||
      active != old.active ||
      track != old.track ||
      phase != old.phase ||
      inset != old.inset;
}
