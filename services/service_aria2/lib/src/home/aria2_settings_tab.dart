import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../aria2_api.dart';
import '../aria2_format.dart';
import '../aria2_providers.dart';

/// Tab 2: Global aria2 configuration editor (bandwidth, concurrency, storage, and BitTorrent).
class Aria2SettingsTab extends ConsumerStatefulWidget {
  const Aria2SettingsTab({
    required this.instance,
    this.onOpenDrawer,
    super.key,
  });

  final Instance instance;
  final VoidCallback? onOpenDrawer;

  @override
  ConsumerState<Aria2SettingsTab> createState() => _Aria2SettingsTabState();
}

class _Aria2SettingsTabState extends ConsumerState<Aria2SettingsTab> {
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

  Future<void> _write(String key, String value) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final Aria2Api api = await ref.read(
        aria2ApiProvider(widget.instance).future,
      );
      await api.changeGlobalOption(<String, String>{key: value});
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Setting saved'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
    } finally {
      ref.invalidate(aria2GlobalOptionsProvider(widget.instance));
    }
  }

  Future<void> _editText({
    required String title,
    required String key,
    required String initial,
    String? helper,
  }) async {
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext _) =>
          _EditDialog(title: title, initial: initial, helper: helper),
    );
    if (result != null && result != initial) {
      await _write(key, result);
    }
  }

  Future<void> _editNumber({
    required String title,
    required String key,
    required String initial,
    bool decimal = false,
    String? helper,
  }) async {
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext _) => _EditDialog(
        title: title,
        initial: initial,
        helper: helper,
        number: true,
        decimal: decimal,
      ),
    );
    if (result != null && result != initial) {
      await _write(key, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Map<String, String>> options = ref.watch(
      aria2GlobalOptionsProvider(widget.instance),
    );

    ref.listen<int>(aria2ScrollToTopProvider((widget.instance, 1)), (
      previous,
      next,
    ) {
      if (next > 0 && _scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: widget.onOpenDrawer ??
              () => Scaffold.of(context).openDrawer(),
        ),
        title: const Text('Aria2 Settings'),
      ),
      body: AsyncValueView<Map<String, String>>(
        value: options,
        onRetry: () =>
            ref.invalidate(aria2GlobalOptionsProvider(widget.instance)),
        data: (Map<String, String> opt) {
          final String dlLimit = opt['max-overall-download-limit'] ?? '0';
          final String ulLimit = opt['max-overall-upload-limit'] ?? '0';
          final String taskDlLimit = opt['max-download-limit'] ?? '0';
          final String taskUlLimit = opt['max-upload-limit'] ?? '0';

          final String maxConcurrent = opt['max-concurrent-downloads'] ?? '5';
          final String maxConnPerServer =
              opt['max-connection-per-server'] ?? '1';
          final String split = opt['split'] ?? '5';
          final String minSplitSize = opt['min-split-size'] ?? '20M';
          final String connectTimeout = opt['connect-timeout'] ?? '60';

          final String downloadDir = opt['dir'] ?? '';
          final String diskCache = opt['disk-cache'] ?? '16M';
          final String fileAlloc = opt['file-allocation'] ?? 'prealloc';
          final bool autoRenaming =
              (opt['auto-file-renaming'] ?? 'true') == 'true';
          final bool conditionalGet =
              (opt['conditional-get'] ?? 'false') == 'true';

          final String seedRatio = opt['seed-ratio'] ?? '1.0';
          final String seedTime = opt['seed-time'] ?? '';
          final bool enableDht = (opt['enable-dht'] ?? 'true') == 'true';
          final String btMaxPeers = opt['bt-max-peers'] ?? '55';
          final String listenPort = opt['listen-port'] ?? '6881-6999';

          String formatRate(String bytesStr) {
            final int? b = int.tryParse(bytesStr);
            if (b == null || b <= 0) return 'Unlimited (0)';
            return aria2FmtRate(b);
          }

          return EasyRefresh(
            onRefresh: () async {
              ref.invalidate(aria2GlobalOptionsProvider(widget.instance));
              await ref.read(
                aria2GlobalOptionsProvider(widget.instance).future,
              );
            },
            child: ListView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                Insets.md,
                Insets.xs,
                Insets.md,
                Insets.xl,
              ),
              children: <Widget>[
                // Group 1: Bandwidth & Limits
                _SettingsGroup(
                  title: 'Bandwidth & Limits',
                  icon: Icons.speed_outlined,
                  children: <Widget>[
                    ListTile(
                      title: const Text('Overall download speed limit'),
                      subtitle: Text(formatRate(dlLimit)),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => _editNumber(
                        title: 'Overall Download Limit (bytes/sec)',
                        key: 'max-overall-download-limit',
                        initial: dlLimit,
                        helper: '0 for unlimited, e.g. 1048576 for 1 MB/s',
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Overall upload speed limit'),
                      subtitle: Text(formatRate(ulLimit)),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => _editNumber(
                        title: 'Overall Upload Limit (bytes/sec)',
                        key: 'max-overall-upload-limit',
                        initial: ulLimit,
                        helper: '0 for unlimited, e.g. 524288 for 512 KB/s',
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Default task download limit'),
                      subtitle: Text(formatRate(taskDlLimit)),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => _editNumber(
                        title: 'Task Download Limit (bytes/sec)',
                        key: 'max-download-limit',
                        initial: taskDlLimit,
                        helper: 'Speed limit per download (0 = unlimited)',
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Default task upload limit'),
                      subtitle: Text(formatRate(taskUlLimit)),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => _editNumber(
                        title: 'Task Upload Limit (bytes/sec)',
                        key: 'max-upload-limit',
                        initial: taskUlLimit,
                        helper: 'Upload limit per download (0 = unlimited)',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.md),

                // Group 2: Tasks & Concurrency
                _SettingsGroup(
                  title: 'Tasks & Concurrency',
                  icon: Icons.alt_route_outlined,
                  children: <Widget>[
                    ListTile(
                      title: const Text('Max concurrent downloads'),
                      subtitle: Text('$maxConcurrent active downloads at once'),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => _editNumber(
                        title: 'Max Concurrent Downloads',
                        key: 'max-concurrent-downloads',
                        initial: maxConcurrent,
                        helper: 'Number of parallel downloads (default: 5)',
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Connections per server'),
                      subtitle: Text('$maxConnPerServer per host'),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => _editNumber(
                        title: 'Max Connections per Server',
                        key: 'max-connection-per-server',
                        initial: maxConnPerServer,
                        helper: '1 to 16 (default: 1)',
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Split count'),
                      subtitle: Text('Download file in $split pieces'),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => _editNumber(
                        title: 'Split Pieces Count',
                        key: 'split',
                        initial: split,
                        helper: 'Number of pieces to split a file into (1 to 16)',
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Min split size'),
                      subtitle: Text(minSplitSize),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => _editText(
                        title: 'Min Split Size',
                        key: 'min-split-size',
                        initial: minSplitSize,
                        helper: 'e.g. 10M, 20M, 50M',
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Connection timeout'),
                      subtitle: Text('$connectTimeout seconds'),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => _editNumber(
                        title: 'Connect Timeout (seconds)',
                        key: 'connect-timeout',
                        initial: connectTimeout,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.md),

                // Group 3: Storage & Directories
                _SettingsGroup(
                  title: 'Storage & Directories',
                  icon: Icons.folder_outlined,
                  children: <Widget>[
                    ListTile(
                      title: const Text('Download directory'),
                      subtitle: Text(
                        downloadDir.isEmpty ? 'Default' : downloadDir,
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => _editText(
                        title: 'Default Download Directory',
                        key: 'dir',
                        initial: downloadDir,
                        helper: 'Absolute filesystem path on the aria2 host',
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Disk cache'),
                      subtitle: Text(
                        '${diskCache.isEmpty ? 'Disabled' : diskCache} (startup only • set in aria2.conf)',
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('File allocation method'),
                      subtitle: Text(fileAlloc),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () async {
                        final String? selected = await showDialog<String>(
                          context: context,
                          builder: (BuildContext ctx) => SimpleDialog(
                            title: const Text('File Allocation Method'),
                            children: <Widget>[
                              for (final String m in <String>[
                                'none',
                                'prealloc',
                                'trunc',
                                'falloc',
                              ])
                                SimpleDialogOption(
                                  onPressed: () => Navigator.of(ctx).pop(m),
                                  child: Text(m),
                                ),
                            ],
                          ),
                        );
                        if (selected != null && selected != fileAlloc) {
                          await _write('file-allocation', selected);
                        }
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Auto file renaming'),
                      subtitle: const Text(
                        'Rename file if filename already exists',
                      ),
                      value: autoRenaming,
                      onChanged: (bool val) =>
                          _write('auto-file-renaming', val ? 'true' : 'false'),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Conditional GET'),
                      subtitle: const Text(
                        'Skip downloading if local file has matching timestamp',
                      ),
                      value: conditionalGet,
                      onChanged: (bool val) =>
                          _write('conditional-get', val ? 'true' : 'false'),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.md),

                // Group 4: BitTorrent & Seeding
                _SettingsGroup(
                  title: 'BitTorrent & Seeding',
                  icon: Icons.grain_outlined,
                  children: <Widget>[
                    ListTile(
                      title: const Text('Seed ratio'),
                      subtitle: Text(
                        seedRatio == '0' || seedRatio == '0.0'
                            ? 'Infinite seeding'
                            : '${seedRatio}x',
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => _editNumber(
                        title: 'Seed Ratio',
                        key: 'seed-ratio',
                        initial: seedRatio,
                        decimal: true,
                        helper: '0.0 for unlimited, or e.g. 1.0, 2.0',
                      ),
                    ),
                    if (seedTime.isNotEmpty) ...<Widget>[
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Seed time'),
                        subtitle: Text('$seedTime minutes'),
                        trailing: const Icon(Icons.chevron_right, size: 20),
                        onTap: () => _editNumber(
                          title: 'Seed Time (minutes)',
                          key: 'seed-time',
                          initial: seedTime,
                        ),
                      ),
                    ],
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Enable DHT'),
                      subtitle: Text(
                        '${enableDht ? 'Enabled' : 'Disabled'} (startup only • set in aria2.conf)',
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Max peers'),
                      subtitle: Text('$btMaxPeers peers'),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => _editNumber(
                        title: 'Max BitTorrent Peers',
                        key: 'bt-max-peers',
                        initial: btMaxPeers,
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Listen port'),
                      subtitle: Text(
                        '${listenPort.isEmpty ? 'Default' : listenPort} (startup only • set in aria2.conf)',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.md,
              Insets.md,
              Insets.md,
              Insets.xs,
            ),
            child: Row(
              children: <Widget>[
                Icon(icon, size: 18, color: cs.primary),
                const SizedBox(width: Insets.sm),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _EditDialog extends StatefulWidget {
  const _EditDialog({
    required this.title,
    required this.initial,
    this.helper,
    this.number = false,
    this.decimal = false,
  });

  final String title;
  final String initial;
  final String? helper;
  final bool number;
  final bool decimal;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: widget.number
            ? TextInputType.numberWithOptions(decimal: widget.decimal)
            : TextInputType.text,
        inputFormatters: <TextInputFormatter>[
          if (widget.number)
            FilteringTextInputFormatter.allow(
              RegExp(widget.decimal ? r'[0-9.]' : r'[0-9]'),
            ),
        ],
        decoration: InputDecoration(
          helperText: widget.helper,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
