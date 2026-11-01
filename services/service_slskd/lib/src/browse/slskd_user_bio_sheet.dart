import 'dart:typed_data';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../models/slskd_models.dart';
import '../slskd_format.dart';

/// Shows the modal bottom sheet displaying a Soulseek peer's profile, bio, and upload slots.
Future<void> showSlskdUserBioSheet(
  BuildContext context, {
  required String username,
  SlskdUserInfo? userInfo,
  SlskdUserStatus? userStatus,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext _) => SlskdUserBioSheet(
      username: username,
      userInfo: userInfo ?? const SlskdUserInfo(description: ''),
      userStatus: userStatus ?? const SlskdUserStatus(),
    ),
  );
}

/// Modal bottom sheet displaying a Soulseek peer's profile, avatar, bio description,
/// and connection capabilities.
class SlskdUserBioSheet extends StatelessWidget {
  const SlskdUserBioSheet({
    required this.username,
    required this.userInfo,
    required this.userStatus,
    super.key,
  });

  final String username;
  final SlskdUserInfo userInfo;
  final SlskdUserStatus userStatus;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final Uint8List? picBytes =
        userInfo.picture != null ? Uint8List.fromList(userInfo.picture!) : null;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom + Insets.lg,
          left: Insets.md,
          right: Insets.md,
          top: Insets.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
          // Header: Avatar, Username, Status & Privileged pill
          Row(
            children: <Widget>[
              // Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primaryContainer,
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: picBytes != null && picBytes.isNotEmpty
                    ? Image.memory(
                        picBytes,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.person_rounded,
                          size: 32,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      )
                    : Icon(
                        Icons.person_rounded,
                        size: 32,
                        color: colorScheme.onPrimaryContainer,
                      ),
              ),
              const SizedBox(width: Insets.md),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            username,
                            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (userStatus.isPrivileged) ...<Widget>[
                          const SizedBox(width: Insets.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Supporter',
                              style: textTheme.labelSmall?.copyWith(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: <Widget>[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: slskdPresenceColor(
                              colorScheme,
                              isOnline: userStatus.isOnline,
                              isAway: userStatus.isAway,
                            ),
                          ),
                        ),
                        const SizedBox(width: Insets.xs),
                        Text(
                          userStatus.presence,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),

          // Connection Stats Chips Row
          Wrap(
            spacing: Insets.xs,
            runSpacing: Insets.xs,
            children: <Widget>[
              // Free slot indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: userInfo.hasFreeUploadSlot
                      ? colorScheme.tertiaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      userInfo.hasFreeUploadSlot
                          ? Icons.bolt_rounded
                          : Icons.hourglass_empty_rounded,
                      size: 13,
                      color: userInfo.hasFreeUploadSlot
                          ? colorScheme.onTertiaryContainer
                          : colorScheme.outline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      userInfo.hasFreeUploadSlot ? 'Free Upload Slot' : 'Queue: #${userInfo.queueLength}',
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: userInfo.hasFreeUploadSlot
                            ? colorScheme.onTertiaryContainer
                            : colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),

              // Upload slots count
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.swap_vert_rounded, size: 13, color: colorScheme.outline),
                    const SizedBox(width: 4),
                    Text(
                      'Slots: ${userInfo.uploadSlots}',
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),

          // User Bio / Description
          Text(
            'User Bio',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: Insets.xs),

          Container(
            padding: const EdgeInsets.all(Insets.sm),
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                width: 0.5,
              ),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                userInfo.description.isNotEmpty
                    ? userInfo.description
                    : 'This peer has not set a user bio.',
                style: textTheme.bodySmall?.copyWith(
                  color: userInfo.description.isNotEmpty
                      ? colorScheme.onSurface
                      : colorScheme.outline,
                  height: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: Insets.md),

          // Close button
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    ),
  );
  }
}
