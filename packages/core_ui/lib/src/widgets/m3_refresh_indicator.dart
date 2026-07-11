import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:m3_expressive/m3_expressive.dart';
import 'package:m3_expressive/material_shapes.dart';

/// A Material 3 Expressive pull-to-refresh indicator.
///
/// Behaviour:
///
/// DRAG PHASE
///   The indicator circle slides down from above the content at exactly
///   the same rate as the finger, so it appears to be pushed out by the
///   gesture. The circle is always full size — only its vertical position
///   changes. The shape inside starts as a pure circle and morphs toward
///   [MaterialShapes.sunny] as the drag progresses to 50% of the trigger
///   distance, then continues to [MaterialShapes.verySunny] at 100%.
///   Rotation accumulates in proportion to the drag distance.
///
/// LOADING PHASE
///   On release past the threshold the indicator snaps to its resting
///   position and the shape cycles through a fixed sequence with an elastic
///   bounce motion until [onRefresh] completes.
///
/// DISMISS
///   The circle slides back up out of view.
///
/// ```dart
/// M3RefreshIndicator(
///   onRefresh: _handleRefresh,
///   child: ListView(...),
/// )
/// ```
class M3RefreshIndicator extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  /// Diameter of the indicator circle. Defaults to 56.
  final double indicatorSize;

  /// Pull distance in pixels required to trigger refresh. Defaults to 140.
  final double triggerDistance;

  /// Circle background color.
  /// Defaults to [ColorScheme.primaryContainer].
  final Color? backgroundColor;

  /// Shape fill color.
  /// Defaults to [ColorScheme.primary].
  final Color? shapeColor;

  /// Duration of one shape cycle during loading. Defaults to 750 ms.
  final Duration loadingMorphDuration;

  const M3RefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.indicatorSize = 56,
    this.triggerDistance = 140,
    this.backgroundColor,
    this.shapeColor,
    this.loadingMorphDuration = const Duration(milliseconds: 750),
  });

  @override
  State<M3RefreshIndicator> createState() => _M3RefreshIndicatorState();
}

class _M3RefreshIndicatorState extends State<M3RefreshIndicator>
    with TickerProviderStateMixin {
  _Phase _phase = _Phase.idle;

  double _dragPixels = 0.0;
  bool _isPulling = false;

  // Rotation accumulated during the drag (radians)
  double _dragRotation = 0.0;

  // Loading animation — cycles through the loading shape sequence
  late final AnimationController _loadCtrl;
  int _loadIndex = 0;

  // Slide-out animation when dismissing
  late final AnimationController _dismissCtrl;

  // Fixed loading sequence: verySunny → gem → pentagon → diamond → circle
  static final _loadingSequence = <RoundedPolygon>[
    MaterialShapes.verySunny,
    MaterialShapes.gem,
    MaterialShapes.pentagon,
    MaterialShapes.diamond,
    MaterialShapes.arrow,
    MaterialShapes.pill,
    MaterialShapes.circle,
  ];

  @override
  void initState() {
    super.initState();
    _loadCtrl = AnimationController(
      vsync: this,
      duration: widget.loadingMorphDuration,
    )..addStatusListener(_onLoadCycle);

    _dismissCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _loadCtrl.dispose();
    _dismissCtrl.dispose();
    super.dispose();
  }

  // ── Scroll handling ─────────────────────────────────────────────────────

  bool _shouldStart(ScrollNotification n) {
    if (n.depth != 0) return false;
    if (_phase != _Phase.idle) return false;
    if (n.metrics.pixels > 0.0) return false;

    if (n is ScrollStartNotification) {
      return n.dragDetails != null;
    }
    if (n is ScrollUpdateNotification) {
      final delta = n.scrollDelta;
      return delta != null && delta < 0.0 && n.dragDetails != null;
    }
    return false;
  }

  bool _handleNotification(ScrollNotification n) {
    if (n.depth != 0) return false;
    if (_phase == _Phase.refreshing || _phase == _Phase.dismissing) {
      return false;
    }

    if (_shouldStart(n)) {
      _isPulling = true;
      _dragPixels = 0.0;
      _dragRotation = 0.0;
      setState(() => _phase = _Phase.dragging);
      return false;
    }

    if (_phase == _Phase.dragging || _phase == _Phase.armed) {
      if (n is ScrollUpdateNotification) {
        if (n.metrics.pixels > 0.0) {
          _isPulling = false;
          _dismiss();
        } else {
          final delta = n.scrollDelta;
          if (delta != null) {
            _onPull(-delta);
          }
        }
        if (_phase == _Phase.armed && n.dragDetails == null) {
          // iOS release during overscroll
          _beginRefresh();
        }
      } else if (n is OverscrollNotification) {
        _onPull(-n.overscroll);
      } else if (n is ScrollEndNotification) {
        if (_phase == _Phase.armed) {
          _beginRefresh();
        } else {
          _dismiss();
        }
      }
    }
    return false;
  }

  void _onPull(double delta) {
    if (_phase == _Phase.refreshing || _phase == _Phase.dismissing) return;

    if (!_isPulling) {
      _isPulling = true;
    }

    // Apply rubber-banding resistance only to positive delta (pulling down further)
    double adjustedDelta = delta;
    if (delta > 0) {
      final progress = (_dragPixels / widget.triggerDistance).clamp(0.0, 1.0);
      final resistance = 1.0 - progress * 0.6;
      adjustedDelta = delta * resistance;
    }

    _dragPixels = (_dragPixels + adjustedDelta)
        .clamp(0.0, widget.triggerDistance * 2.0);

    _dragRotation += delta * 0.016;

    final nextPhase = _dragPixels >= widget.triggerDistance
        ? _Phase.armed
        : _Phase.dragging;

    if (_dragPixels <= 0 && delta < 0) {
      _isPulling = false;
      _dismiss();
    } else {
      if (_phase != nextPhase) {
        setState(() => _phase = nextPhase);
      } else {
        setState(() {});
      }
    }
  }

  // ── Phases ───────────────────────────────────────────────────────────────

  Future<void> _beginRefresh() async {
    _isPulling = false;
    setState(() {
      _phase = _Phase.refreshing;
      _loadIndex = 0;
    });
    unawaited(_loadCtrl.forward());
    await widget.onRefresh();
    if (mounted) _dismiss();
  }

  void _onLoadCycle(AnimationStatus status) {
    if (status == AnimationStatus.completed &&
        _phase == _Phase.refreshing &&
        mounted) {
      setState(() {
        _loadIndex = (_loadIndex + 1) % _loadingSequence.length;
      });
      _loadCtrl
        ..reset()
        ..forward();
    }
  }

  void _dismiss() {
    _isPulling = false;
    setState(() => _phase = _Phase.dismissing);
    _loadCtrl.stop();
    _dismissCtrl.forward().then((_) {
      if (!mounted) return;
      _dismissCtrl.reset();
      setState(() {
        _phase = _Phase.idle;
        _dragPixels = 0.0;
        _dragRotation = 0.0;
        _loadIndex = 0;
      });
    });
  }

  // ── Geometry helpers ─────────────────────────────────────────────────────

  double get _dragProgress =>
      (_dragPixels / widget.triggerDistance).clamp(0.0, 1.0);

  /// How far down the indicator circle sits, in pixels from the top edge.
  /// Tracks the finger during drag, stays at indicatorSize/2 + 8 during loading.
  double _indicatorTopOffset() {
    final size = widget.indicatorSize;
    const restingTop = 8.0; // gap from top edge when fully shown
    switch (_phase) {
      case _Phase.idle:
        return -(size + 8); // fully hidden above
      case _Phase.dragging:
      case _Phase.armed:
      // Move down with the finger from fully hidden to resting position
        final travel = size + 8 + restingTop;
        return -(size + 8) + _dragProgress * travel;
      case _Phase.refreshing:
        return restingTop;
      case _Phase.dismissing:
      // Slide back up
        final t = Curves.easeInCubic.transform(_dismissCtrl.value);
        return restingTop - t * (size + 8 + restingTop);
    }
  }

  // ── Shape selection ──────────────────────────────────────────────────────

  /// During drag: circle → sunny → verySunny mapped to dragProgress 0..1.
  (RoundedPolygon, RoundedPolygon, double) _dragBlend() {
    // First half: circle → sunny, second half: sunny → verySunny
    if (_dragProgress <= 0.5) {
      return (
      MaterialShapes.circle,
      MaterialShapes.sunny,
      _dragProgress * 2,
      );
    } else {
      return (
      MaterialShapes.sunny,
      MaterialShapes.verySunny,
      (_dragProgress - 0.5) * 2,
      );
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bgColor = widget.backgroundColor ?? cs.primaryContainer;
    final shapeColor = widget.shapeColor ?? cs.primary;
    final sz = widget.indicatorSize;

    return NotificationListener<ScrollNotification>(
      onNotification: _handleNotification,
      child: Stack(
        children: [
          widget.child,
          if (_phase != _Phase.idle)
            AnimatedBuilder(
              animation: Listenable.merge([_loadCtrl, _dismissCtrl]),
              builder: (_, __) {
                final topOffset = _indicatorTopOffset();

                RoundedPolygon shapeA;
                RoundedPolygon shapeB;
                double morphT;
                double angle;

                if (_phase == _Phase.dragging || _phase == _Phase.armed) {
                  final (a, b, t) = _dragBlend();
                  shapeA = a;
                  shapeB = b;
                  morphT = Curves.easeInOutCubic.transform(t);
                  angle = _dragRotation;
                } else {
                  // Refreshing or dismissing — keep animating loading sequence
                  shapeA = _loadingSequence[_loadIndex];
                  shapeB = _loadingSequence[
                  (_loadIndex + 1) % _loadingSequence.length];
                  // Elastic out: fast start, squishy bounce
                  morphT = Curves.elasticOut
                      .transform(_loadCtrl.value)
                      .clamp(0.0, 1.0);
                  angle = _dragRotation +
                      _loadCtrl.value * math.pi * 1.5 +
                      _loadIndex * math.pi * 0.6;
                }

                return Positioned(
                  top: topOffset,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: sz,
                      height: sz,
                      decoration: BoxDecoration(
                        color: bgColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: shapeColor.withAlpha(35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: CustomPaint(
                          painter: M3ShapeMorphPainter(
                            shapeA: shapeA,
                            shapeB: shapeB,
                            morphProgress: morphT,
                            color: shapeColor,
                            rotationAngle: angle,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

enum _Phase { idle, dragging, armed, refreshing, dismissing }
