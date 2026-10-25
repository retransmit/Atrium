import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/cleanuparr_event.dart';
import 'cleanuparr_event_detail_sheet.dart';

/// Card item displaying an audit log event with semantic icon, title, and timestamp.
class CleanuparrEventCard extends StatelessWidget {
  const CleanuparrEventCard({required this.event, super.key});

  final CleanuparrEvent event;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final IconData icon = event.isMalware
        ? Icons.shield_outlined
        : (event.isStrike
            ? Icons.gavel_outlined
            : (event.isRemoval
                ? Icons.delete_outline_rounded
                : Icons.info_outline));

    final Color iconColor = event.isMalware
        ? colorScheme.error
        : (event.isStrike
            ? colorScheme.tertiary
            : colorScheme.primary);

    final String timeStr = DateFormat('MMM d, HH:mm').format(event.timestamp.toLocal());

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(borderRadius: Radii.card),
      margin: const EdgeInsets.only(bottom: Insets.sm),
      child: InkWell(
        borderRadius: Radii.card,
        onTap: () => CleanuparrEventDetailSheet.show(context, event),
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(Insets.xs + 2),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            event.eventType,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          timeStr,
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Insets.xxs),
                    if (event.downloadItemTitle != null) ...<Widget>[
                      Text(
                        event.downloadItemTitle!,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: Insets.xxs),
                    ],
                    Text(
                      event.message,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
