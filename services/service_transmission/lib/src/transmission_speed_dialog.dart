import 'package:flutter/material.dart';

import 'transmission_format.dart';

/// Preset caps in KB/s. [unlimitedSentinel] is offered as "Unlimited".
const List<int> _presetsKbps = <int>[512, 1024, 2048, 5120, 10240];

/// What [showTransmissionSpeedDialog] returns to mean "turn the limit off".
///
/// Transmission stores a limit value *and* a separate enabled flag, so
/// "unlimited" is not a value - it is the flag going false, and the old value
/// stays put. This sentinel keeps that distinction out of the caller's way.
const int transmissionUnlimited = -1;

/// Picks a global bandwidth cap. Returns KB/s, [transmissionUnlimited] to turn
/// the limit off, or null when dismissed.
Future<int?> showTransmissionSpeedDialog(
  BuildContext context, {
  required String title,
  required int currentKbps,
  required bool currentEnabled,
}) {
  return showDialog<int>(
    context: context,
    builder: (BuildContext context) => _SpeedDialogContent(
      title: title,
      currentKbps: currentKbps,
      currentEnabled: currentEnabled,
    ),
  );
}

class _SpeedDialogContent extends StatefulWidget {
  const _SpeedDialogContent({
    required this.title,
    required this.currentKbps,
    required this.currentEnabled,
  });

  final String title;
  final int currentKbps;
  final bool currentEnabled;

  @override
  State<_SpeedDialogContent> createState() => _SpeedDialogContentState();
}

class _SpeedDialogContentState extends State<_SpeedDialogContent> {
  final TextEditingController _custom = TextEditingController();

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _submitCustom() {
    final int? kbps = int.tryParse(_custom.text.trim());
    if (kbps != null && kbps >= 0) {
      Navigator.of(context).pop(kbps);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ListTile(
              contentPadding: EdgeInsets.zero,
              selected: !widget.currentEnabled,
              title: const Text('Unlimited'),
              trailing:
                  !widget.currentEnabled ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(context).pop(transmissionUnlimited),
            ),
            for (final int kbps in _presetsKbps)
              ListTile(
                contentPadding: EdgeInsets.zero,
                selected: widget.currentEnabled && kbps == widget.currentKbps,
                title: Text(trFmtLimit(kbps: kbps, enabled: true)),
                trailing: widget.currentEnabled && kbps == widget.currentKbps
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(context).pop(kbps),
              ),
            TextField(
              controller: _custom,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Custom (KB/s)',
                helperText: widget.currentEnabled
                    ? 'Currently ${widget.currentKbps} KB/s'
                    : 'Currently unlimited',
              ),
              onSubmitted: (_) => _submitCustom(),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitCustom,
          child: const Text('Set'),
        ),
      ],
    );
  }
}
