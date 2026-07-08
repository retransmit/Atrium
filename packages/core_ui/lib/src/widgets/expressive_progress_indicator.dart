import 'package:flutter/material.dart';
import 'package:m3_expressive/m3_expressive.dart';
import 'package:core_ui/core_ui.dart';

class ExpressiveProgressIndicator extends StatelessWidget {
  const ExpressiveProgressIndicator({
    super.key,
    this.value,
    this.backgroundColor,
    this.color,
    this.valueColor,
    this.strokeWidth = 4.0,
    this.strokeCap,
    this.strokeAlign,
    this.semanticsLabel,
    this.semanticsValue,
  });

  final double? value;
  final Color? backgroundColor;
  final Color? color;
  final Animation<Color?>? valueColor;
  final double strokeWidth;
  final StrokeCap? strokeCap;
  final double? strokeAlign;
  final String? semanticsLabel;
  final String? semanticsValue;

  @override
  Widget build(BuildContext context) {
    if (value != null) {
      // m3_expressive doesn't support determinate progress for the circular loader,
      // so we fall back to the standard CircularProgressIndicator.
      return CircularProgressIndicator(
        value: value,
        backgroundColor: backgroundColor,
        color: color,
        valueColor: valueColor,
        strokeWidth: strokeWidth,
        strokeCap: strokeCap,
        strokeAlign: strokeAlign ?? CircularProgressIndicator.strokeAlignCenter,
        semanticsLabel: semanticsLabel,
        semanticsValue: semanticsValue,
      );
    }

    final effectiveColor = valueColor?.value ?? color;

    // Use M3LoadingIndicator as a drop-in replacement for indeterminate loaders.
    return M3LoadingIndicator(
      color: effectiveColor,
    );
  }
}
