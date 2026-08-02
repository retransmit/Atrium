import 'dart:typed_data';

import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'rtorrent_api.dart';
import 'rtorrent_providers.dart';

/// Opens the add-torrent sheet for [instance].
Future<void> showRtorrentAddSheet(BuildContext context, Instance instance) {
  return showModalBottomSheet<void>(
    context: context,
    // The sheet is a route too, so it needs the root navigator for the
    // same reason a pushed page does.
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (BuildContext context) => _RtorrentAddSheet(instance: instance),
  );
}

enum _AddMode { link, file }

/// A [ConsumerStatefulWidget] rather than a sheet borrowing the caller's `ref`:
/// the list behind it polls every few seconds, and a borrowed ref is pruned on
/// that rebuild, leaving the sheet's controls dead.
class _RtorrentAddSheet extends ConsumerStatefulWidget {
  const _RtorrentAddSheet({required this.instance});

  final Instance instance;

  @override
  ConsumerState<_RtorrentAddSheet> createState() => _RtorrentAddSheetState();
}

class _RtorrentAddSheetState extends ConsumerState<_RtorrentAddSheet> {
  final TextEditingController _link = TextEditingController();
  final TextEditingController _directory = TextEditingController();

  _AddMode _mode = _AddMode.link;
  bool _startPaused = false;
  bool _busy = false;

  Uint8List? _fileBytes;
  String? _fileName;

  @override
  void dispose() {
    _link.dispose();
    _directory.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['torrent'],
    );
    final PlatformFile? file = result?.files.singleOrNull;
    if (file == null) return;
    // Read now: on Android the pick is a content:// URI, not a reopenable path.
    final Uint8List bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _fileBytes = bytes;
      _fileName = file.name;
    });
  }

  bool get _canSubmit {
    if (_busy) return false;
    return switch (_mode) {
      _AddMode.link => _link.text.trim().isNotEmpty,
      _AddMode.file => _fileBytes != null,
    };
  }

  Future<void> _submit() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      final RtorrentApi api =
          await ref.read(rtorrentApiProvider(widget.instance).future);
      final String? dir =
          _directory.text.trim().isEmpty ? null : _directory.text.trim();
      switch (_mode) {
        case _AddMode.link:
          await api.addUrl(
            _link.text.trim(),
            start: !_startPaused,
            directory: dir,
          );
        case _AddMode.file:
          await api.addFile(
            _fileBytes!,
            start: !_startPaused,
            directory: dir,
          );
      }
      ref.invalidate(rtorrentRawTorrentsProvider(widget.instance));
      navigator.pop();
      // The `*_verbose` load commands fault on a bad URI, so reaching here
      // means rTorrent accepted it. It says nothing about the tracker yet.
      messenger.showSnackBar(
        const SnackBar(content: Text('Sent to rTorrent')),
      );
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text('Add failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: Insets.md,
        right: Insets.md,
        top: Insets.md,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Insets.md,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Add torrent', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Insets.md),
            SegmentedButton<_AddMode>(
              segments: const <ButtonSegment<_AddMode>>[
                ButtonSegment<_AddMode>(
                  value: _AddMode.link,
                  label: Text('Magnet or URL'),
                  icon: Icon(Icons.link),
                ),
                ButtonSegment<_AddMode>(
                  value: _AddMode.file,
                  label: Text('File'),
                  icon: Icon(Icons.attach_file),
                ),
              ],
              selected: <_AddMode>{_mode},
              onSelectionChanged: _busy
                  ? null
                  : (Set<_AddMode> s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: Insets.md),
            if (_mode == _AddMode.link)
              TextField(
                controller: _link,
                autofocus: true,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'magnet: link or .torrent URL',
                ),
                onChanged: (_) => setState(() {}),
              )
            else
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickFile,
                icon: const Icon(Icons.folder_open),
                label: Text(_fileName ?? 'Choose a .torrent file'),
              ),
            const SizedBox(height: Insets.md),
            TextField(
              controller: _directory,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Download folder (optional)',
                helperText: 'A path as the server sees it, not your phone',
              ),
            ),
            const SizedBox(height: Insets.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _startPaused,
              onChanged:
                  _busy ? null : (bool v) => setState(() => _startPaused = v),
              title: const Text('Add stopped'),
            ),
            const SizedBox(height: Insets.sm),
            FilledButton.icon(
              onPressed: _canSubmit ? _submit : null,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: Text(_busy ? 'Adding...' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }
}
