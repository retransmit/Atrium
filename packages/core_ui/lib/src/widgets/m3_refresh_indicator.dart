import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:m3_expressive/m3_expressive.dart';
import 'package:m3_expressive/material_shapes.dart';

/// A Material 3 Expressive pull-to-refresh indicator.
///
/// Under the hood, this widget uses the exact same scroll lifecycle and state
/// machine as Flutter's official SDK [RefreshIndicatorState]. This guarantees
/// identical physics, nested scroll view compatibility, and cancelation on
/// iOS and Android, while custom painting the Material 3 Expressive shape morphs
/// and color styles.
class M3RefreshIndicator extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  /// Diameter of the indicator circle. Defaults to 56.
  final double indicatorSize;

  /// Pull distance in pixels required to trigger refresh. Defaults to 140.
  final double triggerDistance;

  /// The distance from the child's top or bottom outline where the refresh indicator
  /// will settle. Defaults to 40.0.
  final double displacement;

  /// The offset where the indicator starts its slide-down. Defaults to 0.0.
  final double edgeOffset;

  /// How the refresh indicator is triggered. Defaults to [RefreshIndicatorTriggerMode.onEdge].
  final RefreshIndicatorTriggerMode triggerMode;

  /// Whether the scroll notification bubbles should be handled. Defaults to depth == 0.
  final ScrollNotificationPredicate notificationPredicate;

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
    this.displacement = 40.0,
    this.edgeOffset = 0.0,
    this.triggerMode = RefreshIndicatorTriggerMode.onEdge,
    this.notificationPredicate = defaultScrollNotificationPredicate,
    this.backgroundColor,
    this.shapeColor,
    this.loadingMorphDuration = const Duration(milliseconds: 750),
  });

  @override
  State<M3RefreshIndicator> createState() => _M3RefreshIndicatorState();
}

class _M3RefreshPhysics extends ScrollPhysics {
  final _M3RefreshIndicatorState state;

  const _M3RefreshPhysics(this.state, {super.parent});

  @override
  _M3RefreshPhysics applyTo(ScrollPhysics? ancestor) {
    return _M3RefreshPhysics(state, parent: buildParent(ancestor));
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (position.axis == Axis.vertical && state._dragOffset != null && state._dragOffset! > 0.0) {
      if (offset < 0.0) {
        if (position.pixels >= position.minScrollExtent) {
          final double absorbable = state._dragOffset!;
          final double dragAmount = -offset;
          if (dragAmount <= absorbable) {
            state.absorbDrag(dragAmount);
            return 0.0;
          } else {
            state.absorbDrag(absorbable);
            final double remainingOffset = -(dragAmount - absorbable);
            return super.applyPhysicsToUserOffset(position, remainingOffset);
          }
        }
      }
    }
    return super.applyPhysicsToUserOffset(position, offset);
  }
}

class _M3RefreshIndicatorState extends State<M3RefreshIndicator>
    with TickerProviderStateMixin {
  late AnimationController _positionController;
  late AnimationController _scaleController;
  late Animation<double> _positionFactor;
  late Animation<double> _scaleFactor;

  RefreshIndicatorStatus? _status;
  late Future<void> _pendingRefreshFuture;
  bool? _isIndicatorAtTop;
  double? _dragOffset;
  double? _lastContainerExtent;

  void absorbDrag(double delta) {
    if (_dragOffset != null) {
      _dragOffset = math.max(0.0, _dragOffset! - delta);
      if (_lastContainerExtent != null) {
        _checkDragOffset(_lastContainerExtent!);
      }
    }
  }

  // Loading animation variables
  late final AnimationController _loadCtrl;
  int _loadIndex = 0;

  static const double _kDragSizeFactorLimit = 1.5;
  static const Duration _kIndicatorSnapDuration = Duration(milliseconds: 150);
  static const Duration _kIndicatorScaleDuration = Duration(milliseconds: 200);

  static final Animatable<double> _kDragSizeFactorLimitTween = Tween<double>(
    begin: 0.0,
    end: _kDragSizeFactorLimit,
  );

  static final Animatable<double> _oneToZeroTween =
      Tween<double>(begin: 1.0, end: 0.0);

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
    _positionController = AnimationController(vsync: this);
    _positionFactor = _positionController.drive(_kDragSizeFactorLimitTween);

    _scaleController = AnimationController(vsync: this);
    _scaleFactor = _scaleController.drive(_oneToZeroTween);

    _loadCtrl = AnimationController(
      vsync: this,
      duration: widget.loadingMorphDuration,
    )..addStatusListener(_onLoadCycle);
  }

  @override
  void dispose() {
    _positionController.dispose();
    _scaleController.dispose();
    _loadCtrl.dispose();
    super.dispose();
  }

  void _onLoadCycle(AnimationStatus status) {
    if (status == AnimationStatus.completed &&
        _status == RefreshIndicatorStatus.refresh &&
        mounted) {
      setState(() {
        _loadIndex = (_loadIndex + 1) % _loadingSequence.length;
      });
      _loadCtrl
        ..reset()
        ..forward();
    }
  }

  bool _shouldStart(ScrollNotification notification) {
    return ((notification is ScrollStartNotification &&
                notification.dragDetails != null) ||
            (notification is ScrollUpdateNotification &&
                notification.dragDetails != null &&
                widget.triggerMode == RefreshIndicatorTriggerMode.anywhere)) &&
        ((notification.metrics.axisDirection == AxisDirection.up &&
                notification.metrics.extentAfter == 0.0) ||
            (notification.metrics.axisDirection == AxisDirection.down &&
                notification.metrics.extentBefore == 0.0)) &&
        _status == null &&
        _start(notification.metrics.axisDirection);
  }

  bool _start(AxisDirection direction) {
    assert(_status == null);
    assert(_isIndicatorAtTop == null);
    assert(_dragOffset == null);
    switch (direction) {
      case AxisDirection.down:
      case AxisDirection.up:
        _isIndicatorAtTop = true;
      case AxisDirection.left:
      case AxisDirection.right:
        _isIndicatorAtTop = null;
        return false;
    }
    _dragOffset = 0.0;
    _scaleController.value = 0.0;
    _positionController.value = 0.0;
    return true;
  }

  void _checkDragOffset(double containerExtent) {
    assert(_status == RefreshIndicatorStatus.drag ||
        _status == RefreshIndicatorStatus.armed);
    // Custom trigger distance mapping
    double newValue = _dragOffset! / widget.triggerDistance;
    
    if (_status == RefreshIndicatorStatus.armed && newValue < 1.0 / _kDragSizeFactorLimit) {
      setState(() {
        _status = RefreshIndicatorStatus.drag;
      });
    } else if (_status == RefreshIndicatorStatus.drag && newValue >= 1.0 / _kDragSizeFactorLimit) {
      setState(() {
        _status = RefreshIndicatorStatus.armed;
      });
    }
    
    _positionController.value = newValue.clamp(0.0, 1.0);
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    _lastContainerExtent = notification.metrics.viewportDimension;
    if (!widget.notificationPredicate(notification) ||
        notification.metrics.axis != Axis.vertical) {
      return false;
    }
    if (_shouldStart(notification)) {
      setState(() {
        _status = RefreshIndicatorStatus.drag;
      });
      return false;
    }
    bool? indicatorAtTopNow;
    switch (notification.metrics.axisDirection) {
      case AxisDirection.down:
        indicatorAtTopNow = notification.metrics.extentBefore == 0.0;
        break;
      case AxisDirection.up:
        indicatorAtTopNow = notification.metrics.extentAfter == 0.0;
        break;
      case AxisDirection.left:
      case AxisDirection.right:
        indicatorAtTopNow = null;
        break;
    }
    if (indicatorAtTopNow != _isIndicatorAtTop) {
      if (_status == RefreshIndicatorStatus.drag ||
          _status == RefreshIndicatorStatus.armed) {
        _dismiss(RefreshIndicatorStatus.canceled);
      }
    } else if (notification is ScrollUpdateNotification) {
      if (_status == RefreshIndicatorStatus.drag ||
          _status == RefreshIndicatorStatus.armed) {
        if (notification.metrics.axisDirection == AxisDirection.down) {
          _dragOffset = _dragOffset! - notification.scrollDelta!;
        } else if (notification.metrics.axisDirection == AxisDirection.up) {
          _dragOffset = _dragOffset! + notification.scrollDelta!;
        }
        _checkDragOffset(notification.metrics.viewportDimension);
      }
      if (_status == RefreshIndicatorStatus.armed &&
          notification.dragDetails == null) {
        // iOS bounce back release trigger
        _show();
      }
    } else if (notification is OverscrollNotification) {
      if (_status == RefreshIndicatorStatus.drag ||
          _status == RefreshIndicatorStatus.armed) {
        if (notification.metrics.axisDirection == AxisDirection.down) {
          _dragOffset = _dragOffset! - notification.overscroll;
        } else if (notification.metrics.axisDirection == AxisDirection.up) {
          _dragOffset = _dragOffset! + notification.overscroll;
        }
        _checkDragOffset(notification.metrics.viewportDimension);
      }
    } else if (notification is ScrollEndNotification) {
      switch (_status) {
        case RefreshIndicatorStatus.armed:
          if (_positionController.value < 1.0 / _kDragSizeFactorLimit) {
            _dismiss(RefreshIndicatorStatus.canceled);
          } else {
            _show();
          }
        case RefreshIndicatorStatus.drag:
          _dismiss(RefreshIndicatorStatus.canceled);
        case RefreshIndicatorStatus.canceled:
        case RefreshIndicatorStatus.done:
        case RefreshIndicatorStatus.refresh:
        case RefreshIndicatorStatus.snap:
        case null:
          break;
      }
    }
    return false;
  }

  bool _handleIndicatorNotification(
      OverscrollIndicatorNotification notification) {
    if (notification.depth != 0 || !notification.leading) {
      return false;
    }
    if (_status == RefreshIndicatorStatus.drag || _status == RefreshIndicatorStatus.armed) {
      notification.disallowIndicator();
      return true;
    }
    return false;
  }

  Future<void> _dismiss(RefreshIndicatorStatus newMode) async {
    await Future<void>.value();
    assert(newMode == RefreshIndicatorStatus.canceled ||
        newMode == RefreshIndicatorStatus.done);
    setState(() {
      _status = newMode;
    });
    switch (_status!) {
      case RefreshIndicatorStatus.done:
        await _scaleController.animateTo(1.0,
            duration: _kIndicatorScaleDuration);
      case RefreshIndicatorStatus.canceled:
        await _positionController.animateTo(0.0,
            duration: _kIndicatorScaleDuration);
      case RefreshIndicatorStatus.armed:
      case RefreshIndicatorStatus.drag:
      case RefreshIndicatorStatus.refresh:
      case RefreshIndicatorStatus.snap:
        assert(false);
    }
    if (mounted && _status == newMode) {
      _dragOffset = null;
      _isIndicatorAtTop = null;
      _loadCtrl.stop();
      setState(() {
        _status = null;
        _loadIndex = 0;
      });
    }
  }

  void _show() {
    assert(_status != RefreshIndicatorStatus.refresh);
    assert(_status != RefreshIndicatorStatus.snap);
    final completer = Completer<void>();
    _pendingRefreshFuture = completer.future;
    _status = RefreshIndicatorStatus.snap;
    _positionController
        .animateTo(1.0 / _kDragSizeFactorLimit,
            duration: _kIndicatorSnapDuration)
        .then<void>((void value) {
      if (mounted && _status == RefreshIndicatorStatus.snap) {
        setState(() {
          _status = RefreshIndicatorStatus.refresh;
        });
        unawaited(_loadCtrl.forward());
        final Future<void> refreshResult = widget.onRefresh();
        refreshResult.whenComplete(() {
          if (mounted && _status == RefreshIndicatorStatus.refresh) {
            completer.complete();
            _dismiss(RefreshIndicatorStatus.done);
          }
        });
      }
    });
  }

  Future<void> show({bool atTop = true}) {
    if (_status != RefreshIndicatorStatus.refresh &&
        _status != RefreshIndicatorStatus.snap) {
      if (_status == null) {
        _start(atTop ? AxisDirection.down : AxisDirection.up);
      }
      _show();
    }
    return _pendingRefreshFuture;
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
    final Widget child = NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: NotificationListener<OverscrollIndicatorNotification>(
        onNotification: _handleIndicatorNotification,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            physics: _M3RefreshPhysics(
              this,
              parent: ScrollConfiguration.of(context).getScrollPhysics(context),
            ),
          ),
          child: widget.child,
        ),
      ),
    );

    final cs = Theme.of(context).colorScheme;
    final bgColor = widget.backgroundColor ?? cs.primaryContainer;
    final shapeColor = widget.shapeColor ?? cs.primary;
    final sz = widget.indicatorSize;

    final bool showIndeterminateIndicator =
        _status == RefreshIndicatorStatus.refresh ||
            _status == RefreshIndicatorStatus.done;

    return Stack(
      children: <Widget>[
        child,
        if (_status != null)
          Positioned(
            top: _isIndicatorAtTop! ? widget.edgeOffset : null,
            bottom: !_isIndicatorAtTop! ? widget.edgeOffset : null,
            left: 0.0,
            right: 0.0,
            child: SizeTransition(
              axisAlignment: _isIndicatorAtTop! ? 1.0 : -1.0,
              sizeFactor: _positionFactor,
              child: Padding(
                padding: _isIndicatorAtTop!
                    ? EdgeInsets.only(top: widget.displacement)
                    : EdgeInsets.only(bottom: widget.displacement),
                child: Align(
                  alignment: _isIndicatorAtTop!
                      ? Alignment.topCenter
                      : Alignment.bottomCenter,
                  child: ScaleTransition(
                    scale: _scaleFactor,
                    child: AnimatedBuilder(
                      animation: _positionController,
                      builder: (BuildContext context, Widget? child) {
                        RoundedPolygon shapeA;
                        RoundedPolygon shapeB;
                        double morphT;
                        double angle;

                        if (!showIndeterminateIndicator) {
                          final progress = (_positionController.value *
                                  _kDragSizeFactorLimit)
                              .clamp(0.0, 1.0);
                          final (a, b, t) = _dragBlend(progress);
                          shapeA = a;
                          shapeB = b;
                          morphT = Curves.easeInOutCubic.transform(t);
                          angle = progress * math.pi * 2.2;
                        } else {
                          shapeA = _loadingSequence[_loadIndex];
                          shapeB = _loadingSequence[
                              (_loadIndex + 1) % _loadingSequence.length];
                          morphT = Curves.elasticOut
                              .transform(_loadCtrl.value)
                              .clamp(0.0, 1.0);
                          angle = _loadCtrl.value * math.pi * 1.5 +
                              _loadIndex * math.pi * 0.6;
                        }

                        return Container(
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
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
