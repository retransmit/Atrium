import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'emby_client.dart';

/// Launches the Emby app for a given item.
Future<void> launchEmbyDeepLink(
    BuildContext context, EmbyClient client, String itemId) async {
  final String serverId = client.serverId ?? '';
  final String urlStr = 'emby://items/$serverId/$itemId';
  final Uri uri = Uri.parse(urlStr);

  try {
    final bool launched = await launchUrl(
      uri,
      mode: LaunchMode.externalNonBrowserApplication,
    );
    if (!launched && context.mounted) {
      _showNotInstalled(context);
    }
  } catch (e) {
    if (context.mounted) {
      _showNotInstalled(context);
    }
  }
}

void _showNotInstalled(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Emby app is not installed or could not be opened.'),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 3),
    ),
  );
}
