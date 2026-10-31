import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../models/slskd_system_models.dart';
import '../slskd_format.dart';

/// Card displaying authenticated Soulseek user account, privileges, and network statistics.
class SlskdUserCard extends StatelessWidget {
  const SlskdUserCard({
    required this.user,
    super.key,
  });

  final SlskdUserState user;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final String initial = user.username.isNotEmpty
        ? user.username[0].toUpperCase()
        : 'U';

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 20,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        user.username.isNotEmpty ? user.username : 'Unknown User',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Soulseek Account',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.sm,
                    vertical: Insets.xs / 2,
                  ),
                  decoration: BoxDecoration(
                    color: user.isPrivileged
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        user.isPrivileged
                            ? Icons.star_rounded
                            : Icons.person_outline_rounded,
                        size: 14,
                        color: user.isPrivileged
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: Insets.xs / 2),
                      Text(
                        user.isPrivileged
                            ? 'Privileged (${user.privilegesRemaining}d)'
                            : 'Standard',
                        style: textTheme.labelSmall?.copyWith(
                          color: user.isPrivileged
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.md),
            // 2x2 Stats Grid
            Row(
              children: <Widget>[
                Expanded(
                  child: _StatBox(
                    icon: Icons.speed_rounded,
                    label: 'Avg Speed',
                    value: slskdFormatRate(user.averageSpeed),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: _StatBox(
                    icon: Icons.cloud_upload_rounded,
                    label: 'Uploads',
                    value: '${user.uploadCount}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: _StatBox(
                    icon: Icons.insert_drive_file_rounded,
                    label: 'Shared Files',
                    value: '${user.fileCount}',
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: _StatBox(
                    icon: Icons.folder_rounded,
                    label: 'Directories',
                    value: '${user.directoryCount}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.sm,
        vertical: Insets.sm,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: Insets.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
                Text(
                  value,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
