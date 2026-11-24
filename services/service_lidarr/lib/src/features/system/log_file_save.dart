import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Saves a log file's text, already read through the API, with the system
/// save sheet.
///
/// The API is the only route that carries the key as a header. A browser
/// can only be handed a URL, so the old "open in browser" download put the
/// key in its query, where the browser's history and any reverse proxy's
/// access log kept it.
Future<void> saveLidarrLogFile(
  BuildContext context, {
  required String filename,
  required Future<String> Function() read,
}) async {
  final String name = _safeFileName(filename);
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  void say(String text) => messenger.showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );

  final String content;
  try {
    content = await read();
  } on Object {
    say('Could not read $name');
    return;
  }

  final String? saved;
  try {
    saved = await FilePicker.saveFile(
      dialogTitle: 'Save log file',
      fileName: name,
      bytes: Uint8List.fromList(utf8.encode(content)),
    );
  } on PlatformException catch (e) {
    say('Could not open save sheet: ${e.message}');
    return;
  }
  if (saved != null) {
    say('Saved $name');
  }
}

/// The last segment of [reported], with characters a file name cannot hold
/// replaced. The name comes from the server, so it is never trusted as a
/// path.
String _safeFileName(String reported) {
  final String last = reported
      .split(RegExp(r'[\\/]'))
      .last
      .replaceAll(RegExp(r'[<>:"|?*]'), '_')
      .trim();
  return last.isEmpty || last == '.' || last == '..' ? 'lidarr.txt' : last;
}
