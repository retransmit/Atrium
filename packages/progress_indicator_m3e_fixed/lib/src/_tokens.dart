import 'package:flutter/material.dart';

import 'enums.dart';

@immutable
class Palette {
  const Palette(this.cs);
  final ColorScheme cs;

  // Use theme roles; callers can override colors if needed.
  Color get active => cs.primary;
  Color get track => cs.onSurfaceVariant.withValues(alpha: 0.24);
  Color get bg => cs.surface;
}

@immutable
class LinearSpec {
  const LinearSpec({
    required this.trackHeight,
    required this.gap,
    required this.dotDiameter,
    required this.dotOffset,
    required this.trailingMargin,
    required this.isWavy,
    this.waveAmplitude = 0,
    this.wavePeriod = 40,
  });

  final double trackHeight;
  final double gap; // vertical space between active lane and track lane
  final double dotDiameter;
  final double dotOffset; // center offset from end of active segment
  final double trailingMargin; // empty space at the far right
  final bool isWavy;
  final double waveAmplitude;
  final double wavePeriod;
}

LinearSpec specForLinear({
  required LinearProgressM3ESize size,
  required ProgressM3EShape shape,
}) =>
    switch ((shape, size)) {
      (ProgressM3EShape.flat, LinearProgressM3ESize.s) => const LinearSpec(
          trackHeight: 4,
          gap: 4,
          dotDiameter: 4,
          dotOffset: 4,
          trailingMargin: 4,
          isWavy: false,
        ),
      (ProgressM3EShape.flat, LinearProgressM3ESize.m) => const LinearSpec(
          trackHeight: 8,
          gap: 4,
          dotDiameter: 4,
          dotOffset: 2,
          trailingMargin: 8,
          isWavy: false,
        ),
      (ProgressM3EShape.wavy, LinearProgressM3ESize.s) => const LinearSpec(
          trackHeight: 4,
          gap: 4,
          dotDiameter: 4,
          dotOffset: 2,
          trailingMargin: 10,
          isWavy: true,
          waveAmplitude: 3,
        ),
      (ProgressM3EShape.wavy, LinearProgressM3ESize.m) => const LinearSpec(
          trackHeight: 8,
          gap: 4,
          dotDiameter: 4,
          dotOffset: 2,
          trailingMargin: 14,
          isWavy: true,
          waveAmplitude: 3,
        ),
    };
