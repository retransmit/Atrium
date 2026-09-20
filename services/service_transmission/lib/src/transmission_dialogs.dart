import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

// The small dialogs the web UI has: one field and a verb each. Each owns its
// text controller as a StatefulWidget: disposing it when `showDialog`
// completes is too early, since the dialog is still animating out then.

Future<String?> showTransmissionLocationDialog(
  BuildContext context, {
  required String initial,
}) =>
    showDialog<String>(
      context: context,
      builder: (BuildContext _) => const _TextDialog(
        title: 'Set torrent location',
        label: 'Location',
        verb: 'Apply',
        helper: 'A path as the server sees it. The data is moved there.',
        initial: '',
      ).withInitial(initial),
    );

Future<String?> showTransmissionRenameDialog(
  BuildContext context, {
  required String initial,
}) =>
    showDialog<String>(
      context: context,
      builder: (BuildContext _) => _TextDialog(
        title: 'Rename',
        label: 'Enter new name',
        verb: 'Rename',
        initial: initial,
      ),
    );

class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    required this.label,
    required this.verb,
    required this.initial,
    this.helper,
  });

  final String title;
  final String label;
  final String verb;
  final String initial;
  final String? helper;

  _TextDialog withInitial(String value) => _TextDialog(
        title: title,
        label: label,
        verb: verb,
        initial: value,
        helper: helper,
      );

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
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
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: widget.label,
          helperText: widget.helper,
        ),
        onSubmitted: (String v) => Navigator.of(context).pop(v.trim()),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(widget.verb),
        ),
      ],
    );
  }
}

/// Comma-separated, as the web UI takes them, with the instance's other
/// labels offered as chips that add themselves to the field.
Future<List<String>?> showTransmissionLabelsDialog(
  BuildContext context, {
  required List<String> initial,
  required List<String> suggestions,
}) =>
    showDialog<List<String>>(
      context: context,
      builder: (BuildContext _) =>
          _LabelsDialog(initial: initial, suggestions: suggestions),
    );

class _LabelsDialog extends StatefulWidget {
  const _LabelsDialog({required this.initial, required this.suggestions});

  final List<String> initial;
  final List<String> suggestions;

  @override
  State<_LabelsDialog> createState() => _LabelsDialogState();
}

class _LabelsDialogState extends State<_LabelsDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial.join(', '));

  static List<String> _parse(String text) => <String>[
        for (final String part in text.split(','))
          if (part.trim().isNotEmpty) part.trim(),
      ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit labels'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Labels',
              helperText: 'Separate labels with commas',
            ),
          ),
          if (widget.suggestions.isNotEmpty) ...<Widget>[
            const SizedBox(height: Insets.sm),
            Wrap(
              spacing: Insets.xs,
              children: <Widget>[
                for (final String s in widget.suggestions)
                  ActionChip(
                    label: Text(s),
                    onPressed: () {
                      final List<String> current = _parse(_controller.text);
                      if (!current.contains(s)) {
                        _controller.text = <String>[...current, s].join(', ');
                      }
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_parse(_controller.text)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Returns whether to trash the data as well, or null when cancelled.
Future<bool?> showTransmissionRemoveDialog(
  BuildContext context, {
  required List<String> names,
  required bool trash,
}) {
  bool withData = trash;
  return showDialog<bool>(
    context: context,
    builder: (BuildContext context) => StatefulBuilder(
      builder: (BuildContext context, StateSetter setLocal) => AlertDialog(
        title: Text(
          names.length == 1
              ? 'Remove torrent'
              : 'Remove ${names.length} torrents',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              names.length == 1 ? names.single : names.join('\n'),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: Insets.md),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: withData,
              onChanged: (bool? v) => setLocal(() => withData = v ?? false),
              title: const Text('Also trash the downloaded data'),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(withData),
            child: const Text('Remove'),
          ),
        ],
      ),
    ),
  );
}

/// The web UI's peer flag legend, letter for letter.
const List<(String, String)> transmissionPeerFlags = <(String, String)>[
  ('O', 'Optimistic unchoke'),
  ('D', 'Downloading from this peer'),
  ('d', "We would download from this peer if they'd let us"),
  ('U', 'Uploading to peer'),
  ('u', "We would upload to this peer if they'd ask"),
  ('K', "Peer has unchoked us, but we're not interested"),
  ('?', "We unchoked this peer, but they're not interested"),
  ('E', 'Encrypted connection'),
  ('H', 'Peer was discovered through DHT'),
  ('X', 'Peer was discovered through Peer Exchange (PEX)'),
  ('I', 'Peer is an incoming connection'),
  ('T', 'Peer is connected via uTP'),
];

Future<void> showTransmissionPeerFlagsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (BuildContext context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding:
              const EdgeInsets.fromLTRB(Insets.lg, 0, Insets.lg, Insets.lg),
          children: <Widget>[
            Text('Peer flags', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Insets.sm),
            for (final (String flag, String meaning) in transmissionPeerFlags)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Text(
                  flag,
                  style:
                      const TextStyle(fontFamily: 'monospace', fontSize: 16),
                ),
                title: Text(meaning),
              ),
          ],
        ),
      ),
    );
