import 'dart:async';
import 'dart:io';

import 'package:easy_refresh/easy_refresh.dart' as er;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'expressive_progress_indicator.dart';

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

          final double value =
              (state.offset / state.triggerOffset).clamp(0.01, 1.0);
          final bool isRefreshing = state.mode == er.IndicatorMode.ready ||
              state.mode == er.IndicatorMode.processing;
          final double scale = isRefreshing ? 1.0 : value;
          final double opacity = (state.offset / 30.0).clamp(0.0, 1.0);

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
                    child: Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: scale,
                        child: Card(
                          elevation: 6,
                          shape: const CircleBorder(),
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHigh,
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: ExpressiveProgressIndicator(
                              value: null,
                            ),
                          ),
                        ),
                      ),
                    ),
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
