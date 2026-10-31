import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../models/slskd_community_models.dart';
import '../slskd_format.dart';
import 'slskd_peer_action_sheet.dart';

/// Bubble widget rendering an individual message in a Soulseek chat room or DM thread.
class SlskdChatBubble extends StatelessWidget {
  SlskdChatBubble.room({
    required this.instance,
    required SlskdRoomMessage roomMessage,
    this.onPeerTap,
    super.key,
  })  : username = roomMessage.username,
        message = roomMessage.message,
        timestamp = roomMessage.timestamp,
        isOutbound = roomMessage.self,
        isSystem = roomMessage.username.isEmpty ||
            roomMessage.username.toLowerCase() == 'system',
        isRoom = true;

  SlskdChatBubble.direct({
    required this.instance,
    required SlskdPrivateMessage privateMessage,
    this.onPeerTap,
    super.key,
  })  : username = privateMessage.username,
        message = privateMessage.message,
        timestamp = privateMessage.timestamp,
        isOutbound = privateMessage.direction == MessageDirection.outbound,
        isSystem = false,
        isRoom = false;

  final Instance instance;
  final String username;
  final String message;
  final DateTime timestamp;
  final bool isOutbound;
  final bool isSystem;
  final bool isRoom;
  final VoidCallback? onPeerTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.xs),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: Insets.sm, vertical: 3),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message,
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final double maxBubbleWidth = MediaQuery.sizeOf(context).width * 0.78;
    final String timeStr = slskdFormatTime(timestamp);

    final Color bubbleColor = isOutbound
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHigh;
    final Color textColor = isOutbound
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;

    final BorderRadius radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: isOutbound ? const Radius.circular(16) : const Radius.circular(3),
      bottomRight: isOutbound ? const Radius.circular(3) : const Radius.circular(16),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 3),
      child: Row(
        mainAxisAlignment: isOutbound ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          // Show chatter avatar only in multi-user rooms for inbound messages
          if (isRoom && !isOutbound) ...<Widget>[
            GestureDetector(
              onTap: onPeerTap ??
                  () => showSlskdPeerActionSheet(
                        context,
                        instance: instance,
                        username: username,
                      ),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: colorScheme.secondaryContainer,
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ),
            const SizedBox(width: Insets.xs),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Insets.sm + 2,
                vertical: Insets.xs + 2,
              ),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: radius,
              ),
              child: Column(
                crossAxisAlignment:
                    isOutbound ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: <Widget>[
                  // Show chatter handle only in multi-user rooms
                  if (isRoom && !isOutbound && username.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: InkWell(
                        onTap: onPeerTap ??
                            () => showSlskdPeerActionSheet(
                                  context,
                                  instance: instance,
                                  username: username,
                                ),
                        borderRadius: BorderRadius.circular(4),
                        child: Text(
                          username,
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  Text(
                    message,
                    style: textTheme.bodyMedium?.copyWith(
                      color: textColor,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeStr,
                    style: textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      color: isOutbound
                          ? colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                          : colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
