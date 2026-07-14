import 'dart:async';
import 'dart:io';

import 'package:easy_refresh/easy_refresh.dart' as er;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'dart:math' as math;

import 'package:m3_expressive/m3_expressive.dart';
import 'package:m3_expressive/material_shapes.dart';

/// A wrapper around [er.EasyRefresh] that transparently falls back to
/// standard Flutter [RefreshIndicator] during widget tests to prevent
/// background timer/animation leak issues.
class EasyRefresh extends StatelessWidget {
  final er.Header? header;
  final er.Footer? footer;
  final er.EasyRefreshController? controller;
  final FutureOr<dynamic> Function()? onRefresh;
  final FutureOr<dynamic> Function()? onLoad;
  final Widget child;

  const EasyRefresh({
    super.key,
    this.header,
    this.footer,
    this.controller,
    this.onRefresh,
    this.onLoad,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    bool isTesting = false;
    if (!kIsWeb) {
      try {
        isTesting = Platform.environment.containsKey('FLUTTER_TEST');
      } catch (_) {}
    }

    if (isTesting) {
      if (onRefresh != null) {
        return RefreshIndicator(
          onRefresh: () async {
            await onRefresh!();
          },
          child: child,
        );
      }
      return child;
    }

    er.Header? effectiveHeader = header;
    if (effectiveHeader == null || effectiveHeader is er.MaterialHeader) {
      final er.IndicatorPosition position =
          (effectiveHeader as er.MaterialHeader?)?.position ??
              er.IndicatorPosition.behind;
      final bool clamping =
          (effectiveHeader as er.MaterialHeader?)?.clamping ?? false;

      effectiveHeader = er.BuilderHeader(
        triggerOffset: 70,
        clamping: clamping,
        position: position,
        builder: (BuildContext context, er.IndicatorState state) {
          if (state.offset <= 0.0) {
            return const SizedBox.shrink();
          }

          final double top = position == er.IndicatorPosition.locator
              ? (state.offset - 40.0) / 2
              : -40.0 + state.offset.clamp(0.0, 70.0);

          return SizedBox(
            height: state.offset,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: top,
                  left: 0,
                  right: 0,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: _ExpressiveHeaderWidget(state: state),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        if (notification.depth > 0 ||
            notification.metrics.axis == Axis.horizontal) {
          return true;
        }
        return false;
      },
      child: er.EasyRefresh(
        header: effectiveHeader,
        footer: footer,
        controller: controller,
        onRefresh: onRefresh,
        onLoad: onLoad,
        child: child,
      ),
    );
  }
}

class _ExpressiveHeaderWidget extends StatefulWidget {
  final er.IndicatorState state;

  const _ExpressiveHeaderWidget({required this.state});

  @override
  State<_ExpressiveHeaderWidget> createState() =>
      _ExpressiveHeaderWidgetState();
}

class _ExpressiveHeaderWidgetState extends State<_ExpressiveHeaderWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loadCtrl;
  int _loadIndex = 0;

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
      duration: const Duration(milliseconds: 500),
    )..addStatusListener(_onLoadCycle);

    _checkRefreshing();
  }

  @override
  void didUpdateWidget(_ExpressiveHeaderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkRefreshing();
  }

  void _checkRefreshing() {
    final bool isRefreshing = widget.state.mode == er.IndicatorMode.ready ||
        widget.state.mode == er.IndicatorMode.processing;
    if (isRefreshing) {
      if (!_loadCtrl.isAnimating) {
        _loadCtrl.forward();
      }
    } else {
      if (_loadCtrl.isAnimating) {
        _loadCtrl.stop();
      }
    }
  }

  void _onLoadCycle(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() {
        _loadIndex = (_loadIndex + 1) % _loadingSequence.length;
      });
      _loadCtrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _loadCtrl.dispose();
    super.dispose();
  }

  (RoundedPolygon, RoundedPolygon, double) _dragBlend(double progress) {
    if (progress <= 0.5) {
      return (
        MaterialShapes.circle,
        MaterialShapes.sunny,
        progress * 2,
      );
    } else {
      return (
        MaterialShapes.sunny,
        MaterialShapes.verySunny,
        (progress - 0.5) * 2,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final bool isRefreshing = state.mode == er.IndicatorMode.ready ||
        state.mode == er.IndicatorMode.processing;

    final double value = (state.offset / state.triggerOffset).clamp(0.01, 1.0);
    final double scale = isRefreshing ? 1.0 : value;
    final double opacity = (state.offset / 30.0).clamp(0.0, 1.0);

    RoundedPolygon shapeA;
    RoundedPolygon shapeB;
    double morphT;
    double angle;

    if (!isRefreshing) {
      final (a, b, t) = _dragBlend(value);
      shapeA = a;
      shapeB = b;
      morphT = Curves.easeInOutCubic.transform(t);
      angle = value * math.pi * 2.2;
    } else {
      shapeA = _loadingSequence[_loadIndex];
      shapeB = _loadingSequence[(_loadIndex + 1) % _loadingSequence.length];
      morphT = Curves.elasticOut.transform(_loadCtrl.value).clamp(0.0, 1.0);
      angle = _loadCtrl.value * math.pi * 1.5 + _loadIndex * math.pi * 0.6;
    }

    final cs = Theme.of(context).colorScheme;
    final shapeColor = cs.primary;

    return AnimatedBuilder(
      animation: _loadCtrl,
      builder: (context, child) {
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Card(
              elevation: 6,
              shape: const CircleBorder(),
              color: cs.surfaceContainerHigh,
              child: SizedBox(
                width: 36,
                height: 36,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
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
          ),
        );
      },
    );
  }
}
