import 'dart:typed_data';

import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'qbittorrent_client.dart';
import 'qbittorrent_providers.dart';

/// Bottom sheet to add a torrent to a qBittorrent instance.
///
/// Two input modes:
/// * **Link** - one or more magnet links / `.torrent` URLs (one per line).
/// * **File** - a picked `.torrent` file, uploaded as multipart bytes.
///
/// Plus optional category (dropdown of the server's categories), an optional
/// save path override, and "start paused" / "sequential" toggles.
///
/// Returns `true` via `Navigator.pop` when something was successfully added,
/// so the caller can refresh the torrent list.
class AddTorrentSheet extends ConsumerStatefulWidget {
  const AddTorrentSheet({required this.instance, super.key});

  final Instance instance;

  /// Opens the sheet and returns whether a torrent was added.
  static Future<bool> show(BuildContext context, Instance instance) async {
    final bool? added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // Root navigator so the sheet isn't swept when GoRouter rebuilds the
      // shell branch navigators (same issue as imperative page pushes).
      useRootNavigator: true,
      builder: (_) => AddTorrentSheet(instance: instance),
    );
    return added ?? false;
  }

  @override
  ConsumerState<AddTorrentSheet> createState() => _AddTorrentSheetState();
}

enum _Mode { link, file }

class _AddTorrentSheetState extends ConsumerState<AddTorrentSheet> {
  final TextEditingController _links = TextEditingController();
  final TextEditingController _savePath = TextEditingController();

  _Mode _mode = _Mode.link;
  PlatformFile? _file;
  String? _category;
  bool _paused = false;
  bool _sequential = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _links.dispose();
    _savePath.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_busy) {
      return false;
    }
    return _mode == _Mode.link
        ? _links.text.trim().isNotEmpty
        : _file != null;
  }

  Future<void> _pickFile() async {
    final FilePickerResult? res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['torrent'],
      withData: true,
    );
    if (res != null && res.files.isNotEmpty) {
      setState(() => _file = res.files.single);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final QbittorrentClient client =
          await ref.read(qbittorrentClientProvider(widget.instance).future);
      final String? savePath =
          _savePath.text.trim().isEmpty ? null : _savePath.text.trim();

      if (_mode == _Mode.link) {
        final List<String> urls = _links.text
            .split('\n')
            .map((String s) => s.trim())
            .where((String s) => s.isNotEmpty)
            .toList();
        await client.addUrls(
          urls,
          category: _category,
          savePath: savePath,
          paused: _paused,
          sequential: _sequential,
        );
      } else {
        final PlatformFile f = _file!;
        final List<int>? bytes = f.bytes;
        if (bytes == null) {
          throw StateError('Could not read the selected file.');
        }
        await client.addTorrentFile(
          Uint8List.fromList(bytes),
          filename: f.name,
          category: _category,
          savePath: savePath,
          paused: _paused,
          sequential: _sequential,
        );
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Could not add: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final EdgeInsets viewInsets = MediaQuery.of(context).viewInsets;
    final AsyncValue<List<String>> categories =
        ref.watch(qbitCategoriesProvider(widget.instance));

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SingleChildScrollView(
        padding: Insets.page,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Add torrent', style: theme.textTheme.titleLarge),
            const SizedBox(height: Insets.md),
            SegmentedButton<_Mode>(
              segments: const <ButtonSegment<_Mode>>[
                ButtonSegment<_Mode>(
                  value: _Mode.link,
                  label: Text('Link / magnet'),
                  icon: Icon(Icons.link),
                ),
                ButtonSegment<_Mode>(
                  value: _Mode.file,
                  label: Text('.torrent file'),
                  icon: Icon(Icons.attach_file),
                ),
              ],
              selected: <_Mode>{_mode},
              onSelectionChanged: (Set<_Mode> s) =>
                  setState(() => _mode = s.first),
            ),
            const SizedBox(height: Insets.md),
            if (_mode == _Mode.link)
              TextField(
                controller: _links,
                minLines: 2,
                maxLines: 5,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Magnet links or .torrent URLs',
                  hintText: 'magnet:?xt=… (one per line)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              )
            else
              OutlinedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.folder_open),
                label: Text(_file?.name ?? 'Choose a .torrent file'),
              ),
            const SizedBox(height: Insets.md),
            categories.when(
              data: (List<String> cats) => DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Category (optional)',
                  border: OutlineInputBorder(),
                ),
                items: <DropdownMenuItem<String>>[
                  const DropdownMenuItem<String>(
                    child: Text('None'),
                  ),
                  ...cats.map(
                    (String c) => DropdownMenuItem<String>(
                      value: c,
                      child: Text(c),
                    ),
                  ),
                ],
                onChanged: (String? v) => setState(() => _category = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: Insets.sm),
            TextField(
              controller: _savePath,
              decoration: const InputDecoration(
                labelText: 'Save path (optional)',
                hintText: 'Leave blank for the default',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: Insets.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start paused'),
              value: _paused,
              onChanged: (bool v) => setState(() => _paused = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Download in sequential order'),
              value: _sequential,
              onChanged: (bool v) => setState(() => _sequential = v),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: Insets.sm),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: Insets.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed:
                      _busy ? null : () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: Insets.sm),
                FilledButton.icon(
                  onPressed: _canSubmit ? _submit : null,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
