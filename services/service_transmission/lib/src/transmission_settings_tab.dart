import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/transmission_session.dart';
import 'transmission_api.dart';
import 'transmission_format.dart';
import 'transmission_providers.dart';
import 'transmission_visuals.dart';

/// The web UI's Statistics dialog and its four preference pages, as one
/// scrolling tab. Every change is written on its own, then the session is
/// read again so the screen shows what the daemon accepted.
class TransmissionSettingsTab extends ConsumerStatefulWidget {
  const TransmissionSettingsTab({required this.instance, super.key});

  final Instance instance;

  @override
  ConsumerState<TransmissionSettingsTab> createState() =>
      _TransmissionSettingsTabState();
}

class _TransmissionSettingsTabState
    extends ConsumerState<TransmissionSettingsTab> {
  bool _updatingBlocklist = false;
  bool _testingPort = false;

  /// Per protocol, or a single `''` key on a daemon that tests only one.
  Map<String, bool> _portResults = <String, bool>{};

  Future<void> _write(String key, Object? value) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final TransmissionApi api =
          await ref.read(transmissionApiProvider(widget.instance).future);
      await api.setSession(<String, Object?>{key: value});
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Setting saved'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
    } finally {
      // Whether it took or not, show what the daemon has now.
      ref.invalidate(transmissionSessionProvider(widget.instance));
    }
  }

  Future<void> _editText({
    required String title,
    required String key,
    required String initial,
    bool multiline = false,
    String? helper,
  }) async {
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext _) => _EditDialog(
        title: title,
        initial: initial,
        helper: helper,
        multiline: multiline,
      ),
    );
    if (result != null && result != initial) await _write(key, result);
  }

  Future<void> _editNumber({
    required String title,
    required String key,
    required num initial,
    bool decimal = false,
    String? helper,
  }) async {
    final String? text = await showDialog<String>(
      context: context,
      builder: (BuildContext _) => _EditDialog(
        title: title,
        initial: '$initial',
        helper: helper,
        number: true,
        decimal: decimal,
      ),
    );
    if (text == null) return;
    final num? value = decimal ? double.tryParse(text) : int.tryParse(text);
    if (value != null && value != initial) await _write(key, value);
  }

  Future<void> _pickTime({required String key, required int minutes}) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked != null) await _write(key, picked.hour * 60 + picked.minute);
  }

  Future<void> _updateBlocklist() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _updatingBlocklist = true);
    try {
      final TransmissionApi api =
          await ref.read(transmissionApiProvider(widget.instance).future);
      final int rules = await api.updateBlocklist();
      messenger.showSnackBar(
        SnackBar(content: Text('Blocklist updated: $rules rules')),
      );
      ref.invalidate(transmissionSessionProvider(widget.instance));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Blocklist update failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _updatingBlocklist = false);
    }
  }

  Future<void> _testPort(TransmissionSession session) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() {
      _testingPort = true;
      _portResults = <String, bool>{};
    });
    try {
      final TransmissionApi api =
          await ref.read(transmissionApiProvider(widget.instance).future);
      final Map<String, bool> results = <String, bool>{};
      if (session.supportsPortTestPerProtocol) {
        for (final String protocol in <String>['ipv4', 'ipv6']) {
          results[protocol] = await api.portTest(ipProtocol: protocol);
        }
      } else {
        results[''] = await api.portTest();
      }
      if (mounted) setState(() => _portResults = results);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Port test failed: $e')));
    } finally {
      if (mounted) setState(() => _testingPort = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final AsyncValue<TransmissionSession> session =
        ref.watch(transmissionSessionProvider(widget.instance));
    return AsyncValueView<TransmissionSession>(
      value: session,
      onRetry: () =>
          ref.invalidate(transmissionSessionProvider(widget.instance)),
      data: (TransmissionSession s) => ListView(
        padding: const EdgeInsets.fromLTRB(
          Insets.md,
          Insets.xs,
          Insets.md,
          Insets.xl,
        ),
        children: <Widget>[
          _StatisticsCard(instance: widget.instance),
          const SizedBox(height: Insets.sm),
          _Group(
            title: 'Torrents',
            children: <Widget>[
              _pathTile('Download to', s.downloadDir, 'download-dir'),
              _switchTile(
                'Start when added',
                s.startAddedTorrents,
                'start-added-torrents',
              ),
              _switchTile(
                'Stop seeding at ratio',
                s.seedRatioLimited,
                'seedRatioLimited',
              ),
              _numberTile(
                'Seed ratio limit',
                s.seedRatioLimit,
                'seedRatioLimit',
                decimal: true,
              ),
              _switchTile(
                'Stop seeding if idle',
                s.idleSeedingLimitEnabled,
                'idle-seeding-limit-enabled',
              ),
              _numberTile(
                'Idle limit (minutes)',
                s.idleSeedingLimit,
                'idle-seeding-limit',
              ),
              _switchTile(
                'Keep incomplete torrents in a separate folder',
                s.incompleteDirEnabled,
                'incomplete-dir-enabled',
              ),
              _pathTile('Incomplete folder', s.incompleteDir, 'incomplete-dir'),
              _switchTile(
                'Append ".part" to incomplete files',
                s.renamePartialFiles,
                'rename-partial-files',
              ),
              _switchTile(
                'Limit the download queue',
                s.downloadQueueEnabled,
                'download-queue-enabled',
              ),
              _numberTile(
                'Download queue size',
                s.downloadQueueSize,
                'download-queue-size',
              ),
              if (s.supportsDefaultTrackers)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Default public trackers'),
                  subtitle: Text(_trackerCount(s.defaultTrackers)),
                  onTap: () => _editText(
                    title: 'Default public trackers',
                    key: 'default-trackers',
                    initial: s.defaultTrackers,
                    multiline: true,
                    helper: 'One URL per line, a blank line between tiers',
                  ),
                ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          _Group(
            title: 'Speed',
            children: <Widget>[
              _switchTile(
                'Limit upload',
                s.speedLimitUpEnabled,
                'speed-limit-up-enabled',
              ),
              _numberTile(
                'Upload limit (kB/s)',
                s.speedLimitUp,
                'speed-limit-up',
              ),
              _switchTile(
                'Limit download',
                s.speedLimitDownEnabled,
                'speed-limit-down-enabled',
              ),
              _numberTile(
                'Download limit (kB/s)',
                s.speedLimitDown,
                'speed-limit-down',
              ),
              _numberTile(
                'Alternative upload limit (kB/s)',
                s.altSpeedUp,
                'alt-speed-up',
              ),
              _numberTile(
                'Alternative download limit (kB/s)',
                s.altSpeedDown,
                'alt-speed-down',
              ),
              _switchTile(
                'Scheduled alternative limits',
                s.altSpeedTimeEnabled,
                'alt-speed-time-enabled',
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('From'),
                subtitle: Text(_clock(s.altSpeedTimeBegin)),
                onTap: () => _pickTime(
                  key: 'alt-speed-time-begin',
                  minutes: s.altSpeedTimeBegin,
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('To'),
                subtitle: Text(_clock(s.altSpeedTimeEnd)),
                onTap: () => _pickTime(
                  key: 'alt-speed-time-end',
                  minutes: s.altSpeedTimeEnd,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Insets.xs),
                child: Text('On days: ${trDaySummary(s.altSpeedTimeDay)}'),
              ),
              Wrap(
                spacing: Insets.xs,
                runSpacing: Insets.xs,
                children: <Widget>[
                  for (final (int mask, String name) in <(int, String)>[
                    (trEveryDay, 'Every day'),
                    (trWeekdays, 'Weekdays'),
                    (trWeekends, 'Weekends'),
                  ])
                    ChoiceChip(
                      label: Text(name),
                      selected: s.altSpeedTimeDay == mask,
                      onSelected: (_) => _write('alt-speed-time-day', mask),
                    ),
                  for (final (int bit, String name) in trDays)
                    FilterChip(
                      label: Text(name),
                      selected: s.altSpeedTimeDay & bit != 0,
                      onSelected: (_) => _write(
                        'alt-speed-time-day',
                        trToggleDay(s.altSpeedTimeDay, bit),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          _Group(
            title: 'Peers',
            children: <Widget>[
              _numberTile(
                'Max peers per torrent',
                s.peerLimitPerTorrent,
                'peer-limit-per-torrent',
              ),
              _numberTile(
                'Max peers overall',
                s.peerLimitGlobal,
                'peer-limit-global',
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Encryption'),
                subtitle: Text(_encryptionLabel(s.encryption)),
                onTap: () async {
                  final String? mode = await showDialog<String>(
                    context: context,
                    builder: (BuildContext context) => SimpleDialog(
                      title: const Text('Encryption'),
                      children: <Widget>[
                        RadioGroup<String>(
                          groupValue: _encryptionValue(s.encryption),
                          onChanged: (String? v) =>
                              Navigator.of(context).pop(v),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              for (final (String value, String label)
                                  in _encryptionModes)
                                RadioListTile<String>(
                                  value: value,
                                  title: Text(label),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                  if (mode != null) await _write('encryption', mode);
                },
              ),
              _switchTile(
                'Use PEX to find more peers',
                s.pexEnabled,
                'pex-enabled',
              ),
              _switchTile(
                'Use DHT to find more peers',
                s.dhtEnabled,
                'dht-enabled',
              ),
              _switchTile(
                'Use LPD to find local peers',
                s.lpdEnabled,
                'lpd-enabled',
              ),
              _switchTile(
                'Enable blocklist',
                s.blocklistEnabled,
                'blocklist-enabled',
              ),
              _pathTile('Blocklist URL', s.blocklistUrl, 'blocklist-url'),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Insets.xs),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TransmissionPill(
                        icon: Icons.block,
                        label: 'Blocklist has ${s.blocklistSize} rules',
                        foreground: cs.onSurfaceVariant,
                        background: cs.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    FilledButton.tonal(
                      onPressed: _updatingBlocklist ? null : _updateBlocklist,
                      child: const Text('Update blocklist'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          _Group(
            title: 'Network',
            children: <Widget>[
              _numberTile('Peer listening port', s.peerPort, 'peer-port'),
              _switchTile(
                'Randomize port on launch',
                s.peerPortRandomOnStart,
                'peer-port-random-on-start',
              ),
              _switchTile(
                'Use port forwarding (UPnP or NAT-PMP)',
                s.portForwardingEnabled,
                'port-forwarding-enabled',
              ),
              _switchTile('Enable uTP', s.utpEnabled, 'utp-enabled'),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Insets.xs),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Wrap(
                        spacing: Insets.xs,
                        runSpacing: Insets.xs,
                        children: <Widget>[
                          for (final MapEntry<String, bool> r
                              in _portResults.entries)
                            TransmissionPill(
                              icon: r.value
                                  ? Icons.check_circle_outline
                                  : Icons.error_outline,
                              label: '${_protocolLabel(r.key)} is '
                                  '${r.value ? 'Open' : 'Closed'}',
                              foreground: r.value
                                  ? cs.onTertiaryContainer
                                  : cs.onErrorContainer,
                              background: r.value
                                  ? cs.tertiaryContainer
                                  : cs.errorContainer,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    FilledButton.tonal(
                      onPressed: _testingPort ? null : () => _testPort(s),
                      child: const Text('Test port'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.lg),
          Center(
            child: Text(
              'Transmission ${s.version}, RPC ${s.rpcVersion}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _switchTile(String title, bool value, String key) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        value: value,
        onChanged: (bool v) => _write(key, v),
      );

  Widget _numberTile(
    String title,
    num value,
    String key, {
    bool decimal = false,
  }) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        subtitle: Text('$value'),
        onTap: () => _editNumber(
          title: title,
          key: key,
          initial: value,
          decimal: decimal,
        ),
      );

  Widget _pathTile(String title, String value, String key) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        subtitle: Text(value.isEmpty ? 'Not set' : value),
        onTap: () => _editText(
          title: title,
          key: key,
          initial: value,
          helper: 'A path as the server sees it, not your phone',
        ),
      );

  static String _clock(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';

  static String _trackerCount(String trackers) {
    final int n = trackers
        .split('\n')
        .where((String l) => l.trim().isNotEmpty)
        .length;
    return n == 0 ? 'None' : trCount(n, 'tracker', 'trackers');
  }

  static String _protocolLabel(String protocol) => switch (protocol) {
        'ipv4' => 'IPv4 port',
        'ipv6' => 'IPv6 port',
        _ => 'Port',
      };

  /// The daemon writes `allowed` but reads it back as `tolerated`.
  static const List<(String, String)> _encryptionModes = <(String, String)>[
    ('allowed', 'Allow encryption'),
    ('preferred', 'Prefer encryption'),
    ('required', 'Require encryption'),
  ];

  static String _encryptionValue(String raw) =>
      raw == 'tolerated' ? 'allowed' : raw;

  static String _encryptionLabel(String raw) {
    final String value = _encryptionValue(raw);
    for (final (String v, String label) in _encryptionModes) {
      if (v == value) return label;
    }
    return raw;
  }
}

/// One of the web UI's preference pages, as a titled panel of rows.
class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return TransmissionPanel(
      padding: const EdgeInsets.fromLTRB(
        Insets.md,
        Insets.md,
        Insets.md,
        Insets.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TransmissionPanelTitle(title),
          ...children,
        ],
      ),
    );
  }
}

/// One field and Save, owning its controller so it outlives the dialog's
/// exit animation.
class _EditDialog extends StatefulWidget {
  const _EditDialog({
    required this.title,
    required this.initial,
    this.helper,
    this.multiline = false,
    this.number = false,
    this.decimal = false,
  });

  final String title;
  final String initial;
  final String? helper;
  final bool multiline;
  final bool number;
  final bool decimal;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

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
        maxLines: widget.multiline ? 6 : 1,
        keyboardType: widget.number
            ? TextInputType.numberWithOptions(decimal: widget.decimal)
            : null,
        inputFormatters: <TextInputFormatter>[
          if (widget.number)
            FilteringTextInputFormatter.allow(
              RegExp(widget.decimal ? r'[0-9.]' : r'[0-9]'),
            ),
        ],
        decoration: transmissionFieldDecoration(context, helper: widget.helper),
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

/// The web UI's Statistics dialog: this session beside all time, each as
/// one tinted block of figures.
class _StatisticsCard extends ConsumerWidget {
  const _StatisticsCard({required this.instance});

  final Instance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final TextTheme text = theme.textTheme;
    final TransmissionSessionStats stats =
        ref.watch(transmissionSessionStatsProvider(instance)).value ??
            const TransmissionSessionStats();

    Widget figure(String label, String value) => Padding(
          padding: const EdgeInsets.only(bottom: Insets.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: text.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        );

    Widget block(
      String title,
      IconData icon,
      TransmissionStatsBlock b, {
      bool started = false,
    }) {
      final double ratio =
          b.downloadedBytes == 0 ? -1 : b.uploadedBytes / b.downloadedBytes;
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(Insets.md),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(icon, size: 16, color: cs.primary),
                  const SizedBox(width: Insets.xs),
                  Expanded(
                    child: Text(
                      title,
                      style: text.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.sm),
              figure('Uploaded', trFmtBytes(b.uploadedBytes)),
              figure('Downloaded', trFmtBytes(b.downloadedBytes)),
              figure('Ratio', trRatioString(ratio)),
              figure('Running time', trTimeInterval(b.secondsActive)),
              if (started)
                Text(
                  'Started ${b.sessionCount} times',
                  style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
            ],
          ),
        ),
      );
    }

    return TransmissionPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const TransmissionPanelTitle('Statistics'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              block('This session', Icons.timelapse_rounded, stats.currentStats),
              const SizedBox(width: Insets.sm),
              block(
                'All time',
                Icons.history_rounded,
                stats.cumulativeStats,
                started: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
