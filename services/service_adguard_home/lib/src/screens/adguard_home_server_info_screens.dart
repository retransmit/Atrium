import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../adguard_home_errors.dart';
import '../adguard_home_format.dart';
import '../adguard_home_providers.dart';
import '../models/adguard_home_settings.dart';
import '../models/adguard_home_status.dart';
import '../widgets/adguard_home_fields.dart';
import '../widgets/adguard_home_settings_form.dart';

/// Whether encryption is set up, and how. Read only: a wrong certificate
/// or port locks the owner out, so it is changed on the server's own page.
class AdguardHomeEncryptionScreen extends ConsumerWidget {
  const AdguardHomeEncryptionScreen({required this.instance, super.key});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AdguardHomeTlsStatus> read =
        ref.watch(adguardHomeTlsStatusProvider(instance));
    final AdguardHomeTlsStatus? tls = read.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Encryption')),
      body: tls == null
          ? adguardHomeSettingsWaiting<AdguardHomeTlsStatus>(
                context,
                ref,
                instance,
                read,
                onRetry: () =>
                    ref.invalidate(adguardHomeTlsStatusProvider(instance)),
              ) ??
              const SizedBox.shrink()
          : _InfoList(children: _rows(context, tls)),
    );
  }

  static List<Widget> _rows(BuildContext context, AdguardHomeTlsStatus tls) {
    final ThemeData theme = Theme.of(context);
    final DateTime? until = tls.notAfter;
    final bool expired = until != null && until.isBefore(DateTime.now());
    return <Widget>[
      _State(
        on: tls.enabled,
        title: tls.enabled ? 'Encryption is on' : 'Encryption is off',
        detail: tls.enabled
            ? null
            : 'DNS over HTTPS, TLS and QUIC are set up in AdGuard Home\'s web '
                'interface.',
      ),
      if (tls.enabled) ...<Widget>[
        const AdguardHomeHeading('Server'),
        AdguardHomeField(
          'Server name',
          tls.serverName.isNotEmpty ? tls.serverName : tls.dnsNames.join(', '),
        ),
        AdguardHomeField('HTTPS port', _port(tls.portHttps)),
        AdguardHomeField('DNS-over-TLS port', _port(tls.portDnsOverTls)),
        AdguardHomeField('DNS-over-QUIC port', _port(tls.portDnsOverQuic)),
        AdguardHomeField('DNSCrypt port', _port(tls.portDnsCrypt)),
        AdguardHomeField('Redirect to HTTPS', tls.forceHttps ? 'Yes' : 'No'),
        AdguardHomeField('Plain DNS', tls.servePlainDns ? 'Answered' : 'Off'),
        const AdguardHomeHeading('Certificate'),
        AdguardHomeField(
          'Certificate chain',
          tls.validChain
              ? 'Valid'
              : tls.validCertificate
                  ? 'Valid, but not trusted by the system'
                  : 'Not valid',
        ),
        AdguardHomeField('Subject', tls.subject),
        AdguardHomeField('Issuer', tls.issuer),
        AdguardHomeField('Names', tls.dnsNames.join('\n')),
        if (until != null)
          AdguardHomeBlock('Valid until', <Widget>[
            Text(
              expired
                  ? '${formatAdguardHomeDate(until)}, expired'
                  : formatAdguardHomeDate(until),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: expired ? theme.colorScheme.error : null,
              ),
            ),
          ]),
        const AdguardHomeHeading('Private key'),
        AdguardHomeField(
          'Key',
          tls.validKey
              ? (tls.keyType.isEmpty ? 'Valid' : 'Valid, ${tls.keyType}')
              : 'Not valid',
        ),
        AdguardHomeField(
          'Matches the certificate',
          tls.validPair ? 'Yes' : 'No',
        ),
        if (tls.warning.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: Insets.lg),
            child: Text(
              tls.warning,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ),
      ],
    ];
  }

  /// Nothing for a port that is not served.
  static String _port(int port) => port > 0 ? '$port' : '';
}

/// The server's DHCP: whether it hands out addresses, from where, and to
/// whom. Read only here.
class AdguardHomeDhcpScreen extends ConsumerWidget {
  const AdguardHomeDhcpScreen({required this.instance, super.key});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The status, polled anyway, says whether the server can run DHCP at
    // all. Where it cannot, its DHCP is not asked about: that read would
    // only fail, and say less.
    final AsyncValue<AdguardHomeStatus> statusRead =
        ref.watch(adguardHomeStatusProvider(instance));
    final AdguardHomeStatus? status = statusRead.value;
    if (status == null && !statusRead.hasError) {
      // Polled for the other tabs, so nearly always in by now.
      return Scaffold(
        appBar: AppBar(title: const Text('DHCP')),
        body: const Center(child: ExpressiveProgressIndicator()),
      );
    }
    if (status != null && !status.dhcpAvailable) {
      return Scaffold(
        appBar: AppBar(title: const Text('DHCP')),
        body: const _InfoList(
          children: <Widget>[
            _State(
              on: false,
              title: 'DHCP is not available on this server',
              detail: 'AdGuard Home cannot hand out addresses where it '
                  'runs, for example in a container without the host\'s '
                  'network.',
            ),
          ],
        ),
      );
    }
    final AsyncValue<AdguardHomeDhcpStatus> read =
        ref.watch(adguardHomeDhcpStatusProvider(instance));
    final AdguardHomeDhcpStatus? dhcp = read.value;
    return Scaffold(
      appBar: AppBar(title: const Text('DHCP')),
      body: dhcp == null
          ? adguardHomeSettingsWaiting<AdguardHomeDhcpStatus>(
                context,
                ref,
                instance,
                read,
                onRetry: () =>
                    ref.invalidate(adguardHomeDhcpStatusProvider(instance)),
              ) ??
              const SizedBox.shrink()
          : _InfoList(children: _rows(context, dhcp)),
    );
  }

  static List<Widget> _rows(BuildContext context, AdguardHomeDhcpStatus dhcp) {
    final AdguardHomeDhcpRange v4 = dhcp.v4;
    final AdguardHomeDhcpRange v6 = dhcp.v6;
    return <Widget>[
      _State(
        on: dhcp.enabled,
        title: dhcp.enabled
            ? 'Handing out addresses'
            : 'DHCP is off on this server',
        detail: dhcp.enabled
            ? null
            : 'It is set up in AdGuard Home\'s web interface.',
      ),
      AdguardHomeField('Interface', dhcp.interfaceName),
      if (v4.rangeStart.isNotEmpty) ...<Widget>[
        const AdguardHomeHeading('IPv4'),
        AdguardHomeField('Range', '${v4.rangeStart} to ${v4.rangeEnd}'),
        AdguardHomeField('Gateway', v4.gateway),
        AdguardHomeField('Subnet mask', v4.subnetMask),
        AdguardHomeField('Lease time', _length(v4.leaseDuration)),
      ],
      if (v6.rangeStart.isNotEmpty) ...<Widget>[
        const AdguardHomeHeading('IPv6'),
        AdguardHomeField('Range start', v6.rangeStart),
        AdguardHomeField('Lease time', _length(v6.leaseDuration)),
      ],
      if (dhcp.leases.isNotEmpty) ...<Widget>[
        AdguardHomeHeading('Leases (${dhcp.leases.length})'),
        for (final AdguardHomeDhcpLease lease in dhcp.leases)
          _Lease(lease: lease),
      ],
      if (dhcp.staticLeases.isNotEmpty) ...<Widget>[
        AdguardHomeHeading('Static leases (${dhcp.staticLeases.length})'),
        for (final AdguardHomeDhcpLease lease in dhcp.staticLeases)
          _Lease(lease: lease),
      ],
    ];
  }

  static String _length(Duration length) {
    if (length == Duration.zero) return '';
    // Not a whole number of hours: in minutes, so 90 minutes is not "1 hour".
    if (length.inMinutes % 60 != 0) {
      return length.inMinutes == 1 ? '1 minute' : '${length.inMinutes} minutes';
    }
    return adguardHomeRetentionLabel(length);
  }
}

class _Lease extends StatelessWidget {
  const _Lease({required this.lease});

  final AdguardHomeDhcpLease lease;

  @override
  Widget build(BuildContext context) {
    final DateTime? expires = lease.expires;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(lease.hostname.isEmpty ? lease.ip : lease.hostname),
      subtitle: Text(
        <String>[
          if (lease.hostname.isNotEmpty) lease.ip,
          lease.mac,
          if (expires != null) 'until ${formatAdguardHomeDate(expires)}',
        ].join(' · '),
      ),
    );
  }
}

/// The server's version and addresses, and whether a newer version is out.
class AdguardHomeAboutScreen extends ConsumerStatefulWidget {
  const AdguardHomeAboutScreen({required this.instance, super.key});

  final Instance instance;

  @override
  ConsumerState<AdguardHomeAboutScreen> createState() =>
      _AdguardHomeAboutScreenState();
}

class _AdguardHomeAboutScreenState
    extends ConsumerState<AdguardHomeAboutScreen> {
  bool _checking = false;
  AdguardHomeVersionCheck? _check;
  Object? _error;

  Future<void> _checkVersion() async {
    if (_checking) return;
    // After a refused sign-in nothing is sent until asked; checking again
    // is the asking.
    if (_error is AdguardHomeSignInRefused) {
      ref.read(adguardHomeActionsProvider(widget.instance)).retrySignIn();
    }
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final AdguardHomeVersionCheck check = await ref
          .read(adguardHomeActionsProvider(widget.instance))
          .checkVersion(recheck: true);
      if (mounted) setState(() => _check = check);
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AdguardHomeStatus> read =
        ref.watch(adguardHomeStatusProvider(widget.instance));
    final AdguardHomeStatus? status = read.value;
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: status == null
          ? adguardHomeSettingsWaiting<AdguardHomeStatus>(
                context,
                ref,
                widget.instance,
                read,
                onRetry: () => ref
                    .invalidate(adguardHomeStatusProvider(widget.instance)),
              ) ??
              const SizedBox.shrink()
          : _InfoList(children: _rows(context, status)),
    );
  }

  List<Widget> _rows(BuildContext context, AdguardHomeStatus status) {
    final ThemeData theme = Theme.of(context);
    final AdguardHomeVersionCheck? check = _check;
    final Object? error = _error;
    final String port = status.dnsPort == 53 ? '' : ':${status.dnsPort}';
    return <Widget>[
      AdguardHomeField('Version', status.version),
      AdguardHomeField(
        'DNS addresses',
        <String>[
          for (final String address in status.dnsAddresses)
            address.contains(':') && port.isNotEmpty
                ? '[$address]$port'
                : '$address$port',
        ].join('\n'),
      ),
      AdguardHomeField('DNS port', '${status.dnsPort}'),
      AdguardHomeField('Web interface port', '${status.httpPort}'),
      const AdguardHomeHeading('Updates'),
      const SizedBox(height: Insets.sm),
      if (error != null)
        Text(
          describeAdguardHomeError(error),
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.error),
        )
      else if (check != null)
        ..._verdict(theme, status, check),
      const SizedBox(height: Insets.sm),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: OutlinedButton.icon(
          onPressed: _checking ? null : _checkVersion,
          icon: _checking
              ? const SizedBox.square(
                  dimension: 18,
                  child: ExpressiveProgressIndicator(),
                )
              : const Icon(Icons.system_update_alt),
          label: Text(
            error is AdguardHomeSignInRefused
                ? 'Try again'
                : 'Check for updates',
          ),
        ),
      ),
    ];
  }

  List<Widget> _verdict(
    ThemeData theme,
    AdguardHomeStatus status,
    AdguardHomeVersionCheck check,
  ) {
    if (check.disabled) {
      return <Widget>[
        Text(
          'Update checks are off on this server.',
          style: theme.textTheme.bodyMedium,
        ),
      ];
    }
    if (!check.isNewerThan(status.version)) {
      return <Widget>[
        Text('This is the latest version.', style: theme.textTheme.bodyMedium),
      ];
    }
    final Uri? notes = Uri.tryParse(check.announcementUrl);
    return <Widget>[
      Text(
        'AdGuard Home ${check.newVersion} is out.',
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      Text(
        'It is installed from the server or its web interface.',
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      if (notes != null && notes.hasScheme)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () =>
                launchUrl(notes, mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new),
            label: const Text("What's new"),
          ),
        ),
    ];
  }
}

/// A page of read-only fields.
class _InfoList extends StatelessWidget {
  const _InfoList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
        padding:
            const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.xl),
        children: children,
      );
}

/// Whether a feature is on, at the top of its page.
class _State extends StatelessWidget {
  const _State({required this.on, required this.title, this.detail});

  final bool on;
  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        on ? Icons.check_circle_outline : Icons.remove_circle_outline,
        color: on ? theme.colorScheme.primary : theme.colorScheme.outline,
      ),
      title: Text(title),
      subtitle: detail == null ? null : Text(detail!),
    );
  }
}
