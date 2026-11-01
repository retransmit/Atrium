import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../models/slskd_models.dart';
import '../slskd_format.dart';
import 'slskd_user_bio_sheet.dart';

/// Card summarizing a peer's identity, presence, slot availability, and bio launcher.
class SlskdBrowsePeerCard extends StatelessWidget {
  const SlskdBrowsePeerCard({
    required this.username,
    required this.userInfo,
    required this.userStatus,
    this.totalFolders = 0,
    this.totalFiles = 0,
    super.key,
  });

  final String username;
  final SlskdUserInfo? userInfo;
  final SlskdUserStatus? userStatus;
  final int totalFolders;
  final int totalFiles;

  void _openBio(BuildContext context) {
    if (userInfo == null && userStatus == null) return;
    showSlskdUserBioSheet(
      context,
      username: username,
      userInfo: userInfo,
      userStatus: userStatus,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final bool isOnline = userStatus?.isOnline ?? false;
    final bool isAway = userStatus?.isAway ?? false;
    final bool hasFreeSlot = userInfo?.hasFreeUploadSlot ?? false;
    final int queueLen = userInfo?.queueLength ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.xs),
      elevation: 0,
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Insets.sm),
        child: Row(
          children: <Widget>[
            // Avatar with Presence indicator
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                CircleAvatar(
                  radius: 20,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    username.isNotEmpty ? username[0].toUpperCase() : '?',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: slskdPresenceColor(
                        colorScheme,
                        isOnline: isOnline,
                        isAway: isAway,
                      ),
                      border: Border.all(
                        color: colorScheme.surfaceContainerHigh,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: Insets.sm),

            // Peer info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          username,
                          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (userStatus?.isPrivileged == true) ...<Widget>[
                        const SizedBox(width: Insets.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'SUPPORTER',
                            style: textTheme.labelSmall?.copyWith(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: <Widget>[
                      // Slot badge, only once the profile has loaded: before
                      // that the queue length is a default, not the peer's.
                      if (userInfo != null) ...<Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: hasFreeSlot
                                ? colorScheme.tertiaryContainer
                                : colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            hasFreeSlot ? 'Free Slot' : 'Queue: #$queueLen',
                            style: textTheme.labelSmall?.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: hasFreeSlot
                                  ? colorScheme.onTertiaryContainer
                                  : colorScheme.outline,
                            ),
                          ),
                        ),
                        const SizedBox(width: Insets.xs),
                      ],
                      if (totalFolders > 0 || totalFiles > 0)
                        Flexible(
                          child: Text(
                            slskdFormatFolderAndFileCounts(totalFolders, totalFiles),
                            style: textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              color: colorScheme.outline,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Bio / Info action button
            IconButton.filledTonal(
              tooltip: 'View Peer Profile & Bio',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.info_outline_rounded, size: 18),
              onPressed: (userInfo == null && userStatus == null)
                  ? null
                  : () => _openBio(context),
            ),
          ],
        ),
      ),
    );
  }
}
