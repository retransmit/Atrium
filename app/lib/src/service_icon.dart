import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// A service's bundled icon (`assets/service_icons/<kind>.png`), falling
/// back to [ServiceVisuals.icon] tinted with [ServiceVisuals.accent].
class ServiceIcon extends StatelessWidget {
  const ServiceIcon({
    required this.kind,
    this.size = 24,
    super.key,
  });

  final ServiceKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/service_icons/${kind.name}.png',
      width: size,
      height: size,
      errorBuilder: (
        BuildContext context,
        Object error,
        StackTrace? stackTrace,
      ) =>
          Icon(
        ServiceVisuals.icon(kind),
        size: size,
        color: ServiceVisuals.accent(kind),
      ),
    );
  }
}
