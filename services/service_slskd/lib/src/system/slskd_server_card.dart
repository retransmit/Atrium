import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/slskd_system_models.dart';
import '../slskd_api.dart';
import '../slskd_providers.dart';

/// Card displaying Soulseek server connection status, watchdog state, and connection controls.
class SlskdServerCard extends ConsumerStatefulWidget {
  const SlskdServerCard({
    required this.instance,
    required this.server,
    this.watchdog,
    super.key,
  });

  final Instance instance;
  final SlskdServerStatus server;
  final SlskdConnectionWatchdogState? watchdog;

  @override
  ConsumerState<SlskdServerCard> createState() => _SlskdServerCardState();
}

class _SlskdServerCardState extends ConsumerState<SlskdServerCard> {
  bool _isActionInProgress = false;

  Future<void> _handleConnect() async {
    setState(() => _isActionInProgress = true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final SlskdApi api =
          await ref.read(slskdApiProvider(widget.instance).future);
      await api.reconnectServer();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Connecting to Soulseek network...'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to connect: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isActionInProgress = false);
        ref.invalidate(slskdApplicationStateProvider(widget.instance));
      }
    }
  }

  Future<void> _handleDisconnect() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Disconnect from Soulseek?'),
        content: const Text(
          'Active searches, chat rooms, and direct messages will be paused until reconnected.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isActionInProgress = true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final SlskdApi api =
          await ref.read(slskdApiProvider(widget.instance).future);
      await api.disconnectServer();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Disconnected from Soulseek network'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to disconnect: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isActionInProgress = false);
        ref.invalidate(slskdApplicationStateProvider(widget.instance));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    final bool isOnline = widget.server.isConnected || widget.server.isLoggedIn;
    final bool isTransitioning = widget.server.isTransitioning ||
        widget.server.isConnecting ||
        widget.server.isLoggingIn ||
        widget.server.isDisconnecting;

    final Color statusColor = isTransitioning
        ? colorScheme.tertiary
        : (isOnline ? colorScheme.primary : colorScheme.error);

    final Color statusBgColor = isTransitioning
        ? colorScheme.tertiaryContainer
        : (isOnline
            ? colorScheme.primaryContainer
            : colorScheme.errorContainer);

    final Color statusTextColor = isTransitioning
        ? colorScheme.onTertiaryContainer
        : (isOnline
            ? colorScheme.onPrimaryContainer
            : colorScheme.onErrorContainer);

    String statusLabel = 'Disconnected';
    if (isTransitioning) {
      if (widget.server.isDisconnecting) {
        statusLabel = 'Disconnecting...';
      } else if (widget.server.isLoggingIn) {
        statusLabel = 'Logging In...';
      } else {
        statusLabel = 'Connecting...';
      }
    } else if (widget.server.isLoggedIn) {
      statusLabel = 'Logged In';
    } else if (widget.server.isConnected) {
      statusLabel = 'Connected';
    }

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
                Container(
                  padding: const EdgeInsets.all(Insets.xs),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.dns_rounded,
                    size: 20,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Soulseek Network',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.server.address.isNotEmpty
                            ? widget.server.address
                            : 'server.slsknet.org',
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
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: Insets.xs),
                      Text(
                        statusLabel,
                        style: textTheme.labelSmall?.copyWith(
                          color: statusTextColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (widget.watchdog != null && widget.watchdog!.isEnabled) ...<Widget>[
              const SizedBox(height: Insets.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.sm,
                  vertical: Insets.xs,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: Insets.xs),
                    Expanded(
                      child: Text(
                        widget.watchdog!.isAttemptingConnection
                            ? 'Watchdog: Attempting automatic reconnect...'
                            : 'Watchdog: Active (Auto-reconnect enabled)',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: Insets.md),
            Row(
              children: <Widget>[
                if (isOnline || isTransitioning) ...<Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.error,
                        side: BorderSide(color: colorScheme.error),
                        minimumSize: const Size.fromHeight(42),
                      ),
                      onPressed: _isActionInProgress ? null : _handleDisconnect,
                      icon: const Icon(Icons.link_off_rounded, size: 18),
                      label: const Text('Disconnect'),
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(42),
                      ),
                      onPressed: _isActionInProgress ? null : _handleConnect,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Reconnect'),
                    ),
                  ),
                ] else ...<Widget>[
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(42),
                      ),
                      onPressed: _isActionInProgress ? null : _handleConnect,
                      icon: const Icon(Icons.link_rounded, size: 18),
                      label: const Text('Connect to Soulseek'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
