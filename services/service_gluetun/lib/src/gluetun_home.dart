import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'gluetun_api.dart';
import 'gluetun_failure.dart';
import 'gluetun_providers.dart';
import 'models/gluetun_models.dart';

class GluetunHome extends ConsumerStatefulWidget {
  const GluetunHome({required this.instance, super.key});

  final Instance instance;

  @override
  ConsumerState<GluetunHome> createState() => _GluetunHomeState();
}

class _GluetunHomeState extends ConsumerState<GluetunHome> {
  bool _togglingVpn = false;
  bool _togglingDns = false;
  bool _triggeringUpdater = false;

  void _refreshAll() {
    ref.invalidate(gluetunVpnStatusProvider(widget.instance));
    ref.invalidate(gluetunPublicIpProvider(widget.instance));
    ref.invalidate(gluetunPortForwardProvider(widget.instance));
    ref.invalidate(gluetunDnsStatusProvider(widget.instance));
    ref.invalidate(gluetunUpdaterStatusProvider(widget.instance));
  }

  Future<void> _toggleVpn(bool currentlyRunning) async {
    if (_togglingVpn) return;
    if (currentlyRunning &&
        !await _confirmStop(
          title: 'Stop the VPN?',
          message: 'Anything that shares the Gluetun network loses its '
              'connection until the VPN is started again, because the '
              'firewall blocks traffic while the tunnel is down. With port '
              'forwarding on, the forwarded port can change when it '
              'reconnects.',
          action: 'Stop VPN',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => _togglingVpn = true);

    try {
      final GluetunApi api =
          await ref.read(gluetunApiProvider(widget.instance).future);
      await api.setVpnStatus(run: !currentlyRunning);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !currentlyRunning ? 'Starting VPN...' : 'Stopping VPN...',
            ),
          ),
        );
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not change the VPN. '
              '${describeGluetunFailure(e, 'PUT /v1/vpn/status')}',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _togglingVpn = false);
        _refreshAll();
      }
    }
  }

  Future<void> _reconnectVpn() async {
    if (_togglingVpn) return;
    if (!await _confirmStop(
      title: 'Reconnect the VPN?',
      message: 'Gluetun stops the tunnel and starts it again, which can move '
          'it to another server with a new public IP and forwarded port. '
          'Anything that shares the Gluetun network loses its connection for '
          'a few seconds.',
      action: 'Reconnect',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => _togglingVpn = true);

    try {
      final GluetunApi api =
          await ref.read(gluetunApiProvider(widget.instance).future);
      await api.reconnectVpn();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reconnecting VPN...')),
        );
      }
    } on GluetunRestartFailed catch (e) {
      // The worst place to stop: the tunnel is down and so is everything
      // behind it, so say that plainly rather than as a failed reconnect.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'The VPN stopped but did not start again. '
              '${describeGluetunFailure(e.cause, 'PUT /v1/vpn/status')}',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not reconnect the VPN. '
              '${describeGluetunFailure(e, 'PUT /v1/vpn/status')}',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _togglingVpn = false);
        _refreshAll();
      }
    }
  }

  Future<void> _toggleDns(bool currentlyRunning) async {
    if (_togglingDns) return;
    if (currentlyRunning &&
        !await _confirmStop(
          title: 'Stop DNS?',
          message: 'Anything that shares the Gluetun network uses this DNS '
              'server to look up names, so it may fail to connect until DNS '
              'is started again.',
          action: 'Stop DNS',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => _togglingDns = true);

    try {
      final GluetunApi api =
          await ref.read(gluetunApiProvider(widget.instance).future);
      await api.setDnsStatus(run: !currentlyRunning);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !currentlyRunning ? 'Starting DNS...' : 'Stopping DNS...',
            ),
          ),
        );
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not change DNS. '
              '${describeGluetunFailure(e, 'PUT /v1/dns/status')}',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _togglingDns = false);
        _refreshAll();
      }
    }
  }

  Future<void> _triggerUpdater() async {
    if (_triggeringUpdater) return;
    setState(() => _triggeringUpdater = true);

    try {
      final GluetunApi api =
          await ref.read(gluetunApiProvider(widget.instance).future);
      await api.setUpdaterStatus(run: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Triggered server list database update...'),
          ),
        );
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not start the update. '
              '${describeGluetunFailure(e, 'PUT /v1/updater/status')}',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _triggeringUpdater = false);
        _refreshAll();
      }
    }
  }

  /// Asks before stopping something that cuts off what sits behind Gluetun.
  ///
  /// In the usual setup the download client shares Gluetun's network, so a
  /// single mis-tap on Stop would stall every download, or break every name
  /// lookup. Starting is always safe, which is why only stopping asks, and a
  /// reconnect stops the VPN first, so it asks too.
  Future<bool> _confirmStop({
    required String title,
    required String message,
    required String action,
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<GluetunVpnStatus> vpnStatus =
        ref.watch(gluetunVpnStatusProvider(widget.instance));
    final AsyncValue<GluetunPublicIp?> publicIp =
        ref.watch(gluetunPublicIpProvider(widget.instance));
    // Port forwarding is optional and most providers do not offer it, so the
    // row only appears once a port is forwarded. A failed read hides it too:
    // a role that leaves the route out is a normal setup for everyone who
    // does not forward a port, and not worth a warning on their screen.
    final List<int> forwardedPorts =
        ref.watch(gluetunPortForwardProvider(widget.instance)).value?.ports ??
            const <int>[];
    final AsyncValue<GluetunDnsStatus?> dnsStatus =
        ref.watch(gluetunDnsStatusProvider(widget.instance));
    final AsyncValue<GluetunUpdaterStatus?> updaterStatus =
        ref.watch(gluetunUpdaterStatusProvider(widget.instance));

    final ColorScheme scheme = Theme.of(context).colorScheme;

    return EasyRefresh(
      header: const ClassicHeader(
        dragText: 'Pull to refresh',
        armedText: 'Release ready',
        readyText: 'Refreshing...',
        processingText: 'Refreshing...',
        processedText: 'Succeeded',
        failedText: 'Failed',
        messageText: 'Last updated at %T',
      ),
      onRefresh: () async => _refreshAll(),
      child: ListView(
        padding: Insets.page,
        children: <Widget>[
          // VPN Control Card Banner
          vpnStatus.when(
            data: (GluetunVpnStatus status) {
              final bool isRunning = status.isRunning;
              // Theme roles rather than a fixed green, so the card follows the
              // user's palette, dynamic wallpaper colours included, and agrees
              // with the dashboard widget, which uses the same two roles.
              final Color statusColor =
                  isRunning ? scheme.primary : scheme.error;

              return Card(
                elevation: 0,
                color: statusColor.withValues(alpha: 0.12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: statusColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(Insets.lg),
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.all(Insets.md),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isRunning
                                  ? Icons.shield_outlined
                                  : Icons.shield_moon_outlined,
                              size: 32,
                              color: statusColor,
                            ),
                          ),
                          const SizedBox(width: Insets.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'VPN Status',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  status.status.toUpperCase(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: statusColor,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Insets.lg),
                      SizedBox(
                        width: double.infinity,
                        child: _togglingVpn
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : Row(
                                children: <Widget>[
                                  if (isRunning) ...<Widget>[
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _reconnectVpn,
                                        icon: const Icon(Icons.restart_alt),
                                        label: const Text('Reconnect'),
                                      ),
                                    ),
                                    const SizedBox(width: Insets.sm),
                                  ],
                                  Expanded(
                                    child: FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: isRunning
                                            ? scheme.error
                                            : scheme.primary,
                                        foregroundColor: isRunning
                                            ? scheme.onError
                                            : scheme.onPrimary,
                                      ),
                                      onPressed: () => _toggleVpn(isRunning),
                                      icon: Icon(
                                        isRunning
                                            ? Icons.power_settings_new
                                            : Icons.play_arrow,
                                      ),
                                      label: Text(
                                        isRunning ? 'Stop VPN' : 'Start VPN',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const Card(
              child: Padding(
                padding: EdgeInsets.all(Insets.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (Object error, StackTrace stack) => Card(
              color: scheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(Insets.lg),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.error_outline, color: scheme.onErrorContainer),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Text(
                        'Could not check the VPN. '
                        '${describeGluetunFailure(error, 'GET /v1/vpn/status')}',
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: Insets.lg),

          // Public IP Card (Connection Details)
          Text(
            'Connection Details',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.primary,
                ),
          ),
          const SizedBox(height: Insets.sm),

          Card(
            elevation: 0,
            color: scheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: publicIp.when(
                data: (GluetunPublicIp? ipInfo) {
                  if (ipInfo == null || ipInfo.publicIp.isEmpty) {
                    return const ListTile(
                      leading: Icon(Icons.public_off),
                      title: Text('Public IP Unavailable'),
                      subtitle: Text(
                        'Unable to retrieve external IP or check disabled.',
                      ),
                    );
                  }
                  final GluetunPlaces places = ipInfo.places;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.public),
                        title: const Text('Public IP Address'),
                        subtitle: SelectableText(
                          ipInfo.publicIp,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          tooltip: 'Copy IP',
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: ipInfo.publicIp),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Public IP copied to clipboard'),
                              ),
                            );
                          },
                        ),
                      ),
                      if (places.country != null ||
                          places.region != null ||
                          places.city != null ||
                          ipInfo.organization != null) ...<Widget>[
                        const Divider(),
                        const SizedBox(height: Insets.xs),
                        Wrap(
                          spacing: Insets.xs,
                          runSpacing: Insets.xs,
                          children: <Widget>[
                            if (places.country != null)
                              Chip(
                                avatar: const Icon(Icons.flag, size: 16),
                                label: Text(places.country!),
                                padding: EdgeInsets.zero,
                              ),
                            if (places.region != null)
                              Chip(
                                avatar:
                                    const Icon(Icons.location_on, size: 16),
                                label: Text(places.region!),
                                padding: EdgeInsets.zero,
                              ),
                            if (places.city != null)
                              Chip(
                                avatar:
                                    const Icon(Icons.location_city, size: 16),
                                label: Text(places.city!),
                                padding: EdgeInsets.zero,
                              ),
                            if (ipInfo.organization != null)
                              Chip(
                                avatar: const Icon(Icons.business, size: 16),
                                // Provider names like an ASN plus a full company
                                // name outgrow the row; end them with an ellipsis
                                // rather than cutting a word in half.
                                label: Text(
                                  ipInfo.organization!,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                          ],
                        ),
                      ],
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(Insets.md),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (Object error, StackTrace stack) => ListTile(
                  leading: const Icon(Icons.public_off),
                  title: const Text('Public IP Address'),
                  subtitle: Text(
                    describeGluetunFailure(error, 'GET /v1/publicip/ip'),
                  ),
                ),
              ),
            ),
          ),

          if (forwardedPorts.isNotEmpty) ...<Widget>[
            const SizedBox(height: Insets.md),
            Card(
              elevation: 0,
              color: scheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(Insets.md),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.settings_ethernet),
                  title: Text(
                    forwardedPorts.length == 1
                        ? 'Forwarded Port'
                        : 'Forwarded Ports',
                  ),
                  subtitle: SelectableText(
                    forwardedPorts.join(', '),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    tooltip: 'Copy port',
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: forwardedPorts.join(',')),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Forwarded port copied to clipboard'),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: Insets.md),

          // DNS Server Card with Toggle Action
          Card(
            elevation: 0,
            color: scheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: dnsStatus.when(
                data: (GluetunDnsStatus? dns) {
                  final bool isOk = dns?.isRunning ?? false;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.dns,
                      color: isOk ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                    title: const Text('DNS Server Status'),
                    subtitle: Text(
                      dns?.status.toUpperCase() ?? 'UNKNOWN',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isOk ? scheme.primary : null,
                      ),
                    ),
                    trailing: _togglingDns
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : TextButton.icon(
                            onPressed: () => _toggleDns(isOk),
                            icon: Icon(
                              isOk ? Icons.pause : Icons.play_arrow,
                              size: 18,
                            ),
                            label: Text(isOk ? 'Stop' : 'Start'),
                          ),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(Insets.md),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (Object error, StackTrace stack) => ListTile(
                  leading: const Icon(Icons.dns_outlined),
                  title: const Text('DNS Server Status'),
                  subtitle: Text(
                    describeGluetunFailure(error, 'GET /v1/dns/status'),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: Insets.md),

          // Server Database Updater Card with Trigger Action
          Card(
            elevation: 0,
            color: scheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(Insets.md),
              child: updaterStatus.when(
                data: (GluetunUpdaterStatus? updater) {
                  final bool isRunning = updater?.isRunning ?? false;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.sync,
                      color: isRunning ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                    title: const Text('Server Database Updater'),
                    subtitle: Text(
                      updater?.status.toUpperCase() ?? 'IDLE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isRunning ? scheme.primary : null,
                      ),
                    ),
                    trailing: _triggeringUpdater
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : OutlinedButton.icon(
                            onPressed: _triggerUpdater,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Update Servers'),
                          ),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(Insets.md),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (Object error, StackTrace stack) => ListTile(
                  leading: const Icon(Icons.sync_problem),
                  title: const Text('Server Database Updater'),
                  subtitle: Text(
                    describeGluetunFailure(error, 'GET /v1/updater/status'),
                  ),
                ),
              ),
            ),
          ),
          // Proton's server API needs an account login, so without one the
          // update fails inside Gluetun while the app has nothing to show for
          // it. Checked on a live Gluetun, and against its source from v3.40.1.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.md,
              Insets.sm,
              Insets.md,
              0,
            ),
            child: Text(
              'ProtonVPN only updates when Gluetun has your Proton login, set '
              'as UPDATER_PROTONVPN_EMAIL and UPDATER_PROTONVPN_PASSWORD.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
