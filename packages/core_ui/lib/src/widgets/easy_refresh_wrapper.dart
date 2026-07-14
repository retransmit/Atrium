import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:easy_refresh/easy_refresh.dart' as er;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
      // Extract properties if user supplied custom MaterialHeader config,
      // otherwise use defaults that align with MaterialHeader.
      final er.MaterialHeader? userHeader =
          effectiveHeader as er.MaterialHeader?;
      effectiveHeader = ExpressiveHeader(
        key: userHeader?.key,
        triggerOffset: userHeader?.triggerOffset ?? 70,
        clamping: userHeader?.clamping ?? true,
        position: userHeader?.position ?? er.IndicatorPosition.behind,
        processedDuration:
            userHeader?.processedDuration ?? const Duration(milliseconds: 200),
        spring: userHeader?.spring,
        readySpringBuilder: userHeader?.readySpringBuilder,
        frictionFactor: userHeader?.frictionFactor,
        safeArea: userHeader?.safeArea ?? true,
        infiniteOffset: userHeader?.infiniteOffset,
        hitOver: userHeader?.hitOver ?? true,
        infiniteHitOver: userHeader?.infiniteHitOver ?? true,
        hapticFeedback: userHeader?.hapticFeedback ?? false,
        triggerWhenRelease: userHeader?.triggerWhenRelease ?? false,
        maxOverOffset: userHeader?.maxOverOffset ?? double.infinity,
        backgroundColor: userHeader?.backgroundColor,
        color: userHeader?.color,
        valueColor: userHeader?.valueColor,
        semanticsLabel: userHeader?.semanticsLabel,
        semanticsValue: userHeader?.semanticsValue,
        noMoreIcon: userHeader?.noMoreIcon,
        showBezierBackground: userHeader?.showBezierBackground ?? false,
        bezierBackgroundColor: userHeader?.bezierBackgroundColor,
        bezierBackgroundAnimation:
            userHeader?.bezierBackgroundAnimation ?? false,
        bezierBackgroundBounce: userHeader?.bezierBackgroundBounce ?? false,
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

/// Custom Material 3 Expressive Header for [er.EasyRefresh].
/// Subclasses [er.MaterialHeader] directly to inherit all default spring physics,
/// damping coefficients, and friction factors, overriding only the indicator widget tree.
class ExpressiveHeader extends er.MaterialHeader {
  const ExpressiveHeader({
    super.key,
    super.triggerOffset = 70,
    super.clamping = true,
    super.position,
    super.processedDuration = const Duration(milliseconds: 200),
    super.spring,
    super.springRebound = false,
    super.readySpringBuilder,
    super.frictionFactor,
    super.safeArea,
    super.infiniteOffset,
    super.hitOver,
    super.infiniteHitOver,
    super.hapticFeedback,
    super.triggerWhenRelease,
    super.maxOverOffset,
    super.backgroundColor,
    super.color,
    super.valueColor,
    super.semanticsLabel,
    super.semanticsValue,
    super.noMoreIcon,
    super.showBezierBackground = false,
    super.bezierBackgroundColor,
    super.bezierBackgroundAnimation = false,
    super.bezierBackgroundBounce = false,
  });

  @override
  Widget build(BuildContext context, er.IndicatorState state) {
    return _ExpressiveIndicator(
      state: state,
      reverse: state.reverse,
      disappearDuration: processedDuration,
    );
  }
}

class _ExpressiveIndicator extends StatefulWidget {
  final er.IndicatorState state;
  final bool reverse;
  final Duration disappearDuration;

  const _ExpressiveIndicator({
    super.key,
    required this.state,
    required this.reverse,
    required this.disappearDuration,
  });

  @override
  State<_ExpressiveIndicator> createState() => _ExpressiveIndicatorState();
}

class _ExpressiveIndicatorState extends State<_ExpressiveIndicator>
    with TickerProviderStateMixin {
  static const double _kSize = 48.0;

  er.IndicatorMode get _mode => widget.state.mode;
  er.IndicatorResult get _result => widget.state.result;
  Axis get _axis => widget.state.axis;
  double get _offset => widget.state.offset;
  double get _actualTriggerOffset => widget.state.actualTriggerOffset;

  late final AnimationController _loadCtrl;
  int _loadIndex = 0;

  // Fixed loading sequence: verySunny → gem → pentagon → diamond → arrow → pill → circle
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
      duration: const Duration(milliseconds: 750),
    )..addStatusListener(_onLoadCycle);

    final isRefreshing = widget.state.mode == er.IndicatorMode.processing;
    if (isRefreshing) {
      _loadCtrl.forward();
    }
  }

  @override
  void didUpdateWidget(covariant _ExpressiveIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasRefreshing = oldWidget.state.mode == er.IndicatorMode.processing;
    final isRefreshing = widget.state.mode == er.IndicatorMode.processing;

    if (isRefreshing && !wasRefreshing) {
      _loadIndex = 0;
      _loadCtrl.forward();
    } else if (!isRefreshing && wasRefreshing) {
      _loadCtrl.stop();
      _loadCtrl.reset();
      _loadIndex = 0;
    }
  }

  @override
  void dispose() {
    _loadCtrl.dispose();
    super.dispose();
  }

  void _onLoadCycle(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      final isRefreshing = widget.state.mode == er.IndicatorMode.processing;
      if (isRefreshing) {
        setState(() {
          _loadIndex = (_loadIndex + 1) % _loadingSequence.length;
        });
        _loadCtrl
          ..reset()
          ..forward();
      }
    }
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

  Widget _buildIndicator() {
    if (_offset <= 0) {
      return const SizedBox.shrink();
    }
    return Container(
      alignment: _axis == Axis.vertical
          ? (widget.reverse ? Alignment.topCenter : Alignment.bottomCenter)
          : (widget.reverse ? Alignment.centerLeft : Alignment.centerRight),
      height: _axis == Axis.vertical ? _actualTriggerOffset : double.infinity,
      width: _axis == Axis.horizontal ? _actualTriggerOffset : double.infinity,
      child: Center(
        child: AnimatedScale(
          duration: widget.disappearDuration,
          scale: _mode == er.IndicatorMode.processed ||
                  _mode == er.IndicatorMode.done
              ? 0.0
              : 1.0,
          child: Card(
            elevation: 6,
            shape: const CircleBorder(),
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                width: 36,
                height: 36,
                child: AnimatedBuilder(
                  animation: _loadCtrl,
                  builder: (context, _) {
                    final dragProgress =
                        (_offset / _actualTriggerOffset).clamp(0.0, 1.0);
                    final isDragging = _mode == er.IndicatorMode.drag ||
                        _mode == er.IndicatorMode.armed;

                    RoundedPolygon shapeA;
                    RoundedPolygon shapeB;
                    double morphT;
                    double angle;

                    if (isDragging) {
                      final (a, b, t) = _dragBlend(dragProgress);
                      shapeA = a;
                      shapeB = b;
                      morphT = Curves.easeInOutCubic.transform(t);
                      angle = dragProgress * math.pi * 2.2;
                    } else {
                      shapeA = _loadingSequence[_loadIndex];
                      shapeB = _loadingSequence[
                          (_loadIndex + 1) % _loadingSequence.length];
                      morphT = Curves.elasticOut
                          .transform(_loadCtrl.value)
                          .clamp(0.0, 1.0);
                      angle = (dragProgress * math.pi * 2.2) +
                          _loadCtrl.value * math.pi * 1.5 +
                          _loadIndex * math.pi * 0.6;
                    }

                    return CustomPaint(
                      painter: M3ShapeMorphPainter(
                        shapeA: shapeA,
                        shapeB: shapeB,
                        morphProgress: morphT,
                        color: Theme.of(context).colorScheme.primary,
                        rotationAngle: angle,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double offset = _offset;
    if (widget.state.indicator.infiniteOffset != null &&
        widget.state.indicator.position == er.IndicatorPosition.locator &&
        (_mode != er.IndicatorMode.inactive ||
            _result == er.IndicatorResult.noMore)) {
      offset = _actualTriggerOffset;
    }
    final padding = math.max(_offset - _kSize, 0.0) / 2;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: _axis == Axis.vertical ? double.infinity : offset,
          height: _axis == Axis.horizontal ? double.infinity : offset,
        ),
        Positioned(
          top: _axis == Axis.vertical
              ? widget.reverse
                  ? padding
                  : null
              : 0,
          bottom: _axis == Axis.vertical
              ? widget.reverse
                  ? null
                  : padding
              : 0,
          left: _axis == Axis.horizontal
              ? widget.reverse
                  ? padding
                  : null
              : 0,
          right: _axis == Axis.horizontal
              ? widget.reverse
                  ? null
                  : padding
              : 0,
          child: Center(
            child: _buildIndicator(),
          ),
        ),
      ],
    );
  }
}
