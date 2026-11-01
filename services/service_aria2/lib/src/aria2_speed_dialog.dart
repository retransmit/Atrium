import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// Preset download limits in bytes/s; 0 means unlimited.
const List<int> _presetBytes = <int>[
  0,
  512 * 1024,
  1024 * 1024,
  2048 * 1024,
  5120 * 1024,
  10240 * 1024,
  25600 * 1024,
];

/// A speed limit in bytes as a human string.
String aria2SpeedLimitLabel(int bytesPerSec) {
  if (bytesPerSec <= 0) {
    return 'Unlimited';
  }
  if (bytesPerSec % 1024 != 0) {
    return '$bytesPerSec B/s';
  }
  final int kb = bytesPerSec ~/ 1024;
  if (kb >= 1024) {
    final double mb = kb / 1024;
    return '${mb == mb.roundToDouble() ? mb.toInt() : mb.toStringAsFixed(1)} MB/s';
  }
  return '$kb KB/s';
}

/// Parses an entered speed string into bytes per second.
///
/// Accepts:
/// - Plain number: treated as KB/s (e.g. "512" -> 524288, "0" -> 0).
/// - Explicit units:
///   - Bytes: 'b', 'b/s', 'byte', 'bytes', 'bps'
///   - Kilobytes: 'k', 'kb', 'kb/s', 'kib', 'kib/s'
///   - Megabytes: 'm', 'mb', 'mb/s', 'mib', 'mib/s'
///   - Gigabytes: 'g', 'gb', 'gb/s', 'gib', 'gib/s'
///
/// Returns null if the unit is unrecognised, number is invalid/negative,
/// or formatting cannot be parsed. Empty or "0" returns 0 (unlimited).
int? parseAria2SpeedBytes(String input) {
  final String trimmed = input.trim();
  if (trimmed.isEmpty || trimmed == '0') return 0;

  final RegExpMatch? match =
      RegExp(r'^([0-9]+(?:\.[0-9]+)?)\s*([a-zA-Z/]*)$').firstMatch(trimmed);
  if (match == null) return null;

  final double? val = double.tryParse(match.group(1)!);
  if (val == null || val < 0) return null;

  final String rawUnit = (match.group(2) ?? '').toLowerCase();
  if (rawUnit.isEmpty) {
    return (val * 1024).round();
  }

  if (rawUnit == 'b' ||
      rawUnit == 'b/s' ||
      rawUnit == 'byte' ||
      rawUnit == 'bytes' ||
      rawUnit == 'bps') {
    return val.round();
  }
  if (rawUnit == 'k' ||
      rawUnit == 'kb' ||
      rawUnit == 'kb/s' ||
      rawUnit == 'kib' ||
      rawUnit == 'kib/s') {
    return (val * 1024).round();
  }
  if (rawUnit == 'm' ||
      rawUnit == 'mb' ||
      rawUnit == 'mb/s' ||
      rawUnit == 'mib' ||
      rawUnit == 'mib/s') {
    return (val * 1024 * 1024).round();
  }
  if (rawUnit == 'g' ||
      rawUnit == 'gb' ||
      rawUnit == 'gb/s' ||
      rawUnit == 'gib' ||
      rawUnit == 'gib/s') {
    return (val * 1024 * 1024 * 1024).round();
  }

  return null;
}

/// Formats bytes into a concise editable text representation.
String _bytesToEditable(int bytes) {
  if (bytes <= 0) return '';
  if (bytes % 1024 != 0) return '$bytes B';
  if (bytes % (1024 * 1024) == 0) return '${bytes ~/ (1024 * 1024)} MB';
  return '${bytes ~/ 1024}';
}

/// Picks a global download speed limit in bytes per second.
///
/// Returns the bytes/s value (0 = unlimited), or null when dismissed.
Future<int?> showAria2SpeedDialog(BuildContext context, {int currentBytes = 0}) {
  return showDialog<int>(
    context: context,
    builder: (BuildContext ctx) =>
        _GlobalSpeedDialogContent(currentBytes: currentBytes),
  );
}

class _GlobalSpeedDialogContent extends StatefulWidget {
  const _GlobalSpeedDialogContent({required this.currentBytes});

  final int currentBytes;

  @override
  State<_GlobalSpeedDialogContent> createState() =>
      _GlobalSpeedDialogContentState();
}

class _GlobalSpeedDialogContentState extends State<_GlobalSpeedDialogContent> {
  late final TextEditingController _custom = TextEditingController(
    text: _bytesToEditable(widget.currentBytes),
  );
  String? _errorText;

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _submit() {
    final int? bytes = parseAria2SpeedBytes(_custom.text);
    if (bytes == null) {
      setState(() => _errorText = 'Invalid speed (e.g. 512, 10M, 1500 B)');
      return;
    }
    Navigator.of(context).pop(bytes);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Download limit'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final int bytes in _presetBytes)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(aria2SpeedLimitLabel(bytes)),
                trailing: bytes == widget.currentBytes
                    ? const Icon(Icons.check, size: 18)
                    : null,
                onTap: () => Navigator.of(context).pop(bytes),
              ),
            const SizedBox(height: Insets.sm),
            TextField(
              controller: _custom,
              decoration: InputDecoration(
                labelText: 'Custom limit',
                hintText: 'e.g. 512, 10M, 1500 B',
                helperText: 'Numbers default to KB/s; 0 for unlimited',
                errorText: _errorText,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_errorText != null) {
                  setState(() => _errorText = null);
                }
              },
              onSubmitted: (_) => _submit(),
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
          onPressed: _submit,
          child: const Text('Set'),
        ),
      ],
    );
  }
}

/// Dialog for download and upload speed limits on a specific transfer task.
Future<({int dlBytes, int ulBytes})?> showAria2TaskSpeedDialog(
  BuildContext context, {
  required int currentDlBytes,
  required int currentUlBytes,
}) {
  return showDialog<({int dlBytes, int ulBytes})>(
    context: context,
    builder: (BuildContext ctx) => _TaskSpeedDialogContent(
      currentDlBytes: currentDlBytes,
      currentUlBytes: currentUlBytes,
    ),
  );
}

class _TaskSpeedDialogContent extends StatefulWidget {
  const _TaskSpeedDialogContent({
    required this.currentDlBytes,
    required this.currentUlBytes,
  });

  final int currentDlBytes;
  final int currentUlBytes;

  @override
  State<_TaskSpeedDialogContent> createState() =>
      _TaskSpeedDialogContentState();
}

class _TaskSpeedDialogContentState extends State<_TaskSpeedDialogContent> {
  late final TextEditingController _dlController = TextEditingController(
    text: _bytesToEditable(widget.currentDlBytes),
  );
  late final TextEditingController _ulController = TextEditingController(
    text: _bytesToEditable(widget.currentUlBytes),
  );
  String? _dlErrorText;
  String? _ulErrorText;

  @override
  void dispose() {
    _dlController.dispose();
    _ulController.dispose();
    super.dispose();
  }

  void _submit() {
    final int? dl = parseAria2SpeedBytes(_dlController.text);
    final int? ul = parseAria2SpeedBytes(_ulController.text);
    if (dl == null || ul == null) {
      setState(() {
        _dlErrorText = dl == null ? 'Invalid speed (e.g. 512, 5M, 1500 B)' : null;
        _ulErrorText = ul == null ? 'Invalid speed (e.g. 256, 2M, 1500 B)' : null;
      });
      return;
    }
    Navigator.of(context).pop((dlBytes: dl, ulBytes: ul));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Task speed limits'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _dlController,
            decoration: InputDecoration(
              labelText: 'Download limit',
              hintText: 'e.g. 512, 5M, 1500 B',
              helperText: '0 or empty for unlimited (default KB/s)',
              errorText: _dlErrorText,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_dlErrorText != null) {
                setState(() => _dlErrorText = null);
              }
            },
          ),
          const SizedBox(height: Insets.md),
          TextField(
            controller: _ulController,
            decoration: InputDecoration(
              labelText: 'Upload limit',
              hintText: 'e.g. 256, 2M, 1500 B',
              helperText: '0 or empty for unlimited (default KB/s)',
              errorText: _ulErrorText,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_ulErrorText != null) {
                setState(() => _ulErrorText = null);
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
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
