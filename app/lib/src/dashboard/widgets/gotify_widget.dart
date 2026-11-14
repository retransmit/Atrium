import 'package:core_models/core_models.dart';
import 'package:core_router/core_router.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:service_gotify/service_gotify.dart';

import '../dashboard_widget_card.dart';
import '../dashboard_widget_kind.dart';

/// Compact dashboard widget for Gotify.
///
/// Shows how many messages are on the server, how many of them are high
/// priority, and the newest message.
class DashboardGotifyWidget extends StatelessWidget {
  const DashboardGotifyWidget({
    required this.instances,
    super.key,
  });

  final List<Instance> instances;

  @override
  Widget build(BuildContext context) {
    final Color accent = ServiceVisuals.accent(ServiceKind.gotify);

    return DashboardWidgetCard(
      kind: DashboardWidgetKind.gotify,
      accent: accent,
      onTap:
          instances.length == 1 ? () => _open(context, instances.first) : null,
      child: instances.isEmpty
          ? const DashboardIdleRow(text: 'No Gotify instances configured')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (int index = 0; index < instances.length; index++) ...<Widget>[
                  if (index > 0) const Divider(height: Insets.lg),
                  _GotifyInstanceBlock(
                    instance: instances[index],
                    showName: instances.length > 1,
                    onTap: instances.length > 1
                        ? () => _open(context, instances[index])
                        : null,
                  ),
                ],
              ],
            ),
    );
  }

  void _open(BuildContext context, Instance instance) {
    context.go(
      AtriumRoutes.servicePath(instance.kind.name, instance.id),
    );
  }
}

class _GotifyInstanceBlock extends ConsumerWidget {
  const _GotifyInstanceBlock({
    required this.instance,
    required this.showName,
    required this.onTap,
  });

  final Instance instance;
  final bool showName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AsyncValue<GotifyMessageFeed> feedAsync =
        ref.watch(gotifyMessagesProvider(instance));

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showName) ...<Widget>[
          Text(
            instance.name,
            style: textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Insets.xs),
        ],
        feedAsync.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: Insets.sm),
            child: SizedBox(
              height: 20,
              width: 20,
              child: ExpressiveProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (err, _) => DashboardErrorRow(
            onRetry: () => ref.invalidate(gotifyMessagesProvider(instance)),
          ),
          data: (GotifyMessageFeed feed) => _GotifyContent(feed: feed),
        ),
      ],
    );

    if (onTap == null) return content;

    return InkWell(
      onTap: onTap,
      borderRadius: Radii.card,
      child: content,
    );
  }
}

class _GotifyContent extends StatelessWidget {
  const _GotifyContent({required this.feed});

  final GotifyMessageFeed feed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final List<GotifyMessage> messages = feed.messages;

    if (messages.isEmpty) {
      return const DashboardIdleRow(text: 'No messages');
    }

    final GotifyMessage newest = messages.first;
    final int highPriority = messages
        .where((GotifyMessage m) => m.level == GotifyPriority.high)
        .length;
    final String title = newest.title?.trim().isNotEmpty == true
        ? newest.title!.trim()
        : newest.message;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: Insets.xs,
          runSpacing: Insets.xs,
          children: <Widget>[
            _MiniStatPill(
              icon: Icons.notifications_outlined,
              label: feed.hasMore
                  ? '${messages.length}+ messages'
                  : '${messages.length} messages',
              color: colorScheme.surfaceContainerHighest,
              textColor: colorScheme.onSurfaceVariant,
            ),
            _MiniStatPill(
              icon: Icons.priority_high_rounded,
              label: '$highPriority high priority',
              color: highPriority > 0
                  ? colorScheme.errorContainer
                  : colorScheme.surfaceContainerHighest,
              textColor: highPriority > 0
                  ? colorScheme.onErrorContainer
                  : colorScheme.onSurfaceVariant,
            ),
          ],
        ),
        const SizedBox(height: Insets.sm),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (newest.date != null)
          Text(
            gotifyRelativeTime(newest.date!, DateTime.now()),
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _MiniStatPill extends StatelessWidget {
  const _MiniStatPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.xs + 2,
        vertical: Insets.xxs,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: Radii.chip,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: Insets.xxs + 1),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
