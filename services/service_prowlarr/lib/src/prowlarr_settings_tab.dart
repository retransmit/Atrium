import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import 'prowlarr_apps_screen.dart';
import 'prowlarr_form_fields.dart';
import 'prowlarr_provider_settings.dart';

/// The Settings tab: a menu mirroring Prowlarr's web Settings section. Each row
/// opens a dedicated screen. Provider resources (download clients,
/// notifications, indexer proxies) share one generic list + form.
class ProwlarrSettingsTab extends StatelessWidget {
  const ProwlarrSettingsTab({required this.instance, super.key});

  final Instance instance;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: Insets.pageH,
      children: <Widget>[
        const SizedBox(height: Insets.sm),
        _SettingsTile(
          icon: Icons.apps_outlined,
          title: 'Apps',
          subtitle: 'Sonarr, Radarr, and other sync targets',
          onTap: () => _push(context, ProwlarrAppsScreen(instance: instance)),
        ),
        _SettingsTile(
          icon: Icons.download_outlined,
          title: 'Download Clients',
          subtitle: 'qBittorrent, SABnzbd, Transmission, ...',
          onTap: () => _pushProvider(context, _downloadClientConfig),
        ),
        _SettingsTile(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          subtitle: 'Discord, Telegram, email, and more',
          onTap: () => _pushProvider(context, _notificationConfig),
        ),
        _SettingsTile(
          icon: Icons.vpn_lock_outlined,
          title: 'Indexer Proxies',
          subtitle: 'FlareSolverr, HTTP, SOCKS',
          onTap: () => _pushProvider(context, _indexerProxyConfig),
        ),
      ],
    );
  }

  void _pushProvider(BuildContext context, ProwlarrProviderConfig config) {
    _push(
      context,
      ProwlarrProviderScreen(instance: instance, config: config),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: Insets.sm),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

// --- Provider resource configs ---

final ProwlarrProviderConfig _downloadClientConfig = ProwlarrProviderConfig(
  endpoint: 'downloadclient',
  title: 'Download Clients',
  resourceLabel: 'download client',
  icon: Icons.download_outlined,
  topLevel: (BuildContext context, Map<String, dynamic> raw, VoidCallback onChanged) => <Widget>[
    ProwlarrSwitchTile(
      label: 'Enabled',
      value: raw['enable'] != false,
      onChanged: (bool v) {
        raw['enable'] = v;
        onChanged();
      },
    ),
    ProwlarrIntField(
      label: 'Priority',
      helperText: 'Lower is higher priority (1-50)',
      value: (raw['priority'] as num?)?.toInt() ?? 1,
      onChanged: (int v) => raw['priority'] = v,
    ),
  ],
);

final ProwlarrProviderConfig _notificationConfig = ProwlarrProviderConfig(
  endpoint: 'notification',
  title: 'Notifications',
  resourceLabel: 'notification',
  icon: Icons.notifications_outlined,
  topLevel: (BuildContext context, Map<String, dynamic> raw, VoidCallback onChanged) {
    Widget? event(String supportKey, String valueKey, String label) {
      if (raw[supportKey] != true) {
        return null;
      }
      return ProwlarrSwitchTile(
        label: label,
        value: raw[valueKey] == true,
        onChanged: (bool v) {
          raw[valueKey] = v;
          onChanged();
        },
      );
    }

    return <Widget?>[
      event('supportsOnGrab', 'onGrab', 'On Grab'),
      event('supportsOnHealthIssue', 'onHealthIssue', 'On Health Issue'),
      event(
        'supportsOnHealthRestored',
        'onHealthRestored',
        'On Health Restored',
      ),
      event(
        'supportsOnApplicationUpdate',
        'onApplicationUpdate',
        'On Application Update',
      ),
      ProwlarrSwitchTile(
        label: 'Include Health Warnings',
        value: raw['includeHealthWarnings'] == true,
        onChanged: (bool v) {
          raw['includeHealthWarnings'] = v;
          onChanged();
        },
      ),
    ].whereType<Widget>().toList();
  },
);

final ProwlarrProviderConfig _indexerProxyConfig = ProwlarrProviderConfig(
  endpoint: 'indexerproxy',
  title: 'Indexer Proxies',
  resourceLabel: 'indexer proxy',
  icon: Icons.vpn_lock_outlined,
  topLevel: (BuildContext context, Map<String, dynamic> raw, VoidCallback onChanged) => <Widget>[
    if (raw['supportsOnHealthIssue'] == true)
      ProwlarrSwitchTile(
        label: 'On Health Issue',
        value: raw['onHealthIssue'] == true,
        onChanged: (bool v) {
          raw['onHealthIssue'] = v;
          onChanged();
        },
      ),
    ProwlarrSwitchTile(
      label: 'Include Health Warnings',
      value: raw['includeHealthWarnings'] == true,
      onChanged: (bool v) {
        raw['includeHealthWarnings'] = v;
        onChanged();
      },
    ),
  ],
);
