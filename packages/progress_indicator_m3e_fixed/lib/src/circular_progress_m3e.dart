import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'enums.dart';

class CircularProgressIndicatorM3E extends StatefulWidget {
  const CircularProgressIndicatorM3E({
    super.key,
    this.value,
    this.size = CircularProgressM3ESize.m,
    this.shape = ProgressM3EShape.wavy,
    this.activeColor,
    this.trackColor,
    this.rotation = 0.0, // radians, for indeterminate rotation
  });

  final double? value; // 0..1 (null => indeterminate arc sweep)
  final CircularProgressM3ESize size;
  final ProgressM3EShape shape;
  final Color? activeColor;
  final Color? trackColor;
  final double rotation;

  @override
  State<CircularProgressIndicatorM3E> createState() =>
      _CircularProgressIndicatorM3EState();
}

class _CircularProgressIndicatorM3EState
    extends State<CircularProgressIndicatorM3E>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool get _shouldAnimate {
    final v = widget.value;
    return widget.shape == ProgressM3EShape.wavy &&
        (v == null || (v >= 1.0)) &&
        widget.rotation == 0.0;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..addListener(() {
        if (mounted && _shouldAnimate) setState(() {});
      });
    if (_shouldAnimate) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant CircularProgressIndicatorM3E oldWidget) {
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
    final cs = Theme.of(context).colorScheme;
    final active = widget.activeColor ?? cs.primary;
    final track =
        widget.trackColor ?? cs.onSurfaceVariant.withValues(alpha: 0.24);
    final wantsWavy = widget.shape == ProgressM3EShape.wavy;
    final diameter =
        wantsWavy ? widget.size.diameterWavy : widget.size.diameterFlat;

    final double rot = widget.rotation != 0.0
        ? widget.rotation
        : (_shouldAnimate ? _controller.value * 2 * math.pi : 0.0);

    return RepaintBoundary(
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: CustomPaint(
          painter: wantsWavy
              ? _CircularWavyPainter(
                  value: widget.value,
                  active: active,
                  track: track,
                  rotation: rot,)
              : _CircularFlatPainter(
                  value: widget.value,
                  active: active,
                  track: track,
                  rotation: rot,
                  size: widget.size,),
        ),
      ),
    );
  }
}

class _CircularFlatPainter extends CustomPainter {
  _CircularFlatPainter(
      {required this.value,
      required this.active,
      required this.track,
      required this.rotation,
      required this.size,});

  final double? value;
  final Color active;
  final Color track;
  final double rotation;
  final CircularProgressM3ESize size;

  @override
  void paint(Canvas canvas, Size s) {
    const stroke = 4.0;
    final center = s.center(Offset.zero);
    final radius = (math.min(s.width, s.height) - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true
      ..color = track;

    if (value == 0.0) {
      canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);
      return;
    }

    final activePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true
      ..color = active;

    final start = -math.pi / 2 + rotation;
    final sweep =
        value == null ? math.pi * 1.5 : (value!.clamp(0.0, 1.0) * math.pi * 2);

    if (value == 1.0) {
      canvas.drawArc(rect, start, sweep, false, activePaint);
      return;
    }

    // gap before active in dp -> angle
    const gapDp = 8.0;
    final gapAngle = gapDp / radius; // s = r * angle
    const total = math.pi * 2;

    if (sweep + 2 * gapAngle < total) {
      final a1 = start + sweep + gapAngle;
      final a2 = start - gapAngle;
      double sweep1 = a2 - a1;
      while (sweep1 <= 0) {
        sweep1 += total;
      }
      canvas.drawArc(rect, a1, sweep1, false, trackPaint);
    }

    // ACTIVE arc
    canvas.drawArc(rect, start, sweep, false, activePaint);
  }

  @override
  bool shouldRepaint(covariant _CircularFlatPainter old) =>
      value != old.value ||
      active != old.active ||
      track != old.track ||
      rotation != old.rotation ||
      size != old.size;
}

class _CircularWavyPainter extends CustomPainter {
  _CircularWavyPainter(
      {required this.value,
      required this.active,
      required this.track,
      required this.rotation,});

  final double? value;
  final Color active;
  final Color track;
  final double rotation;

  @override
  void paint(Canvas canvas, Size s) {
    const stroke = 4.0;
    final center = s.center(Offset.zero);
    final baseRadius = (math.min(s.width, s.height) - stroke) / 2;

    if (value == 0.0) {
      final trackPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true
        ..color = track;
      canvas.drawArc(Rect.fromCircle(center: center, radius: baseRadius), 0,
          math.pi * 2, false, trackPaint);
      return;
    }

    const amp = 2.0; // radial amplitude of squiggle
    const scallopLen = 18.0; // along-arc wavelength proxy (dp)
    // Taper length to fade the wave amplitude to zero near the end so the line ends "closed".
    const taperLen = scallopLen / 2;

    // Active sweep
    final activeSweep =
        value == null ? math.pi * 2 : (value!.clamp(0.0, 1.0) * math.pi * 2);
    final start = -math.pi / 2 + rotation;
    final end = start + activeSweep;

    // Track ring with gap around active (skip when wave-only: indeterminate or 100%)
    final bool waveOnly = value == null || (value != null && value! >= 1.0);
    if (!waveOnly) {
      final gapAngle = 2.0 / baseRadius;
      final rect = Rect.fromCircle(center: center, radius: baseRadius);
      const total = math.pi * 2;
      
      if (activeSweep + 2 * gapAngle < total) {
        final trackPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true
          ..color = track;

        final a1 = end + gapAngle;
        final a2 = start - gapAngle;
        double sweep1 = a2 - a1;
        while (sweep1 <= 0) {
          sweep1 += total;
        }
        canvas.drawArc(rect, a1, sweep1, false, trackPaint);
      }
    }

    // Active squiggle path
    final steps = math.max(48, (s.width * 1.2).round());
    final path = Path();
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final ang = start + (end - start) * t;
      final arcLen = baseRadius * (ang - start);
      // Fade amplitude to 0 near the end so the path ends on the base radius (closed look).
      final arcToEnd = baseRadius * (end - ang);
      double taperFactor = 1.0;
      if (arcToEnd < taperLen) {
        final tEnd = (arcToEnd / taperLen).clamp(0.0, 1.0);
        // Ease-out to 0 at the very end.
        taperFactor = math.sin(tEnd * math.pi / 2);
      }
      final r = baseRadius +
          (amp * taperFactor) * math.sin(arcLen / scallopLen * 2 * math.pi);
      final p =
          Offset(center.dx + r * math.cos(ang), center.dy + r * math.sin(ang));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    final activePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true
      ..color = active;
    canvas.drawPath(path, activePaint);
  }

  @override
  bool shouldRepaint(covariant _CircularWavyPainter old) =>
      value != old.value ||
      active != old.active ||
      track != old.track ||
      rotation != old.rotation;
}
