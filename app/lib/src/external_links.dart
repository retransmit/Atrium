import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Public project links surfaced from the About section.
class AtriumLinks {
  const AtriumLinks._();

  static const String repo = 'https://github.com/retransmit/Atrium';
  static const String bugReport = '$repo/issues/new?labels=bug';
  static const String featureRequest = '$repo/issues/new?labels=enhancement';
  static const String releases = '$repo/releases';
}

/// Opens [url] in the browser.
///
/// Takes a [messenger] rather than a BuildContext so callers resolve it before
/// the await: the hand-off is async and the caller's context may be gone by the
/// time it returns. Reports failure (no browser, no handler) instead of
/// throwing an unhandled async error.
Future<void> openExternal(ScaffoldMessengerState messenger, String url) async {
  bool opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    opened = false;
  }
  if (!opened) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not open the browser')),
    );
  }
}
