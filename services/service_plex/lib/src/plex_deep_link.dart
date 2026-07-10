import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the item in the official Plex app when possible, else launches the
/// Plex app, else shows a not-installed message. Per-item deep linking is
/// unreliable on Plex, so [webUrl] (which must be an https `app.plex.tv`
/// URL; any other host is ignored) is a best-effort target and the package
/// launch is the fallback.
Future<void> launchPlexDeepLink(BuildContext context, {String? webUrl}) async {
  if (webUrl != null) {
    final Uri? uri = Uri.tryParse(webUrl);
    // Host allowlist: only the fixed Plex web host may be launched, so no
    // caller can hand this an arbitrary https URL.
    if (uri != null &&
        uri.scheme == 'https' &&
        uri.hasAuthority &&
        uri.host == 'app.plex.tv') {
      if (Platform.isAndroid) {
        try {
          const MethodChannel channel = MethodChannel('app.atrium/launcher');
          if (await channel.invokeMethod<bool>('launchDeepLink', <String, dynamic>{'url': webUrl}) ?? false) {
            return;
          }
        } catch (_) {}
      }

      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          return;
        }
      } catch (_) {}
    }
  }
  if (Platform.isAndroid) {
    try {
      const MethodChannel channel = MethodChannel('app.atrium/launcher');
      final bool launched = await channel.invokeMethod<bool>(
            'launchPackage',
            <String, dynamic>{'package': 'com.plexapp.android'},
          ) ??
          false;
      if (launched) {
        return;
      }
    } catch (_) {}
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open the Plex app.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
