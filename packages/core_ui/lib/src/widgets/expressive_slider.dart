import 'dart:math' as math;
import 'package:flutter/material.dart';

class ExpressiveSliderThumbShape extends SliderComponentShape {
  const ExpressiveSliderThumbShape({
    this.width = 4.0,
    this.height = 32.0,
  });

  final double width;
  final double height;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size(width, height);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;
    final Paint paint = Paint()..color = sliderTheme.thumbColor ?? Colors.white;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: width, height: height),
      Radius.circular(width / 2),
    );

    canvas.drawRRect(rrect, paint);
  }
}

class ExpressiveSliderTrackShape extends SliderTrackShape {
  const ExpressiveSliderTrackShape({
    this.gap = 8.0,
  });

  final double gap;

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double overlayWidth = sliderTheme.overlayShape
            ?.getPreferredSize(isEnabled, isDiscrete)
            .width ??
        32.0;
    final double trackHeight = sliderTheme.trackHeight ?? 16.0;
    final double trackLeft = offset.dx + overlayWidth / 2;
    final double trackTop =
        offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth =
        math.max(0.0, parentBox.size.width - overlayWidth);
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 0,
  }) {
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final Paint activePaint = Paint()
      ..color = sliderTheme.activeTrackColor ?? Colors.blue;
    final Paint inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor ?? Colors.grey;
    final Radius radius = Radius.circular(trackRect.height / 2);

    final double minTrackWidth = trackRect.height;

    // Active track
    final double activeTrackRight = thumbCenter.dx - gap;
    if (activeTrackRight - trackRect.left >= minTrackWidth) {
      final Rect activeRect = Rect.fromLTRB(
        trackRect.left,
        trackRect.top,
        activeTrackRight,
        trackRect.bottom,
      );
      context.canvas.drawRRect(
        RRect.fromRectAndRadius(activeRect, radius),
        activePaint,
      );
    } else if (activeTrackRight > trackRect.left) {
      final Rect activeRect = Rect.fromLTRB(
        trackRect.left,
        trackRect.top,
        activeTrackRight,
        trackRect.bottom,
      );
      context.canvas.drawRRect(
        RRect.fromRectAndRadius(
            activeRect, Radius.circular(activeRect.width / 2),),
        activePaint,
      );
    }

    // Inactive track
    final double inactiveTrackLeft = thumbCenter.dx + gap;
    if (trackRect.right - inactiveTrackLeft >= minTrackWidth) {
      final Rect inactiveRect = Rect.fromLTRB(
        inactiveTrackLeft,
        trackRect.top,
        trackRect.right,
        trackRect.bottom,
      );
      context.canvas.drawRRect(
        RRect.fromRectAndRadius(inactiveRect, radius),
        inactivePaint,
      );

      final Paint dotPaint = Paint()
        ..color = sliderTheme.thumbColor ?? Colors.white;
      final double dotRadius = trackRect.height / 8;
      if (trackRect.right - inactiveTrackLeft > dotRadius * 4) {
        context.canvas.drawCircle(
          Offset(trackRect.right - trackRect.height / 2, trackRect.center.dy),
          dotRadius,
          dotPaint,
        );
      }
    } else if (trackRect.right > inactiveTrackLeft) {
      final Rect inactiveRect = Rect.fromLTRB(
        inactiveTrackLeft,
        trackRect.top,
        trackRect.right,
        trackRect.bottom,
      );
      context.canvas.drawRRect(
        RRect.fromRectAndRadius(
            inactiveRect, Radius.circular(inactiveRect.width / 2),),
        inactivePaint,
      );
    }
  }
}
