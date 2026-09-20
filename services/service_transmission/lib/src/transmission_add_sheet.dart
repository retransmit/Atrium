import 'dart:async';
import 'dart:typed_data';

import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/transmission_session.dart';
import 'transmission_api.dart';
import 'transmission_format.dart';
import 'transmission_providers.dart';
import 'transmission_visuals.dart';

/// Opens the add-torrent sheet for [instance].
///
/// The optional arguments prefill the sheet when another app shares torrents
/// with Atrium: [initialLink] for a magnet or `.torrent` URL, or [initialFiles]
/// for one or more `.torrent` files handed over as bytes. A batch shares one
/// download directory and one paused choice, since answering those per torrent
/// is unusable past a handful.
Future<void> showTransmissionAddSheet(
  BuildContext context,
  Instance instance, {
  String? initialLink,
  List<TorrentFileArg>? initialFiles,
}) {
  return showModalBottomSheet<void>(
    context: context,
    // The sheet is a route too, so it needs the root navigator for the
    // same reason a pushed page does.
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) => _TransmissionAddSheet(
      instance: instance,
      initialLink: initialLink,
      initialFiles: initialFiles,
    ),
  );
}

/// One `.torrent` handed to the sheet, as bytes plus a name to show.
///
/// A record rather than a class so the app can pass these in without the
/// service packages needing a shared type to depend on.
typedef TorrentFileArg = ({Uint8List bytes, String? name});

enum _AddMode { link, file }

/// A [ConsumerStatefulWidget] rather than a sheet borrowing the caller's `ref`:
/// the list behind it polls every few seconds, and a borrowed ref is pruned on
/// that rebuild, leaving the sheet's controls dead.
class _TransmissionAddSheet extends ConsumerStatefulWidget {
  const _TransmissionAddSheet({
    required this.instance,
    this.initialLink,
    this.initialFiles,
  });

  final Instance instance;
  final String? initialLink;
  final List<TorrentFileArg>? initialFiles;

  @override
  ConsumerState<_TransmissionAddSheet> createState() =>
      _TransmissionAddSheetState();
}

class _TransmissionAddSheetState
    extends ConsumerState<_TransmissionAddSheet> {
  final TextEditingController _link = TextEditingController();
  final TextEditingController _downloadDir = TextEditingController();

  _AddMode _mode = _AddMode.link;
  bool _busy = false;

  /// Null until the session says what the daemon's own default is.
  bool? _startWhenAdded;

  /// Set once the session's download folder has been filled in, so a folder
  /// the user typed is never overwritten by a late answer.
  bool _prefilled = false;

  /// The folder whose free space is being asked about, after the debounce.
  String _spacePath = '';
  Timer? _debounce;

  final List<TorrentFileArg> _files = <TorrentFileArg>[];

  /// How far through a batch the submit has got, for the button label.
  int _done = 0;

  @override
  void initState() {
    super.initState();
    final List<TorrentFileArg>? shared = widget.initialFiles;
    if (shared != null && shared.isNotEmpty) {
      _mode = _AddMode.file;
      _files.addAll(shared);
    } else if (widget.initialLink != null) {
      _link.text = widget.initialLink!;
    }
  }

  String get _fileLabel => switch (_files.length) {
        0 => 'Choose .torrent files',
        1 => _files.first.name ?? 'One torrent',
        final int n => '$n torrents',
      };

  /// A batch can take a while, so the button counts rather than just spinning.
  String get _addLabel {
    if (!_busy) {
      return _mode == _AddMode.file && _files.length > 1
          ? 'Add ${_files.length}'
          : 'Add';
    }
    if (_mode == _AddMode.file && _files.length > 1) {
      return 'Adding $_done of ${_files.length}...';
    }
    return 'Adding...';
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _link.dispose();
    _downloadDir.dispose();
    super.dispose();
  }

  /// Asks for the folder's free space once typing pauses, not per keystroke.
  void _onFolderChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _spacePath = value.trim());
    });
  }

  Future<void> _pickFile() async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['torrent'],
    );
    // pickFiles is already multi-select; the old code then threw the result
    // away with singleOrNull, so choosing more than one silently did nothing.
    final List<PlatformFile> picked = result?.files ?? <PlatformFile>[];
    if (picked.isEmpty) return;
    // Read now: on Android the pick is a content:// URI, not a reopenable path.
    final List<TorrentFileArg> read = <TorrentFileArg>[];
    for (final PlatformFile file in picked) {
      read.add((bytes: await file.readAsBytes(), name: file.name));
    }
    if (!mounted) return;
    setState(() {
      _files
        ..clear()
        ..addAll(read);
    });
  }

  bool get _canSubmit {
    if (_busy) return false;
    return switch (_mode) {
      _AddMode.link => _link.text.trim().isNotEmpty,
      _AddMode.file => _files.isNotEmpty,
    };
  }

  Future<void> _submit() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      final TransmissionApi api =
          await ref.read(transmissionApiProvider(widget.instance).future);
      final String? dir = _downloadDir.text.trim().isEmpty
          ? null
          : _downloadDir.text.trim();
      // Both add calls report a duplicate as a *success* under a different key,
      // so say which happened rather than claiming a new torrent either way.
      if (_mode == _AddMode.file) {
        // One failure does not abandon the rest of the batch; what failed is
        // reported at the end instead.
        int failed = 0;
        int duplicates = 0;
        for (final TorrentFileArg file in _files) {
          try {
            final bool added = await api.addFile(
              file.bytes,
              downloadDir: dir,
              paused: !(_startWhenAdded ?? true),
            );
            if (!added) duplicates++;
          } catch (_) {
            failed++;
          }
          if (mounted) setState(() => _done++);
        }
        ref.invalidate(transmissionRawTorrentsProvider(widget.instance));
        navigator.pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text(_batchResult(_files.length, failed, duplicates)),
          ),
        );
        return;
      }

      final bool added = await api.addUrl(
        _link.text.trim(),
        downloadDir: dir,
        paused: !(_startWhenAdded ?? true),
      );
      ref.invalidate(transmissionRawTorrentsProvider(widget.instance));
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            added ? 'Torrent added' : 'Transmission already has that torrent',
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text('Add failed: $e')));
    }
  }

  /// Transmission counts a duplicate as a success, so it gets its own tally
  /// rather than being folded into either added or failed.
  static String _batchResult(int total, int failed, int duplicates) {
    final int added = total - failed - duplicates;
    if (failed == 0 && duplicates == 0) {
      return total == 1 ? 'Torrent added' : '$total torrents added';
    }
    final List<String> parts = <String>[
      if (added > 0) '$added added',
      if (duplicates > 0) '$duplicates already there',
      if (failed > 0) '$failed failed',
    ];
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final TransmissionSession? session =
        ref.watch(transmissionSessionProvider(widget.instance)).value;
    if (session != null && !_prefilled) {
      _prefilled = true;
      _startWhenAdded ??= session.startAddedTorrents;
      if (_downloadDir.text.isEmpty && session.downloadDir.isNotEmpty) {
        _downloadDir.text = session.downloadDir;
        _spacePath = session.downloadDir;
      }
    }
    final AsyncValue<int?>? space = _spacePath.isEmpty
        ? null
        : ref.watch(
            transmissionFreeSpaceProvider((widget.instance, _spacePath)),
          );
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: Insets.lg,
        right: Insets.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + Insets.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Add torrent',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
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
                decoration: transmissionFieldDecoration(
                  context,
                  label: 'magnet: link or .torrent URL',
                  prefixIcon: const Icon(Icons.link),
                ),
                onChanged: (_) => setState(() {}),
              )
            else
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _pickFile,
                icon: const Icon(Icons.folder_open),
                label: Text(_fileLabel),
              ),
            const SizedBox(height: Insets.md),
            TextField(
              controller: _downloadDir,
              decoration: transmissionFieldDecoration(
                context,
                label: 'Download folder (optional)',
                helper: 'A path as the server sees it, not your phone',
                prefixIcon: const Icon(Icons.folder_outlined),
              ),
              onChanged: _onFolderChanged,
            ),
            if (space != null)
              Padding(
                padding: const EdgeInsets.only(top: Insets.sm),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: switch (space) {
                    AsyncData<int?>(:final int? value) => TransmissionPill(
                        icon: value == null
                            ? Icons.help_outline
                            : Icons.storage_rounded,
                        label: value == null
                            ? 'Free space unknown'
                            : '${trFmtBytes(value)} free',
                        foreground: value == null
                            ? cs.onSurfaceVariant
                            : cs.onTertiaryContainer,
                        background: value == null
                            ? cs.surfaceContainerHighest
                            : cs.tertiaryContainer,
                      ),
                    AsyncError<int?>() => TransmissionPill(
                        icon: Icons.help_outline,
                        label: 'Free space unknown',
                        foreground: cs.onSurfaceVariant,
                        background: cs.surfaceContainerHighest,
                      ),
                    _ => TransmissionPill(
                        icon: Icons.hourglass_empty_rounded,
                        label: 'Checking free space',
                        foreground: cs.onSurfaceVariant,
                        background: cs.surfaceContainerHighest,
                      ),
                  },
                ),
              ),
            const SizedBox(height: Insets.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _startWhenAdded ?? true,
              onChanged: _busy
                  ? null
                  : (bool v) => setState(() => _startWhenAdded = v),
              title: const Text('Start when added'),
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
              label: Text(_addLabel),
            ),
          ],
        ),
      ),
    );
  }
}
