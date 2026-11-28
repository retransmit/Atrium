import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/technitium_settings.dart';
import '../models/technitium_status.dart';
import '../technitium_providers.dart';

/// Settings and DNS cache operations tab.
class TechnitiumSettingsTab extends ConsumerStatefulWidget {
  const TechnitiumSettingsTab({
    required this.instance,
    super.key,
  });

  final Instance instance;

  @override
  ConsumerState<TechnitiumSettingsTab> createState() =>
      _TechnitiumSettingsTabState();
}

class _TechnitiumSettingsTabState extends ConsumerState<TechnitiumSettingsTab> {
  bool _flushing = false;
  bool _updatingLists = false;

  Instance get _instance => widget.instance;
  TechnitiumActions get _actions =>
      ref.read(technitiumActionsProvider(_instance));

  Future<void> _flushCache() async {
    if (_flushing) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Flush DNS cache?'),
        content: const Text(
          'This will clear all cached DNS records from the server.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Flush'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _flushing = true);
    try {
      await _actions.flushDnsCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('DNS cache flushed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to flush cache: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _flushing = false);
    }
  }

  Future<void> _toggleBlocking(bool enable) async {
    try {
      await _actions.setProtection(enabled: enable);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(enable ? 'Blocking enabled' : 'Blocking disabled'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to set blocking: $e')),
        );
      }
    }
  }

  Future<void> _forceUpdateBlockLists() async {
    if (_updatingLists) return;
    setState(() => _updatingLists = true);
    try {
      await _actions.forceUpdateBlockLists();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Block lists update triggered')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update block lists: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingLists = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    final AsyncValue<TechnitiumSettings> settingsAsync =
        ref.watch(technitiumSettingsProvider(_instance));
    final AsyncValue<TechnitiumStatus> statusAsync =
        ref.watch(technitiumStatusProvider(_instance));

    return RefreshIndicator(
      onRefresh: () async => _actions.refresh(),
      child: ListView(
        padding: const EdgeInsets.all(Insets.md),
        children: <Widget>[
          // 1. DNS Cache Section
          Material(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(Insets.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(Icons.cached_rounded, color: cs.primary),
                      const SizedBox(width: Insets.sm),
                      Text(
                        'DNS Cache',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.xs),
                  Text(
                    'Clear cached DNS records immediately from the resolver.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Insets.md),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: _flushing ? null : _flushCache,
                      icon: _flushing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_sweep_rounded),
                      label: const Text('Flush DNS cache'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Insets.md),

          // 2. Blocking Configuration Section
          settingsAsync.when(
            data: (TechnitiumSettings settings) => Material(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(Insets.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.shield_outlined, color: cs.primary),
                        const SizedBox(width: Insets.sm),
                        Text(
                          'Blocking Configuration',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Insets.md),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enable Blocking'),
                      subtitle: const Text(
                        'Block network-wide ads and tracking domains',
                      ),
                      value: settings.enableBlocking,
                      onChanged: _toggleBlocking,
                    ),
                    const Divider(),
                    _infoRow(theme, 'Blocking Type', settings.blockingType),
                    _infoRow(
                      theme,
                      'Update Interval',
                      '${settings.blockListUpdateIntervalHours} hours',
                    ),
                    _infoRow(
                      theme,
                      'Configured Block Lists',
                      '${settings.blockLists.length} lists',
                    ),
                    const SizedBox(height: Insets.md),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed:
                            _updatingLists ? null : _forceUpdateBlockLists,
                        icon: _updatingLists
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.sync),
                        label: const Text('Force update block lists'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(Insets.lg),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (Object e, _) => Text('Error loading settings: $e'),
          ),
          const SizedBox(height: Insets.md),

          // 3. Server Metrics & Info
          statusAsync.when(
            data: (TechnitiumStatus status) => Material(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(Insets.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.info_outline, color: cs.primary),
                        const SizedBox(width: Insets.sm),
                        Text(
                          'Server Info',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Insets.md),
                    if (status.version.isNotEmpty)
                      _infoRow(theme, 'Version', status.version),
                    if (status.dnsServerDomain.isNotEmpty)
                      _infoRow(theme, 'Server Domain', status.dnsServerDomain),
                    if (status.serverIp.isNotEmpty)
                      _infoRow(theme, 'Server IP', status.serverIp),
                    if (status.uptimeSeconds > 0)
                      _infoRow(
                        theme,
                        'Uptime',
                        '${status.uptimeSeconds ~/ 3600} hours ${(status.uptimeSeconds % 3600) ~/ 60} mins',
                      ),
                  ],
                ),
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: Insets.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
