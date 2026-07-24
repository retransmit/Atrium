import 'dart:convert';
import 'dart:typed_data';

import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'nzbget_api.dart';
import 'nzbget_providers.dart';

/// Bottom sheet for adding an NZB by URL or by picking an .nzb file.
void showNzbgetAddSheet(
  BuildContext context,
  WidgetRef ref,
  Instance instance,
) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: _AddNzbForm(instance: instance, parentRef: ref),
    ),
  );
}

class _AddNzbForm extends StatefulWidget {
  const _AddNzbForm({required this.instance, required this.parentRef});

  final Instance instance;
  final WidgetRef parentRef;

  @override
  State<_AddNzbForm> createState() => _AddNzbFormState();
}

class _AddNzbFormState extends State<_AddNzbForm> {
  final TextEditingController _url = TextEditingController();
  String? _fileName;
  String? _fileBase64;
  String _category = '';
  int _priority = 0;
  bool _addPaused = false;
  bool _busy = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['nzb'],
    );
    final PlatformFile? file = result?.files.singleOrNull;
    if (file == null) {
      return;
    }
    final Uint8List bytes = await file.readAsBytes();
    setState(() {
      _fileName = file.name;
      _fileBase64 = base64Encode(bytes);
      _url.clear();
    });
  }

  Future<void> _submit() async {
    final String url = _url.text.trim();
    final bool byFile = _fileBase64 != null;
    if (!byFile && url.isEmpty) {
      return;
    }
    setState(() => _busy = true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);
    try {
      final NzbgetApi api = await widget.parentRef
          .read(nzbgetApiProvider(widget.instance).future);
      await api.append(
        name: byFile ? _fileName! : url.split('/').last,
        content: byFile ? _fileBase64! : url,
        category: _category,
        priority: _priority,
        addPaused: _addPaused,
      );
      widget.parentRef.invalidate(nzbgetQueueProvider(widget.instance));
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('NZB added')));
    } catch (e) {
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text('Add failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<String>> categories = widget.parentRef
        .watch(nzbgetCategoriesProvider(widget.instance));
    const List<(String, int)> priorities = <(String, int)>[
      ('Very low', -100),
      ('Low', -50),
      ('Normal', 0),
      ('High', 50),
      ('Very high', 100),
      ('Force', 900),
    ];
    return SafeArea(
      child: Padding(
        padding: Insets.page,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Add NZB', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Insets.md),
            TextField(
              controller: _url,
              decoration: const InputDecoration(
                labelText: 'NZB URL',
                hintText: 'https://indexer.example/get/...',
              ),
              onChanged: (String value) {
                if (value.isNotEmpty && _fileBase64 != null) {
                  setState(() {
                    _fileName = null;
                    _fileBase64 = null;
                  });
                }
              },
            ),
            const SizedBox(height: Insets.sm),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.attach_file),
              label: Text(_fileName ?? 'Or pick an .nzb file'),
            ),
            const SizedBox(height: Insets.md),
            DropdownButtonFormField<String>(
              initialValue: _category.isEmpty ? null : _category,
              decoration:
                  const InputDecoration(labelText: 'Category (optional)'),
              items: <DropdownMenuItem<String>>[
                for (final String name
                    in categories.value ?? const <String>[])
                  DropdownMenuItem<String>(value: name, child: Text(name)),
              ],
              onChanged: (String? value) =>
                  setState(() => _category = value ?? ''),
            ),
            const SizedBox(height: Insets.sm),
            DropdownButtonFormField<int>(
              initialValue: _priority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: <DropdownMenuItem<int>>[
                for (final (String label, int value) in priorities)
                  DropdownMenuItem<int>(value: value, child: Text(label)),
              ],
              onChanged: (int? value) =>
                  setState(() => _priority = value ?? 0),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Add paused'),
              value: _addPaused,
              onChanged: (bool value) => setState(() => _addPaused = value),
            ),
            const SizedBox(height: Insets.sm),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
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
