import 'dart:convert';
import 'dart:io';

import 'package:core_models/core_models.dart';
import 'package:core_profile/core_profile.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// User-facing export and import flows for [Profile]s.
///
/// These sit between the Settings UI and `ProfileRepository`. Splitting them
/// out keeps `SettingsScreen` focused on layout - the dialogs and
/// file-picker plumbing live here.
class ProfileIo {
  ProfileIo._();

  /// Export the currently-active profile to a file the user picks.
  ///
  /// Shows a dialog with the "Include API keys & passwords" toggle (off by
  /// default - exports are safer to share when secrets are stripped) before
  /// opening the system save sheet.
  static Future<void> exportActiveProfile(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final Profile? profile = ref.read(activeProfileProvider);
    if (profile == null) {
      _snack(context, 'No profile to export yet.');
      return;
    }

    final bool? includeSecrets = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) =>
          _ExportOptionsDialog(profile: profile),
    );
    if (includeSecrets == null) {
      return;
    }

    final ProfileRepository repo = ref.read(profileRepositoryProvider);
    final String json =
        repo.exportProfile(profile, includeSecrets: includeSecrets);
    final List<int> bytes = utf8.encode(json);

    String? outputPath;
    try {
      outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Atrium profile',
        fileName: _sanitizeFileName('atrium-${profile.name}.json'),
        type: FileType.custom,
        allowedExtensions: <String>['json'],
        bytes: Uint8List.fromList(bytes),
      );
    } on PlatformException catch (e) {
      if (context.mounted) {
        _snack(context, 'Could not open save sheet: ${e.message}');
      }
      return;
    }

    if (outputPath == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    _snack(
      context,
      includeSecrets
          ? 'Exported (includes secrets - keep this file private)'
          : 'Exported (secrets stripped)',
    );
  }

  /// Pick a previously-exported profile JSON and add it as a new profile.
  ///
  /// Validates the file parses to a [Profile] and shows a preview before
  /// committing. The repository mints fresh ids on import so existing
  /// profiles and instances are never overwritten.
  static Future<void> importProfile(
    BuildContext context,
    WidgetRef ref,
  ) async {
    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        dialogTitle: 'Open Atrium profile',
        type: FileType.custom,
        allowedExtensions: <String>['json'],
        withData: true,
      );
    } on PlatformException catch (e) {
      if (context.mounted) {
        _snack(context, 'Could not open file picker: ${e.message}');
      }
      return;
    }
    if (picked == null || picked.files.isEmpty) {
      return;
    }

    final PlatformFile file = picked.files.single;
    final String? json = await _readPlatformFile(file);
    if (json == null) {
      if (context.mounted) {
        _snack(context, 'Could not read file.');
      }
      return;
    }

    Profile preview;
    try {
      preview = Profile.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      if (context.mounted) {
        _snack(context, 'Not a valid Atrium profile file.');
      }
      return;
    }

    if (!context.mounted) {
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) =>
          _ImportConfirmDialog(profile: preview),
    );
    if (confirmed != true) {
      return;
    }

    final ProfileListController controller =
        ref.read(profileListProvider.notifier);
    final Profile created = await controller.importProfile(json);
    if (!context.mounted) {
      return;
    }
    _snack(
      context,
      'Imported "${created.name}" - ${created.instances.length} '
      '${created.instances.length == 1 ? 'instance' : 'instances'}',
    );
  }

  static Future<String?> _readPlatformFile(PlatformFile file) async {
    if (file.bytes != null) {
      return utf8.decode(file.bytes!);
    }
    if (file.path != null) {
      try {
        return File(file.path!).readAsString();
      } on FileSystemException {
        return null;
      }
    }
    return null;
  }

  static String _sanitizeFileName(String s) =>
      s.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');

  static void _snack(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _ExportOptionsDialog extends StatefulWidget {
  const _ExportOptionsDialog({required this.profile});

  final Profile profile;

  @override
  State<_ExportOptionsDialog> createState() => _ExportOptionsDialogState();
}

class _ExportOptionsDialogState extends State<_ExportOptionsDialog> {
  bool _includeSecrets = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int n = widget.profile.instances.length;
    return AlertDialog(
      title: const Text('Export profile'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('"${widget.profile.name}" - $n ${n == 1 ? 'instance' : 'instances'}'),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Include API keys & passwords'),
            subtitle: Text(
              _includeSecrets
                  ? 'Anyone with this file can connect to your servers.'
                  : 'Recommended - credentials are blanked out.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: _includeSecrets ? theme.colorScheme.error : null,
              ),
            ),
            value: _includeSecrets,
            onChanged: (bool v) => setState(() => _includeSecrets = v),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_includeSecrets),
          child: const Text('Export'),
        ),
      ],
    );
  }
}

class _ImportConfirmDialog extends StatelessWidget {
  const _ImportConfirmDialog({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final int n = profile.instances.length;
    return AlertDialog(
      title: const Text('Import profile'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Profile: ${profile.name}'),
          Text('Instances: $n'),
          const SizedBox(height: 12),
          Text(
            "A new profile will be added - your existing profiles aren't "
            'touched. Instances arrive with their credentials only if the '
            'export included them.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Import'),
        ),
      ],
    );
  }
}
