import 'package:core_models/core_models.dart';
import 'package:core_networking/core_networking.dart';
import 'package:core_profile/core_profile.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Manage the active profile's Wake-on-LAN devices and send magic packets.
///
/// Devices live on the [Profile] so they travel with export/import; sending
/// goes through `sendWol` in core_networking (pure dart:io UDP broadcast).
class WakeOnLanScreen extends ConsumerStatefulWidget {
  const WakeOnLanScreen({super.key});

  @override
  ConsumerState<WakeOnLanScreen> createState() => _WakeOnLanScreenState();
}

class _WakeOnLanScreenState extends ConsumerState<WakeOnLanScreen> {
  @override
  Widget build(BuildContext context) {
    final Profile? profile = ref.watch(activeProfileProvider);
    final List<WolDevice> devices = profile?.wolDevices ?? const <WolDevice>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Wake-on-LAN')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: profile == null ? null : _addDevice,
        icon: const Icon(Icons.add),
        label: const Text('Add device'),
      ),
      body: devices.isEmpty
          ? const EmptyView(
              icon: Icons.bolt_outlined,
              title: 'No devices',
              message: 'Add a device to wake it over the network.',
            )
          : ListView(
              padding: Insets.page,
              children: <Widget>[
                for (final WolDevice device in devices)
                  _WolDeviceCard(
                    device: device,
                    onWake: () => _wake(device),
                    onEdit: () => _editDevice(existing: device),
                    onDelete: () => _deleteDevice(device),
                  ),
              ],
            ),
    );
  }

  Future<void> _wake(WolDevice device) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await sendWol(
        mac: device.mac,
        broadcastAddress: device.broadcastAddress,
        port: device.port,
      );
      messenger.showSnackBar(
        SnackBar(content: Text('Magic packet sent to ${device.name}')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to send magic packet')),
      );
    }
  }

  Future<void> _addDevice() => _editDevice();

  Future<void> _editDevice({WolDevice? existing}) async {
    final String id =
        existing?.id ?? ref.read(profileRepositoryProvider).newInstanceId();
    final WolDevice? result = await showDialog<WolDevice>(
      context: context,
      builder: (BuildContext context) =>
          _WolDeviceDialog(id: id, initial: existing),
    );
    if (result == null || !mounted) {
      return;
    }
    final Profile? profile = ref.read(activeProfileProvider);
    if (profile == null) {
      return;
    }
    final List<WolDevice> next = List<WolDevice>.of(profile.wolDevices);
    final int idx = next.indexWhere((WolDevice d) => d.id == result.id);
    if (idx >= 0) {
      next[idx] = result;
    } else {
      next.add(result);
    }
    await ref
        .read(profileListProvider.notifier)
        .updateProfile(profile.copyWith(wolDevices: next));
  }

  Future<void> _deleteDevice(WolDevice device) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Delete ${device.name}?'),
        content: const Text('This removes the device from Wake-on-LAN.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final Profile? profile = ref.read(activeProfileProvider);
    if (profile == null) {
      return;
    }
    final List<WolDevice> next = profile.wolDevices
        .where((WolDevice d) => d.id != device.id)
        .toList();
    await ref
        .read(profileListProvider.notifier)
        .updateProfile(profile.copyWith(wolDevices: next));
  }
}

class _WolDeviceCard extends StatelessWidget {
  const _WolDeviceCard({
    required this.device,
    required this.onWake,
    required this.onEdit,
    required this.onDelete,
  });

  final WolDevice device;
  final VoidCallback onWake;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: Insets.md),
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: InkWell(
        onTap: onEdit,
        onLongPress: onDelete,
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.bolt_outlined,
                  size: 22,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      device.name,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: Insets.xxs),
                    Text(
                      '${device.mac} - '
                      '${device.broadcastAddress}:${device.port}',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.outline),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Insets.sm),
              FilledButton.tonalIcon(
                onPressed: onWake,
                icon: const Icon(Icons.bolt, size: 18),
                label: const Text('Wake'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Add / edit form for one [WolDevice]. Pops with the device on save.
class _WolDeviceDialog extends StatefulWidget {
  const _WolDeviceDialog({required this.id, this.initial});

  final String id;
  final WolDevice? initial;

  @override
  State<_WolDeviceDialog> createState() => _WolDeviceDialogState();
}

class _WolDeviceDialogState extends State<_WolDeviceDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.initial?.name ?? '');
  late final TextEditingController _mac =
      TextEditingController(text: widget.initial?.mac ?? '');
  late final TextEditingController _broadcast = TextEditingController(
    text: widget.initial?.broadcastAddress ?? '255.255.255.255',
  );
  late final TextEditingController _port =
      TextEditingController(text: '${widget.initial?.port ?? 9}');

  @override
  void dispose() {
    _name.dispose();
    _mac.dispose();
    _broadcast.dispose();
    _port.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(
      WolDevice(
        id: widget.id,
        name: _name.text.trim(),
        mac: _mac.text.trim(),
        broadcastAddress: _broadcast.text.trim(),
        port: int.parse(_port.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add device' : 'Edit device'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: _name,
                autofocus: widget.initial == null,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'NAS',
                ),
                validator: (String? v) =>
                    (v ?? '').trim().isEmpty ? 'Enter a name' : null,
              ),
              const SizedBox(height: Insets.md),
              TextFormField(
                controller: _mac,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'MAC address',
                  hintText: 'AA:BB:CC:DD:EE:FF',
                ),
                validator: (String? v) {
                  try {
                    buildMagicPacket((v ?? '').trim());
                    return null;
                  } on FormatException {
                    return 'Enter a valid MAC address';
                  }
                },
              ),
              const SizedBox(height: Insets.md),
              TextFormField(
                controller: _broadcast,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Broadcast address',
                ),
                validator: (String? v) =>
                    (v ?? '').trim().isEmpty ? 'Enter an address' : null,
              ),
              const SizedBox(height: Insets.md),
              TextFormField(
                controller: _port,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: 'Port'),
                onFieldSubmitted: (String _) => _submit(),
                validator: (String? v) {
                  final int? port = int.tryParse((v ?? '').trim());
                  if (port == null || port < 1 || port > 65535) {
                    return 'Port must be 1-65535';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
