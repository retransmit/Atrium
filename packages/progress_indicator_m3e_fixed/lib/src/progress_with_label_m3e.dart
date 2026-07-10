import 'package:flutter/material.dart';

import 'circular_progress_m3e.dart';
import 'enums.dart';

class ProgressWithLabelM3E extends StatelessWidget {
  const ProgressWithLabelM3E({
    super.key,
    required this.value,
    this.size = CircularProgressM3ESize.m,
    this.textStyle,
  });

  final double value;
  final CircularProgressM3ESize size;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final d =
        size.diameterWavy; // ProgressWithLabel uses wavy circular by default
    return SizedBox(
      width: d,
      height: d,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicatorM3E(value: value, size: size),
          Text('${(value * 100).round()}%',
              style: textStyle ?? Theme.of(context).textTheme.labelMedium,),
        ],
      ),
    );
  }
}
