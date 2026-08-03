import 'package:flutter/material.dart';

import 'rtorrent_format.dart';

/// Preset caps in KB/s.
const List<int> _presetsKbps = <int>[512, 1024, 2048, 5120, 10240];

/// Picks a global bandwidth cap. Returns **bytes per second** (0 for
/// unlimited), or null when dismissed.
///
/// The dialog is in KB/s because that is what every torrent client's UI asks
/// for, but rTorrent's XML-RPC takes bytes, so the conversion happens here
/// rather than leaking into the caller.
Future<int?> showRtorrentSpeedDialog(
  BuildContext context, {
  required String title,
  required int currentBytesPerSec,
}) {
  return showDialog<int>(
    context: context,
    builder: (BuildContext context) => _SpeedDialogContent(
      title: title,
      currentBytesPerSec: currentBytesPerSec,
    ),
  );
}

class _SpeedDialogContent extends StatefulWidget {
  const _SpeedDialogContent({
    required this.title,
    required this.currentBytesPerSec,
  });

  final String title;
  final int currentBytesPerSec;

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
      Navigator.of(context).pop(kbps * 1024);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool unlimited = widget.currentBytesPerSec <= 0;
    final int currentKbps = widget.currentBytesPerSec ~/ 1024;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ListTile(
              contentPadding: EdgeInsets.zero,
              selected: unlimited,
              title: const Text('Unlimited'),
              trailing: unlimited ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(context).pop(0),
            ),
            for (final int kbps in _presetsKbps)
              ListTile(
                contentPadding: EdgeInsets.zero,
                selected: !unlimited && kbps == currentKbps,
                title: Text(rtFmtLimit(kbps * 1024)),
                trailing: !unlimited && kbps == currentKbps
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(context).pop(kbps * 1024),
              ),
            TextField(
              controller: _custom,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Custom (KB/s)',
                helperText: unlimited
                    ? 'Currently unlimited'
                    : 'Currently $currentKbps KB/s',
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
