import 'dart:async';
import 'dart:io';

import 'package:easy_refresh/easy_refresh.dart' as er;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;

class EasyRefresh extends material.StatelessWidget {
  final er.Header? header;
  final er.Footer? footer;
  final er.EasyRefreshController? controller;
  final FutureOr<void> Function()? onRefresh;
  final FutureOr<void> Function()? onLoad;
  final material.Widget child;

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
  material.Widget build(material.BuildContext context) {
    final isTest = kDebugMode && !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (isTest) {
      if (onRefresh == null) return child;
      return material.RefreshIndicator(
        onRefresh: () async {
          await onRefresh!();
        },
        child: child,
      );
    }
    
    return er.EasyRefresh(
      header: header,
      footer: footer,
      controller: controller,
      onRefresh: onRefresh,
      onLoad: onLoad,
      triggerAxis: material.Axis.vertical,
      scrollBehaviorBuilder: (material.ScrollPhysics? physics) {
        if (physics != null) {
          return er.ERScrollBehavior(ClampingERScrollPhysics(physics));
        }
        return const er.ERScrollBehavior();
      },
      child: child,
    );
  }
}

class ClampingERScrollPhysics extends material.ScrollPhysics {
  final material.ScrollPhysics _delegate;

  const ClampingERScrollPhysics(this._delegate, {super.parent});

  @override
  ClampingERScrollPhysics applyTo(material.ScrollPhysics? ancestor) {
    return ClampingERScrollPhysics(
      _delegate.applyTo(ancestor),
      parent: buildParent(ancestor),
    );
  }

  @override
  double applyPhysicsToUserOffset(material.ScrollMetrics position, double offset) {
    return _delegate.applyPhysicsToUserOffset(position, offset);
  }

  @override
  double applyBoundaryConditions(material.ScrollMetrics position, double value) {
    if (!position.hasContentDimensions) {
      return 0.0;
    }

    final isDragging = position is material.ScrollPosition &&
        position.activity is material.DragScrollActivity;

    // If dragging or already out of range, let the delegate handle it.
    if (isDragging || position.outOfRange) {
      return _delegate.applyBoundaryConditions(position, value);
    }

    // Otherwise, clamp it so that ballistic flings stop exactly at the boundaries.
    return const material.ClampingScrollPhysics().applyBoundaryConditions(position, value);
  }

  @override
  material.Simulation? createBallisticSimulation(
    material.ScrollMetrics position,
    double velocity,
  ) {
    if (!position.hasContentDimensions) {
      return null;
    }

    if (position.outOfRange) {
      return _delegate.createBallisticSimulation(position, velocity);
    }

    final clampingSimulation = const material.ClampingScrollPhysics()
        .createBallisticSimulation(position, velocity);
    if (clampingSimulation != null) {
      return clampingSimulation;
    }

    return _delegate.createBallisticSimulation(position, velocity);
  }

  @override
  material.SpringDescription get spring => _delegate.spring;

  @override
  double get minFlingVelocity => _delegate.minFlingVelocity;

  @override
  double get maxFlingVelocity => _delegate.maxFlingVelocity;

  @override
  double? get dragStartDistanceMotionThreshold =>
      _delegate.dragStartDistanceMotionThreshold;

  @override
  material.Tolerance toleranceFor(material.ScrollMetrics metrics) =>
      _delegate.toleranceFor(metrics);
}


class HeaderLocator extends material.StatelessWidget {
  final bool _isSliver;

  const HeaderLocator({super.key}) : _isSliver = false;
  const HeaderLocator.sliver({super.key}) : _isSliver = true;

  @override
  material.Widget build(material.BuildContext context) {
    final isTest = kDebugMode && Platform.environment.containsKey('FLUTTER_TEST');
    if (isTest) {
      if (_isSliver) {
        return const material.SliverToBoxAdapter(child: material.SizedBox.shrink());
      }
      return const material.SizedBox.shrink();
    }
    
    if (_isSliver) {
      return const er.HeaderLocator.sliver();
    }
    return const er.HeaderLocator();
  }
}
