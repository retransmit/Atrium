import 'package:flutter/material.dart';

/// Preset speed limits in KB/s; 0 means unlimited.
const List<int> _presetsKb = <int>[0, 1024, 2048, 5120, 10240, 25600];

String speedLimitLabel(int kbPerSec) {
  if (kbPerSec <= 0) {
    return 'Unlimited';
  }
  if (kbPerSec >= 1024) {
    final double mb = kbPerSec / 1024;
    return '${mb == mb.roundToDouble() ? mb.toInt() : mb.toStringAsFixed(1)} MB/s';
  }
  return '$kbPerSec KB/s';
}

/// Picks a global download limit. Returns the KB/s value (0 = unlimited) or
/// null when dismissed.
Future<int?> showNzbgetSpeedDialog(BuildContext context) {
  return showDialog<int>(
    context: context,
    builder: (BuildContext context) => const _SpeedDialogContent(),
  );
}

class _SpeedDialogContent extends StatefulWidget {
  const _SpeedDialogContent();

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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Speed limit'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final int kb in _presetsKb)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(speedLimitLabel(kb)),
              onTap: () => Navigator.of(context).pop(kb),
            ),
          TextField(
            controller: _custom,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Custom (KB/s)'),
            onSubmitted: (String value) {
              final int? kb = int.tryParse(value.trim());
              if (kb != null && kb >= 0) {
                Navigator.of(context).pop(kb);
              }
            },
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final int? kb = int.tryParse(_custom.text.trim());
            if (kb != null && kb >= 0) {
              Navigator.of(context).pop(kb);
            }
          },
          child: const Text('Set'),
        ),
      ],
    );
  }
}
