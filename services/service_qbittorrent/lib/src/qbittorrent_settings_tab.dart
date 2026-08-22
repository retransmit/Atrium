import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/qbit_transfer_info.dart';
import 'qbittorrent_client.dart';
import 'qbittorrent_home.dart' show fmtBytes;
import 'qbittorrent_providers.dart';

/// The Settings tab for qBittorrent matching Sonarr's System tab design:
/// NestedScrollView with scrollable top TabBar for Behavior, Downloads, Connection,
/// Speed, BitTorrent, RSS, WebUI, and Advanced tabs.
class QbittorrentSettingsTab extends ConsumerStatefulWidget {
  const QbittorrentSettingsTab({required this.instance, super.key});

  final Instance instance;

  @override
  ConsumerState<QbittorrentSettingsTab> createState() =>
      _QbittorrentSettingsTabState();
}

class _QbittorrentSettingsTabState
    extends ConsumerState<QbittorrentSettingsTab> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _getBool(dynamic val, {bool defaultValue = false}) {
    if (val is bool) return val;
    if (val is num) return val != 0;
    if (val is String) return val.toLowerCase() == 'true' || val == '1';
    return defaultValue;
  }

  int _getInt(dynamic val, {int defaultValue = 0}) {
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? defaultValue;
    return defaultValue;
  }

  void _refreshAll() {
    final Instance instance = widget.instance;
    ref.invalidate(qbitAppVersionProvider(instance));
    ref.invalidate(qbitApiVersionProvider(instance));
    ref.invalidate(qbitPreferencesProvider(instance));
    ref.invalidate(qbitAltSpeedModeProvider(instance));
    ref.invalidate(qbitTransferProvider(instance));
    ref.invalidate(qbitNetworkInterfacesProvider(instance));
  }

  Future<void> _updatePref(String key, dynamic value) async {
    try {
      final QbittorrentClient client = await ref.read(
        qbittorrentClientProvider(widget.instance).future,
      );
      await client.setPreferences(<String, dynamic>{key: value});
      ref.invalidate(qbitPreferencesProvider(widget.instance));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Setting saved'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update setting: $e')),
        );
      }
    }
  }

  Future<void> _showStringEditDialog({
    required String title,
    required String prefKey,
    required String initialValue,
    String? hintText,
  }) async {
    final TextEditingController controller =
        TextEditingController(text: initialValue);
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: hintText,
            isDense: true,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result != initialValue) {
      await _updatePref(prefKey, result);
    }
  }

  Future<void> _showNumberEditDialog({
    required String title,
    required String prefKey,
    required int initialValue,
    String? helperText,
  }) async {
    final TextEditingController controller =
        TextEditingController(text: initialValue.toString());
    final int? result = await showDialog<int>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            helperText: helperText,
            isDense: true,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, int.tryParse(controller.text.trim())),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result != initialValue) {
      await _updatePref(prefKey, result);
    }
  }

  Future<void> _showOptionsDialog<T>({
    required String title,
    required String prefKey,
    required T currentValue,
    required List<({String label, T value, String? subtitle})> options,
  }) async {
    final T? selected = await showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      useRootNavigator: true,
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.lg,
                  Insets.xs,
                  Insets.lg,
                  Insets.sm,
                ),
                child: Text(
                  title,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (BuildContext context, int index) {
                    final item = options[index];
                    final bool isSelected = item.value == currentValue;
                    return ListTile(
                      title: Text(
                        item.label,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? Theme.of(ctx).colorScheme.primary
                              : null,
                        ),
                      ),
                      subtitle:
                          item.subtitle != null ? Text(item.subtitle!) : null,
                      trailing: isSelected
                          ? Icon(
                              Icons.check_rounded,
                              color: Theme.of(ctx).colorScheme.primary,
                            )
                          : null,
                      onTap: () => Navigator.pop(ctx, item.value),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null && selected != currentValue) {
      await _updatePref(prefKey, selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Instance instance = widget.instance;
    final ThemeData theme = Theme.of(context);

    ref.listen<int>(
      qbitHomeScrollToTopProvider((instance, 1)),
      (int? previous, int next) {
        if (next > 0 && _scrollController.hasClients) {
          _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          );
        }
      },
    );

    return DefaultTabController(
      length: 9,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: NestedScrollView(
          controller: _scrollController,
          headerSliverBuilder:
              (BuildContext innerContext, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverAppBar(
                floating: true,
                snap: true,
                pinned: true,
                scrolledUnderElevation: 0.0,
                surfaceTintColor: Colors.transparent,
                backgroundColor: theme.colorScheme.surface,
                leadingWidth: 56,
                leading: IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
                title: Text('${instance.name} Settings'),
                actions: <Widget>[
                  IconButton(
                    tooltip: 'Refresh',
                    icon: const Icon(Icons.refresh),
                    onPressed: _refreshAll,
                  ),
                  const SizedBox(width: Insets.xs),
                ],
                bottom: TabBar(
                  dividerColor: Colors.transparent,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorColor: theme.colorScheme.primary,
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelStyle: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelStyle: theme.textTheme.titleSmall,
                  tabs: const <Widget>[
                    Tab(text: 'System'),
                    Tab(text: 'Behavior'),
                    Tab(text: 'Downloads'),
                    Tab(text: 'Connection'),
                    Tab(text: 'Speed'),
                    Tab(text: 'BitTorrent'),
                    Tab(text: 'RSS'),
                    Tab(text: 'WebUI'),
                    Tab(text: 'Advanced'),
                  ],
                ),
              ),
            ];
          },
          body: TabBarView(
            children: <Widget>[
              _buildSystemTab(),
              _buildBehaviorTab(),
              _buildDownloadsTab(),
              _buildConnectionTab(),
              _buildSpeedTab(),
              _buildBitTorrentTab(),
              _buildRssTab(),
              _buildWebUiTab(),
              _buildAdvancedTab(),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 1. SYSTEM TAB
  // ==========================================
  Widget _buildSystemTab() {
    final Instance instance = widget.instance;
    final AsyncValue<String> appVersion =
        ref.watch(qbitAppVersionProvider(instance));
    final AsyncValue<String> apiVersion =
        ref.watch(qbitApiVersionProvider(instance));
    final QbitTransferInfo? transfer =
        ref.watch(qbitTransferProvider(instance)).value;

    final String shareRatio = transfer != null && transfer.dlData > 0
        ? (transfer.upData / transfer.dlData).toStringAsFixed(2)
        : '0.00';

    return _buildTabListView(
      children: <Widget>[
        _buildSectionHeader('Server Information'),
        _buildCard(
          children: <Widget>[
            _buildInfoTile(
              icon: Icons.dns_rounded,
              title: 'qBittorrent Version',
              value: appVersion.value ?? 'Loading...',
              color: Theme.of(context).colorScheme.primary,
            ),
            const Divider(height: 1),
            _buildInfoTile(
              icon: Icons.api_rounded,
              title: 'Web API Version',
              value: apiVersion.value ?? 'Loading...',
              color: Theme.of(context).colorScheme.secondary,
            ),
            const Divider(height: 1),
            _buildInfoTile(
              icon: Icons.wifi_tethering_rounded,
              title: 'Connection Status',
              value: transfer?.connectionStatus.toUpperCase() ?? 'CONNECTED',
              color: transfer?.connectionStatus == 'disconnected'
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
            ),
            const Divider(height: 1),
            _buildInfoTile(
              icon: Icons.link_rounded,
              title: 'Instance Address',
              value: instance.localUrl.isNotEmpty
                  ? instance.localUrl
                  : instance.externalUrl,
              color: Theme.of(context).colorScheme.tertiary,
            ),
          ],
        ),
        const SizedBox(height: Insets.md),
        _buildSectionHeader('Transfer Statistics'),
        _buildCard(
          children: <Widget>[
            _buildInfoTile(
              icon: Icons.arrow_downward_rounded,
              title: 'Current Download Speed',
              value: '${fmtBytes(transfer?.dlSpeed ?? 0)}/s',
              color: Theme.of(context).colorScheme.primary,
            ),
            const Divider(height: 1),
            _buildInfoTile(
              icon: Icons.arrow_upward_rounded,
              title: 'Current Upload Speed',
              value: '${fmtBytes(transfer?.upSpeed ?? 0)}/s',
              color: Theme.of(context).colorScheme.secondary,
            ),
            const Divider(height: 1),
            _buildInfoTile(
              icon: Icons.file_download_done_rounded,
              title: 'Session Downloaded',
              value: fmtBytes(transfer?.dlData ?? 0),
              color: Theme.of(context).colorScheme.primary,
            ),
            const Divider(height: 1),
            _buildInfoTile(
              icon: Icons.file_upload_outlined,
              title: 'Session Uploaded',
              value: fmtBytes(transfer?.upData ?? 0),
              color: Theme.of(context).colorScheme.secondary,
            ),
            const Divider(height: 1),
            _buildInfoTile(
              icon: Icons.pie_chart_outline_rounded,
              title: 'Session Share Ratio',
              value: shareRatio,
              color: Theme.of(context).colorScheme.tertiary,
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // 2. BEHAVIOR TAB
  // ==========================================
  Widget _buildBehaviorTab() {
    final Instance instance = widget.instance;
    final Map<String, dynamic> prefs =
        ref.watch(qbitPreferencesProvider(instance)).value ??
            <String, dynamic>{};

    return _buildTabListView(
      children: <Widget>[
        _buildSectionHeader('Localization & Interface'),
        _buildCard(
          children: <Widget>[
            _buildActionTile(
              icon: Icons.language_rounded,
              title: 'UI Locale',
              value: prefs['locale']?.toString() ?? 'en',
              onTap: () => _showStringEditDialog(
                title: 'UI Locale (e.g. en, fr, de, es)',
                prefKey: 'locale',
                initialValue: prefs['locale']?.toString() ?? 'en',
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.md),
        _buildSectionHeader('Confirmations & Prompts'),
        _buildCard(
          children: <Widget>[
            _buildSwitchTile(
              icon: Icons.delete_outline_rounded,
              title: 'Confirm Torrent Deletion',
              subtitle: 'Show confirmation dialog before deleting torrents',
              value: _getBool(
                prefs['confirm_torrent_deletion'],
                defaultValue: true,
              ),
              onChanged: (bool val) =>
                  _updatePref('confirm_torrent_deletion', val),
            ),
            const Divider(height: 1),
            _buildSwitchTile(
              icon: Icons.refresh_rounded,
              title: 'Confirm Torrent Recheck',
              subtitle: 'Show confirmation dialog before force rechecking',
              value: _getBool(
                prefs['confirm_torrent_recheck'],
                defaultValue: true,
              ),
              onChanged: (bool val) =>
                  _updatePref('confirm_torrent_recheck', val),
            ),
          ],
        ),
        const SizedBox(height: Insets.md),
        _buildSectionHeader('Power Management'),
        _buildCard(
          children: <Widget>[
            _buildSwitchTile(
              icon: Icons.bedtime_outlined,
              title: 'Inhibit System Sleep',
              subtitle: 'Prevent system standby while torrents are active',
              value: _getInt(prefs['auto_exit_mode']) != 0,
              onChanged: (bool val) =>
                  _updatePref('auto_exit_mode', val ? 1 : 0),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // 2. DOWNLOADS TAB
  // ==========================================
  Widget _buildDownloadsTab() {
    final Instance instance = widget.instance;
    final Map<String, dynamic> prefs =
        ref.watch(qbitPreferencesProvider(instance)).value ??
            <String, dynamic>{};

    return _buildTabListView(
      children: <Widget>[
        _buildSectionHeader('Storage Directories'),
        _buildCard(
          children: <Widget>[
            _buildActionTile(
              icon: Icons.folder_outlined,
              title: 'Default Save Path',
              value: prefs['save_path']?.toString() ?? 'Default',
              onTap: () => _showStringEditDialog(
                title: 'Default Save Path',
                prefKey: 'save_path',
                initialValue: prefs['save_path']?.toString() ?? '',
              ),
            ),
            const Divider(height: 1),
            _buildSwitchTile(
              icon: Icons.folder_copy_outlined,
              title: 'Keep Incomplete Torrents in Temp Path',
              subtitle: prefs['temp_path']?.toString() ?? 'Disabled',
              value: _getBool(prefs['temp_path_enabled']),
              onChanged: (bool val) => _updatePref('temp_path_enabled', val),
            ),
            if (_getBool(prefs['temp_path_enabled'])) ...<Widget>[
              const Divider(height: 1),
              _buildActionTile(
                icon: Icons.edit_location_alt_outlined,
                title: 'Incomplete Files Path',
                value: prefs['temp_path']?.toString() ?? '',
                onTap: () => _showStringEditDialog(
                  title: 'Incomplete Files Path',
                  prefKey: 'temp_path',
                  initialValue: prefs['temp_path']?.toString() ?? '',
                ),
              ),
            ],
            const Divider(height: 1),
            _buildActionTile(
              icon: Icons.file_download_outlined,
              title: 'Copy .torrent Files to',
              value: prefs['export_dir']?.toString().isNotEmpty == true
                  ? prefs['export_dir'].toString()
                  : 'None',
              onTap: () => _showStringEditDialog(
                title: 'Copy .torrent Files to',
                prefKey: 'export_dir',
                initialValue: prefs['export_dir']?.toString() ?? '',
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.md),
        _buildSectionHeader('File Allocation & Naming'),
        _buildCard(
          children: <Widget>[
            _buildSwitchTile(
              icon: Icons.extension_outlined,
              title: 'Append .!qB Extension',
              subtitle: 'Append extension to incomplete files',
              value: _getBool(prefs['incomplete_files_ext']),
              onChanged: (bool val) => _updatePref('incomplete_files_ext', val),
            ),
            const Divider(height: 1),
            _buildSwitchTile(
              icon: Icons.storage_rounded,
              title: 'Pre-allocate Disk Space',
              subtitle: 'Pre-allocate storage for all files on add',
              value: _getBool(prefs['preallocate_all']),
              onChanged: (bool val) => _updatePref('preallocate_all', val),
            ),
            const Divider(height: 1),
            _buildSwitchTile(
              icon: Icons.auto_mode_rounded,
              title: 'Automatic Torrent Management',
              subtitle: 'Relocate torrents when category paths change',
              value: _getBool(prefs['auto_tmm_enabled']),
              onChanged: (bool val) => _updatePref('auto_tmm_enabled', val),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // 3. CONNECTION TAB
  // ==========================================
  Widget _buildConnectionTab() {
    final Instance instance = widget.instance;
    final Map<String, dynamic> prefs =
        ref.watch(qbitPreferencesProvider(instance)).value ??
            <String, dynamic>{};

    return _buildTabListView(
      children: <Widget>[
        _buildSectionHeader('Listening Port & Protocol'),
        _buildCard(
          children: <Widget>[
            _buildActionTile(
              icon: Icons.numbers_rounded,
              title: 'Incoming Connection Port',
              value: prefs['listen_port']?.toString() ?? 'Default',
              onTap: () => _showNumberEditDialog(
                title: 'Incoming Connection Port',
                prefKey: 'listen_port',
                initialValue: _getInt(prefs['listen_port'], defaultValue: 6881),
              ),
            ),
            const Divider(height: 1),
            _buildSwitchTile(
              icon: Icons.router_outlined,
              title: 'Use UPnP / NAT-PMP',
              subtitle: 'Forward port automatically via router',
              value: _getBool(prefs['upnp'], defaultValue: true),
              onChanged: (bool val) => _updatePref('upnp', val),
            ),
          ],
        ),
        const SizedBox(height: Insets.md),
        _buildSectionHeader('Connection Limits'),
        _buildCard(
          children: <Widget>[
            _buildActionTile(
              icon: Icons.hub_outlined,
              title: 'Global Maximum Connections',
              value: prefs['max_connec']?.toString() ?? '500',
              onTap: () => _showNumberEditDialog(
                title: 'Global Maximum Connections',
                prefKey: 'max_connec',
                initialValue: _getInt(prefs['max_connec'], defaultValue: 500),
              ),
            ),
            const Divider(height: 1),
            _buildActionTile(
              icon: Icons.cable_rounded,
              title: 'Maximum Connections Per Torrent',
              value: prefs['max_connec_per_torrent']?.toString() ?? '100',
              onTap: () => _showNumberEditDialog(
                title: 'Maximum Connections Per Torrent',
                prefKey: 'max_connec_per_torrent',
                initialValue:
                    _getInt(prefs['max_connec_per_torrent'], defaultValue: 100),
              ),
            ),
            const Divider(height: 1),
            _buildActionTile(
              icon: Icons.upload_file_outlined,
              title: 'Global Maximum Upload Slots',
              value: prefs['max_uploads']?.toString() ?? '4',
              onTap: () => _showNumberEditDialog(
                title: 'Global Maximum Upload Slots',
                prefKey: 'max_uploads',
                initialValue: _getInt(prefs['max_uploads'], defaultValue: 4),
              ),
            ),
            const Divider(height: 1),
            _buildActionTile(
              icon: Icons.file_upload_outlined,
              title: 'Upload Slots Per Torrent',
              value: prefs['max_uploads_per_torrent']?.toString() ?? '4',
              onTap: () => _showNumberEditDialog(
                title: 'Upload Slots Per Torrent',
                prefKey: 'max_uploads_per_torrent',
                initialValue:
                    _getInt(prefs['max_uploads_per_torrent'], defaultValue: 4),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // 4. SPEED TAB
  // ==========================================
  Widget _buildSpeedTab() {
    final Instance instance = widget.instance;
    final Map<String, dynamic> prefs =
        ref.watch(qbitPreferencesProvider(instance)).value ??
            <String, dynamic>{};
    final bool altSpeedMode =
        ref.watch(qbitAltSpeedModeProvider(instance)).value ?? false;

    return _buildTabListView(
      children: <Widget>[
        _buildSectionHeader('Global Rate Limits'),
        _buildCard(
          children: <Widget>[
            _buildActionTile(
              icon: Icons.arrow_downward_rounded,
              title: 'Global Download Limit',
              value: _formatLimit(prefs['dl_limit']),
              onTap: () => _showNumberEditDialog(
                title: 'Global Download Limit (bytes/s)',
                prefKey: 'dl_limit',
                initialValue: _getInt(prefs['dl_limit']),
                helperText: 'Enter 0 for unlimited',
              ),
            ),
            const Divider(height: 1),
            _buildActionTile(
              icon: Icons.arrow_upward_rounded,
              title: 'Global Upload Limit',
              value: _formatLimit(prefs['up_limit']),
              onTap: () => _showNumberEditDialog(
                title: 'Global Upload Limit (bytes/s)',
                prefKey: 'up_limit',
                initialValue: _getInt(prefs['up_limit']),
                helperText: 'Enter 0 for unlimited',
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.md),
        _buildSectionHeader('Alternative Rate Limits'),
        _buildCard(
          children: <Widget>[
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: Insets.md,
                vertical: Insets.xs,
              ),
              secondary: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.speed_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              title: const Text('Alternative Rate Limits Active'),
              subtitle: const Text('Toggle secondary throttle mode'),
              value: altSpeedMode,
              onChanged: (bool val) async {
                final QbittorrentClient client = await ref.read(
                  qbittorrentClientProvider(instance).future,
                );
                await client.toggleAltSpeedLimits();
                ref.invalidate(qbitAltSpeedModeProvider(instance));
              },
            ),
            const Divider(height: 1),
            _buildActionTile(
              icon: Icons.slow_motion_video_rounded,
              title: 'Alt Download Limit',
              value: _formatLimit(prefs['alt_dl_limit']),
              onTap: () => _showNumberEditDialog(
                title: 'Alt Download Limit (bytes/s)',
                prefKey: 'alt_dl_limit',
                initialValue: _getInt(prefs['alt_dl_limit']),
                helperText: 'Enter 0 for unlimited',
              ),
            ),
            const Divider(height: 1),
            _buildActionTile(
              icon: Icons.slow_motion_video_rounded,
              title: 'Alt Upload Limit',
              value: _formatLimit(prefs['alt_up_limit']),
              onTap: () => _showNumberEditDialog(
                title: 'Alt Upload Limit (bytes/s)',
                prefKey: 'alt_up_limit',
                initialValue: _getInt(prefs['alt_up_limit']),
                helperText: 'Enter 0 for unlimited',
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.md),
        _buildSectionHeader('Rate Limit Scope'),
        _buildCard(
          children: <Widget>[
            _buildSwitchTile(
              icon: Icons.compare_arrows_rounded,
              title: 'Apply to μTP Protocol',
              subtitle: 'Enforce rate limits on μTP connections',
              value: _getBool(prefs['limit_utp_rate'], defaultValue: true),
              onChanged: (bool val) => _updatePref('limit_utp_rate', val),
            ),
            const Divider(height: 1),
            _buildSwitchTile(
              icon: Icons.network_check_rounded,
              title: 'Apply to Transport Overhead',
              subtitle: 'Count TCP/IP transport overhead in speed limits',
              value: _getBool(prefs['limit_tcp_overhead']),
              onChanged: (bool val) => _updatePref('limit_tcp_overhead', val),
            ),
            const Divider(height: 1),
            _buildSwitchTile(
              icon: Icons.lan_outlined,
              title: 'Apply to Peers on LAN',
              subtitle: 'Enforce rate limits on local network peers',
              value: _getBool(prefs['limit_lan_peers']),
              onChanged: (bool val) => _updatePref('limit_lan_peers', val),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // 5. BITTORRENT TAB
  // ==========================================
  Widget _buildBitTorrentTab() {
    final Instance instance = widget.instance;
    final Map<String, dynamic> prefs =
        ref.watch(qbitPreferencesProvider(instance)).value ??
            <String, dynamic>{};

    return _buildTabListView(
      children: <Widget>[
        _buildSectionHeader('Privacy & Discovery'),
        _buildCard(
          children: <Widget>[
            _buildSwitchTile(
              icon: Icons.share_location_rounded,
              title: 'Enable DHT (Distributed Hash Table)',
              subtitle: 'Find more peers without trackers',
              value: _getBool(prefs['dht'], defaultValue: true),
              onChanged: (bool val) => _updatePref('dht', val),
            ),
            const Divider(height: 1),
            _buildSwitchTile(
              icon: Icons.sync_alt_rounded,
              title: 'Enable PeX (Peer Exchange)',
              subtitle: 'Exchange peer lists between connected swarms',
              value: _getBool(prefs['pex'], defaultValue: true),
              onChanged: (bool val) => _updatePref('pex', val),
            ),
            const Divider(height: 1),
            _buildSwitchTile(
              icon: Icons.radar_rounded,
              title: 'Enable Local Peer Discovery (LSD)',
              subtitle: 'Discover peers on local LAN network',
              value: _getBool(prefs['lsd'], defaultValue: true),
              onChanged: (bool val) => _updatePref('lsd', val),
            ),
            const Divider(height: 1),
            _buildSwitchTile(
              icon: Icons.security_rounded,
              title: 'Anonymous Mode',
              subtitle: 'Hide user-agent and client fingerprint',
              value: _getBool(prefs['anonymous_mode']),
              onChanged: (bool val) => _updatePref('anonymous_mode', val),
            ),
          ],
        ),
        const SizedBox(height: Insets.md),
        _buildSectionHeader('Torrent Queueing'),
        _buildCard(
          children: <Widget>[
            _buildSwitchTile(
              icon: Icons.queue_play_next_rounded,
              title: 'Torrent Queueing',
              subtitle: 'Enforce limits on active downloads/uploads',
              value: _getBool(prefs['queueing_enabled'], defaultValue: true),
              onChanged: (bool val) => _updatePref('queueing_enabled', val),
            ),
            const Divider(height: 1),
            _buildActionTile(
              icon: Icons.downloading_rounded,
              title: 'Maximum Active Downloads',
              value: prefs['max_active_downloads']?.toString() ?? 'Unlimited',
              onTap: () => _showNumberEditDialog(
                title: 'Maximum Active Downloads',
                prefKey: 'max_active_downloads',
                initialValue:
                    _getInt(prefs['max_active_downloads'], defaultValue: 3),
              ),
            ),
            const Divider(height: 1),
            _buildActionTile(
              icon: Icons.cloud_upload_outlined,
              title: 'Maximum Active Uploads',
              value: prefs['max_active_uploads']?.toString() ?? 'Unlimited',
              onTap: () => _showNumberEditDialog(
                title: 'Maximum Active Uploads',
                prefKey: 'max_active_uploads',
                initialValue:
                    _getInt(prefs['max_active_uploads'], defaultValue: 3),
              ),
            ),
            const Divider(height: 1),
            _buildActionTile(
              icon: Icons.compare_arrows_rounded,
              title: 'Maximum Active Torrents',
              value: prefs['max_active_torrents']?.toString() ?? 'Unlimited',
              onTap: () => _showNumberEditDialog(
                title: 'Maximum Active Torrents',
                prefKey: 'max_active_torrents',
                initialValue:
                    _getInt(prefs['max_active_torrents'], defaultValue: 5),
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.md),
        _buildSectionHeader('Seeding Limits'),
        _buildCard(
          children: <Widget>[
            _buildSwitchTile(
              icon: Icons.pie_chart_outline_rounded,
              title: 'Share Ratio Limit',
              subtitle: prefs['max_ratio'] != null
                  ? 'Limit: ${(prefs['max_ratio'] as num).toStringAsFixed(2)}'
                  : 'Disabled',
              value: _getBool(prefs['max_ratio_enabled']),
              onChanged: (bool val) => _updatePref('max_ratio_enabled', val),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // 6. RSS TAB
  // ==========================================
  Widget _buildRssTab() {
    final Instance instance = widget.instance;
    final Map<String, dynamic> prefs =
        ref.watch(qbitPreferencesProvider(instance)).value ??
            <String, dynamic>{};

    return _buildTabListView(
      children: <Widget>[
        _buildSectionHeader('RSS Processing & Reader'),
        _buildCard(
          children: <Widget>[
            _buildSwitchTile(
              icon: Icons.rss_feed_rounded,
              title: 'Enable RSS Processing',
              subtitle: 'Fetch and update RSS feeds',
              value: _getBool(
                prefs['rss_processing_enabled'],
                defaultValue: true,
              ),
              onChanged: (bool val) =>
                  _updatePref('rss_processing_enabled', val),
            ),
            const Divider(height: 1),
            _buildActionTile(
              icon: Icons.timer_outlined,
              title: 'Feeds Refresh Interval',
              value: '${prefs['rss_refresh_interval'] ?? 30} minutes',
              onTap: () => _showNumberEditDialog(
                title: 'Feeds Refresh Interval (minutes)',
                prefKey: 'rss_refresh_interval',
                initialValue:
                    _getInt(prefs['rss_refresh_interval'], defaultValue: 30),
              ),
            ),
            const Divider(height: 1),
            _buildActionTile(
              icon: Icons.article_outlined,
              title: 'Max Articles Per Feed',
              value: prefs['rss_max_articles_per_feed']?.toString() ?? '50',
              onTap: () => _showNumberEditDialog(
                title: 'Max Articles Per Feed',
                prefKey: 'rss_max_articles_per_feed',
                initialValue: _getInt(
                  prefs['rss_max_articles_per_feed'],
                  defaultValue: 50,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.md),
        _buildSectionHeader('Auto-Downloader'),
        _buildCard(
          children: <Widget>[
            _buildSwitchTile(
              icon: Icons.auto_awesome_rounded,
              title: 'Enable RSS Auto-Downloading',
              subtitle: 'Automatically download matched torrent rules',
              value: _getBool(prefs['rss_auto_downloading_enabled']),
              onChanged: (bool val) =>
                  _updatePref('rss_auto_downloading_enabled', val),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // 7. WEBUI TAB
  // ==========================================
  Widget _buildWebUiTab() {
    final Instance instance = widget.instance;
    final Map<String, dynamic> prefs =
        ref.watch(qbitPreferencesProvider(instance)).value ??
            <String, dynamic>{};

    return _buildTabListView(
      children: <Widget>[
        _buildSectionHeader('Web User Interface'),
        _buildCard(
          children: <Widget>[
            _buildActionTile(
              icon: Icons.lan_rounded,
              title: 'Web UI IP Address',
              value: prefs['web_ui_address']?.toString() ?? '*',
              onTap: () => _showStringEditDialog(
                title: 'Web UI IP Address (* for all)',
                prefKey: 'web_ui_address',
                initialValue: prefs['web_ui_address']?.toString() ?? '*',
              ),
            ),
            const Divider(height: 1),
            _buildActionTile(
              icon: Icons.numbers_rounded,
              title: 'Web UI Port',
              value: prefs['web_ui_port']?.toString() ?? '8080',
              onTap: () => _showNumberEditDialog(
                title: 'Web UI Port',
                prefKey: 'web_ui_port',
                initialValue: _getInt(prefs['web_ui_port'], defaultValue: 8080),
              ),
            ),
            const Divider(height: 1),
            _buildSwitchTile(
              icon: Icons.router_rounded,
              title: 'Use UPnP for Web UI Port',
              subtitle: 'Automatically map Web UI port on router',
              value: _getBool(prefs['web_ui_upnp']),
              onChanged: (bool val) => _updatePref('web_ui_upnp', val),
            ),
          ],
        ),
        const SizedBox(height: Insets.md),
        _buildSectionHeader('Security & Session'),
        _buildCard(
          children: <Widget>[
            _buildSwitchTile(
              icon: Icons.lock_outline_rounded,
              title: 'Use HTTPS',
              subtitle: 'Encrypt Web UI connections with SSL/TLS',
              value: _getBool(prefs['web_ui_use_https']),
              onChanged: (bool val) => _updatePref('web_ui_use_https', val),
            ),
            const Divider(height: 1),
            _buildSwitchTile(
              icon: Icons.security_rounded,
              title: 'CSRF Protection',
              subtitle: 'Prevent Cross-Site Request Forgery attacks',
              value: _getBool(
                prefs['web_ui_csrf_protection_enabled'],
                defaultValue: true,
              ),
              onChanged: (bool val) =>
                  _updatePref('web_ui_csrf_protection_enabled', val),
            ),
            const Divider(height: 1),
            _buildSwitchTile(
              icon: Icons.shield_outlined,
              title: 'Clickjacking Protection',
              subtitle: 'Prevent framing in external web pages',
              value: _getBool(
                prefs['web_ui_clickjacking_protection_enabled'],
                defaultValue: true,
              ),
              onChanged: (bool val) =>
                  _updatePref('web_ui_clickjacking_protection_enabled', val),
            ),
            const Divider(height: 1),
            _buildActionTile(
              icon: Icons.timer_outlined,
              title: 'Session Timeout',
              value: '${prefs['web_ui_session_timeout'] ?? 3600} seconds',
              onTap: () => _showNumberEditDialog(
                title: 'Session Timeout (seconds)',
                prefKey: 'web_ui_session_timeout',
                initialValue: _getInt(
                  prefs['web_ui_session_timeout'],
                  defaultValue: 3600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // 8. ADVANCED TAB
  // ==========================================
  Widget _buildAdvancedTab() {
    final Instance instance = widget.instance;
    final Map<String, dynamic> prefs =
        ref.watch(qbitPreferencesProvider(instance)).value ??
            <String, dynamic>{};

    final AsyncValue<List<Map<String, String>>> ifacesAsync =
        ref.watch(qbitNetworkInterfacesProvider(instance));
    final String currentIface =
        prefs['current_network_interface']?.toString() ?? '';
    final AsyncValue<List<String>> addrsAsync = ref.watch(
      qbitNetworkInterfaceAddressesProvider((instance, currentIface)),
    );

    final dynamic storageTypeVal = prefs['resume_data_storage_type'];
    final String storageTypeDisplay = switch (storageTypeVal?.toString()) {
      '1' || 'SQLite' || 'sqlite' => 'SQLite database',
      _ => 'Fastresume files',
    };

    final dynamic removeModeVal = prefs['torrent_content_remove_mode'] ??
        prefs['torrent_content_removing_mode'];
    final String removeModeDisplay = switch (removeModeVal?.toString()) {
      '1' || 'Trash' || 'trash' => 'Move to trash (if possible)',
      _ => 'Delete files permanently',
    };

    return _buildTabListView(
      children: <Widget>[
        // --- 1. qBittorrent Section (Exact from screenshot) ---
        _buildSectionHeader('qBittorrent Section'),
        _buildCard(
          children: <Widget>[
            // 1. Resume data storage type
            _buildActionTile(
              icon: Icons.storage_rounded,
              title: 'Resume data storage type (requires restart)',
              value: storageTypeDisplay,
              onTap: () => _showOptionsDialog<dynamic>(
                title: 'Resume data storage type',
                prefKey: 'resume_data_storage_type',
                currentValue: storageTypeVal ?? 0,
                options: <({String label, dynamic value, String? subtitle})>[
                  (
                    label: 'Fastresume files',
                    value: storageTypeVal is String ? 'Legacy' : 0,
                    subtitle: 'Legacy .fastresume files in BT_backup directory',
                  ),
                  (
                    label: 'SQLite database',
                    value: storageTypeVal is String ? 'SQLite' : 1,
                    subtitle: 'Store all torrent state in a single SQLite DB',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // 2. Torrent content removing mode
            _buildActionTile(
              icon: Icons.delete_sweep_outlined,
              title: 'Torrent content removing mode',
              value: removeModeDisplay,
              onTap: () => _showOptionsDialog<dynamic>(
                title: 'Torrent content removing mode',
                prefKey: 'torrent_content_remove_mode',
                currentValue: removeModeVal ?? 0,
                options: <({String label, dynamic value, String? subtitle})>[
                  (
                    label: 'Delete files permanently',
                    value: removeModeVal is String ? 'Delete' : 0,
                    subtitle: 'Erase payload data directly from storage',
                  ),
                  (
                    label: 'Move to trash (if possible)',
                    value: removeModeVal is String ? 'Trash' : 1,
                    subtitle:
                        'Move removed files to the OS Recycle Bin / Trash',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // 3. Network interface
            _buildActionTile(
              icon: Icons.lan_outlined,
              title: 'Network interface',
              value: currentIface.isNotEmpty ? currentIface : 'Any interface',
              onTap: () {
                final List<Map<String, String>> ifaces =
                    ifacesAsync.value ?? <Map<String, String>>[];
                final List<({String label, String value, String? subtitle})>
                    options =
                    <({String label, String value, String? subtitle})>[
                  (
                    label: 'Any interface',
                    value: '',
                    subtitle: 'Listen and bind across all network interfaces',
                  ),
                  ...ifaces.map((Map<String, String> iface) {
                    final String name = iface['name'] ?? '';
                    final String val = iface['value'] ?? name;
                    return (
                      label: name.isNotEmpty ? name : val,
                      value: val,
                      subtitle: 'Bind strictly to interface $val',
                    );
                  }),
                ];
                _showOptionsDialog<String>(
                  title: 'Network interface',
                  prefKey: 'current_network_interface',
                  currentValue: currentIface,
                  options: options,
                );
              },
            ),
            const Divider(height: 1),

            // 4. Optional IP address to bind to
            _buildActionTile(
              icon: Icons.pin_drop_outlined,
              title: 'Optional IP address to bind to',
              value:
                  (prefs['current_interface_address']?.toString().isNotEmpty ==
                          true)
                      ? prefs['current_interface_address'].toString()
                      : 'All addresses',
              onTap: () {
                final List<String> addrs = addrsAsync.value ?? <String>[];
                final String currentAddr =
                    prefs['current_interface_address']?.toString() ?? '';
                final List<({String label, String value, String? subtitle})>
                    options =
                    <({String label, String value, String? subtitle})>[
                  (
                    label: 'All addresses',
                    value: '',
                    subtitle: 'Bind to all IPv4 and IPv6 addresses',
                  ),
                  (
                    label: 'All IPv4 addresses (0.0.0.0)',
                    value: '0.0.0.0',
                    subtitle: 'Listen on all available IPv4 interfaces',
                  ),
                  (
                    label: 'All IPv6 addresses (::)',
                    value: '::',
                    subtitle: 'Listen on all available IPv6 interfaces',
                  ),
                  ...addrs.map(
                    (String addr) => (
                      label: addr,
                      value: addr,
                      subtitle: null,
                    ),
                  ),
                ];
                _showOptionsDialog<String>(
                  title: 'Optional IP address to bind to',
                  prefKey: 'current_interface_address',
                  currentValue: currentAddr,
                  options: options,
                );
              },
            ),
            const Divider(height: 1),

            // 5. Save resume data interval
            _buildActionTile(
              icon: Icons.timer_outlined,
              title: 'Save resume data interval',
              value: '${prefs['save_resume_data_interval'] ?? 60} min',
              onTap: () => _showNumberEditDialog(
                title: 'Save resume data interval (min)',
                prefKey: 'save_resume_data_interval',
                initialValue: _getInt(
                  prefs['save_resume_data_interval'],
                  defaultValue: 60,
                ),
                helperText: 'Interval in minutes between periodic state saves',
              ),
            ),
            const Divider(height: 1),

            // 6. Save statistics interval
            _buildActionTile(
              icon: Icons.query_stats_rounded,
              title: 'Save statistics interval',
              value: '${prefs['save_statistics_interval'] ?? 15} min',
              onTap: () => _showNumberEditDialog(
                title: 'Save statistics interval (min)',
                prefKey: 'save_statistics_interval',
                initialValue: _getInt(
                  prefs['save_statistics_interval'],
                  defaultValue: 15,
                ),
                helperText: 'Interval in minutes between saving session stats',
              ),
            ),
            const Divider(height: 1),

            // 7. .torrent file size limit
            _buildActionTile(
              icon: Icons.file_present_outlined,
              title: '.torrent file size limit',
              value: '${prefs['max_torrent_file_size'] ?? 100} MiB',
              onTap: () => _showNumberEditDialog(
                title: '.torrent file size limit (MiB)',
                prefKey: 'max_torrent_file_size',
                initialValue:
                    _getInt(prefs['max_torrent_file_size'], defaultValue: 100),
                helperText:
                    'Maximum allowed file size for added .torrent files',
              ),
            ),
            const Divider(height: 1),

            // 8. Confirm torrent recheck
            _buildSwitchTile(
              icon: Icons.refresh_rounded,
              title: 'Confirm torrent recheck',
              subtitle: 'Show confirmation prompt before force rechecking',
              value: _getBool(
                prefs['confirm_torrent_recheck'],
                defaultValue: true,
              ),
              onChanged: (bool val) =>
                  _updatePref('confirm_torrent_recheck', val),
            ),
            const Divider(height: 1),

            // 9. Recheck torrents on completion
            _buildSwitchTile(
              icon: Icons.check_circle_outline_rounded,
              title: 'Recheck torrents on completion',
              subtitle: 'Verify piece integrity after download reaches 100%',
              value: _getBool(prefs['recheck_completed_torrents']),
              onChanged: (bool val) =>
                  _updatePref('recheck_completed_torrents', val),
            ),
            const Divider(height: 1),

            // 10. Customize application instance name
            _buildActionTile(
              icon: Icons.badge_outlined,
              title: 'Customize application instance name',
              value: prefs['app_instance_name']?.toString().isNotEmpty == true
                  ? prefs['app_instance_name'].toString()
                  : '(Default)',
              onTap: () => _showStringEditDialog(
                title: 'Customize application instance name',
                prefKey: 'app_instance_name',
                initialValue: prefs['app_instance_name']?.toString() ?? '',
                hintText: 'Custom instance name',
              ),
            ),
            const Divider(height: 1),

            // 11. Refresh interval
            _buildActionTile(
              icon: Icons.sync_rounded,
              title: 'Refresh interval',
              value: '${prefs['refresh_interval'] ?? 1500} ms',
              onTap: () => _showNumberEditDialog(
                title: 'Refresh interval (ms)',
                prefKey: 'refresh_interval',
                initialValue:
                    _getInt(prefs['refresh_interval'], defaultValue: 1500),
                helperText: 'Polling refresh interval in milliseconds',
              ),
            ),
            const Divider(height: 1),

            // 12. Resolve peer host names
            _buildSwitchTile(
              icon: Icons.dns_outlined,
              title: 'Resolve peer host names',
              subtitle: 'Perform reverse DNS lookup on connected peer IPs',
              value: _getBool(prefs['resolve_peer_host_names']),
              onChanged: (bool val) =>
                  _updatePref('resolve_peer_host_names', val),
            ),
            const Divider(height: 1),

            // 13. Resolve peer countries
            _buildSwitchTile(
              icon: Icons.flag_outlined,
              title: 'Resolve peer countries',
              subtitle: 'Show country flags for peer IP geolocation',
              value: _getBool(
                prefs['resolve_peer_countries'],
                defaultValue: true,
              ),
              onChanged: (bool val) =>
                  _updatePref('resolve_peer_countries', val),
            ),
            const Divider(height: 1),

            // 14. Reannounce to all trackers when IP or port changed
            _buildSwitchTile(
              icon: Icons.podcasts_rounded,
              title: 'Reannounce to all trackers when IP or port changed',
              subtitle: 'Trigger instant tracker update on network change',
              value: _getBool(prefs['reannounce_when_address_changed']),
              onChanged: (bool val) =>
                  _updatePref('reannounce_when_address_changed', val),
            ),
            const Divider(height: 1),

            // 15. Enable embedded tracker
            _buildSwitchTile(
              icon: Icons.hub_rounded,
              title: 'Enable embedded tracker',
              subtitle: 'Run built-in tracker on this qBittorrent node',
              value: _getBool(prefs['enable_embedded_tracker']),
              onChanged: (bool val) =>
                  _updatePref('enable_embedded_tracker', val),
            ),
            if (_getBool(prefs['enable_embedded_tracker'])) ...<Widget>[
              const Divider(height: 1),
              // 16. Embedded tracker port
              _buildActionTile(
                icon: Icons.numbers_rounded,
                title: 'Embedded tracker port',
                value: '${prefs['embedded_tracker_port'] ?? 9000}',
                onTap: () => _showNumberEditDialog(
                  title: 'Embedded tracker port',
                  prefKey: 'embedded_tracker_port',
                  initialValue: _getInt(
                    prefs['embedded_tracker_port'],
                    defaultValue: 9000,
                  ),
                ),
              ),
              const Divider(height: 1),
              // 17. Enable port forwarding for embedded tracker
              _buildSwitchTile(
                icon: Icons.router_outlined,
                title: 'Enable port forwarding for embedded tracker',
                subtitle: 'Use UPnP/NAT-PMP to open tracker port',
                value: _getBool(prefs['embedded_tracker_port_forwarding']),
                onChanged: (bool val) =>
                    _updatePref('embedded_tracker_port_forwarding', val),
              ),
            ],
            const Divider(height: 1),

            // 18. Ignore SSL errors
            _buildSwitchTile(
              icon: Icons.gpp_maybe_outlined,
              title: 'Ignore SSL errors',
              subtitle:
                  'Ignore HTTPS certification validation errors on trackers & RSS',
              value: _getBool(prefs['ignore_ssl_errors']),
              onChanged: (bool val) => _updatePref('ignore_ssl_errors', val),
            ),
            const Divider(height: 1),

            // 19. Python executable path (may require restart)
            _buildActionTile(
              icon: Icons.terminal_rounded,
              title: 'Python executable path (may require restart)',
              value:
                  prefs['python_executable_path']?.toString().isNotEmpty == true
                      ? prefs['python_executable_path'].toString()
                      : '(Auto detect if empty)',
              onTap: () => _showStringEditDialog(
                title: 'Python executable path',
                prefKey: 'python_executable_path',
                initialValue: prefs['python_executable_path']?.toString() ?? '',
                hintText: '(Auto detect if empty)',
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.md),

        // --- 2. libtorrent Engine Tuning ---
        _buildSectionHeader('libtorrent & Engine Tuning'),
        _buildCard(
          children: <Widget>[
            _buildActionTile(
              icon: Icons.memory_rounded,
              title: 'Disk Write Cache (MiB)',
              value: prefs['disk_cache']?.toString() ?? 'Auto',
              onTap: () => _showNumberEditDialog(
                title: 'Disk Write Cache (MiB, -1 for auto)',
                prefKey: 'disk_cache',
                initialValue: _getInt(prefs['disk_cache'], defaultValue: -1),
              ),
            ),
            const Divider(height: 1),
            _buildActionTile(
              icon: Icons.timer_outlined,
              title: 'Disk Cache Expiry (TTL)',
              value: '${prefs['disk_cache_ttl'] ?? 60} seconds',
              onTap: () => _showNumberEditDialog(
                title: 'Disk Cache Expiry (seconds)',
                prefKey: 'disk_cache_ttl',
                initialValue:
                    _getInt(prefs['disk_cache_ttl'], defaultValue: 60),
              ),
            ),
            const Divider(height: 1),
            _buildActionTile(
              icon: Icons.alt_route_rounded,
              title: 'Asynchronous I/O Threads',
              value: prefs['async_io_threads']?.toString() ?? '4',
              onTap: () => _showNumberEditDialog(
                title: 'Asynchronous I/O Threads',
                prefKey: 'async_io_threads',
                initialValue:
                    _getInt(prefs['async_io_threads'], defaultValue: 4),
              ),
            ),
            const Divider(height: 1),
            _buildActionTile(
              icon: Icons.speed_rounded,
              title: 'Memory Working Set Limit (MiB)',
              value: prefs['memory_working_set_limit']?.toString() ??
                  '0 (Unlimited)',
              onTap: () => _showNumberEditDialog(
                title: 'Memory Working Set Limit (MiB, 0 for unlimited)',
                prefKey: 'memory_working_set_limit',
                initialValue: _getInt(prefs['memory_working_set_limit']),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // SHARED BUILDER HELPERS
  // ==========================================
  Widget _buildTabListView({required List<Widget> children}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Insets.md,
        Insets.sm,
        Insets.md,
        80,
      ),
      children: children,
    );
  }

  Widget _buildSectionHeader(String title) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.xs,
        Insets.sm,
        Insets.xs,
        Insets.xs,
      ),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: cs.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style:
            theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      trailing: Text(
        value,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: cs.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.xs,
      ),
      secondary: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: cs.primary, size: 20),
      ),
      title: Text(
        title,
        style:
            theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: cs.primary, size: 20),
      ),
      title: Text(
        title,
        style:
            theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        value,
        style: theme.textTheme.bodySmall?.copyWith(
          color: cs.primary,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
    );
  }

  String _formatLimit(dynamic limit) {
    if (limit == null) return 'Unlimited';
    final int bytes = int.tryParse(limit.toString()) ?? 0;
    if (bytes <= 0) return 'Unlimited';
    return '${fmtBytes(bytes)}/s';
  }
}
