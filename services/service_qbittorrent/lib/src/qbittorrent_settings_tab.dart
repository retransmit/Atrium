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
  Widget _buildSpeedTab() => _buildTabListView(children: const <Widget>[]);

  // ==========================================
  // 5. BITTORRENT TAB
  // ==========================================
  Widget _buildBitTorrentTab() => _buildTabListView(children: const <Widget>[]);

  // ==========================================
  // 6. RSS TAB
  // ==========================================
  Widget _buildRssTab() => _buildTabListView(children: const <Widget>[]);

  // ==========================================
  // 7. WEBUI TAB
  // ==========================================
  Widget _buildWebUiTab() => _buildTabListView(children: const <Widget>[]);

  // ==========================================
  // 8. ADVANCED TAB
  // ==========================================
  Widget _buildAdvancedTab() => _buildTabListView(children: const <Widget>[]);

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
