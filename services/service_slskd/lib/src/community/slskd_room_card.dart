import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// Card representing a public or joined Soulseek chat room.
class SlskdRoomCard extends StatelessWidget {
  const SlskdRoomCard({
    required this.name,
    required this.userCount,
    this.isJoined = false,
    this.isPrivate = false,
    this.onTap,
    this.onJoin,
    this.onLeave,
    super.key,
  });

  final String name;
  final int userCount;
  final bool isJoined;
  final bool isPrivate;
  final VoidCallback? onTap;
  final VoidCallback? onJoin;
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 3),
      color: isJoined ? colorScheme.surfaceContainerHigh : colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        onTap: isJoined ? onTap : onJoin,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.sm + 2, vertical: Insets.xs + 2),
          child: Row(
            children: <Widget>[
              // Room icon
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isJoined
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isPrivate
                      ? Icons.lock_outline_rounded
                      : (isJoined ? Icons.forum_rounded : Icons.tag_rounded),
                  size: 20,
                  color: isJoined
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: Insets.sm),

              // Room Name & Member Count
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            name,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: isJoined ? FontWeight.bold : FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isJoined) ...<Widget>[
                          const SizedBox(width: Insets.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'JOINED',
                              style: textTheme.labelSmall?.copyWith(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$userCount active members',
                      style: textTheme.labelSmall?.copyWith(color: colorScheme.outline),
                    ),
                  ],
                ),
              ),

              // Action button
              if (isJoined) ...<Widget>[
                if (onLeave != null)
                  IconButton(
                    tooltip: 'Leave room',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.logout_rounded, size: 18, color: colorScheme.outline),
                    onPressed: onLeave,
                  ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: colorScheme.outline,
                ),
              ] else if (onJoin != null) ...<Widget>[
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 4),
                  ),
                  onPressed: onJoin,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.login_rounded, size: 14),
                      SizedBox(width: 4),
                      Text('Join'),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
