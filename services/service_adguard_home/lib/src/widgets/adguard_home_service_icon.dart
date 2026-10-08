import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The icon of a blockable service.
///
/// The server sends each as an SVG drawn in the page's text colour, so it
/// is drawn in [color] here. A service with no icon, or with one that
/// cannot be drawn, gets a plain one: what a server sends must not be able
/// to break a list.
class AdguardHomeServiceIcon extends StatelessWidget {
  const AdguardHomeServiceIcon({
    required this.icon,
    this.size = 24,
    this.color,
    super.key,
  });

  /// The SVG, as bytes.
  final Uint8List? icon;
  final double size;

  /// Defaults to the colour icons have here.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color color = this.color ??
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurfaceVariant;
    final Widget plain = Icon(Icons.block, size: size, color: color);
    final Uint8List? icon = this.icon;
    if (icon == null) return plain;
    return SvgPicture.memory(
      icon,
      width: size,
      height: size,
      theme: SvgTheme(currentColor: color),
      placeholderBuilder: (BuildContext _) => SizedBox.square(dimension: size),
      errorBuilder: (BuildContext _, Object __, StackTrace ___) => plain,
    );
  }
}
