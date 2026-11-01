import 'dart:convert';
import 'dart:typed_data';

import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'aria2_api.dart';
import 'aria2_providers.dart';
import 'aria2_speed_dialog.dart';

/// One `.torrent` or `.metalink` handed to the sheet, as bytes plus a name to show.
typedef TorrentFileArg = ({Uint8List bytes, String? name});

/// Opens the add-download sheet for [instance].
Future<void> showAria2AddSheet(
  BuildContext context,
  Instance instance, {
  String? initialLink,
  List<TorrentFileArg>? initialFiles,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: _AddDownloadForm(
        instance: instance,
        initialLink: initialLink,
        initialFiles: initialFiles,
      ),
    ),
  );
}

class _AddDownloadForm extends ConsumerStatefulWidget {
  const _AddDownloadForm({
    required this.instance,
    this.initialLink,
    this.initialFiles,
  });

  final Instance instance;
  final String? initialLink;
  final List<TorrentFileArg>? initialFiles;

  @override
  ConsumerState<_AddDownloadForm> createState() => _AddDownloadFormState();
}

class _AddDownloadFormState extends ConsumerState<_AddDownloadForm> {
  final TextEditingController _uris = TextEditingController();
  final TextEditingController _dir = TextEditingController();
  final TextEditingController _out = TextEditingController();
  final TextEditingController _split = TextEditingController();
  final TextEditingController _maxConn = TextEditingController();
  final TextEditingController _speedLimit = TextEditingController();
  final TextEditingController _headers = TextEditingController();

  /// Staged files for adding, base64 encoded as aria2 wants them.
  final List<({String name, String base64, bool isMetalink})> _files =
      <({String name, String base64, bool isMetalink})>[];

  bool _pause = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final List<TorrentFileArg>? shared = widget.initialFiles;
    if (shared != null && shared.isNotEmpty) {
      _files.addAll(
        shared.map(
          (TorrentFileArg f) => (
            name: f.name ?? 'torrent',
            base64: base64Encode(f.bytes),
            isMetalink: f.name?.toLowerCase().endsWith('.metalink') ?? false,
          ),
        ),
      );
    } else if (widget.initialLink != null) {
      _uris.text = widget.initialLink!;
    }
  }

  @override
  void dispose() {
    _uris.dispose();
    _dir.dispose();
    _out.dispose();
    _split.dispose();
    _maxConn.dispose();
    _speedLimit.dispose();
    _headers.dispose();
    super.dispose();
  }

  List<String> get _lines => _uris.text
      .split(RegExp(r'[\r\n]+'))
      .map((String line) => line.trim())
      .where((String line) => line.isNotEmpty)
      .toList();

  bool get _byFile => _files.isNotEmpty;

  String get _fileLabel => switch (_files.length) {
    0 => 'Or pick a .torrent / .metalink file',
    1 => _files.first.name,
    final int n => '$n files selected',
  };

  Future<void> _pickFile() async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['torrent', 'metalink'],
    );
    if (result == null) return;

    final List<({String name, String base64, bool isMetalink})> picked =
        <({String name, String base64, bool isMetalink})>[];
    for (final PlatformFile file in result.files) {
      final Uint8List bytes = await file.readAsBytes();
      final bool isMetalink = file.name.toLowerCase().endsWith('.metalink');
      picked.add((
        name: file.name,
        base64: base64Encode(bytes),
        isMetalink: isMetalink,
      ));
    }
    if (picked.isEmpty) return;
    setState(() => _files.addAll(picked));
  }

  Future<void> _submit() async {
    final List<String> uris = _lines;
    final bool byFile = _byFile;
    if (!byFile && uris.isEmpty) return;

    setState(() => _busy = true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);
    try {
      final Aria2Api api = await ref.read(
        aria2ApiProvider(widget.instance).future,
      );

      int? speedBytes;
      if (_speedLimit.text.trim().isNotEmpty) {
        speedBytes = parseAria2SpeedBytes(_speedLimit.text.trim());
        if (speedBytes == null) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Invalid speed limit format (e.g. 512, 10M, 1500 B)'),
            ),
          );
          return;
        }
      }

      final List<String> headerLines = _headers.text
          .split('\n')
          .map((String s) => s.trim())
          .where((String s) => s.isNotEmpty)
          .toList();

      final Map<String, dynamic> options = <String, dynamic>{
        if (_dir.text.trim().isNotEmpty) 'dir': _dir.text.trim(),
        if (uris.length == 1 && _out.text.trim().isNotEmpty)
          'out': _out.text.trim(),
        if (_split.text.trim().isNotEmpty) 'split': _split.text.trim(),
        if (_maxConn.text.trim().isNotEmpty)
          'max-connection-per-server': _maxConn.text.trim(),
        if (speedBytes != null && speedBytes > 0)
          'max-download-limit': '$speedBytes',
        if (headerLines.isNotEmpty) 'header': headerLines,
        if (_pause) 'pause': 'true',
      };

      if (byFile) {
        for (final ({String name, String base64, bool isMetalink}) file
            in _files) {
          if (file.isMetalink) {
            await api.addMetalink(file.base64, options: options);
          } else {
            await api.addTorrent(file.base64, options: options);
          }
        }
      } else if (uris.length == 1) {
        await api.addUri(uris, options: options);
      } else {
        for (final String uri in uris) {
          await api.addUri(<String>[uri], options: options);
        }
      }

      if (!mounted) return;
      ref.invalidate(aria2SnapshotProvider(widget.instance));
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Added')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text('Add failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool byFile = _byFile;
    return SafeArea(
      child: SingleChildScrollView(
        padding: Insets.page,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Add download', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Insets.md),
            TextField(
              controller: _uris,
              minLines: 2,
              maxLines: 4,
              enabled: !byFile,
              decoration: const InputDecoration(
                labelText: 'URI or magnet link',
                hintText: 'magnet:?xt=urn:btih:... or https://host/file',
                helperText:
                    'One per line. Each line is added as its own download.',
              ),
              autocorrect: false,
            ),
            const SizedBox(height: Insets.sm),
            OutlinedButton.icon(
              onPressed: byFile ? null : _pickFile,
              icon: const Icon(Icons.attach_file),
              label: Text(_fileLabel),
            ),
            if (byFile)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(_files.clear),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Clear selected files'),
                ),
              ),
            const SizedBox(height: Insets.sm),
            ExpansionTile(
              title: const Text('Advanced Options'),
              tilePadding: EdgeInsets.zero,
              children: <Widget>[
                TextField(
                  controller: _dir,
                  decoration: const InputDecoration(
                    labelText: 'Download directory (optional)',
                    hintText: '/downloads/custom',
                  ),
                ),
                if (!byFile) ...<Widget>[
                  const SizedBox(height: Insets.sm),
                  TextField(
                    controller: _out,
                    decoration: const InputDecoration(
                      labelText: 'Custom output filename (single URI only)',
                      hintText: 'my_file.zip',
                    ),
                  ),
                ],
                const SizedBox(height: Insets.sm),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _split,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Split pieces',
                          hintText: 'e.g. 8',
                        ),
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: TextField(
                        controller: _maxConn,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Conn per server',
                          hintText: 'e.g. 4',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Insets.sm),
                TextField(
                  controller: _speedLimit,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Download speed limit (KB/s)',
                    hintText: '0 for unlimited',
                  ),
                ),
                const SizedBox(height: Insets.sm),
                TextField(
                  controller: _headers,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Custom HTTP Headers',
                    hintText: 'Cookie: ... or Authorization: ...',
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.xs),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start paused'),
              value: _pause,
              onChanged: (bool? value) =>
                  setState(() => _pause = value ?? false),
            ),
            const SizedBox(height: Insets.md),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}
