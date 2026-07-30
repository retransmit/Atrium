import 'package:flutter/material.dart';

import 'deluge_format.dart';

/// Preset caps in KiB/s. -1 is Deluge's own "unlimited".
const List<double> _presetsKib = <double>[-1, 512, 1024, 2048, 5120, 10240];

/// Picks a global bandwidth cap. Returns KiB/s (-1 for unlimited), or null when
/// dismissed.
///
/// [current] pre-selects the value Deluge already has so the dialog opens
/// showing the truth rather than a guess.
Future<double?> showDelugeSpeedDialog(
  BuildContext context, {
  required String title,
  required double current,
}) {
  return showDialog<double>(
    context: context,
    builder: (BuildContext context) =>
        _SpeedDialogContent(title: title, current: current),
  );
}

class _SpeedDialogContent extends StatefulWidget {
  const _SpeedDialogContent({required this.title, required this.current});

  final String title;
  final double current;

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
    final double? kib = double.tryParse(_custom.text.trim());
    if (kib != null && kib >= 0) {
      Navigator.of(context).pop(kib);
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
            // Deluge may hold a value that is no preset, in which case nothing
            // is ticked - correct, the custom field below carries it.
            for (final double kib in _presetsKib)
              ListTile(
                contentPadding: EdgeInsets.zero,
                selected: kib == widget.current,
                title: Text(delugeFmtLimitKib(kib)),
                trailing:
                    kib == widget.current ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(kib),
              ),
            TextField(
              controller: _custom,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Custom (KB/s)',
                helperText: '0 stops transfers entirely',
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
