import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../models/slskd_community_models.dart';
import '../slskd_format.dart';

/// List tile representing an active 1-on-1 direct message conversation in the inbox.
class SlskdConversationTile extends StatelessWidget {
  const SlskdConversationTile({
    required this.conversation,
    required this.onTap,
    this.onClose,
    super.key,
  });

  final SlskdConversation conversation;
  final VoidCallback onTap;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final String username = conversation.username;
    final SlskdPrivateMessage? last = conversation.lastMessage;
    final int unreadCount = conversation.unAcknowledgedMessageCount;
    final bool hasUnread = unreadCount > 0;

    final String timeStr = last != null ? slskdFormatTime(last.timestamp) : '';
    final String preview = last != null
        ? (last.isOutbound ? 'You: ${last.message}' : last.message)
        : (hasUnread
            ? '$unreadCount unread message${unreadCount > 1 ? 's' : ''}'
            : 'Tap to chat');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 3),
      color: hasUnread
          ? colorScheme.surfaceContainerHigh
          : colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.sm + 2, vertical: Insets.xs + 2),
          child: Row(
            children: <Widget>[
              // Peer Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: hasUnread
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHighest,
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: hasUnread
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: Insets.sm),

              // Username & Last Message Snippet
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            username,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (timeStr.isNotEmpty) ...<Widget>[
                          const SizedBox(width: Insets.xs),
                          Text(
                            timeStr,
                            style: textTheme.labelSmall?.copyWith(
                              color: hasUnread ? colorScheme.primary : colorScheme.outline,
                              fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      preview,
                      style: textTheme.bodySmall?.copyWith(
                        color: hasUnread
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
                        fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Unread pill badge / Close action
              if (hasUnread) ...<Widget>[
                const SizedBox(width: Insets.xs),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    unreadCount.toString(),
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],

              if (onClose != null)
                IconButton(
                  tooltip: 'Close conversation',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close_rounded, size: 18, color: colorScheme.outline),
                  onPressed: onClose,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
