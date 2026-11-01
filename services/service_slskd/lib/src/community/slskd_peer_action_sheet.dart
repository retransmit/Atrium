import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../browse/slskd_user_bio_sheet.dart';
import '../slskd_format.dart';
import '../slskd_providers.dart';

/// Shows the unified peer action bottom sheet when tapping a user in chat.
Future<void> showSlskdPeerActionSheet(
  BuildContext context, {
  required Instance instance,
  required String username,
  WidgetRef? ref,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext _) => SlskdPeerActionSheet(
      instance: instance,
      username: username,
    ),
  );
}

/// Modal bottom sheet providing 1-tap peer shortcuts:
/// - Browse Peer Shares
/// - Send Direct Message
/// - View User Bio & Upload Slots
class SlskdPeerActionSheet extends ConsumerWidget {
  const SlskdPeerActionSheet({
    required this.instance,
    required this.username,
    super.key,
  });

  final Instance instance;
  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final userStatusAsync = ref.watch(slskdUserStatusProvider((instance, username)));
    final userInfoAsync = ref.watch(slskdUserInfoProvider((instance, username)));
    final endpointAsync = ref.watch(slskdUserEndpointProvider((instance, username)));

    final bool isOnline = userStatusAsync.value?.isOnline ?? false;
    final bool isAway = userStatusAsync.value?.isAway ?? false;
    final bool isSupporter = userStatusAsync.value?.isPrivileged ?? false;
    final String? endpointStr = endpointAsync.value?.formatted;
    final String statusText = !userStatusAsync.hasValue
        ? 'Checking status...'
        : (isOnline
            ? (endpointStr != null && endpointStr.isNotEmpty
                ? 'Online • $endpointStr'
                : 'Online on Soulseek')
            : (isAway ? 'Away' : 'Offline'));

    return Padding(
      padding: const EdgeInsets.only(left: Insets.lg, right: Insets.lg, bottom: Insets.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Peer Header
          Row(
            children: <Widget>[
              Stack(
                children: <Widget>[
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Text(
                      username.isNotEmpty ? username[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: slskdPresenceColor(
                          colorScheme,
                          isOnline: isOnline,
                          isAway: isAway,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: colorScheme.surface, width: 2),
                      ),
                    ),
                  ),
                ],
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isSupporter) ...<Widget>[
                          const SizedBox(width: Insets.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'SUPPORTER',
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
                      statusText,
                      style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.lg),

          // Action 1: Browse User Shares
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Icon(Icons.folder_shared_rounded, color: colorScheme.primary),
              title: const Text('Browse User Shares', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Explore files, albums, and discographies'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(context).pop();
                ref.read(slskdBrowseUsernameProvider(instance).notifier).state = username;
                ref.read(slskdBrowsePathSegmentsProvider(instance).notifier).state = const <String>[];
                ref.read(slskdActiveTabProvider(instance).notifier).state = 2;
              },
            ),
          ),
          const SizedBox(height: Insets.xs),

          // Action 2: Send Direct Message
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Icon(Icons.chat_bubble_outline_rounded, color: colorScheme.tertiary),
              title: const Text('Send Direct Message', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Open a private 1-on-1 chat conversation'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(context).pop();
                ref.read(slskdCommunitySegmentProvider(instance).notifier).state = 1;
                ref.read(slskdActiveConversationUsernameProvider(instance).notifier).state = username;
                ref.read(slskdActiveRoomNameProvider(instance).notifier).state = null;
                ref.read(slskdActiveTabProvider(instance).notifier).state = 3;
              },
            ),
          ),
          const SizedBox(height: Insets.xs),

          // Action 3: View Bio & Profile
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Icon(Icons.account_circle_outlined, color: colorScheme.secondary),
              title: const Text('View User Profile', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Check bio, avatar, and upload slot metrics'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                final parentContext = Navigator.of(context).context;
                Navigator.of(context).pop();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (parentContext.mounted) {
                    showSlskdUserBioSheet(
                      parentContext,
                      username: username,
                      userInfo: userInfoAsync.value,
                      userStatus: userStatusAsync.value,
                    );
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }
}
