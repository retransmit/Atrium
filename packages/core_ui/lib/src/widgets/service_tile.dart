import 'package:core_models/core_models.dart';
import 'package:flutter/material.dart';

import '../design_tokens.dart';
import '../service_visuals.dart';
import 'status_chip.dart';

/// A list tile representing one configured [Instance]: service icon badge,
/// instance name, service tagline, and a health dot.
class ServiceTile extends StatelessWidget {
  const ServiceTile({
    required this.instance,
    this.health = Health.unknown,
    this.subtitle,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  final Instance instance;
  final Health health;

  /// Overrides the default subtitle (the service tagline) when provided -
  /// e.g., a queue count or "3 missing".
  final String? subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final Color accent = ServiceVisuals.accent(instance.kind);
    return Card(
      child: ListTile(
        leading: Container(
          width: Sizes.serviceBadge,
          height: Sizes.serviceBadge,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
          child: Icon(ServiceVisuals.icon(instance.kind), color: accent),
        ),
        title: Text(
          instance.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(subtitle ?? instance.kind.tagline),
        trailing: StatusChip(health: health, compact: true),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}
